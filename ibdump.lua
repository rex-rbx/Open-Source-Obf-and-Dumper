--// lol ibdump
--// deserialize ironjew2
local gsub = ("").gsub
local function count_table(t)
    local c = 0
    for i, v in next, t do
        c = c + 1
    end

    return c
end

local function SerializeTable(t, p, c, s)
    local str = ""
    local n = count_table(t)
    local ti = 1
    local e = n > 0

    c = c or {}
    p = p or 1
    s = s or string.rep

    local function localized_format(v, typ)
        return typ == "table" and (c[v][2] >= p) and SerializeTable(v, p + 1, c, s) or typ == "number" and v or '"' .. tostring(v):gsub("%z", "\\0"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"):gsub("[^%w%p ]", function(c)return string.format("\\x%02x", string.byte(c))end) .. '"'
    end

    c[t] = {t, 0}

    for i, v in next, t do
        local typ_i, typ_v = type(i), type(v)
        c[i], c[v] = (not c[i] and typ_i) and {i, p} or c[i], (not c[v] and typ_v) and {v, p} or c[v]
        str = str .. s('  ', p) .. '[' .. localized_format(i, typ_i) .. '] = '  .. localized_format(v, typ_v) .. (ti < n and ',' or '') .. '\n'
        ti = ti + 1
    end

    return ('{' .. (e and '\n' or '')) .. str .. (e and s('  ', p - 1) or '') .. '}'
end
local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")
do
	local b
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
	_G = b
	_VERSION = "Luau"
end
local cenv = {
}
cenv.setmetatable = setmetatable
cenv.getmetatable = getmetatable
cenv.getfenv = function() return cenv end --// we dont want to allow people to get out of my env :\
cenv.setfenv = function(f, ...) return f end --// lol... we dont talk about this
cenv.table = table
cenv.string = string
cenv.math = math
cenv.utf8 = utf8
cenv.coroutine = coroutine
cenv.buffer = buffer --// this DOES allow for ALOT of memory usage, but docker handles that ...
cenv.pairs = pairs
cenv.ipairs = ipairs
cenv.next = next
cenv.type = type
cenv.typeof = typeof
cenv.unpack = unpack
cenv.tostring = tostring
cenv.tonumber = tonumber
cenv.assert = assert
cenv.error = error
cenv.pcall = pcall
cenv.xpcall = xpcall
cenv.print = function()end --// prevent IO spam, lmfao
cenv.select = select
cenv.rawget = rawget
cenv.rawset = rawset
cenv.rawequal = rawequal
cenv.rawlen = rawlen
cenv.warn = function()end --// prevent IO spam, lmfao

cenv._G = cenv
cenv._VERSION = "Luau"
cenv.loadstring = function(...) return function() end end

cenv.debug = debug --[[
	note:
	debug in luau (including lune, a standalone luau cli) is just
		debug.info
		debug.traceback
	so its safe dw
]]

local input = './dumps/original/' .. process.args[1]
local output = './dumps/dumped/' .. process.args[1]
local code = fs.readFile(input)
cenv.__IBDUMP = function(Deserialized)
    fs.writeFile(output, SerializeTable(Deserialized))
end
code = gsub(code, "return %w+%(([^,]+),%s*{},%s*.-%)%(%)", "return __IBDUMP(%1)")
local bytecode
pcall(function()
    bytecode = luau.compile(code, {optimizationLevel=2,debugLevel = 0}) --// compile src to bytecode first lol
end)
if bytecode == nil then
    error("Failed to compile bytecode", 2) --// meow :\
end
luau.load(bytecode, {environment = cenv})() --// load in sandbox XD