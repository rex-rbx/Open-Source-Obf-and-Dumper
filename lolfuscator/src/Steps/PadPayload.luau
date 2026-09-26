local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local PadPayload = StepHandler:AddStep("PadPayload")

local function DummyIf()
    local r = math.random(1, 1000)
    return {
        type = "IfStatement",
        clauses = {
            {
                type = "IfClause",
                condition = {
                    type = "BinaryExpression",
                    operator = "==",
                    left = { type = "NumericLiteral", value = r, raw = tostring(r) },
                    right = { type = "NumericLiteral", value = r + 1, raw = tostring(r+1) }
                },
                body = {
                    {
                        type = "LocalStatement",
                        variables = { { type = "Identifier", name = "dummy_" .. r, isLocal = true } },
                        init = { { type = "NumericLiteral", value = r, raw = tostring(r) } }
                    }
                }
            }
        }
    }
end

local function CollectBlocks(Node, Blocks)
    if type(Node) ~= "table" then return end
    if Node.type == "Chunk" or Node.type == "DoStatement" or Node.type == "WhileStatement" or Node.type == "RepeatStatement" or Node.type == "FunctionDeclaration" then
        if Node.body and type(Node.body) == "table" then
            table.insert(Blocks, Node.body)
        end
    elseif Node.type == "IfStatement" then
        for _, clause in ipairs(Node.clauses or {}) do
            if clause.body and type(clause.body) == "table" then table.insert(Blocks, clause.body) end
        end
    end
    for _, v in pairs(Node) do
        if type(v) == "table" then
            CollectBlocks(v, Blocks)
        end
    end
end

function PadPayload:apply(ast, pipeline)
    if pipeline.Config.Steps.PadPayload == nil or not pipeline.Config.Steps.PadPayload.Enabled then return ast end

    local Blocks = {}
    CollectBlocks(ast, Blocks)
    
    if #Blocks == 0 then
        table.insert(Blocks, ast.body)
    end
    
    local Count = pipeline.Config.Steps.PadPayload.Count or 10
    
    for i = 1, Count do
        local TargetBlock = Blocks[math.random(1, #Blocks)]
        local InsertIdx = math.random(1, #TargetBlock + 1)
        table.insert(TargetBlock, InsertIdx, DummyIf())
    end

    return ast
end

return PadPayload
