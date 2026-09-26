local ModuleHandler = require("./ModuleHandler")

local Logger = ModuleHandler:AddModule("Logger")

local original = print; print = function(...)
    local Config = ModuleHandler:GetModule("Config")
    if Config and Config:Get("Debug/ConsoleOutput") then
        original(...)
    end
end

function Logger:Info(...)
    print("[INFO]:", ...)
end

function Logger:Timer(...)
    print("[TIMER]:", ...)
end

function Logger:Error(...)
    print("[ERROR]:", ...)
end

function Logger:Ignore(Info: boolean)
    if Info then
        print = original
    end
end

return Logger
