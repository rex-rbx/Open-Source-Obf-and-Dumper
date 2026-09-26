local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Parser = ModuleHandler:GetModule("Parser")

local SplitStrings = StepHandler:AddStep("SplitStrings")

local Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz}~!#$%&()*+,-./:;<>?@^_"

local MinChunkLength = 2
local MaxChunkLength = 5

local function IsNode(Value)
	return type(Value) == "table" and type(Value.type) == "string"
end

local function WalkCollect(Node, Collector, Parent, ParentKey)
	if type(Node) ~= "table" then return end

	for Index, Child in ipairs(Node) do
		if IsNode(Child) then
			if Child.type == "StringLiteral" then
				Collector[#Collector + 1] = { Node = Child, Key = Index, Parent = Node }
			end
			WalkCollect(Child, Collector, Node, Index)
		elseif type(Child) == "table" then
			WalkCollect(Child, Collector, Node, Index)
		end
	end

	for Field, Value in next, Node do
		if type(Field) == "string" then
			if IsNode(Value) then
				if Value.type == "StringLiteral" then
					Collector[#Collector + 1] = { Node = Value, Key = Field, Parent = Node }
				end
				WalkCollect(Value, Collector, Node, Field)
			elseif type(Value) == "table" then
				WalkCollect(Value, Collector, Node, Field)
			end
		end
	end
end

local DecoderNames = {
	Decode85 = true,
	DecodeStrings = true,
	DecodeCode = true,
	DecodeNumbers = true,
}

local function IsProtected(Entry)
	local Parent = Entry.Parent
	if not Parent then return false end

	if Parent.type == "MapValue" and Entry.Key == "key" then
		return true
	end

	if Parent.type == "CallExpression" then
		local Base = Parent.base
		if Base and Base.type == "Identifier" then
			if DecoderNames[Base.name] then
				return true
			end
		end
		if Base and Base.type == "MemberExpression" then
			return true
		end
	end

	if Parent.type == "StringCallExpression" or Parent.type == "MemberCallExpression" then
		return true
	end

	return false
end

local function MakeDecodeCall(ShuffledChunks, ShuffleOrder)
	local Fields = {}
	local Count = #ShuffleOrder

	for Index = 1, Count do
		Fields[Index] = {
			type = "TableValue",
			value = {
				type = "NumericLiteral",
				value = ShuffleOrder[Index],
				raw = tostring(ShuffleOrder[Index]),
			},
		}
	end

	for Index = 1, Count do
		Fields[Count + Index] = {
			type = "TableValue",
			value = {
				type = "StringLiteral",
				value = ShuffledChunks[Index],
				raw = '"' .. ShuffledChunks[Index] .. '"',
			},
		}
	end

	return {
		type = "CallExpression",
		base = { type = "Identifier", name = "DecodeChunked", isLocal = true },
		arguments = {
			{
				type = "TableConstructorExpression",
				fields = Fields,
			},
		},
	}
end

local DecoderSource = [=[
local function DecodeChunked(T)
	local Half = #T / 2
	local Result = {}
	for Index = 1, Half do
		Result[Index] = T[Half + T[Index]]
	end
	return table.concat(Result)
end
]=]

function SplitStrings:apply(ast, pipeline)
	local Collected = {}
	WalkCollect(ast, Collected, nil, nil)

	local Eligible = {}
	for _, Entry in ipairs(Collected) do
		local Value = Entry.Node.value
		if Value and #Value >= 3 and Value ~= Alphabet and not IsProtected(Entry) then
			Eligible[#Eligible + 1] = Entry
		end
	end

	if #Eligible == 0 then
		return ast
	end

	for _, Entry in ipairs(Eligible) do
		local Value = Entry.Node.value

		local Chunks = {}
		local Pos = 1
		while Pos <= #Value do
			local Remaining = #Value - Pos + 1
			if Remaining <= MaxChunkLength then
				Chunks[#Chunks + 1] = string.sub(Value, Pos)
				break
			end
			local ChunkLength = math.random(MinChunkLength, MaxChunkLength)
			Chunks[#Chunks + 1] = string.sub(Value, Pos, Pos + ChunkLength - 1)
			Pos = Pos + ChunkLength
		end

		if #Chunks < 2 then
			continue
		end

		local ShuffleOrder = {}
		for Index = 1, #Chunks do
			ShuffleOrder[Index] = Index
		end

		for Index = #Chunks, 2, -1 do
			local SwapWith = math.random(1, Index)
			ShuffleOrder[Index], ShuffleOrder[SwapWith] = ShuffleOrder[SwapWith], ShuffleOrder[Index]
		end

		local ShuffledChunks = {}
		for Index = 1, #Chunks do
			ShuffledChunks[ShuffleOrder[Index]] = Chunks[Index]
		end

		local Replacement = MakeDecodeCall(ShuffledChunks, ShuffleOrder)
		for K in next, Entry.Node do
			Entry.Node[K] = nil
		end
		for K, V in next, Replacement do
			Entry.Node[K] = V
		end
	end

	if not SplitStrings.CachedDecoderAst then
		SplitStrings.CachedDecoderAst = Parser:Parse(DecoderSource)
	end
	local DecoderAst = SplitStrings.CachedDecoderAst

	for _, G in ipairs(DecoderAst.globals) do
		local Found = false
		for _, Existing in ipairs(ast.globals) do
			if Existing.name == G.name then
				Found = true
				break
			end
		end
		if not Found then
			table.insert(ast.globals, G)
		end
	end

	for I = #DecoderAst.body, 1, -1 do
		table.insert(ast.body, 1, DecoderAst.body[I])
	end

	return ast
end

return SplitStrings
