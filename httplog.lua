local _require=require
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
local clock=os.clock
local startt=clock()
local inpath="./dumps/original/"
local outpath="./dumps/dumped/"
local insert=table.insert
local fs = _require("@lune/fs")
local process = _require("@lune/process")
local luau = _require("@lune/luau")
local roblox=_require("@lune/roblox") or {}
local task=_require("@lune/task")
local targetfilename=process.args[1]
if not targetfilename then
    print("lol you didnt put a filename or luarmor link")
    return
end
local LRMPath=targetfilename:find("https://api.luarmor.net/files/v3/") and targetfilename:gsub("https://api.luarmor.net/files/v3/loaders/",""):gsub("https://api.luarmor.net/files/v3/l/","")
if not (LRMPath or fs.isFile(inpath..targetfilename)) then
    print("lol that file doesnt exist")
    return
end
local request=_require("@lune/net").request
local input = LRMPath and (function()
    local cont=request({url=targetfilename:gsub("loaders","l"),method ="GET",headers={["User-Agent"]="Xeno/RobloxApp/V1.0.9"}}).body
    targetfilename=LRMPath
    fs.writeFile(inpath..LRMPath,cont)
    return cont
end)()
or fs.readFile(inpath..targetfilename)
local oldtype=type
local tbl_to_s,tostring_complex,type
function tbl_to_s(tbl, indent)
    indent = indent or 0
    local to_string = function(value)
        if type(value) == "table" then
            return tbl_to_s(value, indent + 2)
        elseif type(value) == "string" then
            return string.format("%q", value)
        else
            return tostring_complex(value)
        end
    end

    local result = "{\n"
    local spacing = string.rep(" ", indent + 2)
    for k, v in pairs(tbl) do
        local key = "[" .. tostring_complex(k) .. "]"
        result = result .. spacing .. key .. " = " .. to_string(v) .. ",\n"
    end
    result = result .. string.rep(" ", indent) .. "}"
    return result
end

local _25msrobloxenv,_tbl= _require("./fakegame")(_require)
local _pcall=pcall
-- if not input:find(expression) then
--     print("couldnt find anything to modify")
--     return
-- end
local runcode = input
-- if runcode==input then
--     warn("regex bad :(")
-- end

local chunk, err = luau.load(runcode)
if err then
    warn("BAD OMGG"..err)
    return
end
local function debug_getinfo(func_or_level)
    local info = {}
    local function getinfo_opt(opt, name)
        local value = debug.info(func_or_level, opt)
        if value ~= nil then
            info[name] = value
        end
    end

    getinfo_opt("l", "linedefined")      -- Line defined
    getinfo_opt("f", "func")              -- Function reference
    -- getinfo_opt("u", "nups")             -- Number of upvalues
    -- getinfo_opt("c", "currentline")      -- Current line
    -- getinfo_opt("p", "nparams")          -- Number of parameters
    -- getinfo_opt("t", "ntransfer")        -- Number of transfer values
    -- getinfo_opt("v", "isvararg")         -- Is variadic
    getinfo_opt("s", "source")           -- Source
    getinfo_opt("n", "namewhat")         -- Name category
    getinfo_opt("l", "istailcall")       -- Is tail call
    getinfo_opt("s", "short_src")        -- Short source
    info.what=info.short_src:gsub("%[(.+)%]","%1")
    -- getinfo_opt("x", "ftransfer")        -- First transfer
    -- getinfo_opt("L", "lastlinedefined")  -- Last line defined
    -- print(info)
    return info
end
local r={}
local c=0
local genv={}
local cenv = {}
for i,v in _25msrobloxenv do
    cenv[i] = v
end
for i,v in roblox do
    cenv[i] = v
end
-- local _game=not commercial and roblox.deserializePlace(fs.readFile("Baseplate.rbxl")) or {}
local whitelistedUrls={
    "https://pastebin.com/",
    "https://pastefy.app/",
    "https://raw.githubusercontent.com/",
    "https://gist.githubusercontent.com/",
}
local tablefuncmt=setmetatable({},{
    index=function()return function()return _tbl end end})
