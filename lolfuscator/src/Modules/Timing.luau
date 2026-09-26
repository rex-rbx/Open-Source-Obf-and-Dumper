local ModuleHandler = require("./ModuleHandler")

local Timing = ModuleHandler:AddModule("Timing")

local function FormatTime(ElapsedSeconds: number): (number, string)
    if ElapsedSeconds >= 1 then
        return ElapsedSeconds, "s"
    elseif ElapsedSeconds >= 0.001 then
        return math.floor(ElapsedSeconds * 1000 + 0.5), "ms"
    else
        return math.floor(ElapsedSeconds * 1000000000 + 0.5), "ns"
    end
end

local Timers = {}

function Timing:Start(Name: string, ShouldLog: boolean?): string
    local StartTime = os.clock()
    Timers[Name] = { StartTime = StartTime, ShouldLog = ShouldLog }
    return Name
end

function Timing:Stop(Name: string): number
    local TimerData = Timers[Name]
    if not TimerData then
        return -1
    end
    Timers[Name] = nil

    local ElapsedSeconds = os.clock() - TimerData.StartTime

    if TimerData.ShouldLog then
        local Value, Unit = FormatTime(ElapsedSeconds)
        local Logger = ModuleHandler:GetModule("Logger")
        Logger:Timer(Name .. " took " .. Value .. Unit)
    end

    return math.floor(ElapsedSeconds * 1000 + 0.5)
end

function Timing:Get(Name: string): number
    local TimerData = Timers[Name]
    if not TimerData then
        return -1
    end
    return math.floor((os.clock() - TimerData.StartTime) * 1000 + 0.5)
end

function Timing:Reset(Name: string)
    local TimerData = Timers[Name]
    if TimerData then
        TimerData.StartTime = os.clock()
    else
        Timers[Name] = { StartTime = os.clock() }
    end
end

function Timing:ResetAll()
    table.clear(Timers)
end

return Timing
