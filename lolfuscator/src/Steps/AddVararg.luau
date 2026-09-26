local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local AddVararg = StepHandler:AddStep("AddVararg")

local function AddVarargToFunctions(Node)
    if type(Node) ~= "table" then return end

    if Node.type == "FunctionDeclaration" or Node.type == "FunctionExpression" then
        Node.parameters = Node.parameters or {}

        local HasVararg = false
        for _, Parameter in ipairs(Node.parameters) do
            if type(Parameter) == "table" and Parameter.type == "VarargLiteral" then
                HasVararg = true
                break
            end
        end

        if not HasVararg then
            table.insert(Node.parameters, {
                type = "VarargLiteral",
                value = "...",
                raw = "...",
            })
        end
    end

    for _, Value in pairs(Node) do
        if type(Value) == "table" then
            AddVarargToFunctions(Value)
        end
    end
end

function AddVararg:apply(ast)
    AddVarargToFunctions(ast)
    return ast
end

return AddVararg