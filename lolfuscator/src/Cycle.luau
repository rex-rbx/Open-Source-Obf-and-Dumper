local Fs = require("@lune/fs")
local Luau = require("@lune/luau")
local ModuleHandler = require("./Modules/ModuleHandler")

require("./Modules/Timing")
require("./Modules/Logger")
require("./Modules/Config")
require("./Modules/FileHandler")
require("./Modules/Parser")
require("./Modules/StepHandler")
require("./Modules/VmCompiler")

require("./cli")

--local TotalTime = ObfuscationTime + RunTime
    -- saved 2ns by commenting this out!!