local services={
    -- RunService=tablefuncmt,
    HttpService=setmetatable({},{
        __index=function(_,key)
            return function(...)
                print(key,"->",...)
                return setmetatable({},{
                    __index=function(_,key)
                        print("index",key)
                        return function (_,func)
                            print(debug_getinfo(func))
                        end
                    end
                })
            end
        end
    })
}

local getglobalfuncname=function(func)
    -- not implemented, LOL!
end
type=function(var)
    local t=oldtype(var)
    return t=="table" and getmetatable(var) and getmetatable(var).__type or t
end 

function tostring_complex(var)
    print(var,type(var))
    if type(var)=="table"then
        return tbl_to_s(var)
    elseif type(var)=="string" then
        return string.format("%q", tostring(var))
    elseif type(var)=="function" then
        local info=debug_getinfo(var)
        local name=info.namewhat~="" and info.namewhat or getglobalfuncname(var) or "~anonymous"
        return "<function n="..name..">"
    elseif type(var)=="context_type" then
        return var.__25mslocation
    else
        return tostring(var)
    end
end


local stringify=function(...)
    local data={...}
    local stringified={}
    for _,v in data do
        insert(stringified,tostring_complex(v))
    end
    return table.concat(stringified,", ")
end
local parentstringify=function(parent,...)
    local data={...}
    local stringified={}
    for i,v in data do
        if v==parent then
            insert(stringified,"self")
        else
            insert(stringified,tostring_complex(v))
        end
    end
    return table.concat(stringified,", ")
end

local function simplelog(source,...)
    print(source,...)
    local callargs=stringify(...)
    insert(r,"["..source.."]:"..callargs)
end
local function complexlog(source,options,...)
    print(source,options,...)
    if options.type=="newindex" then
        local key,value=...
        insert(r,"<ASSIGN>"..source.."."..key.." = "..stringify(value))
    elseif options.parent then
        local callargs=options.parent and parentstringify(options.parent,...) or stringify(...)
        insert(r,"["..source.."]:"..callargs)
    end
end
local spytbl
spytbl=function(pre,parent)
    local lowerpre=pre:lower()
    return setmetatable({
        __25mslocation=pre,
    },{
        __index=function(_,key)
            return spytbl(pre.."."..key,_)
        end,
        __newindex=function(_,key,value)
            complexlog(pre,{
                type="newindex",
            },key,value)
        end,
        __call=function(_,...)
            if parent then
                complexlog(pre,{parent=parent},...)
            else
                simplelog(pre,...)
            end
            local meowstr=(parent and parentstringify(...) or stringify(...))
            if #meowstr>15 then
                meowstr="..."
            end
            return spytbl(pre.."("..meowstr..")",_)
        end,
        __concat=function(_,other)
            return tostring(_)..tostring(other)
        end,
        __tostring=function()
            return pre
        end,
        __type=lowerpre:find("id") and "number" or lowerpre:find("name") or lowerpre:find"GUID" and "string" or "context_type",
    })
