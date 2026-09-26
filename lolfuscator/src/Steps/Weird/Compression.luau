local ModuleHandler = require("../../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Parser = ModuleHandler:GetModule("Parser")

local Compression = StepHandler:AddStep("Compression")

local WindowSize = 4095
local MinMatch = 3
local MaxMatch = 18

local create = buffer.create
local fromstring = buffer.fromstring
local tostring = buffer.tostring
local readu8 = buffer.readu8
local readu32 = buffer.readu32
local writeu8 = buffer.writeu8
local writeu32 = buffer.writeu32

local band = bit32.band
local bor = bit32.bor
local lshift = bit32.lshift
local rshift = bit32.rshift
local btest = bit32.btest

function Compression:apply(Ast: table, Pipeline: table)
	local Source = Parser:ToSource(Ast, true)
	local SourceLen = #Source
	local SourceBuffer = fromstring(Source)

	local Capacity = 4 + SourceLen + math.ceil(SourceLen / 8) + SourceLen
	local OutputBuffer = create(Capacity)

	writeu32(OutputBuffer, 0, SourceLen)
	local OutPos = 4

	local Index = 0
	while Index < SourceLen do
		local FlagPos = OutPos
		OutPos += 1
		local FlagByte = 0

		for Bit = 0, 7 do
			if Index >= SourceLen then break end

			local BestMatchLength = 0
			local BestOff = 0
			local SearchStart = math.max(0, Index - WindowSize)

			for WindowPosition = SearchStart, Index - 1 do
				local Len = 0
				while Index + Len < SourceLen
					and Len < MaxMatch
					and readu8(SourceBuffer, WindowPosition + Len) == readu8(SourceBuffer, Index + Len)
				do
					Len += 1
				end
				if Len > BestMatchLength and Len >= MinMatch then
					BestMatchLength = Len
					BestOff = Index - WindowPosition
				end
			end

			if BestMatchLength >= MinMatch then
				FlagByte = bor(FlagByte, lshift(1, Bit))
				writeu8(OutputBuffer, OutPos, band(BestOff, 0xFF))
				writeu8(OutputBuffer, OutPos + 1, bor(
					lshift(band(BestOff, 0xF00) / 0x100, 4),
					BestMatchLength - MinMatch
				))
				OutPos += 2
				Index += BestMatchLength
			else
				writeu8(OutputBuffer, OutPos, readu8(SourceBuffer, Index))
				OutPos += 1
				Index += 1
			end
		end

		writeu8(OutputBuffer, FlagPos, FlagByte)
	end

	local ByteFreq = {}
	for BytePos = 0, OutPos - 1 do
		local ByteValue = readu8(OutputBuffer, BytePos)
		ByteFreq[ByteValue] = (ByteFreq[ByteValue] or 0) + 1
	end

	local UniqueByteValues = {}
	for ByteValue, _ in ByteFreq do
		UniqueByteValues[#UniqueByteValues + 1] = ByteValue
	end
	table.sort(UniqueByteValues)

	local NumUnique = #UniqueByteValues
	local UseString = NumUnique <= 92

	local Loader: string

	if UseString then
		local CharMap = {}
		local Code = 33
		for _, ByteValue in UniqueByteValues do
			if Code == 34 then Code = 35 end
			if Code == 92 then Code = 93 end
			CharMap[ByteValue] = Code
			Code += 1
		end

		local Encoded = create(OutPos)
		for BytePos = 0, OutPos - 1 do
			writeu8(Encoded, BytePos, CharMap[readu8(OutputBuffer, BytePos)])
		end
		local EncStr = tostring(Encoded)

		local ValEntries = {}
		for ByteValue, Char in CharMap do
			ValEntries[#ValEntries + 1] = "[" .. Char .. "]=" .. ByteValue
		end

		Loader = "local ValueMap={" .. table.concat(ValEntries, ",") .. "}"
			.. "local EncodedSource=\"" .. EncStr .. "\""
			.. [==[
local create=buffer.create
local readu8=buffer.readu8
local writeu8=buffer.writeu8
local readu32=buffer.readu32
local tostring=buffer.tostring
local btest=bit32.btest
local lshift=bit32.lshift
local bor=bit32.bor
local band=bit32.band
local SourceBuffer=create(#EncodedSource)
for Index=0,#EncodedSource-1 do writeu8(SourceBuffer,Index,ValueMap[string.byte(EncodedSource,Index+1)]) end
local Length=#EncodedSource
local OriginalLength=readu32(SourceBuffer,0)
]==]
	else
		local Packed = {}
		local PIdx = 0
		local BytePos = 0
		while BytePos < OutPos do
			local Word1 = readu8(OutputBuffer, BytePos)
			local Word2 = BytePos + 1 < OutPos and readu8(OutputBuffer, BytePos + 1) or 0
			local Word3 = BytePos + 2 < OutPos and readu8(OutputBuffer, BytePos + 2) or 0
			local Word4 = BytePos + 3 < OutPos and readu8(OutputBuffer, BytePos + 3) or 0
			PIdx += 1
			Packed[PIdx] = Word1 * 16777216 + Word2 * 65536 + Word3 * 256 + Word4
			BytePos += 4
		end

		Loader = "local Words={" .. table.concat(Packed, ",") .. "}"
			.. [==[
local create=buffer.create
local readu8=buffer.readu8
local writeu8=buffer.writeu8
local readu32=buffer.readu32
local tostring=buffer.tostring
local btest=bit32.btest
local lshift=bit32.lshift
local bor=bit32.bor
local band=bit32.band
local rshift=bit32.rshift
local Length=#Words*4
local SourceBuffer=create(Length)
for Index=0,#Words-1 do
local Word=Words[Index+1]
writeu8(SourceBuffer,Index*4,rshift(Word,24))
writeu8(SourceBuffer,Index*4+1,band(rshift(Word,16),255))
writeu8(SourceBuffer,Index*4+2,band(rshift(Word,8),255))
writeu8(SourceBuffer,Index*4+3,band(Word,255))
end
local OriginalLength=readu32(SourceBuffer,0)
]==]
	end

	Loader ..= [==[
local Out=create(OriginalLength)
local SourcePointer=4
local DestinationPointer=0
while SourcePointer<Length do
local FlagByte=readu8(SourceBuffer,SourcePointer)
SourcePointer=SourcePointer+1
for Bit=0,7 do
if DestinationPointer>=OriginalLength then break end
if btest(FlagByte,lshift(1,Bit)) then
local LowerByte=readu8(SourceBuffer,SourcePointer)
local UpperByte=readu8(SourceBuffer,SourcePointer+1)
SourcePointer=SourcePointer+2
local Offset=bor(LowerByte,lshift(band(UpperByte,0xF0),4))
local MatchLen=band(UpperByte,0x0F)+3
for CopyIdx=0,MatchLen-1 do writeu8(Out,DestinationPointer+CopyIdx,readu8(Out,DestinationPointer-Offset+CopyIdx)) end
DestinationPointer=DestinationPointer+MatchLen
else
writeu8(Out,DestinationPointer,readu8(SourceBuffer,SourcePointer))
SourcePointer=SourcePointer+1
DestinationPointer=DestinationPointer+1
end
end
end
local Code=tostring(Out)
local Function,Error=loadstring(Code)
return Function()
]==]

	return Parser:Parse(Loader)
end

return Compression
