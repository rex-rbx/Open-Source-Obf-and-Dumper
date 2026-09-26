local DONT_DELETE_FILES, DONE_PROCESSING, NON_ENGLISH, WHILE_LIMIT, MAIN_THREAD = false, false, '[\0-\31\189-\255{}]', 1500000, coroutine.running()

local AstLib, SetGarbageData = require'./mods/ast', require'./mods/garbage'
local IsLowerCase, IsBetween, Ast, fenv, lune_luau = function(byte)
    return byte >= 97 and byte <= 122
end, function(n, min, max)
    return n >= min and n <= max
end, AstLib.Ast, getfenv(), require'@lune/luau'
local loadstring, compile, fs, process, serde, roblox, task, stdio = lune_luau.load, lune_luau.compile, require'@lune/fs', require'@lune/process', require'@lune/serde', table.clone(require'@lune/roblox'), require'@lune/task', require'@lune/stdio'
local TIME_TO_WAIT, PRINT, MAX_OPS_MUL, Instance, ExecutorEnvironment, RandomLib, DateTime, InstanceLib, InstanceFuncs = task.wait(), print, 1, roblox.Instance, require'./env/exec', require'./env/random', require'./env/datetime', unpack(require'./env/instances')
local ExploitLib, GetTerrainMaterialColor, Services, Predefined, IteratorTypes, AliasToName, FunctionHooks, Illegal = require'./env/genv', require'./env/terrain', {}, {}, {}, {
    int64 = 'number',
    double = 'number',
    int = 'number',
}, {}, {
    ['for'] = true,
    ['end'] = true,
}

for Key, Data in next, InstanceLib do
    if table.find(Data.tags or {}, 'Service') then
        Services[Key] = Data
    end
end

local min, max, insert, pack, find, concat, isfrozen, rep, format, gsub, match, split, sub, debuginfo, GlobalIndex, TypeSpy = math.min, math.max, table.insert, table.pack, table.find, table.concat, table.isfrozen, string.rep, string.format, string.gsub, string.match, string.split, string.sub, debug.info, nil, nil
local Alphabet = split('abcdefghijklmnopqrstuvwxyz', '')