end
cenv.game=setmetatable({
    HttpGet=function(_,Url)
        simplelog("game:HttpGet",Url)
        for _,v in whitelistedUrls do
            if Url:sub(1,#v) == v then
                print("returning real")
                return request{url=Url,method="GET"}.body
            end
        end
        return spytbl("game:HttpGet("..tostring_complex(Url)..")")
    end,
    HttpGetAsync=function(_,Url)
        simplelog("game:HttpGetAsync",Url)
        for _,v in whitelistedUrls do
            if Url:sub(1,#v) == v then
                print("returning real")
                return request{url=Url,method="GET"}.body
            end
        end
        return spytbl("game:HttpGetAsync("..tostring_complex(Url)..")")
    end,
    IsLoaded=function()return true end,
    -- GetService=function(_,service)
    --     return spytbl("game.GetService("..service..")")
    -- end,
},{
    __index=function(_,key)
        return spytbl("game."..key,cenv.game)
    end
})

for _,name in {"Instance","Drawing","UDim","CFrame"} do
    cenv[name]=spytbl(name)
end
for _,func_name in {"request","http_request","httpRequest","HttpRequest","http.request"} do
    local requestfunc=function(cont)
        insert(r,"["..func_name.."]:"..tbl_to_s(cont))
        for _,v in whitelistedUrls do
            if cont.Url:sub(1,#v) == v then
                print("returning real")
                return request{url=cont.Url,method=cont.Method,body=cont.Body,headers=cont.Headers}.body
            end
        end
        return [[_LOL_Replace_25ms_]]
    end
    if func_name:find(".",1,true) then
        local splits=func_name:split(".")
        cenv[splits[1]]={}
        cenv[splits[1]][splits[2]]=requestfunc
    else
        cenv[func_name]=requestfunc
    end
end
local print=print
local enumspytbl
enumspytbl=function(pre)
    return setmetatable({},{
        __index=function(_,key)
            return enumspytbl(pre.."."..key)
        end,
        __type="string",
        __tostring=function()
            return "<Enum: "..pre..">"
        end
    })
end
cenv.Enum=enumspytbl("Enum")
-- cenv._25ms=function(var)
--     local vartype=type(var)
--     if vartype=="string" then
--         local wow="["..vartype.."]:"..var
--         if not r[c] or r[c]~=wow:sub(1,#wow-1) then
--             c=c+1
--         end
--         print(wow)
--         r[c]=wow
--     end
--     return var
-- end
cenv.pcall=pcall
cenv.ishooked=function()return false end
cenv.wait=function()return 1 end
local loadstringcount=0
cenv.loadstring=function(src,b)
    if type(src)=="string then" then
        simplelog("loadstring["..loadstringcount.."]",#src<10 and src or "<25ms: long_string>")
        local _func=luau.load(src,b)
        setfenv(_func,cenv)
        return _func
    elseif type(src)=="context_type" then
        simplelog("loadstring["..loadstringcount.."]",src)
        return function(...)
            if ... then simplelog("loadstring[<CALL_WITH_ARGS:"..loadstringcount..">]",...) end
            return spytbl("loadstring["..loadstringcount.."]")
        end
    end
end
cenv.ce_like_loadstring_fn=cenv.loadstring
cenv.script_key="c4ce76cd36f2afee4dcee7e87576e5fa"
cenv.getgenv=function()
    -- return genv
    return setmetatable({},{__index=genv,__newindex=function(_,k,v)
        insert(r,"genv["..stringify(k).."]="..stringify(v))
    end})
end
cenv._G=setmetatable({},{__index=genv,__newindex=function(_,k,v)
    insert(r,"_G["..stringify(k).."]="..stringify(v))
end})
-- cenv.print=function()end
cenv.print=spytbl("print")
cenv.warn=function()end
cenv.task=setmetatable({wait=function()return 1 end},{__index=task})
cenv.spawn=task.spawn
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
for i,v in cenv do
    genv[i] = v
end
cenv.setclipbard=function()end
cenv.toclipboard=function()end
cenv.assert=function()end
cenv.getfenv=function(lvl)
    return cenv
end
local env=getfenv(chunk)
env.require=function()end
local logged_undefined_fenv={}
setfenv(chunk,setmetatable(cenv,{__index=function(_,key)
    if key=="printuiwarn" then error()end
    if not env[key] and not logged_undefined_fenv[key] then
        logged_undefined_fenv[key]=true
        simplelog("fenvRead",key)
        -- return genv[key] --or spytbl("fenv."..key)
    end
    return env[key]
end,__newindex=function(_,k,v)
    insert(r,"fenv["..tostring_complex(k).."]="..tostring_complex(v))
    env[k]=v
end
}))
local success, er = _pcall(chunk)
if not success then
    simplelog("error",er)
else
    simplelog("return",er)
end
print(success,er)
fs.writeFile(outpath..targetfilename:gsub(".lua",""),table.concat(r,"\n"))
local endt=clock()-startt
print("success in",endt,"seconds!\nWritten to "..outpath..targetfilename)