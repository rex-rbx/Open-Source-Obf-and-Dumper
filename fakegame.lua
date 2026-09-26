return function(require)
    local task = require("@lune/task")
    local net = require("@lune/net")
    local roblox = require("@lune/roblox")

    local function noop(...) return nil end
    local env

    local function newProxy(name)
        local proxy = {}
        local mt = {}

        local function methodResult(methodName)
            if methodName == "GetChildren" or methodName == "GetDescendants" or methodName == "GetPlayers" then
                return {}
            end
            if methodName == "IsA" or methodName == "IsDescendantOf" or methodName == "IsAncestorOf" then
                return false
            end
            if methodName == "FindFirstChild" or methodName == "FindFirstChildOfClass" or methodName == "FindFirstAncestor" or methodName == "WaitForChild" then
                return newProxy(tostring(methodName))
            end
            if methodName == "Clone" then
                return newProxy(name)
            end
            if methodName == "Destroy" or methodName == "Remove" or methodName == "ClearAllChildren" then
                return nil
            end
            if methodName == "Connect" or methodName == "Once" then
                return { Disconnect = noop, Connected = true }
            end
            if methodName == "Wait" then
                return nil
            end
            if methodName == "JSONEncode" then
                return "{}"
            end
            if methodName == "JSONDecode" then
                return {}
            end
            if methodName == "GenerateGUID" then
                return "00000000-0000-0000-0000-000000000000"
            end
            return newProxy(tostring(methodName))
        end

        mt.__index = function(_, key)
            if key == "ClassName" then return name or "Instance" end
            if key == "Name" then return name or "FakeInstance" end
            if key == "Parent" then return nil end
            if key == "Value" then return newProxy("Value") end
            if key == "Changed" or key == "ChildAdded" or key == "ChildRemoved" or key == "Touched" then
                return newProxy(tostring(key))
            end
            return function(...)
                return methodResult(tostring(key), ...)
            end
        end

        mt.__newindex = noop
        mt.__call = function()
            return newProxy(name)
        end
        mt.__tostring = function()
            return name or "FakeInstance"
        end
        mt.__len = function()
            return 0
        end
        mt.__iter = function()
            return function()
                return nil
            end
        end
        mt.__concat = function(a, b)
            return tostring(a) .. tostring(b)
        end
        mt.__add = function() return 0 end
        mt.__sub = function() return 0 end
        mt.__mul = function() return 0 end
        mt.__div = function() return 0 end
        mt.__idiv = function() return 0 end
        mt.__mod = function() return 0 end
        mt.__pow = function() return 0 end
        mt.__unm = function() return 0 end
        mt.__lt = function() return false end
        mt.__le = function() return false end

        return setmetatable(proxy, mt)
    end

    local function makeConstructor(className)
        return setmetatable({}, {
            __call = function(_, ...)
                return {
                    ClassName = className,
                    args = { ... },
                    X = select(1, ...) or 0,
                    Y = select(2, ...) or 0,
                    Z = select(3, ...) or 0,
                    R = select(1, ...) or 0,
                    G = select(2, ...) or 0,
                    B = select(3, ...) or 0
                }
            end,
            __index = function(_, key)
                if key == "new" or key == "fromRGB" or key == "fromHSV" or key == "Angles" or key == "lookAt" then
                    return function(...)
                        return makeConstructor(className)(nil, ...)
                    end
                end
                return makeConstructor(className .. "." .. tostring(key))
            end
        })
    end

    local fakeEnum = roblox.Enum
    local fakeGame = newProxy("DataModel")

    fakeGame.GetService = function(_, serviceName)
        serviceName = tostring(serviceName)
        if serviceName == "Players" then
            return {
                LocalPlayer = newProxy("LocalPlayer"),
                GetPlayers = function() return {} end,
                PlayerAdded = newProxy("PlayerAdded")
            }
        end
        if serviceName == "HttpService" then
            return {
                JSONEncode = function() return "{}" end,
                JSONDecode = function() return {} end,
                GenerateGUID = function() return "00000000-0000-0000-0000-000000000000" end,
                UrlEncode = function(_, value) return tostring(value or "") end
            }
        end
        if serviceName == "RunService" then
            return {
                IsClient = function() return true end,
                IsServer = function() return false end,
                Heartbeat = newProxy("Heartbeat"),
                RenderStepped = newProxy("RenderStepped"),
                Stepped = newProxy("Stepped")
            }
        end
        if serviceName == "TweenService" then
            return {
                Create = function()
                    return { Play = noop, Cancel = noop, Completed = newProxy("Completed") }
                end
            }
        end
        return newProxy(serviceName)
    end
    fakeGame.IsLoaded = function() return true end
    fakeGame.HttpGet = function(_, url)
        local ok, response = pcall(function()
            return net.request({ url = tostring(url), method = "GET", headers = {['User-Agent']="Roblox/WinInet"} }).body
        end)
        return ok and response or ""
    end
    fakeGame.HttpGetAsync = fakeGame.HttpGet
    fakeGame.PlaceId = 0
    fakeGame.JobId = "00000000-0000-0000-0000-000000000000"
    fakeGame.GameId = 0
    fakeGame.Loaded = newProxy("Loaded")

    local fakeFilesystem = {}

    local function fakeRequest(options)
        options = options or {}
        local url = options.Url or options.url or ""
        local ok, response = pcall(function()
            return net.request({
                url = tostring(url),
                method = options.Method or options.method or "GET",
                headers = options.Headers or options.headers or {['User-Agent']="Roblox/WinInet"}
            })
        end)
        if ok and response then
            return {
                Success = response.ok ~= false,
                StatusCode = response.statusCode or response.status or 200,
                Body = response.body or "",
                Headers = response.headers or {}
            }
        end
        return { Success = false, StatusCode = 0, Body = "", Headers = {} }
    end

    env = {
        game = fakeGame,
        Game = fakeGame,
        workspace = newProxy("Workspace"),
        Workspace = newProxy("Workspace"),
        script = newProxy("Script"),

        Instance = {
            new = function(className)
                return newProxy(className)
            end
        },
        Vector2 = makeConstructor("Vector2"),
        Vector3 = makeConstructor("Vector3"),
        Vector2int16 = makeConstructor("Vector2int16"),
        Vector3int16 = makeConstructor("Vector3int16"),
        CFrame = makeConstructor("CFrame"),
        UDim = makeConstructor("UDim"),
        UDim2 = makeConstructor("UDim2"),
        Color3 = makeConstructor("Color3"),
        ColorSequence = makeConstructor("ColorSequence"),
        ColorSequenceKeypoint = makeConstructor("ColorSequenceKeypoint"),
        NumberRange = makeConstructor("NumberRange"),
        NumberSequence = makeConstructor("NumberSequence"),
        NumberSequenceKeypoint = makeConstructor("NumberSequenceKeypoint"),
        BrickColor = makeConstructor("BrickColor"),
        Ray = makeConstructor("Ray"),
        RaycastParams = makeConstructor("RaycastParams"),
        Region3 = makeConstructor("Region3"),
        Rect = makeConstructor("Rect"),
        TweenInfo = makeConstructor("TweenInfo"),
        Enum = fakeEnum,
        task = {
            wait = task.wait,
            spawn = task.spawn,
            defer = task.defer,
            delay = task.delay,
            cancel = noop
        },
        wait = task.wait,
        spawn = task.spawn,
        delay = task.delay,
        tick = os.clock,
        time = os.clock,
        elapsedTime = os.clock,
        request = fakeRequest,
        http_request = fakeRequest,
        http = { request = fakeRequest },
        readfile = function(path,...) return fakeFilesystem[path] or "" end,
        writefile = function(path, content,...) fakeFilesystem[path] = tostring(content or "") end,
        appendfile = function(path, content,...) fakeFilesystem[path] = (fakeFilesystem[path] or "") .. tostring(content or "") end,
        isfile = function(path,...) return fakeFilesystem[path] ~= nil end,
        isfolder = function(path,...) return type(fakeFilesystem[path]) == "table" end,
        makefolder = function(path,...) fakeFilesystem[path] = fakeFilesystem[path] or {} end,
        delfile = function(path,...) fakeFilesystem[path] = nil end,
        listfiles = function(...) return {} end,

        setclipboard = noop,
        setrbxclipboard = noop,
        toclipboard = noop,
        queue_on_teleport = noop,
        setfpscap = noop,

        identifyexecutor = function(...) return 'Krnl', "2.0.7" end,
        getexecutorname = function(...) return 'Krnl' end,
        isexecutorclosure = function(...) return false end,
        checkcaller = function() return false end,
        newcclosure = function(fn) return fn end,
        hookfunction = function(_, replacement,...) return replacement end,
        hookmetamethod = function(_, _, replacement,...) return replacement end,
        getnamecallmethod = function() return "" end,
        setnamecallmethod = noop,
        getrawmetatable = getmetatable,
        setrawmetatable = setmetatable,
        setreadonly = noop,
        isreadonly = function(...) return false end,

        getgc = function(...) return {} end,
        getreg = function(...) return {} end,
        getregistry = function(...) return {} end,
        getinstances = function(...) return {} end,
        getnilinstances = function(...) return {} end,
        getscripts = function(...) return {} end,
        getloadedmodules = function(...) return {} end,
        getconnections = function(...) return {} end,
        firesignal = noop,
        fireclickdetector = noop,
        firetouchinterest = noop,
        fireproximityprompt = noop,

        require = function(...)
            return newProxy("Module")
        end,
        loadstring = loadstring,
        getgenv = function(...) return env end,
        getrenv = function(...) return env end,
        getfenv = function(...) return env end,
        setfenv = function(f, env, ...) return f end,
        bit32 = bit32,
        math = math,
        string = string,
        table = table,
        coroutine = coroutine,
        utf8 = utf8,
        debug = debug,
        os = {
            clock = os.clock,
            time = os.time,
            date = os.date,
            difftime = os.difftime
        },

        select = select,
        unpack = unpack,
        next = next,
        pairs = pairs,
        ipairs = ipairs,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        typeof = typeof,
        pcall = pcall,
        xpcall = xpcall,
        assert = assert,
        error = error,
        rawequal = rawequal,
        rawget = rawget,
        rawset = rawset,
        getmetatable = getmetatable,
        setmetatable = setmetatable,

        warn = function() end,
        print = function() end
    }

    return env, newProxy
end