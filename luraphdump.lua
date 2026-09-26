local _require,_getfenv
    = require, getfenv
local robloxenvemulator, _tbl = require("./fakegame")(_require)
do
	local b
	local loadfn = loadstring
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
	b =     _setmetatable({_G = b}, freeze({
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

local fs = _require("@lune/fs")
local process = _require("@lune/process")
local luau = _require("@lune/luau")
local roblox=_require("@lune/roblox")
local task=_require("@lune/task")
local serde=_require("@lune/serde")
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
    local cont=request({url=targetfilename:gsub("loaders","l"),method ="GET",headers={["User-Agent"]="Roblox/WinInet"}}).body
    targetfilename=LRMPath
    fs.writeFile(inpath..LRMPath,cont)
    return cont
end)()
or fs.readFile(inpath..targetfilename)

local methods={
    {
        expressions={"(%a%a?%[%a%a?%[%w[%w_]*%]%]%s*%.%.%s*%a%a?%[%a%a?%[%w[%w_]*%]%])"},
        replace="_25ms(%1)"
    },
    {
        expressions={
            "(local function [%a%d_]+%([%a%d_]+,%s?[%a%d_]+%).-)(local [%a%d_]+,[%a%d_]+,[%a%d_]+,[%a%d_]+.-%]%)?;)(.-[%a%d_]+%s?=%s?%(?function%(%.%.%.)",
            "([%a%d_]+=%(function%([%a%d_]+,%s?[%a%d_]+%).-)(local [%a%d_]+,[%a%d_]+,[%a%d_]+,[%a%d_]+.-%]%)?;)(.-[%a%d_]+%s?=%s?%(?function%(%.%.%.)"
        },
        -- replace=function(pre,interest,post)
        --     local var1=interest:split(",")[4]
        --     local var2=interest:split(",")[5]
        --     local balls=[[local _realvar=%s;%s=setmetatable({},{__index=function(o,J)local V=_realvar[J]_25ms(V)return V end})]]
        --     local injection=balls:format(var1,var1)..balls:format(var2,var2)
        --     print(pre,"\n",interest,"\n",injection,"\n",post)
        --     return pre..interest..injection..post
        -- end
        replace=function(pre,interest,post)
            local balls=[[local _realvar=%s;%s=setmetatable({},{__index=function(o,J)local V=_realvar[J]_25ms(V)return V end})]]
            local injection=""
            for i,v in interest:split(",") do
                v=v:gsub("local ","")
                if #v == 1 then
                    print(i,v)
                    injection=injection..balls:format(v,v)..";"
                end
            end
            -- print(pre,"\n",interest,"\n",injection,"\n",post)
            return pre..interest..injection..post
        end
    },
}
local function applymethods(input)
    local done=false
    for _,method in methods do
        for _,expression in method.expressions do
            if input:find(expression) then
                input=input:gsub(expression,method.replace)
                done=true
                break
            end
        end
        if done then break end
    end
    return input
end
local _pcall=pcall
-- if not input:find(expression) then
--     print("couldnt find anything to modify")
--     return
-- end
-- fs.writeFile("zzRun.lua",input)
local runcode = applymethods(input)
-- if runcode==input then
--     warn("regex bad :(")
-- end
if false then -- insert unminified
    local buffer={}
    local insert=table.insert
    local _25ms=function(s)
        insert(buffer,s)
        return s
    end
    local print,next,type,wait
        = print,next,type,wait or task.wait
    local log=function(s)
        print(s)
        -- appendfile("logs.txt",tostring(s).."\n")
    end
    local wait=task and task.wait or wait
    task.spawn(function()
        while wait(3) do
            for i,v in next,buffer do
                if type(v)=="string" and buffer[i-1] ~= v:sub(1,#v-1)then
                    log(v)
                end
                buffer[i-1] = nil
            end
        end
    end)
end
-- fs.writeFile("zzRun.lua",[[local h={}local g=table.insert local _25ms=function(P)g(h,P)return P end local l,O,A,B=print,next,type,wait or task.wait local d=function(h)l(h)end local m=task and [...]
local chunk, err = luau.load(runcode)
if err then
    warn("BAD OMGG"..err)
    return
end

local r={}
local c=0
local genv={}
local ogenv=_getfenv()
local found={}
local cenv; cenv = setmetatable({},{__index=function(_,key)
    if not found[key] then
        found[key]=true
        print("found",key)
    end
    return rawget(cenv,key) or ogenv[key] or _tbl
end})
for i,v in roblox do
    cenv[i] = v
end
local whitelistedUrls={
"https://pastebin.com",
"https://pastefy.app",
"https://raw.githubusercontent",
"https://luarmor.net"
}
local services={
    RunService={
        IsStudio=function()return false end,
        IsRunning=function()return true end,
        IsServer=function()return false end,
        IsClient=function()return true end,
        IsEdit=function()return false end,
        IsRunMode=function()return false end,
        RunState = {value = 1, Name = "Running"},
        Heartbeat = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }),
        RenderStepped = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }),
        Stepped = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }),
        PreRender = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }),
        PreSimulation = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }), 
        PostSimulation = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }), 
        PreAnimation = setmetatable({},{
            __index=function(_,key)
                return _tbl
            end
        }),
    },
    EncodingService={
        DecompressBuffer = function(s, buf) return buffer.fromstring(serde.decompress("Zstd", buf)) end,
        CompressBuffer = function(s, buf) return buffer.fromstring(serde.compress("Zstd", buf)) end
    },
    Players = {
        LocalPlayer = setmetatable({
            Name = "meower",
            DisplayName = "JohnNotDoe",
            UserId = 0,
            GetMouse = function()
                return _tbl()
            end
        },{
            __index = function(_,key)
                return _tbl()
            end,
            __newindex = error,
            __metatable = false
        })
    }
}
cenv.ws = {
    connect = function()return _tbl()end
}
cenv.WebSocketClient = cenv.ws
cenv.websocket = cenv.ws
cenv.Websocket = cenv.ws
cenv.WebSocket = cenv.ws
cenv.require=function()return _tbl()end
cenv.request = function(data)
    for _,v in whitelistedUrls do
        if data.url:sub(1,#v) == v then
            for i, v in data do
                data[i] = nil
                data[i:sub(1,1):lower()..i:sub(2)] = v
            end
            local res = request(data)
            for i,v in res do
                res[i] = nil
                res[i:sub(1,1):upper()..i:sub(2)] = v
            end
            return res
        end
    end

    return {Body = "_LOL_Replace_25ms_", Headers = {}}
end
local _NOP = function()return _tbl() end
cenv.http_request = request
cenv.http = {request = request}
cenv.httprequest = request
cenv.game=setmetatable({
    HttpGet=function(_,Url)
        for _,v in whitelistedUrls do
            if Url:sub(1,#v) == v then
                return request{url=Url,method="GET"}.body
            end
        end
        return [[_LOL_Replace_25ms_]]
    end,
    IsLoaded=function()
        return true 
    end,
    GetService=function(_,service)
        return services[service] or rawget(robloxenvemulator, 'game'):GetService(service) or _tbl
    end,
    PlaceId=14004668761
},{
    __index=function(_,key)
        return services[key] or rawget(robloxenvemulator, 'game')[key] or _tbl
    end
})
cenv.getrenv = function()
    return cenv
end
cenv.getrawmetatable = function()
    return setmetatable({}, {__index = function()
        return _tbl() 
    end})
end
cenv.setrawmetatable = function()
end
cenv.Vector2 = _tbl()
cenv.Vector3 = _tbl()
cenv.CFrame = _tbl()
cenv.Color3 = _tbl()
cenv.Region3 = _tbl()
cenv.Region3int16 = _tbl()
cenv.Vector3int16 = _tbl()
cenv.NumberRange = _tbl()
cenv.NumberSequence = _tbl()
cenv.NumberSequenceKeypoint = _tbl()
cenv.PhysicalProperties = _tbl()
cenv.TweenInfo = _tbl()
cenv.PathWaypoint = _tbl()
cenv.Vector2int16 = _tbl()
cenv.Path2DControlPoint = _tbl()
cenv.Workspace = cenv.workspace
local SettingsObject = setmetatable({},{
    __index=function(_,key)
        return _tbl()
    end
})
cenv.Settings = SettingsObject
cenv.settings = SettingsObject
cenv.userSettings = SettingsObject
cenv.UserSettings = SettingsObject
cenv.GlobalSettings = SettingsObject
cenv.unpack = unpack
cenv.newproxy = newproxy
cenv.next = next
cenv.type = type
cenv.typeof = type
cenv.tonumber = tonumber
cenv.tostring = tostring
cenv.os = os
cenv.pairs = pairs
cenv.ipairs = ipairs
cenv.getmetatable = getmetatable
cenv.setmetatable = setmetatable
cenv.rawget = rawget
cenv.rawset = rawset
cenv.select = select
cenv.debug = {
    info = debug.info, 
    traceback = function(lol)
        if typeof(lol) == "string" then
            return "stack traceback:\nLocalScript\n"..lol
        end
        return "stack traceback:\nLocalScript"
    end
}
local print=print
cenv._25ms=function(var)
    local vartype=type(var)
    if vartype=="string" then
        local wow="["..vartype.."]:"..var
        if not r[c] or r[c]~=wow:sub(1,#wow-1) then
            c=c+1
        end
        print(wow)
        r[c]=wow
    end
    return var
end
cenv.pcall=function(...)
    local res={_pcall(...)}
    if res[1] == false then
        res[2] = tostring(res[2])
    end
    return unpack(res)
end
cenv.error=function()
end
cenv.wait=function(t)
    return t 
end
cenv.loadstring=function(src,b)
    if rawequal(src,"_LOL_Replace_25ms_") then
        return function()return _tbl()end
    end
    return setfenv(luau.load(applymethods(src),{debugName=b}),cenv)
end
cenv.ce_like_loadstring_fn=cenv.loadstring
cenv.script_key="c4ce76cd36f2afee4dcee7e87576e5fa"
cenv.getgenv=function()
    return genv
end
cenv.getfenv = function(lvl, ...)
    return cenv
end
for i,v in cenv do
    genv[i] = v
end
cenv.print=function()end
cenv.warn=function()end
cenv.task=setmetatable({
    wait=function(t)
        return t
    end, 
    delay = task.delay, 
    defer = task.defer, 
    spawn = task.spawn, 
    cancel = task.cancel
},
{
    __index=function(_,key)
        return function()return _tbl()end
    end
})
cenv.spawn=task.spawn
cenv.table = table
cenv.string = string
cenv.math = math
cenv.utf8 = utf8
cenv.coroutine = coroutine
setfenv(chunk,cenv)
cenv.bit32 = bit32
cenv.buffer = buffer
cenv.identifyexecutor = function()return "Xeno", "v1.3.60" end -- i identify as a xeno 😂😂😂
cenv.getexecutorname = function()return "Xeno" end
for i,v in robloxenvemulator do
    if not cenv[i] then
        cenv[i] = v
    end
end
local success, er = _pcall(chunk)
if not success then
    print(er)
    c=c+1
    r[c]="-- The script errored here. Which means any string constants after this wont be captured in this dump.\n--[[\nError: "..tostring(er).."\n--]]"
end
fs.writeFile(outpath..targetfilename,table.concat(r,"\n"))
local endt=clock()-startt
print("success in",endt,"seconds!\nWritten to "..outpath..targetfilename)