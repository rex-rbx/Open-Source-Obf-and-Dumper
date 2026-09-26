local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")
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
	local fenvFnc = function()
		return b
	end
	local sfenv = function(fn, a)
		for i, v in next, a do
			if typeof(i) ~= "string" and typeof(i) ~= "number" then
				return error("not allowed", 2)
			end;
			if typeof(i) == "string" then
				i = gsub(i, "%z", "")
			end
			rawset(b, i, v)
		end
		return typeof(fn) == "function" and fn or nil
	end
	local lsf
	local req = function(...)
		return error("not allowed", 2)
	end;
	require = req;
	local a = table.clone(getfenv())
	getfenv = fenvFnc
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
			if d == "getfenv" then
				return fenvFnc
			end;
			if d == "setfenv" then
				return sfenv
			end;
			if d == "_G" then
				return b
			end;
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
	setfenv = sfenv
	lsf = function(...)
		local f, e = loadfn(...)
		return f and _setfenv(f, b) or nil, e
	end;
	loadstring = lsf
	_G = b
	_VERSION = "Luau"
end
local targetfilename=process.args[1]
local input = fs.readFile("dumps\\original\\"..targetfilename)

result=""

v0,v1,v2,v4,v5,v6=string.char,string.byte,string.sub,function(a, b)
    local result = 0
    local bit = 1
    while a > 0 or b > 0 do
        if (a % 2 + b % 2) == 1 then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end,table.concat,table.insert
local v7end
local function extract_v7(input)
    -- Find the start of the function definition
    local function_start = input:find("local function v7")
    if not function_start then return nil, nil, nil end

    -- Extract the parameter list
    local param_start = input:find("%(", function_start)
    local param_end = input:find("%)", param_start)
    if not param_start or not param_end then return nil, nil, nil end

    local params = input:sub(param_start + 1, param_end - 1)

    -- Extract the body of the function
    local body_start = param_end + 1
    if not body_start then return nil, nil, nil end

    local do_count, body_end = 1, body_start
    while body_end <= #input do
        local word = input:sub(body_end, body_end + 4):match("^%w+")
        if word == "do" or word=="then" then
            do_count = do_count + 1
            body_end += #word
            print("found",word,do_count)
        elseif word == "end" then
            do_count = do_count - 1
            print("found",word,do_count)
            if do_count == 0 then
                break
            end
            body_end += 3
        else
            body_end += 1
        end
    end

    if do_count ~= 0 then return nil, nil, nil end -- Mismatched do-end block

    local body = input:sub(body_start, body_end + 2)
    v7end = body_end + 2
    local variable1, variable2 = params:match("(.-),%s*(.*)")
    return variable1, variable2, body
end

local variable1, variable2,decode = extract_v7(input)
local wow=input:find("local function v7")
local runcode=input:sub(1,wow-1).."return function("..variable1..","..variable2..")"..decode
print(runcode)

local s,chunk=pcall(luau.load,runcode)
if not s then error"couldnt get ze func correctly" end
local cenv={}
cenv.require=error
cenv.getfenv=function(lvl)
    return cenv
end
setfenv(chunk,setmetatable(cenv,{__index=getfenv(chunk)}))
local decode,err = chunk()


local result=input:sub(v7end+2,#input):gsub('v7%(%"(.-)%",%s?%"(.-)%"%)',function(a,b)
        -- print(b)
        a=setfenv(luau.load('return "'..a..'"')(), cenv)
        b=setfenv(luau.load('return "'..b..'"')(), cenv)
        return "'"..decode(a,b):gsub("'","\\'").."'"
    end)

fs.writeFile("dumps\\dumped\\"..targetfilename,result)
print("success")