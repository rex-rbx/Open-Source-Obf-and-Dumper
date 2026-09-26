local ModuleHandler = require("./ModuleHandler")

local StepHandler = ModuleHandler:AddModule("StepHandler")

local insert = table.insert
local require = require

local Steps = {}

function StepHandler:AddStep(name)
    local Step = { Name = name }
    return Step
end

function StepHandler:GetSteps()
    return Steps
end

function StepHandler:ApplyStep(Step, ast, pipeline)
    local Name = Step.Name
    local Config = ModuleHandler:GetModule("Config")
    if Config:Get("Steps/" .. Name .. "/Enabled") == false then
        return ast
    end

    local Timing = ModuleHandler:GetModule("Timing")
    Timing:Start(Name, true)
    local Applied = Step:apply(ast, pipeline)
    local EndTime = Timing:Stop(Name)

    return Applied or ast
end

function StepHandler:ApplySteps(ast, pipeline)
    StepHandler:RegisterSteps()
    for _, Step in next, Steps do
        ast = StepHandler:ApplyStep(Step, ast, pipeline)
    end
    return ast
end

local Registered = false

function StepHandler:RegisterSteps()
    if Registered then
        local Logger = ModuleHandler:GetModule("Logger")
        Logger:Error("Called ApplySteps twice, dont do that.")
        return
    end; Registered = true
    insert(Steps, require("../Steps/Watermark"))
    insert(Steps, require("../Steps/Macros"))
    insert(Steps, require("../Steps/AddVararg"))
    insert(Steps, require("../Steps/ControlFlowFlattening"))
    insert(Steps, require("../Steps/ArithmeticToExpression"))
    insert(Steps, require("../Steps/PadPayload"))
    insert(Steps, require("../Steps/Vmify"))
    insert(Steps, require("../Steps/EncryptStrings"))
    insert(Steps, require("../Steps/NumbersToExpressions"))
    insert(Steps, require("../Steps/BoolToExpression"))
    insert(Steps, require("../Steps/SplitStrings"))
    insert(Steps, require("../Steps/ConstantArray"))
    insert(Steps, require("../Steps/ProxifyLocals"))

    insert(Steps, require("../Steps/Weird/Compression"))
end

return StepHandler
