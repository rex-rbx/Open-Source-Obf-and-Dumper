local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_ENCODING_LUT = table.create(4096)
local BASE64_DECODING_LUT = buffer.create(256)
do
	for i = 0, 4095 do
		local hi = bit32.rshift(i, 6) + 1
		local lo = bit32.band(i, 0x3F) + 1
		BASE64_ENCODING_LUT[i + 1] =
			bit32.bor(string.byte(BASE64_ALPHABET, hi), bit32.lshift(string.byte(BASE64_ALPHABET, lo), 8))
	end
	buffer.fill(BASE64_DECODING_LUT, 0, 0xFF)
	for i = 1, #BASE64_ALPHABET do
		buffer.writeu8(BASE64_DECODING_LUT, string.byte(BASE64_ALPHABET, i), i - 1)
	end
end
local function encode(input_buffer)
	assert(typeof(input_buffer) == "buffer", "Expected input to be a buffer")

	local input_length = buffer.len(input_buffer)

	if input_length == 0 then
		return buffer.create(0)
	end

	local output = buffer.create(((input_length + 2) // 3) * 4)
	local output_idx = 0
	local i = 0

	while i + 3 <= input_length do
		local triple = bit32.bor(
			bit32.lshift(buffer.readu8(input_buffer, i), 16),
			bit32.lshift(buffer.readu8(input_buffer, i + 1), 8),
			buffer.readu8(input_buffer, i + 2)
		)

		local high = bit32.band(bit32.rshift(triple, 12), 0xFFF) + 1
		local low = bit32.band(triple, 0xFFF) + 1

		local pair0 = BASE64_ENCODING_LUT[high]
		local pair1 = BASE64_ENCODING_LUT[low]

		buffer.writeu32(output, output_idx, bit32.bor(pair0, bit32.lshift(pair1, 16)))

		i += 3
		output_idx += 4
	end

	local rem = input_length - i

	if rem == 1 then
		local high = bit32.band(bit32.lshift(buffer.readu8(input_buffer, i), 4), 0xFF0)

		local TWO_EQUALS = 0x3D3D
		buffer.writeu32(output, output_idx, bit32.bor(BASE64_ENCODING_LUT[high + 1], bit32.lshift(TWO_EQUALS, 16)))
	elseif rem == 2 then
		local first = buffer.readu8(input_buffer, i)
		local second = buffer.readu8(input_buffer, i + 1)
		local high = bit32.bor(bit32.lshift(first, 4), bit32.rshift(second, 4))
		local low_idx = bit32.lshift(bit32.band(second, 0x0F), 2)
		local low_equals = bit32.bor(string.byte(BASE64_ALPHABET, low_idx + 1), bit32.lshift(0x3D, 8))

		buffer.writeu32(output, output_idx, bit32.bor(BASE64_ENCODING_LUT[high + 1], bit32.lshift(low_equals, 16)))
	end

	return output
end
local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local targetfilename=process.args[1]
local input = fs.readFile("./dumps/original/"..targetfilename)
local print=print
local r
local wildcard
wildcard = setmetatable({}, {
    __index = function(t, k)
        return wildcard
    end,
    __newindex = function(t, k, v)
    end,
    __call = function(t, ...)
        return wildcard
    end,
    __tostring = function()
        return "wildcard"
    end
})

do
    --local luau = require("@lune/luau")
    --local loadfn = luau.load
	local b
	local loadfn = loadstring -- Lune already exposes loadstring, so we can use it directly, however we will proxy it
	local gsub = ("").gsub
	local typeof = typeof
	local tostring = tostring
	local error = error
	local _debug = debug
	local freeze = table.freeze
	local _rawset = rawset
	local _rawget = rawget
	local _setmetatable = setmetatable
	local _getmetatable = getmetatable
	local _setfenv = setfenv
	local lsf
	local req = function(...)
		return error("not allowed", 2)
	end;
	require = req;
	local a = table.clone(getfenv())
	b = _setmetatable({_G = b}, freeze({
		__index = function(c, d)
			if typeof(d) == "number" then
				d = tostring(d)
			end
			d = gsub(d, "%z", "")
			if d == "require" then
				return req
			end;
			if d == "loadstring" then
				return lsf
			end;
			if d == "_G" then
				return b
			end
			if d == "_VERSION" then
				return "Luau"
			end;
			return _rawget(b, d) or _rawget(a, d) or a[d] or a[tonumber(d)]
		end,
		__newindex = function(c, d, e)
			_rawset(b, d, e)
		end,
		__tostring = function()
			return "sandbox"
		end
    }))
	_setfenv(0, b)
	_setfenv(1, b)
	lsf = function(...)
		local f, e = loadfn(...)
		return f and _setfenv(f, b) or nil, e
	end;
	loadstring = lsf
	_G = b
	_VERSION = "Luau"
end
local lphcarry = false
if input:find(" (does your environment support load/loadstring?)", 1, true) then
	lphcarry = true
end
local chunk, err = luau.load(input)
if err then
    warn("BAD OMGG"..err)
    return
end
local env=getfenv(chunk)
local cenv = setmetatable({},{__index=function(_,k)
    if k ~= "getfenv" and k ~= "loadstring" and k ~= "require" then
		return env[k]
	end
	return wildcard
end,__metatable=false})
cenv.print=function()end
cenv.warn=function()end
cenv.wait=function(t)return t end
cenv.setclipbard=function()end
cenv.toclipboard=function()end
local fake_file_system={}
cenv.writefile=function(path,cont)
    fake_file_system[path]=cont
end
cenv.readfile=function(path)
    return fake_file_system[path]
end
cenv.isfile=function(path)
    return fake_file_system[path]~=nil
end
cenv.isfolder=function(path)
    return fake_file_system[path]~=nil
end
cenv.mkdir=function(path)
    fake_file_system[path]={}
end
cenv.require=error
cenv.loadstring=function(src,b)
    if type(src)~="string"then
        return nil,"bad argument #1 to 'loadstring' (string expected, got "..type(src)..")"
    end
	src = src:gsub("^\239\187\191", "")
	src = src:gsub("%z", "")
    print("a",src)
    r=src:find("-- http",1,true) and r or src
	local ok, _func, er = pcall(luau.load, src, b)
	if not ok then
		return nil, _func
	end
	if not _func then
		return nil, er
	end
    setfenv(_func,cenv)
    return _func
end
cenv.require=function()return nil end
cenv.getgenv=function()
    return cenv
end
cenv.getfenv = function(f, ...)
	return cenv
end
cenv.game = setmetatable({
	GetService = function(self, name)
		if name == "EncodingService" then
			return {
				DecompressBuffer = function(self, buffer)
					return serde.decompress(buffer, "Zstd")
				end,
				CompressBuffer = function(self, buffer)
					return serde.compress(buffer, "Zstd")
				end
			}
		end
		return wildcard
	end,
	IsLoaded = function(self, ...) return true end,
	Loaded = {Wait = function() end},
	PlaceId = 123456789,
	GameId = 987654321,
	gameId = 987654321,
	PlaceVersion = 1,
	Name = "Ugc",
	name = "Ugc",
	JobId = setmetatable({V = "meow", __typeof = "string", __type = "string"}, {__index = string, __newindex = error, __metatable = false, __len = function() return 36 end, __tostring = function() return "meow" end}),
}, {__index = wildcard, __newindex = error, __metatable = false})
cenv.workspace = setmetatable({}, {__index = wildcard, __newindex = error, __metatable = false})
cenv.Game = cenv.game
cenv.Workspace = cenv.workspace
cenv.typeof = function(v)
	if typeof(v) == "table" and rawget(v, "__typeof") then
		return rawget(v, "__typeof")
	end
	return typeof(v)
end
cenv.type = function(v)
	if type(v) == "table" and rawget(v, "__type") then
		return rawget(v, "__type")
	end
	return type(v)
end
if lphcarry == true then
	cenv.pcall = function(f, ...)
		if f == cenv.loadstring then
			local src, chunkname = ...
			if not chunkname or not chunkname:find"Luraph" then
				return true, cenv.loadstring(src, chunkname)
			end
			return true, function(buf)
				local Var = src:match("local (.)=")
				local original_src = src
				local src_ = original_src:sub(5+1+#Var+1+1)
				local src = [==[local BASE64_ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"local BASE64_ENCODING_LUT=table.create(4096)local BASE64_DECODING_LUT=buffer.create(256)do for i=0,4095 do local hi=bit32.rshift(i,6)+1;local lo=bit32.band(i,63)+1;BASE64_ENCODING_LUT[i+1]=bit32.bor(string.byte(BASE64_ALPHABET,hi),bit32.lshift(string.byte(BASE64_ALPHABET,lo),8))end;buffer.fill(BASE64_DECODING_LUT,0,255)for i=1,#BASE64_ALPHABET do buffer.writeu8(BASE64_DECODING_LUT,string.byte(BASE64_ALPHABET,i),i-1)end end;local function decode(input_buffer)local input_length=buffer.len(input_buffer)if input_length==0 then return buffer.create(0)end;while input_length>0 and buffer.readu8(input_buffer,input_length-1)==61 do input_length-=1 end;if input_length==0 then error("Invalid base64 input",2)end;local output_length=math.floor((3*input_length)/4)local output=buffer.create(output_length)local read_offset=0;local write_offset=0;while write_offset+4<=output_length do local b4=buffer.readu8(BASE64_DECODING_LUT,buffer.readu8(input_buffer,read_offset+3))local b3=buffer.readu8(BASE64_DECODING_LUT,buffer.readu8(input_buffer,read_offset+2))local b2=buffer.readu8(BASE64_DECODING_LUT,buffer.readu8(input_buffer,read_offset+1))local b1=buffer.readu8(BASE64_DECODING_LUT,buffer.readu8(input_buffer,read_offset))if bit32.bor(b1,b2,b3,b4)>=64 then error("Invalid base64 input",2)end;read_offset+=4;buffer.writeu32(output,write_offset,bit32.byteswap(b1*67108864+b2*1048576+b3*16384+b4*256))write_offset+=3 end;local u24be,nbits=0,0;while read_offset<input_length do local b=buffer.readu8(BASE64_DECODING_LUT,buffer.readu8(input_buffer,read_offset))read_offset+=1;if b>=64 then error("Invalid base64 input",2)end;u24be=u24be*64+b;nbits+=6 end;while nbits>=8 do buffer.writeu8(output,write_offset,bit32.rshift(u24be,nbits-8))nbits-=8;write_offset+=1 end;if nbits==6 or(nbits==2 and bit32.btest(u24be,3))or(nbits==4 and bit32.btest(u24be,15))then error("Invalid base64 input",2)end;return output end;]==] .. "local " .. 
				Var .. 
				" = " .. "decode(buffer.fromstring(" .. buffer.tostring(encode(buf)) ..
				"));" 
				.. src_
				r = src
				return function() end
			end
		end
		return pcall(f, ...)
	end
end
setfenv(chunk,cenv)
local s, e = pcall(chunk)
if not s then
	error(e, 0)
end
fs.writeFile("./dumps/dumped/"..targetfilename,r)