local function GenId(len)
    local txt = ''

    for i = 1, len or 6 do
        txt = txt .. Alphabet[math.random(1, #Alphabet)]
    end

    return txt
end

local TraceId, HardwareId, CallId = GenId(6), GenId(4) .. '-' .. GenId(4) .. '-' .. GenId(4) .. '-' .. GenId(4), GenId(8)
local MemoryCategory, EnvName = TraceId, 'fenv'
local IgnoreInEq, StatementHooks, LuaGlobals = {
    [EnvName] = true,
    _G = true,
    string = true,
    tostring = true,
}, {}, {}

for _, v in next, {
    'type',
    'print',
    'warn',
    'tostring',
    'tonumber',
    'newproxy',
}do
    LuaGlobals[v] = true
end

local SharedGlobals, Settings, IsTesting = {
    SavedPristine = {},
    PristineKeys = {
        game = true,
        workspace = true,
        task = true,
        CFrame = true,
        spawn = true,
    },
    Pristine = false,
    Logs = {},
    Callbacks = {},
    Deferred = {},
    Delay = 0,
    FRAME_TIME = TIME_TO_WAIT,
    StartedRunning = 0,
    HWID = HardwareId,
}, {
    hookOp = true,
    minifier = true,
    explore_funcs = true,
    lua = false,
    ipt = nil,
    discord = true,
    inf_loops = true,
    runtimelogs = false,
    constants = false,
    spyexeconly = false,
    roblox = false,
    type_annotations = false,
}, true

local function StrToValue(Str)
    if Str == 'false' then
        return false
    elseif Str == 'true' then
        return true
    elseif Str == 'nil' then
        return nil
    elseif tonumber(Str) then
        return tonumber(Str)
    else
        return Str
    end
end
local args = {...}
if #args < 1 then
    args = process.args
end
for index, arg in args do
    local __DARKLUA_CONTINUE_4 = false

    repeat
        local k, v = match(arg, '([%w_]+)=(.+)')
        local Arg = arg

        if not k and not Settings.ipt then
            Settings.ipt = arg
        end
        if not k and Settings.ipt then
            Settings.out = arg
        end
        if Arg == 'prod' then
            IsTesting = false
            __DARKLUA_CONTINUE_4 = true

            break
        elseif Arg == 'logs' then
            SendLogs = true
            __DARKLUA_CONTINUE_4 = true

            break
        end
        if v then
            Settings[k] = StrToValue(v)
        else
            local neg = sub(Arg, 1, 1)

            if neg == '!' then
                Settings[Arg:sub(2)] = false
                __DARKLUA_CONTINUE_4 = true

                break
            end

            Settings[Arg] = true
        end

        __DARKLUA_CONTINUE_4 = true
    until true

    if not __DARKLUA_CONTINUE_4 then
        break
    end
end

local hookOp = Settings.hookOp

DONT_DELETE_FILES = DONT_DELETE_FILES or Settings.dont_delete
CallId = DONT_DELETE_FILES and '' or CallId

local SpyExecOnly, Id, AllowedGetRequests, Args, CallsHandler, AllowedUrlsInTheEnd, VariablesLen = Settings.spyexeconly, -1, 0, 0, nil, {}, 0
local Variables, ReverseVariables, Internal, Usages, Information, SpiedToInstance, Children, Wrapped, LuaTypes, LuauTypes, _print = (fenv.setmetatable({}, {
    __newindex = function(_, k, v)
        rawset(_, k, v)

        VariablesLen = VariablesLen + 1
    end,
})), {}, {}, {}, {}, {}, {}, {}, {
    string = true,
    number = true,
    table = true,
    userdata = true,
    boolean = true,
    ['function'] = true,
    thread = true,
    ['nil'] = true,
}, {
    string = true,
    number = true,
    table = true,
    userdata = true,
    boolean = true,
    ['function'] = true,
    thread = true,
    buffer = true,
    ['nil'] = true,
}, print

print = function(...)
    local function Color(txt, code)
        return string.format('\27[%sm%s\27[0m', tostring(code), tostring(txt))
    end

    local Line, Name = debug.info(2, 'ln')
    local ColoredName, ColorLine = Color(Name == '' and '???' or Name, 32), Color(string.format('line %s', tostring(Line)), 35)
    local FinalText = string.format('[ %s @ %s ]:', tostring(ColoredName), tostring(ColorLine))

    for _, v in next, {...}do
        if typeof(v) == 'table' and not Variables[v] then
            local mt = getmetatable(v)

            if mt and mt.__tostring then
                return _print(FinalText, 'PROTECTED TABLE DETECTED, POSSIBLE DETECTION?')
            end
        end
    end

    _print(FinalText, ...)
end

local _Env = getfenv()
local TrueEnv = getmetatable(_Env).__index

local function GetVar()
    Id = Id + 1

    return 'r' .. Id
end
local function GetCount(Var, AddAnyway)
    Usages[Var] = (Usages[Var] or -1) + 1

    local Use = Usages[Var]

    if Use == 0 and not AddAnyway then
        return Var
    end

    return Var .. '_' .. Use
end
local function GetInternalValue(Spied, Recursed)
    local Value = Internal[Variables[Spied] ]

    if Value then
        local V1 = Value[1]
        local VARV1 = Variables[V1]

        if VARV1 and not Recursed then
            local Val = Internal[VARV1]

            if not Val then
                return V1
            end

            return GetInternalValue(Val[1], true)
        end

        return V1
    end

    return Spied
end
local function SetInternalValue(Var, Value)
    Internal[Var] = {Value}
end

local SavedParams, ParamsDict, NumbersDict = {}, {}, {}

for i = 1, 10 do
    NumbersDict[tostring(i - 1)] = true
end

local function GetParams(Value, Infos)
    if SavedParams[Value] then
        return SavedParams[Value]
    end

    local Params, pC, vararg = {}, debug.info(Value, 'a')
    local Suffix, InfoList = Args == 1 and '' or '_' .. Args, {}

    for _, v in next, Infos or {}do
        insert(InfoList, v.Name)
    end

    for i = 1, pC do
        insert(Params, (InfoList[i] and {
            (GetCount(InfoList[i])),
        } or {
            ('p' .. i .. Suffix),
        })[1])
    end
    for i = 1, 3 do
        insert(Params, Alphabet[i] .. Suffix)
    end

    if vararg then
        insert(Params, '...')
    end

    SavedParams[Value] = Params

    return Params
end

local Functions, CClosures, Types = {}, {}, {}

local function iscclosure(f)
    if CClosures[f] then
        return true
    end

    local Type = typeof(f)

    if Type ~= 'function' then
        return false
    end

    local info = debuginfo(f, 's')

    return info == '[C]'
end
local function Function(Callback, Path, IsCClosure)
    local Old = ReverseVariables[Path]

    if Old then
        return Old
    end
    if IsCClosure then
        CClosures[Callback] = true
    end

    Variables[Callback] = Path
    ReverseVariables[Path] = Callback
    Types[Callback] = 'function'

    return Callback
end
local function isUnsafePattern(p)
    if p:find'%b()%s*[%*%+]' then
        return true, 'Nested repetition detected'
    end

    local wildcardCount = select(2, p:gsub('%[%*%.]', ''))

    if wildcardCount > 7 then
        return true, 'Too many wildcards'
    end

    return false
end
local function IsExecutor(Key)
    for i, v in next, ExecutorEnvironment do
        if find(v, Key) then
            return i
        end
    end

    return
end
local function SetIterator(Path, TypeI, TypeV)
    IteratorTypes[Path] = {TypeI, TypeV}
end

local UserRegex = 'C:[/\\]+Users[/\\]+.-[\\/]([^\\/]+):(%d+)'

local function HideErrors(text, hideLines, clean)
    if typeof(text) ~= 'string' then
        local Meow = tostring(text)

        if Settings.debug then
            return Meow
        end

        return Meow:match'[^\n]+' or text
    end

    text = text:gsub(UserRegex, format('%s%s', '%1', hideLines and '' or ':%2'))

    if not hideLines then
        text = text:gsub(':%d+:', ':1:')
    end
    if clean then
        text = text:gsub('%w+:%d+:%s*', '')
    end

    return text
end
local function UseHookOp(Source, SourceFile)
    if not hookOp then
        return true, Source
    end
    --[[local FileName = SourceFile

    if not FileName then
        FileName = './cache/' .. GenId(8)

        fs.writeFile(FileName, Source)
    end

    -- hookOp uses the portable @std/fs open/read API. The legacy hookOp
    -- entrypoint calls Lute's readFileToString, which rejects the Docker bind
    -- mount with a misleading "no R/W permissions" error.
    local OutPath, ScriptPath = FileName .. '-unparsed.lua', 'mods/hookOp.luau'
    local HookArgs, HookBin = {
        FileName,
        OutPath,
        CallId,
        Settings.constants and '1' or '0',
        Settings.inf_loops and '1' or '0',
        tostring(WHILE_LIMIT),
    }, process.os:lower() == 'windows' and 'lute.exe' or 'lute'

    local Args = {
            ScriptPath,
            unpack(HookArgs),
        }
    local POut = process.exec(HookBin, Args)

    if POut and POut.exitCode and POut.exitCode ~= 0 then
        local errMsg = POut.stderr and #POut.stderr > 0 and POut.stderr or string.format('hookOp exited with code %s', tostring(POut.exitCode))

        return false, string.format('--err%s', tostring(errMsg))
    end
    if FileName ~= SourceFile then
        fs.removeFile(FileName)
    end

    local s, Content = pcall(fs.readFile, OutPath)

    if not DONT_DELETE_FILES and fs.isFile(OutPath) then
        pcall(fs.removeFile, OutPath)
    end
    if not s or DONT_DELETE_FILES then
        print('Output:', POut.stdout, POut.stderr)
    end
    if not s then
        local errMsg = POut.stderr and #POut.stderr > 0 and POut.stderr or 'hookOp output missing'

        return false, string.format('--err%s', tostring(errMsg))
    end]]

    return true, hookOp and 'print("hookop is removed because its shit")\n' or '' .. Source
end
local function EnvLog(Source, Nest)
    local function GetMaxOps(n)
        return 5000 / max(n * 5, 1) * MAX_OPS_MUL
    end

    Nest = Nest or 0

    local AST = Ast.new()

    AstLib.SetGlobal('AST', AST)

    if Nest == 0 then
        Ast.addStatement(AST, Ast.Assign({
            Ast.Variable(EnvName),
        }, {
            Ast.FunctionCall(Ast.Variable'getfenv', {}),
        }, false))
    end

    task.spawn(function()
        if Settings.version then
            while task.wait(1) and not DONE_PROCESSING do
                PRINT'Alive'

                if Settings.runtimelogs then
                    pcall(function()
                        fs.writeFile(Settings.out, AstLib.Stringify(AstLib.Minify(AST, not Settings.minifier)))
                    end)
                end
            end
        end
    end)

    local OpCount, StartedRunning, TotalWhiles, TotalRepeats, MaxOps, Env, EnvValues = 0, nil, 0, 0, GetMaxOps(Nest), {}, {
        load = {},
        package = {},
        file = {},
        io = {},
    }

    local function OpCountCheck()
        OpCount = OpCount + 1

        if OpCount >= MaxOps then
            error('too many operations', 2)
        end
    end
    local function Typeof(Value)
        local Type = Types[Value]

        if Type then
            return Type, Value
        end

        local int = GetInternalValue(Value)

        return typeof(int), int
    end
    local function checktype(obj, expected, msg, allowNn)
        if allowNn and not Internal[Variables[obj] ] then
            return obj
        end

        local type, int = Typeof(obj)

        assert(type == expected, string.format('%s, %s expected got %s', tostring(msg), tostring(expected), tostring(type)))

        return int
    end

    local ToAST, SpyParams, ToExplore, ToExploreHash, VarValues, WaitingIfs, Strings, ConstantList, AlwaysIgnore, Nil, ForceNil, Indexes, SecureEnv, VisitedTables, Luraph, ActiveLoops, ForLoopId, StopWhileLoops, IfId, WhileExprs, LastLen = nil, nil, {}, {}, {}, {}, {}, {}, {
        [EnvName] = true,
        string = true,
        bit32 = true,
        table = true,
    }, {
        getconstants = true,
        _ENV = true,
        io = true,
        file = true,
    }, {
        RandomStrings = true,
        package = true,
        inf = true,
    }, {}, {}, {}, false, 0, 0, 0, 0, {}, 0

    local function CloseIfs(ASt)
        local AST = ASt or AST

        if #WaitingIfs > 0 then
            local Oldest, LengthNow = WaitingIfs[#WaitingIfs], #AST.data.statements

            do
                local StartedAt, Comment = Oldest[2], Ast.PermaComment(Ast.RawText(string.format('%s, if id: %s', tostring(Oldest[3] and 'didnt run (else)' or 'ran'), tostring(Oldest[#Oldest]))))
                local Body = Ast.Block{Comment}

                for i = StartedAt + 1, LengthNow do
                    Ast.addStatement(Body, AST.data.statements[i])

                    AST.data.statements[i] = nil
                end

                local IsElse = Oldest[3]

                if IsElse then
                    Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Ast.Block{}, Body))
                else
                    Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Body))
                end
            end
        end

        WaitingIfs = {}
    end
    local function Assert(Type, WhatItShouldBe, Message, AllowAny)
        if AllowAny and Type == 'table' then
        else
            assert(Type == WhatItShouldBe, Message)
        end
    end
    local function CloseAllEnds(ASt)
        ASt = ASt or AST

        CloseIfs(ASt)

        for i = 1, ActiveLoops do
            Ast.addStatement(ASt, Ast.End())
        end

        ActiveLoops = 0
    end

    local IsExploring, IsInPcall

    local function Explore(Func, Options, ...)
        Options = Options or {}

        local DontBypassBeautify = not Options.bypass_beautify

        if Options.bypass_ignore then
            DontBypassBeautify = false
        else
            if not Settings.explore_funcs or Options.ignore_funcs then
                if Options.as_func then
                    return Ast.Function(GetParams(Func), Ast.Block{}), {}
                end

                return Ast.Block{}, {}
            end
        end
        if not ToExploreHash[Func] and DontBypassBeautify then
            local id = 'to_explore_' .. GenId(32)
            local node = Ast.Variable(id)

            insert(ToExplore, {
                func = Func,
                id = id,
                node = node,
                args = Options,
                idx = #ToExplore,
                traceback = debug.traceback(),
            })

            ToExploreHash[Func] = true

            return node
        end

        IsExploring = not Options.as_pcall

        local _AST, _Nest, _OpCount, _MaxOps, _Delay, _Whiles, _Limit, _Waiting, _Loops, _LastLen, _LastExpr, _IsInPcall = AST, Nest, OpCount, MaxOps, SharedGlobals.Delay, TotalWhiles, WHILE_LIMIT, WaitingIfs, ActiveLoops, LastLen, WhileExprs, IsInPcall

        AST, Nest, OpCount, MaxOps, SharedGlobals.Delay, TotalWhiles, WHILE_LIMIT, WaitingIfs, ActiveLoops, LastLen, WhileExprs, IsInPcall = Ast.Block{}, Nest + 1, 0, GetMaxOps(Nest + 1), Options.delay or 0, 0, WHILE_LIMIT / 2, {}, 0, 0, {}, Options.as_pcall and Func

        local Params, ParamInfos, Gotten = Options.params, Options.param_infos, {}

        if not Params and (Nest ~= 1 or not Options.as_pcall) then
            Gotten = GetParams(Func, ParamInfos)
            Params = SpyParams(Gotten, ParamInfos)
        end

        local Results, Logged = pack(pcall(Func, unpack(Params or {}))), Ast.Block{}

        for _, Statement in next, AST.data.statements do
            Ast.addStatement(Logged, Statement)
        end

        if #Logged.data.statements > 0 then
            Args = Args + 1
        end

        CloseAllEnds(Logged)

        if not Results[1] then
            if not Options.as_pcall then
                local Last = Logged.data.statements[#Logged.data.statements]

                if Last and Last.kind == 'call' and Last.data.func.data.name == 'error' then
                else
                    local Error = Results[2]

                    Ast.addStatement(Logged, Ast.NonOptionalComment(Ast.RawText'The script errored here with the message: ', ToAST((Settings.debug and {Error} or {
                        (HideErrors(Error, not IsTesting)),
                    })[1])))
                end
            end
        elseif Results.n > 1 then
            local Returned = {}

            for i = 2, Results.n do
                insert(Returned, ToAST(Results[i]))
            end

            Ast.addStatement(Logged, Ast.Return(Returned))
        end

        AST, Nest, OpCount, MaxOps, SharedGlobals.Delay, TotalWhiles, WHILE_LIMIT, WaitingIfs, ActiveLoops, LastLen, WhileExprs, IsInPcall = _AST, _Nest, _OpCount, _MaxOps, _Delay, _Whiles, _Limit, _Waiting, _Loops, _LastLen, _LastExpr, _IsInPcall
        IsExploring = false

        if Options.as_func then
            Logged = Ast.Function(Gotten, Logged)
        end

        return Logged, Results
    end
    local function shallowEqual(t1, t2)
        if t1 == t2 then
            return true
        end
        if type(t1) ~= 'table' or type(t2) ~= 'table' then
            return false
        end

        for k, v in pairs(t1)do
            if t2[k] ~= v then
                return false
            end
        end
        for k, _ in pairs(t2)do
            if t1[k] == nil then
                return false
            end
        end

        return true
    end

    ToAST = function(Value, Data)
        if Ast.IsAst(Value) then
            return Value
        end

        local Var, Str = Variables[Value], Strings[Value]

        if Var then
            return Ast.Variable(Var)
        elseif Str then
            return Ast.Variable(Str)
        end

        local Type = typeof(Value)

        if Type == 'number' then
            return Ast.Number(Value)
        elseif Type == 'string' then
            return Ast.String(Value)
        elseif Type == 'error' then
            local Meow = tostring(Value)

            Meow = (Settings.debug and {Meow} or {
                Meow:match'[^\n]+' or Meow,
            })[1]

            return ToAST(Meow)
        elseif Type == 'nil' then
            return Ast.Nil(Value)
        elseif Type == 'function' then
            local Old = Functions[Value]

            if Old and not (Data and Data.dont_cache) and (not Data or shallowEqual(Data, Old[2])) then
                return Old[1]
            end

            Data = (typeof(Data) == 'table' and {Data} or {{}})[1]
            Data.bypass_beautify = (Data.bypass_beautify == nil and {false} or {
                (Data.bypass_beautify),
            })[1]

            local Logged = Explore(Value, Data)

            Functions[Value] = {Logged, Data}

            return Logged
        elseif Type == 'table' then
            if VisitedTables[Value] then
                return Ast.FunctionCall(Ast.Variable'RECURSIVE_TABLE', {})
            end

            VisitedTables[Value] = true

            local Metatable, Fixed = getmetatable(Value), {}

            for Key, Value in next, Value do
                insert(Fixed, {
                    key = ToAST(Key, Data),
                    val = ToAST(Value, Data),
                })
            end

            local TblVar = Ast.Variable(GetVar())

            Ast.addStatement(AST, Ast.Assign({TblVar}, {
                Ast.Table(Fixed),
            }))

            if Metatable then
                local mt, Type = {}, typeof(Metatable)

                if Type == 'table' then
                    for i, v in next, Metatable do
                        insert(mt, {
                            key = ToAST(i),
                            val = ToAST(v, {
                                ignore_funcs = true,
                                as_func = true,
                            }),
                        })
                    end
                else
                    mt = {
                        {
                            key = Ast.String'__metatable',
                            val = ToAST(Metatable),
                        },
                    }
                end

                VisitedTables[Value] = nil

                return Ast.FunctionCall(Ast.Variable'setmetatable', {
                    TblVar,
                    Ast.Table(mt),
                })
            end

            VisitedTables[Value] = nil

            return TblVar
        elseif Type == 'boolean' then
            return Ast.Boolean(Value)
        elseif Type == 'Color3' then
            return Ast.FunctionCall(Ast.Index(Ast.Variable'Color3', Ast.String'fromRGB'), {
                Ast.Number(math.floor(Value.R * 255 / 1)),
                Ast.Number(math.floor(Value.G * 255 / 1)),
                Ast.Number(math.floor(Value.B * 255 / 1)),
            })
        elseif Type == 'ColorSequenceKeypoint' then
            return Ast.FunctionCall(Ast.Index(Ast.Variable'ColorSequenceKeypoint', Ast.String'new'), {
                Ast.Number(Value.Time),
                ToAST(Value.Value),
            })
        elseif Type == 'EnumItem' then
            return Ast.Variable(tostring(Value))
        else
            return Ast.FunctionCall(Ast.Variable'UNKNOWN_TYPE', {
                Ast.String(Type),
                ToAST(tostring(Value)),
            })
        end
    end

    local function TupleToAST(...)
        local ASTs = {}

        for _, v in next, {...}do
            insert(ASTs, ToAST(v))
        end

        return ASTs
    end
    local function Define(Var, Value, IsGlobal, Raw)
        OpCountCheck()

        local Type = typeof(Var)
        local ActualVar = Type == 'string' and Ast.Variable(Var) or Var
        local Assign = Ast.Assign({ActualVar}, {
            (Raw and {Value} or {
                (ToAST(Value)),
            })[1],
        }, IsGlobal)

        Ast.addStatement(AST, Assign)

        if ActualVar.kind == 'variable' then
            VarValues[ActualVar.data.name] = Value
        end

        return Assign
    end
    local function DefineVar(...)
        local Var = GetVar()
        local Stat = Define(Var, ...)

        return Var, Stat
    end
    local function AppendCall(FuncName, ...)
        OpCountCheck()

        local Value = VarValues[FuncName]

        if Value and Value.kind == 'index' then
            local ValueBase = Value.data.base

            if ValueBase.kind == 'variable' then
                local Name, FirstArg, MethodInfo = ValueBase.data.name, Variables[...], VarValues[FuncName]

                if Name == FirstArg and (MethodInfo and MethodInfo.kind == 'index') then
                    local Key = MethodInfo.data.key
                    local KeyVar = Key.data.value

                    if Key.kind == 'variable' then
                        KeyVar = VarValues[MethodInfo.data.key.data.name].data.value
                    elseif Key.kind == 'string' then
                        KeyVar = Key.data.value
                    end

                    return DefineVar(Ast.Namecall(Ast.Variable(MethodInfo.data.base.data.name), Ast.Variable(KeyVar), TupleToAST(select(2, ...))))
                end
            end
        end

        return DefineVar(Ast.FunctionCall(typeof(FuncName) == 'string' and Ast.Variable(FuncName) or FuncName, TupleToAST(...)))
    end
    local function Comment(...)
        do
            return
        end
    end
    local function ReverseDict(Dict)
        local New = {}

        for i, v in next, Dict do
            New[v] = i
        end

        return New
    end

    local Metatable, Math, MathV2

    MathV2 = {
        __eq = '==',
        __neq = '~=',
        __lt = '<',
        __le = '<=',
        __gt = '>',
        __ge = '>=',
    }
    Math = {
        __add = '+',
        __sub = '-',
        __mul = '*',
        __div = '/',
        __idiv = '//',
        __pow = '^',
        __mod = '%',
        __concat = '..',
    }

    local SymbolToName = ReverseDict(Math)

    local function InternalIfy(...)
        local Args = {...}

        for i, v in next, Args do
            Args[i] = GetInternalValue(v)
        end

        return unpack(Args)
    end

    local Iters, MissingEnums = {}, {
        Font = {
            GothamSemiBold = true,
            GothamSemibold = true
        },
        RaycastFilterType = {
            Blacklist = true,
            Whitelist = true
        },
        CompressionAlgorithm = {
            Zstd = true
        }
    }

    local function __call(Self, ...)
        local Path = Variables[Self]
        local _, args, len = (Internal[Path] or {{}})[1], {...}, select('#', ...)

        if len == 2 and args[1] == nil then
            if args[2] == nil then
                CloseAllEnds(AST)

                Iters[Path] = true

                local i, v = GetCount'i', GetCount'v'

                Ast.addStatement(AST, Ast.ForPrep(Ast.Variable(i), Ast.Variable(v), Ast.Variable(Path), 'obf_' .. ActiveLoops))

                ActiveLoops = ActiveLoops + 1

                return Spy(i), Spy(v)
            elseif Iters[Path] then
                ActiveLoops = ActiveLoops - 1

                CloseIfs()
                Ast.addStatement(AST, Ast.End('obf_' .. ActiveLoops))

                return nil, nil
            end
        end

        local Var = AppendCall(Path, ...)

        return Spy(Var, nil, Information[Self])
    end

    function GetValueInner(x, Symbol, y)
        if Symbol == '+' then
            return x + y
        elseif Symbol == '-' then
            return x - y
        elseif Symbol == '*' then
            return x * y
        elseif Symbol == '/' then
            return x / y
        elseif Symbol == '//' then
            return math.floor(x / y)
        elseif Symbol == '^' then
            return x ^ y
        elseif Symbol == '%' then
            return x % y
        elseif Symbol == '..' then
            return x .. y
        elseif Symbol == '==' then
            return rawequal(x, y)
        elseif Symbol == '~=' then
            return not rawequal(x, y)
        elseif Symbol == '<' then
            return x < y
        elseif Symbol == '<=' then
            return x <= y
        elseif Symbol == '>' then
            return x > y
        elseif Symbol == '>=' then
            return x >= y
        end
    end
    function Spy(Path, Value, Info)
        assert(typeof(Path) == 'string', string.format("invalid argument #1 to 'Spy', string expected got %s - %s, %s", tostring(typeof(Path)), tostring(debuginfo(2, 'l')), tostring(debuginfo(3, 'l'))))

        local Reversed = ReverseVariables[Path]

        if Reversed then
            return Reversed
        end
        if not Metatable then
            local Info = Info or {}

            Metatable = {}

            function Metatable.__newindex(Self, Key, Value)
                Info = Information[Self] or Info

                local Path = Variables[Self]
                local Base, Cached = Ast.Variable(Path), ((Internal[Path] or {{}})[1])

                if rawequal(Cached, Env) then
                    Cached[Key] = Value

                    return
                end

                local Type, DontSet = Typeof(Cached), Info.from_index and Cached == nil

                if Type == 'Instance' then
                    local Int = GetInternalValue(Value)

                    if not Variables[Int] then
                        Cached[Key] = Int

                        return
                    else
                        DontSet = true
                        Value = Int
                    end
                end

                Define(Ast.Index(Base, ToAST(Key)), ToAST(Value), true)

                if LuaTypes[Type] and Type ~= 'table' and Cached then
                    error(string.format("attempt to index %s with '%s'", tostring(Type), tostring(Key)))
                end
                if not DontSet then
                    Value = GetInternalValue(Value)
                    Cached[Key] = Value
                end

                rawset(Self, Key, Value)

                return nil
            end
            function Metatable.__index(Self, Key)
                Info = Information[Self] or Info

                local Path = Variables[Self]
                local IsInternal = Internal[Path]
                local Cached = ((IsInternal or {})[1])

                if rawequal(Cached, Env) then
                    return Cached[Key]
                end

                local DontCache = Variables[Cached] ~= nil or Cached == nil

                Cached = Cached or {}

                local Type = Typeof(Cached)

                if Type == 'Enum' then
                    local EnumKey = tostring(Cached):split'.'[2]
                    local List = MissingEnums[EnumKey]

                    if List and List[Key] then
                        DontCache = true
                    else
                        DontCache = typeof(Key) == 'table'
                    end
                elseif Type == 'Instance' then
                    DontCache = not pcall(function()
                        return Cached[Key]
                    end)
                end

                local Cache, Base = (DontCache and {nil} or {
                    (Cached[Key]),
                })[1], Ast.Variable(Path)
                local Var, newinfo = DefineVar(Ast.Index(Base, ToAST(Key)), false, true), {}

                do
                    local meow = Info.indexed_instance

                    if meow ~= nil then
                        newinfo.indexed_instance = meow
                    end

                    newinfo.from_index = true
                end

                if LuaTypes[Type] and Type ~= 'table' and Type ~= 'string' then
                    error(string.format("attempt to index %s with '%s'", tostring(Type), tostring(Key)))
                end
                if Cached and not DontCache then
                    if typeof(Cache) == 'function' then
                        if Type == 'string' then
                            return SecureEnv.string[Key]
                        end

                        return Function(function(...)
                            local Spied, Statement = AppendCall(Var, ...)
                            local Values = pack(Cache(InternalIfy(...)))

                            if Values.n == 1 then
                                return Spy(Spied, nil, newinfo)
                            else
                                return ToMultiVars(Statement, Values)
                            end
                        end, Var, iscclosure(Cache))
                    end

                    return SafeValue(Var, Cache, newinfo)
                elseif IsInternal and not DontCache then
                    SetInternalValue(Var, IsInternal[1][Key])
                end

                local Spied = Spy(Var, nil, newinfo)

                if not DontCache then
                    Cached[Key] = Spied
                end

                return Spied
            end

            Metatable.__call = __call

            function Metatable.__tostring(Self)
                return Variables[Self]
            end
            function Metatable.__iter(Self, Key)
                local Called, i, v, Ends, Current = nil, GetCount('for_key', true), GetCount('for_val', true), WaitingIfs, ForLoopId + 1

                return function(...)
                    if Called then
                        ActiveLoops = ActiveLoops - 1

                        CloseIfs()
                        Ast.addStatement(AST, Ast.End(Current))

                        WaitingIfs = Ends

                        return nil
                    end

                    local Path = Variables[Self]
                    local IsInternal = Internal[Path]
                    local Cached, Iterator = ((IsInternal or {})[1]), (Key == 'next' and {
                        (Ast.ArgList{
                            Ast.Variable(Key),
                            ToAST(Self),
                        }),
                    } or {
                        ((typeof(Key) == 'string' and {
                            (Ast.FunctionCall(Ast.Variable(Key), {
                                ToAST(Self),
                            })),
                        } or {
                            (ToAST(Self)),
                        })[1]),
                    })[1]

                    CloseAllEnds(AST)

                    local i_Types = IteratorTypes[Path]

                    if not i_Types then
                        if typeof(Cached) ~= 'table' then
                            i_Types = {}
                        else
                            for i2, v2 in next, Cached do
                                i_Types = {
                                    Typeof(i2),
                                    Typeof(v2),
                                }

                                SetInternalValue(i, i2)
                                SetInternalValue(v, v2)

                                break
                            end
                        end
                    end

                    Ast.addStatement(AST, Ast.ForPrep(Ast.Variable(i), Ast.Variable(v), Iterator, Current))

                    Called = true
                    ForLoopId = Current
                    ActiveLoops = ActiveLoops + 1
                    WaitingIfs = {}

                    return TypeSpy(i, i_Types[1]), TypeSpy(v, i_Types[2])
                end
            end

            local InstantlyProcess = {
                ['=='] = true,
                ['~='] = true,
            }

            function GetValue(x, Symbol, y, Var)
                local TypeX, TypeY, VarX, VarY = Typeof(x), Typeof(y), Variables[x], Variables[y]
                local xLune, yLune = not LuauTypes[TypeX], not LuauTypes[TypeY]

                if not InstantlyProcess[Symbol] then
                    if Symbol == '..' then
                        if VarX or VarY then
                            if TypeX ~= 'string' and TypeY ~= 'string' then
                                assert(not Settings.roblox, string.format('attempt to concatenate %s with %s', tostring(TypeX), tostring(TypeY)))
                            end

                            return TypeSpy(Var, 'string')
                        end
                    else
                        if VarX or VarY then
                            if (not xLune and not yLune) or ((VarX and not xLune) or (VarY and not yLune)) then
                                if not LuaTypes[TypeX] and not LuaTypes[TypeY] then
                                    assert(not Settings.roblox, string.format('attempt to perform arithmetic (%s) on %s and %s', tostring(SymbolToName[Symbol]:sub(3)), tostring(TypeX), tostring(TypeY)))
                                end

                                return Spy(Var)
                            end
                        end
                    end
                end

                local Success, Value = pcall(GetValueInner, x, Symbol, y)

                if Settings.roblox then
                    assert(Success, tostring(Value))
                end

                return Value
            end

            for Method, Symbol in next, Math do
                Metatable[Method] = function(Self, Value)
                    if IgnoreInEq[Variables[Self] ] then
                        return GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value))
                    end

                    local Var = DefineVar(Ast.BinaryOp(ToAST(Self), Symbol, ToAST(Value)), false, true)
                    local Value = GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value), Var)

                    if Variables[Value] then
                        return Value
                    end

                    Ast.addStatement(AST, Ast.Comment(ToAST(Value)))

                    return SafeValue(Var, Value)
                end
            end

            if not hookOp then
                for Method, Symbol in next, MathV2 do
                    Metatable[Method] = function(Self, Value)
                        if Variables[Self] == EnvName then
                            return GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value))
                        end

                        local Var = DefineVar(Ast.BinaryOp(ToAST(Self), Symbol, ToAST(Value)), false, true)
                        local Value = GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value), Var)

                        if Variables[Value] then
                            return Value
                        end

                        return SafeValue(Var, Value)
                    end
                end
            end
        end

        local Meta = setmetatable({}, Metatable)

        if typeof(Value) == 'table' then
            local OldMt, ActualMetatable = getmetatable(Value), getmetatable(Meta)

            if OldMt then
                for method, callback in next, OldMt do
                    if typeof(callback) == 'function' then
                        if method:sub(1, 2) == '__' then
                            ActualMetatable[method] = callback
                        else
                            rawset(Meta, method, function(_, ...)
                                local Statement

                                if Variables[_] == Path then
                                    Statement = Ast.Assign({
                                        Ast.Variable(GetVar()),
                                    }, {
                                        Ast.Namecall(Ast.Variable(Path), Ast.Variable(method), TupleToAST(...)),
                                    })

                                    Ast.addStatement(AST, Statement)
                                else
                                    Statement = select(2, AppendCall(Ast.Index(Ast.Variable(Path), ToAST(method)), _, ...))
                                end

                                return ToMultiVars(Statement, pack(callback(GetInternalValue(_), ...)), true)
                            end)
                        end
                    else
                        ActualMetatable[method] = callback
                    end
                end
            end
        end

        Variables[Meta] = Path
        ReverseVariables[Path] = Meta

        if Value ~= nil then
            Types[Meta] = typeof(Value)

            SetInternalValue(Path, Value)
        end

        Information[Meta] = Info

        return Meta
    end

    TypeSpy = function(Path, Type, ...)
        local Meower = Spy(Path, ...)

        if Type then
            Types[Meower] = Type
        end

        return Meower
    end

    function ToMultiVars(Statement, Values, Safe, Info)
        local Length, Spied, Vars, Func = Values.n or #Values, {}, {}, (Safe and {SafeValue} or {Spy})[1]

        for i = 1, Length do
            local Var = GetVar()
            local Meower = Func(Var, Values[i], Info)

            Types[Meower] = typeof(Values[i])

            insert(Spied, Meower)
            insert(Vars, Ast.Variable(Var))
        end

        Statement.data.vars = Vars

        return unpack(Spied)
    end
    function SafeValue(Var, Value, Info)
        local Type = Typeof(Value)

        if Type == 'function' then
            return Function(Value, Var, iscclosure(Value))
        elseif Type == 'table' or hookOp then
            if Variables[Value] then
                Value = GetInternalValue(Value)
            end

            SetInternalValue(Var, Value)

            return TypeSpy(Var, Type, nil, Info)
        else
            return Value
        end
    end

    local function GetMetatable(Path, Extra, Value)
        local Cloned = table.clone(getmetatable(Spy(Path, Value)))

        if Extra then
            for i, v in next, Extra do
                Cloned[i] = v
            end
        end

        local Mt = setmetatable({}, Cloned)

        Variables[Mt] = Path

        return Mt
    end
    local function GetContext(Object)
        local Var = Variables[Object]

        if Var and not AlwaysIgnore[Var] and not Wrapped[Object] and not LuaGlobals[Var] then
            return Var
        end

        return nil
    end

    SpyParams = function(Params, Infos)
        local ParamList, InfoList = {}, {}

        if Infos then
            for _, v in next, Infos do
                insert(InfoList, v.Type)
            end
        end

        for i, Param in next, Params do
            local Spied, thingInfo = Spy(Param, nil, {is_property = true}), InfoList[i]

            if thingInfo then
                if thingInfo.Category == 'Primitive' then
                    local Type = AliasToName[thingInfo.Name] or thingInfo.Name

                    Types[Spied] = Type
                end
            end

            ParamsDict[Spied] = true

            insert(ParamList, Spied)
        end

        return ParamList
    end

    if hookOp then
        local StuffThatRanEq = {}

        local function Eq(Symbol)
            local IsEq = Symbol == '=='
            local eq = IsEq and function(a, b)
                return a == b
            end or function(a, b)
                return a ~= b
            end

            return function(x, y)
                local A, B = GetContext(x), GetContext(y)

                if (not A and not B) or (IgnoreInEq[A] or IgnoreInEq[B]) then
                    return eq(x, y)
                end

                local _, X, Y, Var = StuffThatRanEq[A], StuffThatRanEq[B], GetInternalValue(x), GetInternalValue(y), GetVar()

                Define(Var, Ast.Group(Ast.BinaryOp(ToAST(x), Symbol, ToAST(y))), false, true)

                local Value, RawValue, VarX = nil, eq(X, Y), Variables[X]

                if VarX and (VarX == Variables[Y]) then
                    RawValue = IsEq
                end

                local InfoA, InfoB = Information[x], Information[y]
                local iA, iB = InfoA or {}, InfoB or {}
                local PropertyA, PropertyB = iA.is_property, iB.is_property

                if (PropertyA or PropertyB) and not iA.force_normal and not iB.force_normal then
                    local TypeX, TypeY = Typeof(x), Typeof(y)

                    if TypeX == 'string' or TypeY == 'string' then
                        if x == '' or y == '' then
                            Value = not IsEq
                        else
                            Value = IsEq
                        end
                    else
                        Value = eq(TypeX, TypeY)
                    end
                end
                if Value == nil then
                    Value = RawValue
                end
                if iA.key == 'PlaceId' and typeof(Y) == 'number' then
                    Value = not IsEq or Y > 100000
                elseif iB.key == 'PlaceId' and typeof(X) == 'number' then
                    Value = not IsEq or X > 100000
                end

                local tbl = {Value, IsEq}

                if A then
                    StuffThatRanEq[A] = tbl
                end
                if B then
                    StuffThatRanEq[B] = tbl
                end

                Ast.addStatement(AST, Ast.Comment(ToAST(Value)))

                return Spy(Var, Value, InfoA or InfoB)
            end
        end

        local CompVars, CheckCount, CompIgnore = {}, {}, {
            table = true,
            string = true,
        }

        local function Def(x, Symbol, y, _y, isYFunc)
            local Var

            if isYFunc and typeof(_y) == 'function' then
                local Var1 = DefineVar(Explore(_y, {bypass_beautify = false}), false, true)

                Var = DefineVar(Ast.BinaryOp(ToAST(x), Symbol, Ast.FunctionCall(Ast.Variable(Var1), {})), false, true)
            else
                Var = DefineVar(Ast.BinaryOp(ToAST(x), Symbol, ToAST(y)))
            end

            return Var
        end
        local function Compare(Symbol)
            local IsAnd = Symbol == 'and'
            local GetValue = IsAnd and function(x, y)
                return x and y
            end or function(x, y)
                return x or y
            end

            return function(x, y, isYFunc, ...)
                local a, b, _x, _y, X = GetContext(x), GetContext(y), x, y, GetInternalValue(x)
                local ShouldReturn, TypeX = (IsAnd and {
                    (not X),
                } or {X})[1], Typeof(x)
                local IsFunction = TypeX == 'function'

                if SharedGlobals.Pristine then
                    if IsAnd and SharedGlobals.PristineKeys[a] then
                        return nil
                    end
                end
                if ShouldReturn then
                    if (a or b) and TypeX ~= 'number' and TypeX ~= 'Instance' then
                        if Variables[X] == EnvName or y == nil then
                            return X
                        end

                        local IsPrometheus = typeof(y) == 'number' and y > 10000

                        if not IsPrometheus then
                            if IsAnd then
                                if X == false then
                                    return X
                                end
                            else
                                if TypeX == 'function' then
                                    return X
                                end
                            end
                            if X == false then
                                local Val = VarValues[a]

                                if not Val or Val.kind ~= 'unary' then
                                    return X
                                end
                            end

                            Var = Def(x, Symbol, y, _y, isYFunc)
                        else
                            local ToAST_X = ToAST(x)

                            Var = DefineVar(X and ToAST_X or Ast.UnaryOp(ToAST_X, 'not'))
                        end

                        SetInternalValue(Var, X)

                        return Spy(Var, nil, Information[x] or Information[y])
                    end

                    return X
                end
                if isYFunc then
                    isYFunc = false
                    y = y(...)
                end
                if (not a and not b) or (IsFunction or CompIgnore[a]) then
                    return GetValue(X, y)
                end

                local Var, Info, IsPrometheus = nil, Information[x] or Information[y], typeof(y) == 'number' and y > 10000

                if CompVars[X] then
                    CompVars[y] = string.format('not %s', tostring(CompVars[X]))
                elseif not IsPrometheus then
                    if IsFunction and iscclosure(x) then
                        return GetValue(x, y)
                    end

                    Var = Def(x, Symbol, y, _y, isYFunc)
                end

                x, y = X, GetInternalValue(y)

                local s, Value = pcall(GetValue, x, y)

                if not s then
                    Value = nil
                end
                if IsPrometheus then
                    local Condition = _x

                    CompVars[y] = Condition
                    CheckCount[y] = 0

                    return Value
                end
                if Typeof(Value) == 'function' or Value == Env then
                    return Value
                end

                SetInternalValue(Var, Value)

                return Spy(Var, nil, Info)
            end
        end

        local CheckedIfs, ForLoops, Checked, CheckedKeys, Last = {}, {}, {}, {}, nil

        function SecureEnv.GET(text, ...)
            local Type = typeof(text)

            if Type ~= 'string' then
                if IsExploring and ParamsDict[text] then
                    return Spy(DefineVar(ToAST(text), false, true), text), ...
                end

                return text, ...
            end

            local Len = #text

            if not Strings[text] and Len % 4 ~= 0 and Len > 1 and not IsBetween(Len, 13, 15) and not text:find'[\1-\30\133-\255]' then
                text:sub(1, -2)

                local Var, Stat = DefineVar(Ast.String(text))

                ConstantList[text] = Stat
                Strings[text] = Var
            end

            return text, ...
        end
        function SecureEnv.CONCAT(text, text2)
            local Result = text .. text2

            if Result:find('\239', 0, true) then
                return Result
            end

            local Subbed = Result:sub(1, -2)

            if Strings[Subbed] then
                Strings[Subbed] = nil

                local Old = ConstantList[Subbed]

                if Old then
                    Old.data.vars, Old.data.values = {}, {}
                end

                local Var, Stat = DefineVar(Ast.String(Result))

                Strings[Result] = Var
                ConstantList[Result] = Stat
            end

            return Result
        end
        function SecureEnv.CALL(func, ...)
            if not func or typeof(func) == 'number' then
                local Var, Call = GetVar(), Ast.FunctionCall(Ast.Group(Ast.Variable'nil'), TupleToAST(...))
                local Assign = Ast.Assign({
                    Ast.Variable(Var),
                }, {Call})

                Ast.addStatement(AST, Assign)
            end

            local Hook = FunctionHooks[func]

            if Hook then
                Ast.Comment(Ast.RawText'A hooked function was used here.')

                return Hook(...)
            end
            if typeof(func) ~= 'function' then
                local var = Variables[func]

                if var and LuaTypes[Typeof(func)] then
                    return __call(func, ...)
                end
            end
            if CallsHandler then
                return CallsHandler(func, ...)
            end

            return func(...)
        end
        function SecureEnv.NAMECALL(func, method, ...)
            if typeof(func) == 'string' then
                return SecureEnv.string[method](GetInternalValue(func), ...)
            end

            return func[method](func, ...)
        end
        function SecureEnv.CHECKIF(Condition, id, elseId)
            local Var, _Condition = GetContext(Condition), Condition

            Condition = GetInternalValue(Condition)

            if Var then
                IfId = IfId + 1

                local Value = VarValues[Var]

                if Value then
                    local Expr = AstLib.ExprToCode(Value)
                    local If = CheckedIfs[Expr] or {
                        uses = 0,
                        condition = Condition,
                    }

                    If.uses = If.uses + 1
                    CheckedIfs[Expr] = If

                    if If.uses >= 20 then
                        StopWhileLoops = StopWhileLoops + 1

                        return not If.condition
                    end
                end

                local WillRun, HasElse, IsFunc, Hook = Condition, elseId == 1, Typeof(Condition) == 'function', StatementHooks[IfId]

                if Hook ~= nil then
                    WillRun = Hook
                end
                if IsFunc and (Wrapped[Condition]) then
                    return WillRun
                end
                if not WillRun then
                    if not HasElse then
                        Ast.addStatement(AST, Ast.IfStat(ToAST(_Condition), Ast.Block{
                            Ast.PermaComment(Ast.RawText(string.format('didnt run, if id: %s', tostring(IfId)))),
                        }))

                        return WillRun
                    end
                end

                OpCountCheck()
                insert(WaitingIfs, {
                    _Condition,
                    #AST.data.statements,
                    not WillRun and HasElse,
                    HasElse,
                    IfId,
                })

                return WillRun
            end

            return Condition
        end
        function SecureEnv.CHECKIFEND(id)
            local LengthNow, Len = #AST.data.statements, #WaitingIfs

            if Len == 0 then
                return
            end

            local Oldest = WaitingIfs[Len]

            if Oldest[2] == LengthNow then
                return
            end

            local LastStat = AST.data.statements[LengthNow]

            if LastStat.kind == 'assign' and LastStat.data.values[1].kind == 'index' then
                return
            end

            local StartedAt, Comment = Oldest[2], Ast.PermaComment(Ast.RawText(string.format('%s, if id: %s', tostring(Oldest[3] and 'didnt run (else)' or 'ran'), tostring(Oldest[#Oldest]))))
            local Body = Ast.Block{Comment}

            for i = StartedAt + 1, LengthNow do
                Ast.addStatement(Body, AST.data.statements[i])

                AST.data.statements[i] = nil
            end

            local IsElse = Oldest[3]

            if IsElse then
                Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Ast.Block{}, Body))
            else
                Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Body))
            end

            table.remove(WaitingIfs, Len)

            Last = Oldest
        end
        function SecureEnv.CHECKWHILE(x, id)
            TotalWhiles = TotalWhiles + 1

            local Var = Variables[x]

            if Var then
                if Indexes[Var] then
                    return nil
                end
            end
            if TotalWhiles >= WHILE_LIMIT then
                print'too many iterations!'
                Ast.addStatement(AST, Ast.WhileLoop(ToAST(x), Ast.Block{}))
                error'too many iterations'
            end

            local X, Stats = GetInternalValue(x), AST.data.statements
            local Len = #Stats

            if Len ~= LastLen and Settings.inf_loops and false then
                local Exprs, Stat = WhileExprs[id] or {}, Stats[Len]

                if Stat.kind == 'assign' and Stat.data.values[1].kind == 'index' then
                    WhileExprs[id] = {}
                elseif Stat.kind == 'variable' then
                else
                    local meower = AstLib.ExprToCode(Stat, 0, true)

                    for n, expr in next, Exprs do
                        if expr[1] == meower then
                            if expr[3] <= 10 then
                                if expr[3] == 0 then
                                    expr[4] = Len - expr[2]
                                end

                                expr[3] = expr[3] + 1

                                break
                            else
                                local Start = expr[2]
                                local OrigStat = Stats[Start]

                                if not OrigStat then
                                    return X
                                end

                                local First, Logged, Added = AstLib.ExprToCode(OrigStat, 0, true), Ast.Block{}, {}

                                for i = Start - (expr[4] - 1), Len do
                                    local __DARKLUA_CONTINUE_33 = false

                                    repeat
                                        local Stat = Stats[i]

                                        if not Stat then
                                            __DARKLUA_CONTINUE_33 = true

                                            break
                                        end

                                        local Coded = AstLib.ExprToCode(Stat, 0, true)

                                        if i ~= Start and Coded == First then
                                            for x = i, Len do
                                                Stats[x] = nil
                                            end

                                            break
                                        end
                                        if Added[Coded] then
                                        else
                                            Added[Coded] = true

                                            Ast.addStatement(Logged, Stats[i])
                                        end

                                        Stats[i] = nil
                                        __DARKLUA_CONTINUE_33 = true
                                    until true

                                    if not __DARKLUA_CONTINUE_33 then
                                        break
                                    end
                                end

                                if x then
                                    Ast.addStatement(AST, Ast.WhileLoop(ToAST(x), Logged))
                                else
                                    Ast.addStatement(AST, Logged)
                                end

                                StopWhileLoops = StopWhileLoops + 1
                            end
                        end
                    end

                    insert(Exprs, {meower, Len, 0})

                    WhileExprs[id] = Exprs
                    LastLen = Len
                end
            end
            if StopWhileLoops > 0 then
                StopWhileLoops = StopWhileLoops - 1

                return false
            end

            return X
        end
        function SecureEnv.CHECKWHILEEND() end
        function SecureEnv.REPEAT()
            TotalRepeats = TotalRepeats + 0.5

            if TotalRepeats >= WHILE_LIMIT then
                print'REPEAT'
                print'too many iterations!'
                error'too many iterations'
            end
        end
        function SecureEnv.CHECKINDEX(tbl, key)
            if typeof(tbl) == 'string' or tbl == string then
                return SecureEnv.string[key]
            end
            if Checked[tbl] or CheckedKeys[key] then
                return tbl[key]
            end

            local Pre = Predefined[key]

            if Pre then
                local Var = DefineVar(Ast.Index(ToAST(tbl), ToAST(key)))

                return SafeValue(Var, Pre[1])
            end

            local KeyVar, TblVar, _Key = GetContext(key), Variables[tbl], key

            key = GetInternalValue(key)

            if not TblVar and tbl then
                local ShouldSpy = KeyVar

                Checked[tbl] = true

                if ShouldSpy then
                    local ResultVar = DefineVar(ToAST(tbl), false, true)

                    Variables[tbl] = ResultVar

                    local mt = fenv.getmetatable(tbl)

                    if typeof(mt) == 'table' then
                        local old = table.clone(tbl)

                        table.clear(tbl)
                        setmetatable(tbl, getmetatable(GetMetatable(ResultVar, mt, old)))

                        return tbl[key]
                    else
                        local doimeowtoomuch, info = DefineVar(Ast.Index(Ast.Variable(ResultVar), Ast.Variable(KeyVar)), false, true), Information[_Key]

                        if info and info.is_property or Settings.discord then
                            return Spy(doimeowtoomuch, tbl[key], info)
                        end
                    end

                    CheckedKeys[_Key] = true
                end
            end

            return tbl[key]
        end
        function SecureEnv.CONSTRUCT(tbl)
            return tbl
        end
        function SecureEnv.RETURN(...)
            if IsExploring or IsInPcall or true then
                return ...
            end

            for _, v in next, {...}do
                local Context = GetContext(v)

                if Context and typeof(v) ~= 'function' then
                    local caller = debuginfo(2, 'f')

                    if not iscclosure(caller) and not Variables[caller] then
                        local FuncName = DefineVar(ToAST(caller, {as_func = true}))

                        Variables[caller] = FuncName

                        local _, Called = AppendCall(FuncName)

                        return ToMultiVars(Called, pack(...))
                    end
                end
            end

            return ...
        end
        function SecureEnv.ADD(x, y)
            if y == 1 and x == 0 and IsInPcall then
                return 2
            end

            return x + y
        end
        function SecureEnv.FORINFO(id, from, to, step)
            ForLoops[id] = {from, to, step}
        end

        for i = 1, 2 do
            SecureEnv['FORSTEP' .. i] = function(id)
                local Loop = ForLoops[id]
                local Value = Loop[i]

                if Variables[Value] then
                    Ast.addStatement(AST, Ast.ForNum('i', ToAST(Loop[1]), ToAST(Loop[2]), ToAST(Loop[3] or 1), Ast.Block{}))

                    local Thing = GetInternalValue(Value)

                    if Variables[Thing] then
                        return 1
                    else
                        return Thing
                    end
                end

                return Value
            end
        end

        local EqFunc = Eq'=='

        SecureEnv.CHECKEQ = EqFunc
        SecureEnv.CHECKNEQ = Eq'~='

        local HowManyChecks = 6

        local function NumCompare(Symbol)
            local IsLessThan, IsGreaterThan, IsGreaterOrEqual, IsLessOrEqual = Symbol == '<', Symbol == '>', Symbol == '>=', Symbol == '<='
            local GetValue = IsLessThan and function(x, y)
                return x < y
            end or IsGreaterThan and function(x, y)
                return x > y
            end or IsGreaterOrEqual and function(x, y)
                return x >= y
            end or IsLessOrEqual and function(x, y)
                return x <= y
            end

            return function(IsMarCute, YesSheIs)
                local VarA, VarB, Comp = GetContext(IsMarCute), GetContext(YesSheIs), CompVars[IsMarCute]

                if Comp then
                    local Value, Variable = GetValue(IsMarCute, YesSheIs), Variables[Comp]

                    if not Variable then
                        return Value
                    end

                    local Count = CheckCount[IsMarCute]

                    CheckCount[IsMarCute] = Count + 1

                    if Count == HowManyChecks then
                        local MarIsCute = Ast.Variable(Variable)
                        local Var = DefineVar(Value and MarIsCute or Ast.UnaryOp(MarIsCute, 'not'))

                        return Spy(Var, Value)
                    else
                        return Value
                    end
                end

                local ShesEvenCuter, OrIsShe = GetInternalValue(IsMarCute), GetInternalValue(YesSheIs)

                if not VarA and not VarB then
                    return GetValue(ShesEvenCuter, OrIsShe)
                end

                local TypeMar, TypeShi = Typeof(IsMarCute), Typeof(YesSheIs)
                local IsMarNumber = TypeMar == 'number'

                if IsLessOrEqual then
                    if IsMarCute and (Information[YesSheIs] or {}).is_random and IsMarCute == 1 then
                        AlwaysIgnore[VarB] = true

                        return GetValue(ShesEvenCuter, OrIsShe)
                    end
                end

                local Var = DefineVar(Ast.BinaryOp(ToAST(IsMarCute), Symbol, ToAST(YesSheIs)), false, true)

                if TypeMar == 'Instance' or TypeShi == 'Instance' then
                    error(string.format('attempt to compare %s %s %s', tostring(TypeMar), tostring(Symbol), tostring(TypeShi)))
                end

                local Success, Val = pcall(GetValue, ShesEvenCuter, OrIsShe)

                if not Success then
                    assert(not Settings.roblox, Val)

                    if VarB and IsMarNumber then
                        Val = IsLessThan or IsLessOrEqual
                    elseif VarA and TypeShi == 'number' then
                        Val = IsGreaterThan or IsGreaterOrEqual
                    end
                end

                Ast.addStatement(AST, Ast.Comment(ToAST(Val)))

                return Spy(Var, Val)
            end
        end

        SecureEnv.COMPG = NumCompare'>'
        SecureEnv.COMPGE = NumCompare'>='
        SecureEnv.COMPL = NumCompare'<'
        SecureEnv.COMPLE = NumCompare'<='
        SecureEnv.CHECKAND = Compare'and'
        SecureEnv.CHECKOR = Compare'or'

        local New = {}

        for i, v in next, SecureEnv do
            Nil[i] = true
            New[CallId .. i] = v
        end

        SecureEnv = New
        SecureEnv.rawequal = function(a, b)
            if Variables[a] or Variables[b] then
                return EqFunc(a, b)
            end

            return rawequal(a, b)
        end
    else
        SecureEnv.rawequal = function(a, b)
            if Variables[a] or Variables[b] then
                return a == b
            end

            return rawequal(a, b)
        end
    end

    local function Unary(Symbol)
        local function Get(x)
            if Symbol == 'not' then
                return not x
            elseif Symbol == '-' then
                return -x
            elseif Symbol == '#' then
                return #x
            end
        end

        return function(x)
            local Var, X = GetContext(x), GetInternalValue(x)

            if Var then
                local IsNot, Type = Symbol == 'not', Typeof(X)

                if TrueEnv[Var] and Type == 'function' then
                    return Get(x)
                end
                if not IsNot and Type == 'Instance' then
                    error(string.format('attempt to perform arithmetic (__%s) on an Instance value', tostring(Symbol == '#' and 'len' or 'unm')))
                end

                local Value

                if not Variables[X] or IsNot then
                    local Success, Result = pcall(Get, X)

                    if Success then
                        Value = Result
                    end
                end

                local Var, Type = DefineVar(Ast.UnaryOp(ToAST(x), Symbol)), Symbol == '#' and 'number' or (Symbol == 'not' and 'boolean' or 'number')

                if not hookOp then
                    return SafeValue(Var, Value)
                end

                return TypeSpy(Var, Type, Value)
            end

            return Get(X)
        end
    end

    SecureEnv[CallId .. 'CHECKNOT'] = Unary'not'
    SecureEnv[CallId .. 'CHECKUNM'] = Unary'-'
    SecureEnv[CallId .. 'CHECKLEN'] = Unary'#'
    SecureEnv[CallId .. 'TEMPLATE_STRING'] = function(...)
        local Var, strTable = DefineVar(Ast.InterpolatedString(unpack(TupleToAST(...)))), {}

        for _, v in next, {...}do
            if Variables[v] then
                return Spy(Var)
            else
                insert(strTable, tostring(v))
            end
        end

        SetInternalValue(Var, concat(strTable, ''))

        return Spy(Var)
    end

    local SayPlease, FineUgh = {}, {
        'select',
        'newproxy',
    }

    local function TypeFunction(Name)
        return Function(function(Value)
            local Type = Typeof(Value)

            if Name == 'type' and not LuaTypes[Type] then
                Type = 'userdata'
            end

            local Variable = GetContext(Value)

            if Variable and not IgnoreInEq[Variable] and Type ~= 'function' then
                return SafeValue((AppendCall(Name, Value)), Type)
            end

            return Type
        end, Name, true)
    end
    local function DefineTable(Table)
        local TableStr, OldMetatable = DefineVar(Table), getmetatable(Table)
        local NewMetatable, FixedMetatable = getmetatable(GetMetatable(TableStr)), {}

        if OldMetatable then
            for method, callback in next, NewMetatable do
                local oldMethod = OldMetatable[method]

                if oldMethod then
                    FixedMetatable[method] = function(...)
                        callback(...)

                        return oldMethod(...)
                    end
                else
                    FixedMetatable[method] = callback
                end
            end
        else
            FixedMetatable = NewMetatable
        end

        setmetatable(Table, FixedMetatable)

        Variables[Table] = TableStr

        return TableStr
    end
    local function SafeWrap(Func, Path)
        local Library, DoRecurse, DontLogAnyways, LogPath = split(Path, '.')[1], Path == 'table.concat', Path == 'table.pack', Path == 'table.insert'
        local OutFunc = Function(function(...)
            local args, info, DoSpy, DontRun = {...}, nil, nil, nil

            local function Iterate(tbl, recursive)
                local Var, Int = GetContext(tbl), GetInternalValue(tbl)

                if Var then
                    DoSpy = true

                    if Variables[Int] then
                        DontRun = true
                    end

                    return Int
                end

                for i, v in next, tbl do
                    local __DARKLUA_CONTINUE_40 = false

                    repeat
                        if DontRun then
                            return tbl
                        end

                        local Var = Variables[v]

                        if ParamsDict[v] then
                            DontRun = DontRun or (Library ~= 'table' and Nest > 0)

                            if DontRun then
                                break
                            end

                            __DARKLUA_CONTINUE_40 = true

                            break
                        end
                        if not DoSpy and Var then
                            DoSpy = true
                        end

                        info = info or Information[v]

                        local Val = GetInternalValue(v)

                        if Variables[Val] then
                            DontRun = true

                            break
                        end
                        if recursive and typeof(v) == 'table' then
                            for i2, v2 in next, v do
                                v[i2] = (typeof(v2) == 'table' and {
                                    (Iterate(v2, recursive)),
                                } or {v2})[1]
                            end
                        else
                            tbl[i] = Val
                        end

                        __DARKLUA_CONTINUE_40 = true
                    until true

                    if not __DARKLUA_CONTINUE_40 then
                        break
                    end
                end

                return tbl
            end

            args = Iterate(args, DoRecurse)

            if (DoSpy or DontRun) and not DontLogAnyways then
                if LogPath then
                    for _, arg in next, {...}do
                        if typeof(arg) == 'table' and not Variables[arg] then
                            DefineTable(arg)
                        end
                    end

                    Func(unpack(args))

                    local Var = AppendCall(Path, ...)

                    return Spy(Var)
                end
                if DontRun and not Settings.roblox then
                    local Var = AppendCall(Path, ...)

                    return Spy(Var)
                else
                    local Var, Statement = AppendCall(Path, ...)
                    local Values = pack(Func(unpack(args)))

                    if Path == 'string.byte' then
                        return unpack(Values)
                    end

                    return ToMultiVars(Statement, Values, true, info)
                end
            else
                return Func(...)
            end

            return Func(unpack(args))
        end, Path, true)

        Wrapped[OutFunc] = true

        return OutFunc
    end
    local function HookLibrary(Path, Extra)
        local Library, New = table.clone(TrueEnv[Path]), {}

        if Extra then
            for i, v in next, Extra do
                New[i] = (typeof(v) == 'function' and not Types[v] and {
                    (Function(v, Path .. '.' .. i, true)),
                } or {v})[1]
            end
        end

        for Key, Value in next, Library do
            New[Key] = (typeof(Value) == 'function' and not New[Key] and {
                (SafeWrap(Value, Path .. '.' .. Key)),
            } or {
                New[Key] or Value,
            })[1]
        end

        New = GetMetatable(Path, {
            __index = New,
            __newindex = function(_, k, v)
                Ast.addStatement(AST, Ast.Assign({
                    Ast.Index(Ast.Variable(Path), ToAST(k)),
                }, {
                    ToAST(v),
                }, true))
                error'attempt to modify a readonly table'
            end,
        })

        return New
    end
    local function DoIgnore(Key)
        if typeof(Key) ~= 'string' then
            return false
        end
        if Key:match(NON_ENGLISH) or NumbersDict[Key:sub(1, 1)] then
            return true
        end

        local Len = #Key

        if Len < 12 then
            return false
        elseif Len >= 24 then
            return true
        end

        local Uppercase, Lowercase = match(Key, '[A-Z]'), match(Key, '[a-z]')

        return Uppercase and (Lowercase or match(Key, '%d'))
    end
    local function IsWeird(Key)
        if Key == '' or typeof(Key) ~= 'string' or tonumber(sub(Key, 1, 1)) then
            return true
        end

        return match(Key, '[^%w_]') ~= nil or Illegal[Key]
    end
    local function Index(Key, Path, InNewindex)
        if Path == '...' then
            Path = '({...})'
        end
        if not IsWeird(Key) then
            return Path and string.format('%s.%s', tostring(Path), tostring(Key)) or Key
        end

        Path = Path or EnvName

        return string.format('%s[%s]', tostring(Path), tostring(tostring(Key)))
    end

    local TickCalls, startTime, startClock = 0, os.time(), os.clock()

    local function tick()
        TickCalls = TickCalls + 1

        return startTime + (os.clock() - startClock) + (TickCalls / 1000)
    end

    SetGarbageData{
        DoIgnore = DoIgnore,
        Strings = Strings,
    }

    local function HookFunction(Name)
        return Function(function(a, b)
            local typeA, typeB = Typeof(a), Typeof(b)

            assert(typeA == 'function' or not Types[a], "invalid argument #1 to '" .. Name .. "', function expected got " .. typeA)
            assert(typeB == 'function' or not Types[b], "invalid argument #2 to '" .. Name .. "', function expected got " .. typeB)

            local Old = AppendCall(Name, a, b)

            if not hookOp then
                Ast.addStatement(AST, Ast.Comment(Ast.RawText"hookOp isn't enabled, therefore hookfunction cannot be used."))
            end

            FunctionHooks[a] = b

            return Function(function(...)
                return a(...)
            end, Old, iscclosure(a))
        end, Name, true)
    end
    local function Restore(Func)
        FunctionHooks[Func] = nil
    end
    local function IsHooked(f)
        return FunctionHooks[f] ~= nil
    end

    if Nest == 0 then
        local PropertyHooks, Generated, ForceNormal, GlobalInstanceData, Attributes, Signals, ServicesCreated, Gets, urlCache = {
            DataModel = {
                PlaceId = {
                    Type = 'Primitive',
                    Name = 'number',
                },
                GameId = {
                    Type = 'Primitive',
                    Name = 'number',
                },
                JobId = {
                    Type = 'Primitive',
                    Name = 'string',
                },
            },
            Player = {
                Team = {
                    Type = 'Class',
                    Name = 'Team',
                },
                PlayerGui = {
                    Type = 'Class',
                    Name = 'PlayerGui',
                },
            },
            TextBox = {},
            ['*'] = {},
        }, {}, {Name = true}, InstanceLib.Object, {}, {}, nil, 0, {}

        function httpGet(url)
            local cached = urlCache[url]

            if cached then
                return cached
            end

            local out = process.exec('node', {
                './request.js',
                url,
            })
            local result, success = out.stdout, not out.stderr:find('Unable to fetch', 0, true)

            if success and result then
                urlCache[url] = result

                return result
            end

            return
        end

        local function HttpGet(Self, Url, Sync)
            local UrlType = Typeof(Url)
            local IsRaw = UrlType == 'string'

            assert(IsRaw or not Settings.roblox, string.format("invalid argument #1 to '%s', string expected got %s", tostring(Sync and 'HttpGetAsync' or 'HttpGet'), tostring(UrlType)))

            Gets = Gets + 1
            Url = GetInternalValue(Url)

            if Gets <= AllowedGetRequests and typeof(Url) == 'string' then
                insert(AllowedUrlsInTheEnd, Url)

                local result = httpGet(Url)

                if result then
                    SetInternalValue(Self.var, result)
                end
            end

            return TypeSpy(Self.var, 'string', nil, {
                is_http = true,
                url = Url,
            })
        end

        local MethodsHooks, EventHooks = {
            DataModel = {
                HttpGet = HttpGet,
                HttpGetAsync = function(self, url, idk, ...)
                    return HttpGet(self, url, true, ...)
                end,
                IsLoaded = function(self)
                    return SafeValue(self.var, true)
                end,
            },
            RunService = {
                IsClient = function(Self)
                    return SafeValue(Self.var, true)
                end,
                IsServer = function(Self)
                    return SafeValue(Self.var, false)
                end,
                IsStudio = function(Self)
                    return SafeValue(Self.var, false)
                end,
            },
            RbxAnalyticsService = {
                GetClientId = function(Self)
                    return SafeValue(Self.var, SharedGlobals.HWID)
                end,
            },
            HttpService = {
                JSONEncode = function(Self, Data)
                    Data = GetInternalValue(Data)

                    local Type, Meower = typeof(Data), TypeSpy(Self.var, 'string')

                    if Type ~= 'table' then
                        assert(not Settings.roblox, string.format("invalid argument #1 to 'JSONEncode', table expected got %s", tostring(Type)))

                        return Meower
                    else
                        for i, v in next, Data do
                            local _v = GetInternalValue(v)
                            local varV = Variables[_v]

                            if varV then
                                return Meower
                            end

                            Data[i] = _v
                        end
                    end

                    local Encoded = serde.encode('json', Data, false)

                    return SafeValue(Self.var, Encoded)
                end,
                JSONDecode = function(Self, Data)
                    Data = GetInternalValue(Data)

                    local Type = typeof(Data)

                    if Type ~= 'string' then
                        assert(not Settings.roblox, string.format("invalid argument #1 to 'JSONDecode', string expected got %s", tostring(Type)))

                        return TypeSpy(Self.var, 'table')
                    end

                    return SafeValue(Self.var, serde.decode('json', Data))
                end,
            },
            EncodingService = {
                DecompressBuffer = function(Self, Data)
                    Data = GetInternalValue(Data)

                    local Type = typeof(Data)

                    if Type ~= 'buffer' then
                        error(string.format("invalid argument #1 to 'DecompressBuffer', buffer expected got %s", tostring(Type)))
                    end
                    return SafeValue(Self.var, serde.decompress("zstd", Data))
                end
            },
            Terrain = {
                GetMaterialColor = function(self, material)
                    local mat = GetInternalValue(material)

                    assert(mat, 'Argument 1 missing or nil')

                    local type, Aliases, Stringed = typeof(mat), {
                        number = 'double',
                    }, tostring(mat)

                    assert(Stringed:find'.Material.', string.format('Unable to cast %s', tostring((LuaTypes[type] and {
                        Aliases[type] or type,
                    } or {
                        'null',
                    })[1])))

                    return SafeValue(self.var, GetTerrainMaterialColor(Stringed:match'%w+%.%w+%.(.+)'))
                end,
            },
            ['*'] = {
                GetAttribute = function(self, attribute)
                    return SafeValue(self.var, (Attributes[self.self] or {})[attribute])
                end,
                GetAttributes = function(self)
                    return SafeValue(self.var, Attributes[self.self] or {})
                end,
                SetAttribute = function(self, attribute, value)
                    local AttributesList = Attributes[self.self] or {}

                    AttributesList[attribute] = value
                    Attributes[self.self] = AttributesList
                end,
            },
        }, {
            RunService = {
                Heartbeat = {
                    ReturnValue = {TIME_TO_WAIT},
                },
            },
        }

        for funcName, func in next, InstanceFuncs do
            MethodsHooks['*'][funcName] = function(Self, ...)
                local Values = pack(func(SpiedToInstance[Self.self], ...))

                if Values.n == 1 then
                    return SafeValue(Self.var, Values[1])
                end

                return unpack(Values)
            end
        end

        MethodsHooks.DataModel.HttpGetAsync = MethodsHooks.DataModel.HttpGet

        local function GetChildren(Parent, Recursive)
            if not ServicesCreated and SpiedToInstance[Parent] == SpiedToInstance[SecureEnv.game] then
                for ServiceName in next, Services do
                    pcall(function()
                        insert(Children[Parent], CreateInstance(Index(ServiceName, 'game'), ServiceName, true))
                    end)
                end

                ServicesCreated = true
            end

            local Kids = Children[Parent]

            if not Kids then
                return {}
            end
            if not Recursive then
                return Kids
            end

            local Total = {}

            for _, Child in next, Kids do
                for _, v in next, GetChildren(Child, Recursive)do
                    insert(Total, v)
                end

                insert(Total, Child)
            end

            return Total
        end

        MethodsHooks['*'].GetChildren = function(Self)
            SetIterator(Self.var, 'number', 'Instance')

            return SafeValue(Self.var, GetChildren(Self.self, false))
        end
        MethodsHooks['*'].GetDescendants = function(Self)
            SetIterator(Self.var, 'number', 'Instance')

            return SafeValue(Self.var, GetChildren(Self.self, true))
        end

        local function SetParent(Instance, Parent)
            local SpiedParentV1, SpiedInstanceV1 = SpiedToInstance[Parent], SpiedToInstance[Instance]
            local RealSelf, RealParent = SpiedInstanceV1 or Instance, SpiedParentV1 or Parent

            for oldParent, children in next, Children do
                local idx = find(children, RealSelf)

                if idx then
                    table.remove(children, idx)

                    break
                end
            end

            RealSelf.Parent = RealParent

            local SpiedParent, SpiedInstance

            if SpiedParentV1 then
                SpiedParent = Parent
            else
                for Spied, Real in next, SpiedToInstance do
                    if Real == Parent then
                        SpiedParent = Spied

                        break
                    end
                end
            end
            if SpiedInstanceV1 then
                SpiedInstance = Instance
            else
                for Spied, Real in next, SpiedToInstance do
                    if Real == Instance then
                        SpiedInstance = Spied

                        break
                    end
                end
            end
            if SpiedParent then
                local list = Children[SpiedParent] or {}

                insert(list, SpiedInstance)

                Children[SpiedParent] = list
            end
        end

        function CreateInstance(Variable, Class, EnableCache, FromInstanceNew)
            local function GenerateProperty(ValueType, Name)
                if Generated[ValueType] then
                    return Generated[ValueType]
                end

                local Category = ValueType.Category or ValueType.Type

                if Category == 'Primitive' then
                    local Type = AliasToName[ValueType.Name] or ValueType.Name

                    if Type == 'number' then
                        return math.random(0, 1e6)
                    elseif Type == 'string' then
                        return GenId(8)
                    end
                elseif Category == 'Class' then
                    return CreateInstance(Name, ValueType.Name, true)
                elseif Category == 'DataType' then
                    if ValueType.Name == 'Instances' then
                        local Meow = DefineVar(Ast.Index(Ast.Variable(Name), Ast.Number(1)))

                        return {
                            CreateInstance(Meow),
                        }
                    end
                end

                return Spy(Name)
            end
            local function CreateEvent(Self, EventName, Params, EventStr)
                local Sigs = Signals[Self] or {}

                if Sigs[EventName] then
                    return Sigs[EventName]
                end

                local BaseVar, Hooks = Ast.Variable(EventStr), EventHooks[Class] or {}
                local Hook = Hooks[EventName]
                local Signal = GetMetatable(EventStr, {
                    __index = function(event, Key)
                        assert(event, string.format("missing argument #1 to '%s' (RBXScriptSignal expected)", tostring(Key)))

                        local key, Var = (typeof(Key) == 'string' and {
                            (Key:lower()),
                        } or {Key})[1], DefineVar(Ast.Index(BaseVar, ToAST(Key)))

                        if key == 'connect' or Key == 'ConnectParallel' or Key == 'connectParallel' or Key == 'connectparallel' then
                            local Spied = Function(function(x, callback)
                                checktype(callback, 'function', string.format("invalid argument #2 to '%s'", tostring(key)))

                                local Info = {param_infos = Params}
                                local Conn, int = DefineVar(Ast.Namecall(BaseVar, Ast.Variable(Key), {
                                    ToAST(callback, Info),
                                }), false, true), {}

                                int.Connected = true
                                int.Disconnect = function(self, ...)
                                    assert(self, "missing argument #1 to 'Disconnect' (RBXScriptConnection expected)")

                                    local Type = Typeof(self)

                                    assert(Type == 'RBXScriptConnection', "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got " .. Type .. ')')
                                    assert(int.Connected, 'Connection is not connected!')

                                    int.Connected = false
                                end
                                int.disconnect = int.Disconnect

                                local Connection = GetMetatable(Conn, {
                                    __index = function(_, Key)
                                        return SafeValue(DefineVar(Ast.Index(Ast.Variable(Conn), ToAST(Key))), int[Key])
                                    end,
                                })

                                Types[Connection] = 'RBXScriptConnection'

                                return Connection
                            end, Var, true)

                            return Spied
                        elseif key == 'wait' then
                            return Function(function(_, ...)
                                local ReturnedMeowers, Vars = {}, {}

                                for i, v in next, Params do
                                    local Var = GetCount(v.Name)
                                    local Spied, thingInfo = Spy(Var, (Hook and Hook.ReturnValue and {
                                        (Hook.ReturnValue[i]),
                                    } or {nil})[1]), v.Type

                                    if thingInfo.Category == 'Primitive' then
                                        local Type = AliasToName[thingInfo.Name] or thingInfo.Name

                                        Types[Spied] = Type
                                    end

                                    insert(ReturnedMeowers, Spied)
                                    insert(Vars, Ast.Variable(Var))
                                end

                                Ast.addStatement(AST, Ast.Assign(Vars, {
                                    Ast.Namecall(BaseVar, Ast.Variable(Key), TupleToAST(...)),
                                }, false))
                                task.wait()

                                return unpack(ReturnedMeowers)
                            end, Var, true)
                        elseif key == 'once' then
                            return Spy(Var)
                        end

                        error(string.format('%s is not a valid member of RBXScriptSignal', tostring(Key)))
                    end,
                })

                Types[Signal] = 'RBXScriptSignal'
                Sigs[EventName] = Signal
                Signals[Self] = Sigs

                return Signal
            end

            if EnableCache then
                for x, Real in next, SpiedToInstance do
                    if Real.ClassName == Class then
                        return x
                    end
                end
            end

            local InstanceData, IsSpied = InstanceLib[Class], not Class

            if FromInstanceNew then
                assert(InstanceData, string.format('Unable to create an Instance of type "%s"', tostring(Class)))
            end

            InstanceData = InstanceData or GlobalInstanceData

            local Hooks, Properties, Callbacks, imsocute, MethodHooksSelf, Methods, Events, ActualInstance = PropertyHooks[Class] or {}, InstanceData.properties, InstanceData.callbacks or {}, IsSpied and {
                Name = Spy(Index('Name', Variable)),
            } or Instance.new(Class), MethodsHooks[Class] or MethodsHooks['*'], InstanceData.methods, InstanceData.events, {}

            for PropertyName, Property in next, Properties do
                local s, v = pcall(function()
                    return imsocute[PropertyName]
                end)

                ActualInstance[PropertyName] = (s and {v} or {
                    (GenerateProperty(Property.ValueType, PropertyName)),
                })[1]
            end

            local is_property, Instance = not FromInstanceNew, nil
            local Mt = {
                __index = function(Self, Key)
                    assert(Key, 'invalid argument #2 (string expected, got nil)')

                    local Oldest, Prefix = Key, Key:sub(1, 1)

                    if IsLowerCase(Prefix:byte()) then
                        Key = Prefix:upper() .. Key:sub(2)
                    end
                    if Callbacks[Key] then
                        error(string.format('%s is a callback member of %s; you can only set the callback value, get is not available', tostring(Key), tostring(Class)))
                    end

                    local ErrMsg = string.format('%s is not a valid member of %s "%s"', tostring(Oldest), tostring(Class or 'Instance'), tostring(IsSpied and Class or imsocute.Name))

                    if typeof(Key) == 'string' and Key:find'\0' then
                        error(ErrMsg)
                    end

                    local Hook, _, Indexed, isName = Hooks[Key] or PropertyHooks['*'][Key], Information[Self] or {}, DefineVar(Ast.Index(Ast.Variable(Variable), ToAST(Oldest)), false, true), (Key == 'name' or Key == 'Name')

                    if Hook ~= nil or isName then
                        local Property = (isName and {
                            (imsocute.Name),
                        } or {
                            (GenerateProperty(Hook, Indexed)),
                        })[1]

                        if Typeof(Property) == 'Instance' then
                            return Property
                        end

                        local Spied = Spy(Indexed, Property, {
                            is_property = is_property,
                            key = Key,
                        })

                        rawset(Self, Key, Spied)

                        return Spied
                    elseif Key == 'Parent' then
                        for Parent, List in next, Children do
                            if find(List, Self) then
                                return SafeValue(Indexed, Parent)
                            end
                        end

                        local P = ActualInstance.Parent

                        if P then
                            for Spied, Meow in next, SpiedToInstance do
                                if P == Meow then
                                    P = Spied

                                    break
                                end
                            end

                            return SafeValue(Indexed, P)
                        end

                        return SafeValue(Indexed, nil)
                    end

                    local Property = ActualInstance[Key]

                    if Property ~= nil then
                        if typeof(Property) == 'Instance' then
                            local Meowed = CreateInstance(Indexed, Property.ClassName)
                            local Real = SpiedToInstance[Meowed]

                            if typeof(Real) == 'table' then
                                for i in next, Real do
                                    pcall(function()
                                        Real[i] = Property[i]
                                    end)
                                end
                            end

                            return Meowed
                        end

                        local Spied = Spy(Indexed, Property, {
                            is_property = is_property,
                            force_normal = ForceNormal[Key],
                        })

                        rawset(Self, Key, Spied)

                        return Spied
                    end

                    local Kids = Children[Instance] or {}

                    for _, v in next, Kids do
                        if SpiedToInstance[v].Name == Key then
                            return v
                        end
                    end

                    if Class == 'DataModel' and Services[Key] then
                        for _, v in next, Kids do
                            if SpiedToInstance[v].ClassName == Key then
                                return v
                            end
                        end

                        return CreateInstance(Indexed, Key, true)
                    end
                    if GlobalInstanceData.properties[Key] then
                        local Spied = Spy(Indexed, GenerateProperty(GlobalInstanceData.properties[Key].ValueType, Indexed))

                        rawset(Self, Key, Spied)

                        return Spied
                    elseif Properties[Key] then
                        local Property = GenerateProperty(Properties[Key].ValueType, Indexed)
                        local Real = SpiedToInstance[Property]

                        if Real then
                            SetParent(Real, Instance)

                            return Property
                        end

                        return SafeValue(Indexed, Property, {
                            is_property = is_property,
                            force_normal = true,
                        })
                    end

                    local Method, Method2, FuncName = MethodHooksSelf[Key] or MethodsHooks['*'][Key], Methods[Key] or GlobalInstanceData.methods[Key], Index(Key, Variable)

                    if Method then
                        return Function(function(...)
                            return Method({
                                var = AppendCall(Indexed, ...),
                                self = ...,
                            }, select(2, ...))
                        end, FuncName, true)
                    elseif Method2 then
                        return Function(function(...)
                            local Var = AppendCall(Indexed, ...)
                            local Thing = Spy(Var)

                            if not hookOp then
                                local Value = GenerateProperty(Method2.ReturnType, Var)

                                SetInternalValue(Var, Value)
                            end

                            return Thing
                        end, FuncName, true)
                    end

                    local Event = Events[Key]

                    if Event then
                        return CreateEvent(Self, Event.Name, Event.Parameters, Indexed)
                    elseif GlobalInstanceData.events[Key] then
                        local Spied = Spy(Indexed)

                        rawset(Self, Key, Spied)

                        return Spied
                    end

                    assert(not Settings.roblox, ErrMsg)

                    local Spied = Spy(Indexed, nil, {indexed_instance = true})

                    rawset(Self, Key, Spied)

                    return Spied
                end,
                __newindex = function(Self, Key, Value)
                    Define(Ast.Index(Ast.Variable(Variable), ToAST(Key)), ToAST(Value), true, true)

                    local Info = Information[Self] or {}

                    if Key == 'Parent' then
                        if Info.destroyed or Info.service then
                            local Type = Typeof(Value)

                            assert(Type == 'Instance', string.format('invalid argument #3 (Instance expected, got %s)', tostring(Type)))
                            error(string.format('The Parent property of %s is locked, current parent: NULL, new parent %s', tostring(ActualInstance.Name), tostring((SpiedToInstance[Value] or Value).Name)))
                        end
                        if SpiedToInstance[Value] == ActualInstance then
                            error(string.format('Attempt to set %s as its own parent', tostring(ActualInstance.Name)))
                        end
                    end

                    local Property = Properties[Key]

                    if Property then
                        assert(Property.CanSave, string.format('Unable to assign property %s. Property is read only', tostring(Key)))
                    else
                        if Callbacks[Key] then
                            local callbacks = SharedGlobals.Callbacks[Self] or {}

                            insert(callbacks, {
                                Key = Key,
                                Callback = Value,
                            })

                            SharedGlobals.Callbacks[Self] = callbacks
                        else
                            error(string.format('%s is not a valid member of %s "%s"', tostring(Key), tostring(Class), tostring(ActualInstance.Name)))
                        end
                    end

                    ActualInstance[Key] = GetInternalValue(Value)
                end,
                __tostring = function()
                    return Variable
                end,
                __call = function(Self, ...)
                    return error('attempt to call a Instance value', 2)
                end,
                __add = function(Self, ...)
                    return error('attempt to perform arithmetic on a Instance value', 2)
                end,
                __div = function(Self, ...)
                    return error('attempt to perform arithmetic on a Instance value', 2)
                end,
                __mul = function(Self, ...)
                    return error('attempt to perform arithmetic on a Instance value', 2)
                end,
                __unm = function(Self, ...)
                    return error('attempt to perform arithmetic on a Instance value', 2)
                end,
                __sub = function(Self, ...)
                    return error('attempt to perform arithmetic on a Instance value', 2)
                end,
                __pow = function(Self, ...)
                    return error('attempt to perform arithmetic on a Instance value', 2)
                end,
                __concat = function(Self, ...)
                    return error('attempt to concatenate a Instance value', 2)
                end,
            }

            for i, v in next, Math do
                Mt[i] = function(Self, Value)
                    local TypeLhs, Lhs = Typeof(Self)
                    local TypeRhs, Rhs = Typeof(Value)
                    local Symbol = Math[i]
                    local Var = DefineVar(Ast.BinaryOp(ToAST(Self), Symbol, ToAST(Value)))

                    if TypeLhs == 'Instance' or TypeRhs == 'Instance' or TypeLhs == 'table' or TypeRhs == 'table' then
                        if i == '__concat' then
                            error(string.format('attempt to concatenate %s with %s', tostring(TypeLhs), tostring(TypeRhs)))
                        end

                        error(string.format('attempt to perform arithmetic (%s) on %s and %s', tostring(i:sub(3)), tostring(TypeLhs), tostring(TypeRhs)))
                    end

                    return GetValue(Lhs, Symbol, Rhs, Var)
                end
            end

            Instance = GetMetatable(Variable, Mt)
            SpiedToInstance[Instance] = ActualInstance
            Types[Instance] = 'Instance'
            Variables[Instance] = Variable
            Information[Instance] = {
                service = Services[Class] ~= nil,
                was_created = FromInstanceNew,
            }

            return Instance
        end

        local function GetParent(Instance)
            for Meow, List in next, Children do
                if find(List, Instance) then
                    return Meow
                end
            end
        end

        MethodsHooks['*'].FindFirstChild = function(Self, childName, Recursive)
            local Type = Typeof(childName)

            Assert(Type, 'string', "invalid argument #1 to 'FindFirstChild', string expected got " .. Type, true)

            local Kids = GetChildren(Self.self, Recursive)

            for _, Kid in next, Kids do
                if SpiedToInstance[Kid].Name == childName then
                    return Kid
                end
            end

            if Settings.roblox then
                return SafeValue(Self.var, nil)
            else
                return CreateInstance(Self.var)
            end
        end
        MethodsHooks['*'].FindFirstChildWhichIsA = function(Self, className, Recursive)
            local Type = Typeof(className)

            Assert(Type, 'string', "invalid argument #1 to 'FindFirstChildWhichIsA', string expected got " .. Type, true)

            local Kids = GetChildren(Self.self, Recursive)

            for _, Kid in next, Kids do
                if InstanceFuncs.IsA(SpiedToInstance[Kid].ClassName, className) then
                    return Kid
                end
            end

            if Settings.roblox then
                return SafeValue(Self.var, nil)
            else
                return CreateInstance(Self.var)
            end
        end
        MethodsHooks['*'].FindFirstChildOfClass = function(Self, className, Recursive)
            local Type = Typeof(className)

            Assert(Type, 'string', "invalid argument #1 to 'FindFirstChildOfClass', string expected got " .. Type, true)

            local Kids = GetChildren(Self.self, Recursive)

            for _, Kid in next, Kids do
                if SpiedToInstance[Kid].ClassName == className then
                    return Kid
                end
            end

            if Settings.roblox then
                return SafeValue(Self.var, nil)
            else
                return CreateInstance(Self.var)
            end
        end
        MethodsHooks['*'].FindFirstAncestorWhichIsA = function(Self, className, Recursive)
            local Type = Typeof(className)

            Assert(Type, 'string', "invalid argument #1 to 'FindFirstAncestorWhichIsA', string expected got " .. Type, true)

            local Inst = Self.self

            local function FindFirstAncestor(Kid)
                if not Kid then
                    return
                end
                if SpiedToInstance[Kid].ClassName == className then
                    return Kid
                end

                return FindFirstAncestor(GetParent(Kid))
            end

            local Ancestor = FindFirstAncestor(Inst)

            return Spy(Self.var, Ancestor)
        end
        MethodsHooks['*'].WaitForChild = function(Self, childName, timeOut)
            local Type = Typeof(childName)

            assert(Type == 'string', "invalid argument #1 to 'WaitForChild', string expected got " .. Type)

            local Instance = CreateInstance(Self.var)

            SpiedToInstance[Instance].Name = childName

            return Instance
        end

        local game, workspace = CreateInstance('game', 'DataModel'), CreateInstance('workspace', 'Workspace')

        SpiedToInstance[game].Name = 'UGC'
        SecureEnv.game = game
        SecureEnv.Game = game
        SecureEnv.workspace = workspace
        SecureEnv.Workspace = workspace
        SecureEnv.script = CreateInstance('script', 'LocalScript')
        Children[game] = {workspace}

        do
            local Cam = Index('CurrentCamera', 'workspace')
            local Camera = CreateInstance(Cam, 'Camera')

            SetParent(Camera, workspace)
        end

        local function Clone(Self, Recursive)
            local Instance = SpiedToInstance[Self.self]
            local New = CreateInstance(Self.var, Instance.ClassName, false)
            local NewInstance = SpiedToInstance[New]

            for key, Property in next, Instance do
                NewInstance[key] = Property
            end

            if Recursive then
                local Kids = {}

                for _, Kid in next, Children[Self.self] or {}do
                    insert(Kids, Clone({
                        self = Kid,
                        var = Variables[Kid],
                    }, Recursive))
                end

                Children[New] = Kids
            end

            Information[New] = Information[Self.self] or {}
            Attributes[New] = Attributes[Self.self] or {}

            return New
        end

        MethodsHooks['*'].Clone = function(Self)
            return Clone(Self, true)
        end
        MethodsHooks['*'].Destroy = function(Self)
            local Meow = Self.self
            local Info = Information[Meow] or {}

            if Info.service then
                local ActualInstance = SpiedToInstance[Meow]

                error(string.format('The Parent property of %s is locked', tostring(ActualInstance.Name)))
            end

            Info.destroyed = true
            Information[Meow] = Info

            for i, List in next, Children do
                local Index = find(List, Meow)

                if Index then
                    table.remove(List, Index)
                end
            end
        end
        MethodsHooks.DataModel.GetService = function(Self, name)
            checktype(name, 'string', "invalid argument #1 to 'GetService'")

            if name == 'nil' then
                return SafeValue(Self.var, nil)
            end

            name = name:sub(1, (name:find'\0' or 0) - 1)

            local Service = Services[name]

            assert(Service, string.format("'%s' is not a valid Service name", tostring(name)))

            return CreateInstance(Self.var, name, true)
        end
        SecureEnv.UserSettings = function()
            return CreateInstance(AppendCall'UserSettings', 'UserSettings', true)
        end
        SecureEnv.Instance = table.freeze{
            new = Function(function(Class, Parent)
                local Type = Typeof(Class)

                assert(Type == 'string', "invalid argument #1 to 'new', string expected got " .. Type)

                local Var = AppendCall('Instance.new', Class, Parent)
                local Created = CreateInstance(Var, Class, false, true)

                if Parent then
                    local PType = Typeof(Parent)

                    assert(PType == 'Instance', "invalid argument #2 to 'new', Instance expected got " .. PType)

                    local List = Children[Parent] or {}

                    insert(List, Created)

                    Children[Parent] = List
                end

                return Created
            end, 'Instance.new', true),
            fromExisting = Function(function(Old)
                local PType = Typeof(Old)

                assert(PType == 'Instance', "invalid argument #1 to 'fromExisting', Instance expected got " .. PType)

                return Clone(Old, false)
            end, 'Instance.fromExisting', true),
        }
        Variables[SecureEnv.Instance] = 'Instance'
        SecureEnv.cloneref = function(original)
            local Var, Type = AppendCall('cloneref', original), Typeof(original)

            Assert(Type, 'Instance', string.format("invalid argument #1 to 'clonref', Instance expected got %s", tostring(Type)), true)

            return Clone({
                self = original,
                var = Var,
            }, true)
        end
        SecureEnv.gethui = function()
            local x = AppendCall'gethui'

            return Spy(x, CreateInstance(x, 'CoreGui', true))
        end
    end

    local function PleaseBeSafe(Pattern)
        if typeof(Pattern) == 'string' then
            local x, y = isUnsafePattern(Pattern)

            if x then
                error(string.format('[REGEX ERROR]: %s', tostring(y)))
            end
        end
    end

    SecureEnv.string = HookLibrary('string', {
        find = Function(function(str, pat, ...)
            if str == true or pat == true then
                Ast.addStatement(AST, Ast.FunctionCall(Ast.Variable'LPH_CRASH', {}))
                error'LPH_CRASH()'
            end

            local VarStr, VarPat, Out, Statement = Variables[str], Variables[pat], nil, nil

            if VarStr or VarPat then
                Out, Statement = AppendCall('string.find', str, pat, ...)

                local vS, vP = GetInternalValue(str), GetInternalValue(pat)

                if (VarStr and Variables[vS] == VarStr) or (VarPat and Variables[vP] == VarPat) then
                    return TypeSpy(Out, 'string')
                end

                str, pat = vS, vP
            end

            PleaseBeSafe(pat)

            if Variables[str] or Variables[pat] then
                return Spy(Out)
            end

            local vals = pack(string.find(str, pat, ...))

            if VarStr or VarPat then
                return ToMultiVars(Statement, vals, true)
            end

            return unpack(vals)
        end, 'string.find', true),
        match = function(str, pat, init)
            print('match', str, pat)

            local VStr, VPat, VInit, VarStr, VarPat, VarInit = GetInternalValue(str), GetInternalValue(pat), GetInternalValue(init), Variables[str], Variables[pat], Variables[init]

            if VarStr or VarPat or VarInit then
                local Values, Vars, Spied = pack(pcall(match, VStr, VPat, VInit)), {}, {}

                for i = 2, max(Values.n, 3)do
                    local Var = GetVar()

                    if Values[1] then
                        SetInternalValue(Var, Values[i])
                    end

                    insert(Vars, Ast.Variable(Var))
                    insert(Spied, Spy(Var))
                end

                Ast.addStatement(AST, Ast.Assign(Vars, {
                    Ast.FunctionCall(Ast.Index(Ast.Variable'string', Ast.String'match'), TupleToAST(str, pat, init)),
                }))

                return unpack(Spied)
            end

            PleaseBeSafe(VPat)

            return match(VStr, VPat, VInit)
        end,
        gmatch = function(...)
            local args, DoLog, DontRun = {...}, nil, nil

            for i, v in next, args do
                if Variables[v] then
                    DoLog = true

                    local val = GetInternalValue(v)

                    if Variables[val] then
                        DontRun = true

                        break
                    end

                    args[i] = val
                end
            end

            PleaseBeSafe(args[2])

            if DoLog or DontRun then
                local Var, Success, Iterator = AppendCall('string.gmatch', ...), pcall(string.gmatch, unpack(args))

                if not Success or DontRun then
                    return Spy(Var)
                end

                return Function(function(...)
                    local Values, Vars, Spied = pack(Iterator(...)), {}, {}

                    for i = 1, max(Values.n, 1)do
                        local Var = GetVar()

                        insert(Vars, Ast.Variable(Var))
                        insert(Spied, Spy(Var, Values[i]))
                    end

                    Ast.addStatement(AST, Ast.Assign(Vars, {
                        Ast.FunctionCall(Ast.Variable(Var), TupleToAST(...)),
                    }))

                    return unpack(Spied)
                end, Var, true)
            end

            return string.gmatch(unpack(args))
        end,
        pack = string.pack,
        unpack = string.unpack,
        len = function(x)
            checktype(x, 'string', "invalid argument #1 to 'len'", true)

            return SecureEnv[CallId .. 'CHECKLEN'](x)
        end,
        rep = function(x, y)
            if typeof(y) == 'number' and y >= 1e6 then
                AppendCall('string.rep', x, y)

                return x
            end

            return rep(x, y)
        end,
    })
    SecureEnv.table = HookLibrary('table', {
        create = table.create,
        move = table.move,
        concat = function(a, ...)
            if Typeof(a) ~= 'table' then
                error(string.format("invalid argument #1 to 'table.concat' (table expected, got %s)", tostring(Typeof(a))))
            end

            return SafeValue(table.concat(a, ...), table.concat(GetInternalValue(a), ...))
        end,
    })

    local RandomCombinations, LastRandom = {}

    SecureEnv.math = HookLibrary('math', {
        random = function(min, max)
            if not min and not max then
                return math.random()
            end

            local _min, _max, Combinations, Result = GetInternalValue(min), GetInternalValue(max), (RandomCombinations[min])

            if Variables[_min] or Variables[_max] then
                return TypeSpy((AppendCall('math.random', min, max)), 'number')
            end
            if (max == 1e4 and min == 0) or (min == 3 and max == 65) or (max == 255) or (min == 1) then
                return math.random(min, max)
            end
            if _min and _max then
                Result = math.random(_min, _max)
            elseif _min then
                Result = math.random(_min)
            else
                error("invalid argument #1 to 'random' (number expected, got nil)")
            end
            if Combinations then
                if Combinations[max] then
                    return Result
                else
                    Combinations[max] = true
                end
            elseif min and max then
                RandomCombinations[min] = {[max] = true}
            end
            if LastRandom and LastRandom == max + 1 then
                LastRandom = max

                return Result
            else
                if max == 255 or min == 1 then
                    return Result
                end

                LastRandom = max
            end

            local Var = AppendCall('math.random', min, max)

            return SafeValue(Var, Result, {is_random = true})
        end,
        nan = 0/0
    })
    SecureEnv.os = HookLibrary('os', {
        clock = function()
            local Var = AppendCall'os.clock'

            return Spy(Var, os.clock() + SharedGlobals.Delay)
        end,
        time = function(...)
            local Var = AppendCall('os.time', ...)

            return Spy(Var, os.time(...) + SharedGlobals.Delay)
        end,
        date = function(meow)
            local Var, Date = AppendCall('os.date', meow), os.date(meow, os.time() + SharedGlobals.Delay)

            return SafeValue(Var, Date)
        end,
        difftime = function(...)
            local Var = AppendCall('os.difftime', ...)

            return Spy(Var, os.difftime(...))
        end,
    })
    SecureEnv.bit32 = HookLibrary('bit32', {})
    SecureEnv.bit = SecureEnv.bit32
    SecureEnv.coroutine = HookLibrary('coroutine', {
        yield = Function(function(...)
            if coroutine.running() == MAIN_THREAD then
                print('No i will not yield', Nest)

                return
            end

            print'Yield'

            Luraph = true

            return coroutine.yield(...)
        end, 'coroutine.yield', true),
        create = coroutine.create,
    })
    SecureEnv.utf8 = HookLibrary'utf8'
    SecureEnv.buffer = HookLibrary'buffer'
    SecureEnv.vector = HookLibrary'vector'

    do
        local function Or(a, b)
            if a == nil then
                return b
            end

            return a
        end

        roblox.Random = RandomLib
        roblox.DateTime = DateTime
        roblox.TweenInfo = {
            new = function(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
                time = Or(time, 1)
                easingStyle = Or(easingStyle, Enum.EasingStyle.Quad)
                easingDirection = Or(easingDirection, Enum.EasingDirection.Out)
                reverses = Or(reverses, false)
                repeatCount = Or(repeatCount, 0)
                delayTime = Or(delayTime, 0)

                if time then
                    assert(Typeof(time) == 'number', 'TweenInfo.new first argument expects a number for time.')
                end
                if easingStyle then
                    assert(Typeof(easingStyle) == 'EnumItem', 'TweenInfo.new second argument expects Enum.EasingStyle input')
                    assert(tostring(easingStyle):find'Enum.EasingStyle', 'TweenInfo.new second argument expects Enum.EasingStyle input')
                end
                if easingDirection then
                    assert(Typeof(easingDirection) == 'EnumItem', 'TweenInfo.new third argument expects Enum.EasingDirection input')
                    assert(tostring(easingDirection):find'Enum.EasingDirection', 'TweenInfo.new third argument expects Enum.EasingDirection input')
                end
                if repeatCount then
                    assert(Typeof(repeatCount) == 'number', 'TweenInfo.new fourth arg should be a number for RepeatCount.')
                end
                if reverses then
                    assert(Typeof(reverses) == 'boolean', 'TweenInfo.new fifth arg should be a boolean for Reverses.')
                end
                if delayTime then
                    assert(Typeof(delayTime) == 'number', 'TweenInfo.new sixth arg should be a number for DelayTime.')
                end

                return {
                    EasingDirection = easingDirection,
                    Time = time,
                    DelayTime = delayTime,
                    RepeatCount = repeatCount,
                    EasingStyle = easingStyle,
                    Reverses = reverses,
                }
            end,
        }

        local Libraries = {
            'Vector2',
            'Vector3',
            "Vector2int16",
            "Vector3int16",
            "Path2DControlPoint",
            'CFrame',
            'BrickColor',
            'UDim',
            'UDim2',
            'Font',
            'Enum',
            'Color3',
            'Ray',
            'NumberSequence',
            'NumberRange',
            'NumberSequenceKeypoint',
            'ColorSequence',
            'ColorSequenceKeypoint',
            'RaycastParams',
            'PhysicalProperties',
            'Random',
            'DateTime',
            'Axes',
            'Content',
            'Faces',
            'Region3',
            'Region3int16',
            'Rect',
            'TweenInfo',
        }

        local function ShallowCopy(thing)
            if Variables[thing] then
                return thing
            end

            local Type = typeof(thing)

            if Type ~= 'table' then
                return thing
            end

            local new = {}

            for i, v in next, thing do
                new[ShallowCopy(i)] = ShallowCopy(v)
            end

            return new
        end

        for _, LibraryName in next, Libraries do
            local Library, LibVar = roblox[LibraryName], Ast.Variable(LibraryName)

            SecureEnv[LibraryName] = (GetMetatable(LibraryName, {
                __index = Library and function(Self, Key)
                    local Indexed, Var = Index(Key, LibraryName), DefineVar(Ast.Index(LibVar, ToAST(Key)), false, true)

                    if LibraryName == 'Enum' then
                        assert(pcall(function()
                            return Library[Key]
                        end), string.format('%s is not a valid member of "Enum"', tostring(Key)))
                    end

                    local Callback = Library[Key]

                    if Callback then
                        if typeof(Callback) == 'function' then
                            local Func = Function(function(...)
                                local function Wrap(x)
                                    if Variables[x] or typeof(x) ~= 'table' then
                                        return GetInternalValue(x)
                                    end

                                    for i, v in next, x do
                                        x[i] = Wrap(v)
                                    end

                                    return x
                                end

                                local OldArgs, Args = ShallowCopy{...}, Wrap{...}
                                local Values = pack(pcall(Callback, unpack(Args)))
                                local Success, Vars, Spied = Values[1], {}, {}

                                for i = 2, Values.n do
                                    local Var = GetVar()

                                    insert(Spied, Spy(Var, ((Success or i ~= 2) and {
                                        (Values[i]),
                                    } or {nil})[1]))
                                    insert(Vars, Ast.Variable(Var))
                                end

                                Ast.addStatement(AST, Ast.Assign(Vars, {
                                    Ast.FunctionCall(Ast.Variable(Var), TupleToAST(unpack(OldArgs))),
                                }))

                                if not Success then
                                    warn(Values[2])

                                    if Settings.roblox then
                                        error(tostring(Values[2]))
                                    end
                                end

                                return unpack(Spied)
                            end, Indexed, true)

                            return Func
                        end

                        local Spied = Spy(Var, Callback)

                        return Spied
                    end

                    local Spied = Spy(Var)

                    return Spied
                end or function(Self, Key)
                    local Var = DefineVar(Ast.Index(LibVar, ToAST(Key)), false, true)

                    return Spy(Var)
                end,
                __call = function(Self, ...)
                    AppendCall(LibraryName, ...)
                    error(string.format('attempt to call a %s value', tostring(Typeof(Self))))
                end,
            }))
        end

        Types[SecureEnv.Enum] = 'Enums'
    end

    SecureEnv.getmetatable = function(table)
        local Var = GetContext(table)

        if Var then
            local Var, Type = AppendCall('getmetatable', table), Typeof(table)

            if Type == 'table' then
                return nil
            elseif Type == 'string' then
            elseif Type == 'number' or Type == 'nil' or Type == 'function' then
                return nil
            else
                return Spy(Var, 'The metatable is locked')
            end
        end

        return getmetatable(table)
    end
    SecureEnv.setmetatable = function(table, mt)
        if Variables[table] then
            local a = {table, mt}

            table = GetInternalValue(table)

            local TypeTbl, TypeMt = Typeof(table), Typeof(mt)

            assert(TypeTbl == 'table', string.format("invalid argument #1 to 'setmetatable' (table expected, got %s)", tostring(TypeTbl)))
            assert(TypeMt == 'table' or TypeMt == 'nil', string.format("invalid argument #2 to 'setmetatable' (nil or table expected, got %s)", tostring(TypeMt)))
            AppendCall('setmetatable', unpack(a))
            assert(not isfrozen(table), 'attempt to modify a readonly table')

            return
        end

        return setmetatable(table, mt)
    end
    SecureEnv.tonumber = function(num, base)
        local VarNum, VarBase = Variables[num], Variables[base]

        if VarNum or VarBase then
            local VNum, VBase = GetInternalValue(num), (base and {
                (GetInternalValue(base)),
            } or {10})[1]

            if typeof(VNum) == 'number' then
                if Variables[VBase] then
                    VBase = 10
                end
            end

            local Var = AppendCall('tonumber', num, base)

            return Spy(Var, tonumber(VNum, VBase))
        end

        return tonumber(num, base)
    end
    SecureEnv.tostring = function(value)
        local VarVal = Variables[value]

        if VarVal then
            if typeof(value) == 'function' and CClosures[value] then
                return tostring(value)
            end

            local Info, Value = Information[value], GetInternalValue(value)
            local Type, Var = Typeof(Value), AppendCall('tostring', value)

            if Type == 'function' then
                return Spy(Var, tostring(Value), Info)
            elseif Type == 'Enum' then
                return SafeValue(Var, tostring(Value):split'.'[2], Info)
            elseif Type == 'Instance' then
                return SafeValue(Var, SpiedToInstance[value].Name, Info)
            end
            if not Variables[Value] then
                return SafeValue(Var, tostring(Value), Info)
            end

            return TypeSpy(Var, 'string', nil, Info)
        end

        return tostring(value)
    end
    SecureEnv.error = function(msg, lvl)
        if lvl ~= 0 then
            Ast.addStatement(AST, Ast.Comment(Ast.RawText'`error` here was used by the script itself.'))
            Ast.addStatement(AST, Ast.FunctionCall(Ast.Variable'error', TupleToAST(msg, lvl)))
        end

        error(msg, lvl)
    end

    local SpoofedEnvs = {}

    SecureEnv.getfenv = function(Level)
        local Type, Spoofed = Typeof(Level), SpoofedEnvs[Level]

        if Spoofed then
            return Spoofed
        end
        if Type == 'string' then
            Level = assert(tonumber(Level), string.format("invalid argument #1 to 'getfenv' (number expected, got %s)", tostring(Type)))
        end
        if Type == 'number' then
            if Level > Nest + 2 or Level < 0 then
                error("invalid argument #1 to 'getfenv' (invalid level)")
            end

            return Env
        elseif Type == 'function' or Type == 'nil' then
            return Env
        end

        error(string.format("invalid argument #1 to 'getfenv' (number expected, got %s)", tostring(Type)))
    end
    SecureEnv.setfenv = function(a, b)
        local Type = Typeof(a)

        assert(Typeof(b) == 'table', "missing argument #2 to 'setfenv' (table expected)")
        assert(Type == 'number' or Type == 'function', string.format("invalid argument #1 to 'setfenv' (number expected, got %s)", tostring(Type)))

        if Variables[b] == EnvName then
            return a
        end
        if getmetatable(b) then
            SpoofedEnvs[a] = b

            return b
        end

        AppendCall('setfenv', a, b)

        if iscclosure(a) then
            error"'setfenv' cannot change environment of given object"
        end

        SpoofedEnvs[a] = b

        local meow = IsInPcall or a

        if getmetatable(b) ~= nil then
            return meow
        end
    end
    SecureEnv.collectgarbage = function(t)
        assert(t, "missing argument #1 to 'collectgarbage' (string expected)")
        assert(t == 'count', "collectgarbage must be called with 'count'; use gcinfo() instead")

        return collectgarbage'count'
    end
    SecureEnv.tick = function()
        return SafeValue(AppendCall'tick', tick())
    end
    SecureEnv.require = function(path)
        local Type, Var, lua = Typeof(path), AppendCall('require', path), Settings.lua

        if Type ~= 'string' and lua then
            return Spy(Var)
        end
        if Type == 'string' then
            local Start = path:sub(1, 2)
            local IsAt, Unable = Start:sub(1, 1) == '@', string.format("Unable to require module from given path '%s'", tostring(path))

            if not (Start == './' or Start == '..' or IsAt) then
                if lua then
                    return Spy(Var)
                end

                error(string.format("Path must begin with './', '../', or '@': received '%s'", tostring(path)))
            elseif IsAt then
                local Alias, Thing = path:match'@([^/]+)', path:match'@.-/(%w+)'

                if Alias == 'game' then
                    if path == '@game' then
                        error(Unable)
                    else
                        assert(Services[Thing], string.format("'%s' is not a valid Service name", tostring(Thing)))
                        error(Unable)
                    end
                elseif Alias == 'self' then
                    error(Unable)
                end

                error(string.format("Path contains unsupported alias '@%s", tostring(Alias)))
            end

            error(Unable)
        elseif Type ~= 'number' and (Type ~= 'Instance') then
            local Info = Information[path] or {}

            if not Info.indexed_instance then
                Assert(Type, 'Instance', 'Attempted to call require with invalid argument(s).', true)
            end
        end
        if Type == 'Instance' and (Information[path] or {}).was_created then
            error('Module code did not return exactly one value')
        end

        return Spy(Var)
    end

    local files, FileFuncs = {}, {}

    local function startswith(a, b)
        return sub(a, 1, #b) == b
    end
    local function endswith(hello, lo)
        return sub(hello, #hello - #lo + 1, #hello) == lo
    end

    FileFuncs.writefile = function(path, content)
        local Path, CurrentPath = split(path, '/'), {}

        for i = 1, #Path do
            local a = Path[i]

            CurrentPath[i] = a

            if not files[a] and i ~= #Path then
                files[concat(CurrentPath, '/')] = {}
                files[concat(CurrentPath, '/') .. '/'] = files[concat(CurrentPath, '/')]
            elseif i == #Path then
                files[concat(CurrentPath, '/')] = tostring(content)
            end
        end
    end
    FileFuncs.makefolder = function(path)
        files[path] = {}
        files[path .. '/'] = files[path]
    end
    FileFuncs.isfolder = function(path)
        return type(files[path]) == 'table'
    end
    FileFuncs.isfile = function(path)
        return type(files[path]) == 'string'
    end
    FileFuncs.readfile = function(path)
        local content = files[path]

        assert(content, "invalid argument #1 to 'readfile', file does not exist!")

        return content
    end
    FileFuncs.appendfile = function(path, text2)
        FileFuncs.writefile(path, FileFuncs.readfile(path) .. text2)
    end
    FileFuncs.loadfile = function(path, var)
        if not FileFuncs.isfile(path) then
            error("File '" .. tostring(path) .. "' does not exist.", 2)

            return ''
        end

        local content = FileFuncs.readfile(path)
        local s, func = pcall(function()
            return loadstring(content)
        end)

        if not s then
            return nil, tostring(func):match'[^\n]+'
        end

        return Function(function(...)
            AppendCall(var, ...)

            return fenv.setfenv(func, Env)(...)
        end, var), s
    end
    FileFuncs.dofile = FileFuncs.loadfile
    FileFuncs.delfolder = function(path)
        local f = files[path]

        if type(f) == 'table' then
            files[path] = nil
        end
    end
    FileFuncs.delfile = function(path)
        local f = files[path]

        if type(f) == 'string' then
            files[path] = nil
        end
    end
    FileFuncs.listfiles = function(path)
        if not path or path == '' then
            local Files = {}

            for i, v in pairs(files)do
                if #i:split'/' == 1 then
                    insert(Files, i)
                end
            end

            return Files
        end
        if type(files[path]) ~= 'table' then
            return error(path .. ' is not a folder.')
        end

        local Files = {}

        for i in pairs(files)do
            if startswith(i, path .. '/') and not endswith(i, '/') and i ~= path and #i:split'/' == (#path:split'/' + 1) then
                insert(Files, i)
            end
        end

        return Files
    end

    for FuncName, Func in next, FileFuncs do
        SecureEnv[FuncName] = function(...)
            local Returned = pack(pcall(Func, InternalIfy(...)))
            local Success, _, Stat = Returned[1], DefineVar(Ast.FunctionCall(Ast.Variable(FuncName), TupleToAST(...)))

            if not Success then
                Comment(tostring(Returned[2]))

                if Settings.roblox then
                    error(Returned[2])
                end
            end

            return ToMultiVars(Stat, {
                unpack(Returned, 2),
            })
        end
    end

    SecureEnv.type = TypeFunction'type'
    SecureEnv.typeof = TypeFunction'typeof'

    local PcallIgnore = {
        getfenv = true,
        rawget = true,
        setfenv = true,
        ['table.concat'] = true,
    }

    SecureEnv.pcall = function(func, ...)
        local Var = Variables[func]

        if Var then
            local Logged, Values = Explore(func, {
                params = {...},
                bypass_ignore = true,
                as_pcall = true,
            })
            local Len, Meow = #Logged.data.statements, nil

            for _, v in next, Values do
                if Variables[v] then
                    Meow = true

                    break
                end
            end

            if not Values[1] then
                local Error = Values[2]
                local Type = typeof(Error)

                if Type == 'error' then
                    Error = tostring(Error)
                end
                if Type == 'error' or Type == 'string' then
                    Values[2] = Error:match':%d+: ([^\n]+)'
                end
            end
            if Values[2] == 'LPH_CRASH()' then
                error('LPH_CRASH()', 2)
            end
            if not PcallIgnore[Var] or Len > 1 or Meow then
                local Ctx, Vars, Spied = Ast.Variable(Var), {}, {}

                for i = 1, Values.n do
                    local Var = GetVar()

                    insert(Vars, Ast.Variable(Var))
                    insert(Spied, SafeValue(Var, Values[i]))
                end

                Stat = Ast.addStatement(AST, Ast.Assign(Vars, {
                    Ast.FunctionCall(Ast.Variable'pcall', {
                        Ctx,
                        unpack(TupleToAST(...)),
                    }),
                }))

                return unpack(Spied)
            end

            return unpack(Values)
        end

        local Type = typeof(func)

        if Type ~= 'function' then
            return false, string.format('[string "%s"]:1: attempt to call a %s value"', tostring(TraceId), tostring(Type))
        end

        local Logged, ReturnValues = Explore(func, {
            params = {...},
            bypass_ignore = true,
            as_pcall = true,
        })

        if not ReturnValues[1] then
            local Type = typeof(ReturnValues[2])

            if Type == 'error' or Type == 'string' then
                local Error = tostring(ReturnValues[2])

                if Error == 'too many operations' or Error == 'too many iterations' then
                    print('Yes', Error)
                    error(Error)
                end

                local HasArithmetic, RandomString = Error:find('attempt to perform arithmetic', 0, true), Error:find("attempt to index nil with 'randomString'", 0, true)

                if not HasArithmetic and not RandomString then
                    ReturnValues[2] = HideErrors(Error):match'[^\n]+'
                else
                    local Line = (HasArithmetic and Error:find('attempt to perform arithmetic (unm)', 0, true)) and '1' or '%2'

                    ReturnValues[2] = Error:gsub(UserRegex, string.format('[string "%s"]:%s', tostring(TraceId), tostring(Line)))
                end

                ReturnValues[2] = ReturnValues[2]:gsub('luau%.load%(%.%.%.%)', TraceId):gsub("%.?/unveilr/?[^%s]+?/?", "[string \"" .. tostring(TraceId) .. "\"]")

                if startswith(ReturnValues[2], 'terrain:') then
                    ReturnValues[2] = ReturnValues[2]:match'terrain:%d*:%s*(.+)'
                end
            end
        end

        local Statements = Logged.data.statements
        local Len = #Statements

        if Len ~= 0 and (Len ~= 1 or Statements[Len].kind ~= 'return') and ReturnValues.n <= 10 then
            local Last = Statements[Len]

            if Last and Last.kind == 'assign' and Last.data.values[1].kind == 'string' then
                Ast.addStatement(AST, Last)

                return unpack(ReturnValues)
            end

            local Vars, Spied, InternalStuff, ToReturn, TypeA = {}, {}, {}, {}, typeof(ReturnValues[1])
            local AreAllNumbers, Names = TypeA == 'number' or (TypeA == 'boolean' and ReturnValues.n >= 3), {
                'success',
            }

            for i = 1, ReturnValues.n do
                local Var, Value = Names[i] and GetCount(Names[i]) or GetVar(), ReturnValues[i]

                if i > 1 and typeof(Value) ~= 'number' then
                    AreAllNumbers = false
                end

                insert(Vars, Ast.Variable(Var))
                insert(Spied, SafeValue(Var, Value, Information[Value]))
                insert(ToReturn, ToAST(ReturnValues[i]))

                if Settings.debug then
                    insert(InternalStuff, Value)
                end
            end

            if AreAllNumbers then
                return unpack(ReturnValues)
            end
            if (ReturnValues[1] and ReturnValues.n > 1 or ReturnValues.n > 2) and Statements[Len].kind ~= 'return' then
                Ast.addStatement(Logged, Ast.Return(ToReturn))
            end

            Ast.addStatement(AST, Ast.Assign(Vars, {
                Ast.FunctionCall(Ast.Variable'pcall', {
                    Ast.Function(GetParams(func), Logged),
                }),
            }))

            if #InternalStuff > 0 then
                print(InternalStuff)
            end

            return unpack(Spied)
        end

        return unpack(ReturnValues)
    end
    SecureEnv.ypcall = function(...)
        return SecureEnv.pcall(...)
    end
    SecureEnv.xpcall = function(func, onFail)
        AppendCall('xpcall', func, onFail)

        local Type = Typeof(onFail)

        if Type == 'nil' then
            error("missing argument #2 to 'xpcall' (function expected)")
        elseif Type ~= 'function' then
            error(string.format("missing argument #2 to 'xpcall' (function expected, got %s)", tostring(Type)))
        end

        return xpcall(func, function(...)
            return onFail(HideErrors(tostring((...))), select(2, ...))
        end)
    end
    SecureEnv.rawget = function(tbl, k)
        local Var, Type = Variables[tbl], Typeof(tbl)

        assert(Type == 'table', string.format("invalid argument #1 to 'rawget' (table expected, got %s)", tostring(Type)))

        if Var then
            if Var == EnvName or Var == '_G' then
                return (EnvValues[k] or {})[1]
            end

            do
                return rawget(GetInternalValue(tbl), k)
            end
        end

        return rawget(tbl, k)
    end
    SecureEnv.rawlen = function(tbl)
        if GetContext(tbl) then
            local Var = AppendCall('rawlen', tbl)

            return SafeValue(Var, 0)
        end

        local Type = Typeof(tbl)

        assert(Type == 'table', string.format("invalid argument #1 to 'rawlen', table expected got %s", tostring(Type)))

        return rawlen(tbl)
    end

    local WrappedUnpack = SafeWrap(unpack, 'unpack')

    SecureEnv.unpack = function(tab, i, j)
        if typeof(tab) ~= 'table' then
            return tab
        end
        if Variables[i] or Variables[j] then
            return WrappedUnpack(tab, i, j)
        end

        return unpack(tab, i, j)
    end

    function GetInfo(i)
        local Type = typeof(i)

        if Type ~= 'function' and Type ~= 'thread' and Type ~= 'number' then
            return {}, true
        end

        local Returned, s, l, n, params, vararg, f = {}, debuginfo(i, 'slnaf')

        Returned.func = i

        local RealC, True = CClosures[i] or s == '[C]', TrueEnv[Variables[i] ]

        if True then
            RealC = RealC or iscclosure(True)
        end
        if RealC then
            Returned.what = 'C'
            Returned.namewhat = ''
            Returned.source = '=[C]'
            Returned.short_src = '[C]'
            Returned.line, Returned.linedefined, Returned.currentline, Returned.lastlinedefined = RealC and -1 or 1, RealC and -1 or 1, RealC and -1 or 1, RealC and -1 or 1
            Returned.numparams, Returned.is_vararg = 0, 1
            Returned.nups = 1

            local Var = Variables[i] or n
            local name = split(Var, '.')

            name = name[#name]
            Returned.name = name
        else
            if typeof(i) == 'number' then
                local CallStackNumbers, Traceback, String = {}, split(debug.traceback(), '\n'), string.format('[string "%s"]', tostring(TraceId))
                local Len = #String

                for x = 1, #Traceback do
                    local Line = Traceback[x]

                    if Line:sub(1, Len) == String then
                        insert(CallStackNumbers, x)
                    end
                end

                table.sort(CallStackNumbers, function(a, b)
                    return a > b
                end)

                for x, level in next, CallStackNumbers do
                    if x == i then
                        s, l, n, params, vararg, f = debuginfo(level, 'slnaf')
                        Returned.line, Returned.linedefined, Returned.currentline = l, l, l
                        Returned.name = n
                        Returned.is_vararg, Returned.numparams = vararg, params
                        Returned.func = f

                        if n == '' and s == String and vararg then
                            s = TraceId
                        end

                        Returned.source, Returned.short_src = s, s

                        return Returned
                    end
                end

                do
                    return nil
                end
            else
                Returned.what = 'Lua'
                Returned.line, Returned.linedefined, Returned.currentline = l, l, l
                Returned.source, Returned.short_src = TraceId, TraceId:sub(1, -2)
                Returned.nups = 0
                Returned.is_vararg, Returned.numparams = vararg and 1 or 0, params
            end
        end

        return Returned
    end

    local Debug = GetMetatable('debug', {
        __index = {
            getinfo = Function(function(t, i)
                t, i = GetInternalValue(t), GetInternalValue(i)

                local Type = Typeof(t)

                assert(Type == 'function' or Type == 'number', "invalid argument #1 to 'getinfo' (function or level expected)")

                if t == 0 then
                    t = Function(function() end, 'debug.getinfo', true)
                end
                if not GetContext(t) then
                    local Info, DoSpy = GetInfo(t)

                    if not DoSpy then
                        return Info
                    end

                    return Spy(AppendCall('debug.getinfo', t, i), Info)
                end

                local Var, Info, DoSpy = AppendCall('debug.getinfo', unpack{t, i}), GetInfo(t)

                if not DoSpy then
                    SetInternalValue(Var, Info)
                end

                return Spy(Var)
            end, 'debug.getinfo', true),
            info = Function(function(t, i)
                t, i = GetInternalValue(t), GetInternalValue(i)

                assert(typeof(t) == 'function' or typeof(t) == 'number' or typeof(t) == 'thread', "invalid argument #1 to 'info', function, thread or level expected got " .. typeof(t))
                assert(typeof(i) == 'string', "invalid argument #2 to 'info', string expected got " .. typeof(i))

                if t == 0 then
                    t = Function(function() end, 'debug.getinfo', true)
                end

                local Vars, Names, DefinedVars, Vararg = split(string.lower(i), ''), {
                    n = 'name',
                    a = 'params',
                    l = 'line',
                    s = 'source',
                }, {}, nil

                for _, option in next, Vars do
                    insert(DefinedVars, Ast.Variable(GetCount(Names[option] or option)))

                    if option == 'a' then
                        Vararg = GetCount'vararg'

                        insert(DefinedVars, Ast.Variable(Vararg))
                    end
                end

                Ast.addStatement(AST, Ast.Assign(DefinedVars, {
                    Ast.FunctionCall(Ast.Variable'debug.info', TupleToAST(t, i)),
                }, false))

                local ToReturn, Values, Info, Skip = {}, {}, GetInfo(t) or {}, nil

                for x, v in next, Vars do
                    local __DARKLUA_CONTINUE_86 = false

                    repeat
                        local value, var = nil, DefinedVars[x + (Skip and 1 or 0)].data.name

                        Skip = false

                        if v == 's' then
                            value = Info.what == 'C' and '[C]' or Info.source
                        elseif v == 'n' then
                            value = Info.name or ''
                        elseif v == 'a' then
                            value = Info.numparams

                            insert(Values, value)
                            insert(ToReturn, SafeValue(var, value))

                            value = Info.is_vararg == 1

                            insert(Values, value)
                            insert(ToReturn, SafeValue(Vararg, value))

                            Skip = true
                            __DARKLUA_CONTINUE_86 = true

                            break
                        elseif v == 'f' then
                            value = Info.func

                            if value then
                                Variables[value] = var
                            end
                        elseif v == 'l' then
                            value = Info.line
                        else
                            error"invalid argument #2 to 'info' (invalid option)"
                        end

                        insert(Values, value)
                        insert(ToReturn, SafeValue(var, value))

                        __DARKLUA_CONTINUE_86 = true
                    until true

                    if not __DARKLUA_CONTINUE_86 then
                        break
                    end
                end

                OpCountCheck()

                return unpack(ToReturn)
            end, 'debug.info', true),
            dumpcodesize = Spy'debug.dumpcodesize',
            traceback = Function(function(a)
                assert(not a or Typeof(a) == 'string', "invalid argument #1 to 'traceback' (string expected got " .. Typeof(a) .. ')')

                local trace = debug.traceback(a)
                local lines, out = split(trace, '\n'), {}

                for _, v in next, lines do
                    if HideErrors(v) == v then
                        insert(out, v)
                    end
                end

                local value = concat(out, '\n')

                value = gsub(value, ':%d+', ':1'):gsub('%[string ["\'](.-)["\']%]', '%1')

                local Var = AppendCall('debug.traceback', a)

                Comment(value)

                return SafeValue(Var, value)
            end, 'debug.traceback', true),
            getmemorycategory = Function(function()
                return SafeValue(AppendCall'debug.getmemorycategory', MemoryCategory)
            end, 'debug.getmemorycategory', true),
            setmemorycategory = Function(function(Category)
                assert(Typeof(Category) == 'string', "invalid argument #1 to 'setmemorycategory', string expected got " .. Typeof(Category))

                MemoryCategory = Category

                return SafeValue(AppendCall'debug.getmemorycategory', MemoryCategory)
            end, 'debug.setmemorycategory', true),
            resetmemorycategory = Function(function()
                MemoryCategory = TraceId
            end, 'debug.resetmemorycategory', true),
            getlocal = Function(function(func, idx)
                local Meower = AppendCall('debug.getlocal', func, idx)

                checktype(func, 'function', "invalid argument #1 to 'getlocal'")
                checktype(idx, 'number', "invalid argument #2 to 'getlocal'")

                if iscclosure(func) then
                    return SafeValue(Meower, nil)
                end

                return Spy(Meower, nil, {is_propery = true})
            end, 'debug.getlocal', true),
            getupvalue = Function(function(func, idx)
                local Upvalue, Type = AppendCall('debug.getupvalue', func), Typeof(func)

                assert(Type == 'function' or Type == 'number', string.format("invalid argument #1 to 'getupvalue', function or number expected got %s", tostring(Type)))

                if iscclosure(func) then
                    error("'getupvalue' cannot be called on a CClosure!")
                end
                if idx <= 0 then
                    error("invalid argument #2 to 'getupvalue' (invalid index!)")
                end

                return Spy(Upvalue, nil, {is_propery = true})
            end, 'debug.getupvalue', true),
        },
    })

    SecureEnv.debug = Debug
    SecureEnv.assert = function(condition, message)
        local _c, _m = condition, message

        condition, message = GetInternalValue(condition), GetInternalValue(message)

        if condition ~= _c or _m ~= message then
            AppendCall('assert', _c, _m)
        end

        return assert(condition, message)
    end
    SecureEnv.newcclosure = function(Closure)
        local type = Typeof(Closure)

        assert(type == 'function', "invalid argument #1 to 'newcclosure', function expected got " .. type)

        local Var = AppendCall('newcclosure', Closure)

        return Function(function(...)
            return Closure(...)
        end, Var, true)
    end
    SecureEnv.hookfunction = HookFunction'hookfunction'
    SecureEnv.replaceclosure = HookFunction'replaceclosure'
    SecureEnv.restorefunction = function(f)
        AppendCall('restorefunction', f)

        local Type = Typeof(f)

        assert(Type == 'function', string.format("invalid argument #1 to 'restorefunction', function expected got %s", tostring(Type)))
        Restore(GetInternalValue(f))
    end
    SecureEnv.isfunctionhooked = function(f)
        local Var = AppendCall('isfunctionhooked', f)

        return SafeValue(Var, FunctionHooks[f] ~= nil)
    end
    SecureEnv.is_function_hooked = function(f)
        local Var = AppendCall('is_function_hooked', f)

        return SafeValue(Var, IsHooked(f))
    end
    SecureEnv.ishooked = function(f)
        local Var = AppendCall('ishooked', f)

        return SafeValue(Var, IsHooked(f))
    end
    SecureEnv._VERSION = 'Luau'

    for _, Key in next, SayPlease do
        SecureEnv[Key] = SafeWrap(TrueEnv[Key], Key)
    end
    for _, Key in next, FineUgh do
        SecureEnv[Key] = TrueEnv[Key]
    end
    for Key, Val in next, SecureEnv do
        if typeof(Val) == 'function' and not Types[Val] then
            SecureEnv[Key] = Function(Val, Key, true)
        end
    end

    local IterFuncs, Iterator, Iterators, PristineIdxAmount, Envs = {
        next = true,
        ipairs = true,
        pairs = true,
    }, nil, {}, 0, {}

    local function CreateEnv(path)
        local env = Envs[path]

        if env then
            return env
        end
        if path == '_G' or path == 'shared' then
            local Meower, EnvVar = CreateEnv'getgenv()', Ast.Variable(path)

            return GetMetatable(path, {
                __index = function(_, Key)
                    if Key == 'globalEnv' then
                        return Meower
                    end

                    local Var, ExecType = DefineVar(Ast.Index(EnvVar, ToAST(Key)), false, true), IsExecutor(Key)

                    if (SpyExecOnly and (typeof(Key) == 'string' and not ExecType)) or TrueEnv[Key] or Nil[Key] or ForceNil[Key] then
                        return SafeValue(Var, nil)
                    end

                    SetInternalValue(Var, nil)

                    local Meower = Spy(Var)

                    if ExecType then
                        Types[Meower] = ExecType
                    end

                    return Meower
                end,
            })
        end

        local Metatable = setmetatable({}, {
            __index = function(Self, Key)
                local Var, Value, Meow = DefineVar(Ast.Index(Ast.FunctionCall(Ast.Variable'getgenv', {}), ToAST(Key)), false, true), EnvValues[Key], rawget(SecureEnv, Key)

                if Meow then
                    Value = {Meow}
                end
                if Value then
                    local X = Value[1]

                    return SafeValue(Var, X)
                end

                local ExecType = IsExecutor(Key)

                if SpyExecOnly then
                    SetInternalValue(Var, nil)

                    return TypeSpy(Var, ExecType)
                end
                if ExecType == 'function' then
                    return Function(function(...)
                        local Var = AppendCall(Var, ...)

                        return Spy(Var)
                    end, Var, true)
                end

                local Spied = Spy(Var, rawget(Env, Key))

                if ExecType then
                    Types[Spied] = ExecType
                end

                return Spied
            end,
            __newindex = function(Self, Key, Value)
                Define(Ast.Index(Ast.FunctionCall(Ast.Variable'getgenv', {}), ToAST(Key)), ToAST(Value), true, true)

                EnvValues[Key] = {Value}
            end,
            __metatable = 'Protected',
        })

        return Metatable
    end

    SecureEnv._G, SecureEnv.shared, SecureEnv.getgenv, SecureEnv.getrenv = CreateEnv'_G', CreateEnv'shared', Function(function()
        return CreateEnv'getgenv()'
    end, 'getgenv', true), Function(function()
        return CreateEnv'getrenv()'
    end, 'getrenv', true)

    ExploitLib:setEnv{
        ToAST = ToAST,
        TupleToAST = TupleToAST,
        OpCountCheck = OpCountCheck,
        VarValues = VarValues,
        AST = AST,
        AppendCall = AppendCall,
        Spy = Spy,
        TypeSpy = TypeSpy,
        SafeValue = SafeValue,
        cclosures = CClosures,
        types = Types,
        Function = Function,
        Variables = Variables,
        TraceId = TraceId,
        UseHookOp = UseHookOp,
        Settings = Settings,
        GetInternalValue = GetInternalValue,
        Globals = SharedGlobals,
        GetMetatable = GetMetatable,
        GetVar = GetVar,
    }

    for funcName, func in next, ExploitLib.funcs do
        SecureEnv[funcName] = Function(func, funcName, true)
    end
    for libName, library in next, ExploitLib.libs do
        for Key, Value in next, library do
            library[Key] = (typeof(Value) == 'function' and {
                (Function(Value, Index(Key, libName), true)),
            } or {Value})[1]
        end

        SecureEnv[libName] = GetMetatable(libName, {__index = library})
    end

    local meowed = {}

    GlobalIndex = function(Self, Key)
        if Settings.debug then
            print('Indexed', Key, typeof(Key))
        end

        local EnvValue, ExecType = EnvValues[Key], IsExecutor(Key)

        if EnvValue then
            return SafeValue(Key, EnvValue[1])
        end

        local Type, DontDefine, ToUse = typeof(Key), nil, nil

        if Nil[Key] then
            return SafeValue(Key, nil)
        elseif ForceNil[Key] or Type == 'nil' then
            return nil
        end
        if IterFuncs[Key] then
            return Function(function(tbl, k)
                local Var = Variables[tbl]

                if Key == 'next' and Var then
                    if k then
                        if Iterator then
                            Iterator()
                        end

                        Iterator = nil

                        return nil, nil
                    end

                    Iterator = getmetatable(tbl).__iter(tbl, Key)

                    return Iterator()
                elseif Var then
                    local mt = getmetatable(tbl)

                    if mt then
                        Iterator = mt.__iter(tbl, Key)
                        Iterators[Iterator] = true

                        return Iterator
                    else
                        Ast.addStatement(AST, Ast.PermaComment(Ast.RawText"Unable to get the metatable for '", Ast.Variable(Var), Ast.RawText(string.format("' so we're unable to log the for loop (which uses %s) here.", tostring(Key)))))
                    end
                elseif Key == 'next' then
                    return next(tbl, k)
                end

                return TrueEnv[Key](tbl, k)
            end, Key, true)
        end

        local IgnoreMar = DoIgnore(Key)
        local Casper = IgnoreMar or (Type == 'string' and (#Key == 13 and Key:find'%d')) or Type == 'function' or Type == 'nil' or (SpyExecOnly and not ExecType)

        if Key and not meowed[Key] then
            ToUse = Define((Casper and not IgnoreMar and {
                (typeof(Key) == 'string' and not IsWeird(Key) and {
                    (Ast.Variable(Key:gsub('%W', '_'))),
                } or {
                    (GetVar()),
                })[1],
            } or {
                (GetVar()),
            })[1], Ast.Index(Ast.Variable(EnvName), ToAST(Key)), false, true).data.vars[1].data.name
            DontDefine = true
            ForceNil[Key] = IgnoreMar
            meowed[Key] = ToUse
            Indexes[ToUse] = true
        end
        if Casper then
            ToUse = ToUse or meowed[Key]

            if not hookOp then
                return nil
            end

            SetInternalValue(ToUse, nil)

            return Spy(ToUse, nil, {is_idx = true})
        end
        if SharedGlobals.Pristine then
            PristineIdxAmount = PristineIdxAmount + 1

            local Saved = SharedGlobals.SavedPristine[Key]

            if Saved then
                rawset(Self, Key, Saved)

                SharedGlobals.SavedPristine[Key] = nil

                return Saved
            end
        end

        ToUse = ToUse or GetVar()

        local True, Spied = TrueEnv[Key], nil

        if typeof(True) == 'function' then
            Spied = Function(function(...)
                local Var = AppendCall(ToUse, ...)

                return Spy(Var)
            end, ToUse, true)
        elseif Type == 'string' and Key:find'%W' then
            Spied = Spy(ToUse)

            SetInternalValue(ToUse, nil)
        else
            Spied = Spy(ToUse)
            Types[Spied] = ExecType or typeof(True)
        end
        if not DontDefine then
            Define(ToUse, Ast.Index(Ast.Variable(EnvName), ToAST(Key)), false, true)
        end

        return Spied
    end
    Env = setmetatable(SecureEnv, getmetatable(GetMetatable(EnvName, {
        __index = GlobalIndex,
        __newindex = function(Self, Key, Value)
            if Key == '_msec' or Key == 'heh' then
                return rawset(Self, Key, Value)
            end

            local KeyLen, OldVar, ToUse, New = (typeof(Key) == 'string' and {
                (#Key),
            } or {nil})[1], Variables[Value], (Ast.Variable(Key))
            local IsFunction = typeof(Value) == 'function'

            if IsFunction then
                New = Settings.discord and Function(function(...)
                    local Arg1 = ...

                    if typeof(Arg1) == 'string' and DoIgnore(Arg1) then
                        return Value(...)
                    end

                    local Old, Stat = AppendCall(ToUse, ...)
                    local OldLen, Logged, Values = VariablesLen, Explore(Value, {
                        params = {...},
                        bypass_beautify = true,
                    })

                    if OldLen ~= VariablesLen then
                        for _, stat in next, Logged.data.statements do
                            if stat.kind ~= 'return' then
                                Ast.addStatement(AST, stat)
                            end
                        end
                    end
                    if Values[1] then
                        Values = table.pack(unpack(Values, 2))

                        return ToMultiVars(Stat, Values, true)
                    end

                    error(Values[2])
                end, Key, iscclosure(Value)) or Value
            elseif KeyLen then
                New = Spy(tostring(Key), Value)
            end
            if not New then
                return
            end

            local Len = (typeof(Value) == 'string' and {
                (#Value),
            } or {0})[1]

            if Len > 200 or KeyLen == 2 then
                return rawset(Self, Key, Value)
            end

            local ToUse = Ast.Index(Ast.Variable(EnvName), ToAST(Key))

            rawset(Self, Key, (IsFunction and {New} or {
                ((OldVar and {
                    (SafeValue(AstLib.ExprToCode(ToUse), Value)),
                } or {Value})[1]),
            })[1])

            local Var = Variables[Value]

            if Var and typeof(Value) ~= 'table' and not OldVar then
                Variables[Value] = nil
            end

            Define(ToUse, ToAST(Value), true, true)

            if Value then
                Variables[Value] = Var
            end
        end,
        __tostring = function()
            return EnvName
        end,
        __call = function()
            error'attempt to call a table value'
        end,
        __add = function(t, v)
            error(string.format('attempt to perform arithmetic (add) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __sub = function(t, v)
            error(string.format('attempt to perform arithmetic (sub) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __mul = function(t, v)
            error(string.format('attempt to perform arithmetic (mul) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __div = function(t, v)
            error(string.format('attempt to perform arithmetic (div) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __idiv = function(t, v)
            error(string.format('attempt to perform arithmetic (idiv) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __mod = function(t, v)
            error(string.format('attempt to perform arithmetic (mod) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __pow = function(t, v)
            error(string.format('attempt to perform arithmetic (pow) on %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
        __unm = function(t)
            error(string.format('attempt to perform arithmetic (unm) on %s', tostring(Typeof(t))))
        end,
        __concat = function(t, v)
            error(string.format('attempt to concatenate %s and %s', tostring(Typeof(t)), tostring(Typeof(v))))
        end,
    })))

    local Macros = {
        predefine = function(tbl)
            assert(typeof(tbl) == 'table', string.format("invalid argument #1 to 'predefine', table expected got %s", tostring(typeof(tbl))))

            for i, v in next, tbl do
                Predefined[i] = {v}
            end
        end,
        hook = function(id, val)
            checktype(id, 'number', "invalid argument #1 to 'hook'")
            checktype(val, 'boolean', "invalid argument #2 to 'hook'")

            StatementHooks[id] = val
        end,
        spy = function(path, value, didntStutter)
            local type = typeof(path)

            assert(type == 'string', string.format("invalid argument #1 to 'spy', string expected got %s", tostring(type)))

            local Spied = Spy(path)

            if value ~= nil or didntStutter then
                SetInternalValue(Spied, value)
            end

            return Spied
        end,
        setvalue = function(path, value)
            local type = typeof(path)

            assert(type == 'string', string.format("invalid argument #1 to 'spy', string expected got %s", tostring(type)))
            SetInternalValue(path, value)
        end,
        hookcalls = function(handler)
            checktype(handler, 'function', "invalid argument #1 to 'hookcalls'")

            CallsHandler = handler
        end,
        getpath = function(obj)
            return Variables[obj]
        end,
    }

    ExploitLib:setGlobalEnv(Env)

    Variables[Env] = EnvName

    SetInternalValue(EnvName, SecureEnv)

    local Function, List = (setfenv(Source, Env)), Settings.macros

    if List and fs.isFile(List) then
        local macroData, thing = fs.readFile(List), GetMetatable('macros', {
            __index = function(_, Key)
                return Macros[Key] or Env[Key]
            end,
            __newindex = function(_, Key, Value)
                EnvValues[Key] = {Value, Key}
            end,
        })
        local s, e = pcall(fenv.setfenv(loadstring(macroData), thing))

        if not s then
            Comment(string.format('failed to load macros, error message: %s', tostring(HideErrors(e, true))))
        end
    end

    StartedRunning = os.time()
    SharedGlobals.StartedRunning = StartedRunning

    local Values = pack(pcall(Function))

    CloseAllEnds()

    if not Values[1] then
        local LastStatement = AST.data.statements[#AST.data.statements]

        if LastStatement and LastStatement.kind == 'call' and LastStatement.data.func.data.name == 'error' then
        else
            Ast.addStatement(AST, Ast.FunctionCall(Ast.Variable'error', {
                ToAST(Values[2], {clean = true}),
            }))
        end
    elseif Values.n > 1 then
        Ast.addStatement(AST, Ast.Return(TupleToAST(unpack(Values, 2))))
    end

    SharedGlobals.Deferred = {}

    local Beautified = {}

    WHILE_LIMIT = WHILE_LIMIT / 2.5
    TotalRepeats, TotalWhiles = 0, 0

    print'Iterating..'

    local PlsSave = Settings.save_before

    if Settings.runtimelogs or PlsSave then
        local Success, Result = pcall(AstLib.Stringify, AST)

        if Success then
            fs.writeFile(PlsSave and 'debug.lua' or Settings.out, Result)
        end
    end

    table.sort(ToExplore, function(a, b)
        local DelayA, DelayB, DeferredA, DeferredB = a.args.delay, b.args.delay, a.args.deferred, b.args.deferred

        if DeferredA ~= DeferredB then
            return not DeferredA
        end
        if not DelayA and not DelayB then
            return a.idx < b.idx
        else
            return (DelayA or 0) > (DelayB or 0)
        end
    end)

    local function Iterate()
        yoiterate = true

        for _, Data in next, ToExplore do
            local __DARKLUA_CONTINUE_96 = false

            repeat
                if Beautified[Data] then
                    __DARKLUA_CONTINUE_96 = true

                    break
                end

                local Function, Id, Node, Args = Data.func, Data.id, Data.node, Data.args

                Args.as_func = true
                Args.bypass_beautify = true

                local Explored = Explore(Function, Args)

                Beautified[Data] = true

                table.clear(Node)

                for i, v in next, Explored do
                    Node[i] = v
                end

                __DARKLUA_CONTINUE_96 = true
            until true

            if not __DARKLUA_CONTINUE_96 then
                break
            end
        end
    end

    Iterate()

    return AST
end
local function TimedDump(File)
    local InputDir = process.env and process.env.UNVEILR_INPUT_DIR or 'inputs'
    local DumpDir = process.env and process.env.UNVEILR_DUMP_DIR or 'dumps'
    local InputFile = InputDir .. '/' .. File
    local OutputFile = DumpDir .. '/' .. Settings.out
    local Code = fs.readFile(InputFile)
    local Source = Code
    local StartObf, Success, Hooked = os.clock(), UseHookOp(Code, InputFile)

    print('Obfuscated in', os.clock() - StartObf, 'seconds.')

    if not Success then
        local Reason = tostring(Hooked)
        local ReasonQuoted = string.format('%q', Reason)

        Code = 'print("Unable to load hookOp on this file, this file ran as it would without hookOp. Reason: " .. ' .. ReasonQuoted .. ')\n' .. Code
    else
        Code = Hooked
    end
    if Settings.version then
        fs.removeFile(InputFile)
    end

    Settings.out = OutputFile

    AstLib.SetGlobal('outfile', Settings.out)
    AstLib.SetGlobal('envname', EnvName)
    AstLib.SetGlobal('atruntime', Settings.runtimelogs)
    AstLib.SetGlobal('annotations', Settings.type_annotations)
    AstLib.SetGlobal('minifier', Settings.minifier)
    AstLib.SetGlobal('comments', Settings.comments)

    local Start, Multiplier = os.clock(), (1 + #Code / (2048E2))

    WHILE_LIMIT = WHILE_LIMIT * Multiplier
    MAX_OPS_MUL = Multiplier

    local Loaded
    local Success, Error = pcall(function()
        Loaded = loadstring(Code)
    end)

    if not Success then
        fs.writeFile(Settings.out, '--err' .. fenv.tostring(Error):match'[^\n]+')
        process.exit(0)

        return
    end

    AllowedGetRequests = AllowedGetRequests + (Source:find(':HttpGet(', 0, true) and 1 or 0)

    local AST = EnvLog(Loaded, 0)

    DONE_PROCESSING = true
    Success, Result = pcall(AstLib.Stringify, AstLib.Minify(AST, not Settings.minifier))

    if not Success then
        warn('not success', Result)
    end

    Result = ((Settings.debug and {Result} or {
        (HideErrors(Result, nil, true)),
    })[1]):gsub('\n%s*;\n', '\n')

    local TopComment, Meowed = '-- Successfully sent http GET requests to the following site(s): ', nil

    for _, v in next, AllowedUrlsInTheEnd do
        TopComment = TopComment .. string.format("'%s', ", tostring(v))
        Meowed = true
    end

    if Meowed then
        Result = TopComment:sub(1, -3) .. '\n' .. Result
    end

    print(format('Finished processing in %.8f seconds!', os.clock() - Start))
    fs.writeFile(Settings.out, "-- this file was generated using skidware's unveilr fork\n\n" .. Result)
    _print'Finished processing'
    process.exit(0)
end
return TimedDump(Settings.ipt or 'input.lua')