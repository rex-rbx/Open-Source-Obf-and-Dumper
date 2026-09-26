local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local Watermark = StepHandler:AddStep("Watermark")

function Watermark:apply(ast, pipeline)
    local DeveloperSettings = pipeline.Config.DeveloperSettings
    local WatermarkText = DeveloperSettings and DeveloperSettings.Watermark
    if not WatermarkText then
        error("Watermark: no watermark configured in DeveloperSettings.Watermark")
    end

    table.insert(ast.comments, {
        type = "Comment",
        raw = WatermarkText,
    })
    return ast
end

return Watermark