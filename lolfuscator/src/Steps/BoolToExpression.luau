local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local BoolToExpression = StepHandler:AddStep("BoolToExpression")

local Random = math.random

local function NumNode(Value)
    return {
        type = "NumericLiteral",
        value = Value,
        raw = tostring(Value),
    }
end

local function BinOp(Operator, Left, Right)
    return {
        type = "BinaryExpression",
        operator = Operator,
        left = Left,
        right = Right,
    }
end

local function GenerateComplexOp(TargetBool, Depth)
    Depth = Depth or 0
    if Depth > 2 then
        local A = Random(1, 10000)
        if TargetBool then
            return BinOp("==", NumNode(A), NumNode(A))
        else
            return BinOp("~=", NumNode(A), NumNode(A))
        end
    end

    local Strategy = Random(1, 4)
    if Strategy == 1 then
        -- Math equality check
        local A = Random(1, 100)
        local B = Random(1, 100)
        local Res = A + B
        local Offset = TargetBool and 0 or Random(1, 10)
        return BinOp("==", BinOp("+", NumNode(A), NumNode(B)), NumNode(Res + Offset))
    elseif Strategy == 2 then
        -- Logical NOT
        local Inner = GenerateComplexOp(not TargetBool, Depth + 1)
        Inner.inParens = true
        return {
            type = "UnaryExpression",
            operator = "not",
            argument = Inner
        }
    elseif Strategy == 3 then
        -- AND / OR
        if TargetBool then
            if Random(1, 2) == 1 then
                return BinOp("and", GenerateComplexOp(true, Depth + 1), GenerateComplexOp(true, Depth + 1))
            else
                return BinOp("or", GenerateComplexOp(true, Depth + 1), GenerateComplexOp(false, Depth + 1))
            end
        else
            if Random(1, 2) == 1 then
                return BinOp("or", GenerateComplexOp(false, Depth + 1), GenerateComplexOp(false, Depth + 1))
            else
                return BinOp("and", GenerateComplexOp(false, Depth + 1), GenerateComplexOp(true, Depth + 1))
            end
        end
    else
        -- Inequality logic
        local A = Random(1, 1000)
        local B = Random(1, 1000)
        if A == B then B = B + 1 end
        if TargetBool then
            if A > B then return BinOp(">", NumNode(A), NumNode(B))
            else return BinOp("<", NumNode(A), NumNode(B)) end
        else
            if A > B then return BinOp("<", NumNode(A), NumNode(B))
            else return BinOp(">", NumNode(A), NumNode(B)) end
        end
    end
end

local function GenerateTrueExpression()
    return GenerateComplexOp(true, 0)
end

local function GenerateFalseExpression()
    return GenerateComplexOp(false, 0)
end

local function IsNode(Value)
    return type(Value) == "table" and type(Value.type) == "string"
end

local function CollectLiterals(Node, Acc)
    for _, Child in ipairs(Node) do
        if IsNode(Child) then
            if Child.type == "BooleanLiteral" then
                table.insert(Acc, Child)
            end
            CollectLiterals(Child, Acc)
        elseif type(Child) == "table" then
            CollectLiterals(Child, Acc)
        end
    end
    for Field, Value in next, Node do
        if type(Field) == "string" then
            if IsNode(Value) then
                if Value.type == "BooleanLiteral" then
                    table.insert(Acc, Value)
                end
                CollectLiterals(Value, Acc)
            elseif type(Value) == "table" then
                CollectLiterals(Value, Acc)
            end
        end
    end
end

function BoolToExpression:apply(ast, pipeline)
    local Literals = {}
    CollectLiterals(ast, Literals)

    for _, Node in ipairs(Literals) do
    if Node.type == "BooleanLiteral" then
        local Replacement = Node.value and GenerateTrueExpression() or GenerateFalseExpression()
        Replacement.inParens = true

        for Key in next, Node do
            Node[Key] = nil
        end
        for Key, Value in next, Replacement do
            Node[Key] = Value
        end
    end
    end

    return ast
end

return BoolToExpression