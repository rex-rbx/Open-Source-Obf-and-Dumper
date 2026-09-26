local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Parser = ModuleHandler:GetModule("Parser")

local NumbersToExpressions = StepHandler:AddStep("NumbersToExpressions")

local function IsNode(Value)
    return type(Value) == "table" and type(Value.type) == "string"
end

local function CollectLiterals(Node, Acc)
    for _, Child in ipairs(Node) do
        if IsNode(Child) then
            if Child.type == "NumericLiteral" then
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
                if Value.type == "NumericLiteral" then
                    table.insert(Acc, Value)
                end
                CollectLiterals(Value, Acc)
            elseif type(Value) == "table" then
                CollectLiterals(Value, Acc)
            end
        end
    end
end

local Random = math.random
local Floor = math.floor

local function IsInteger(Value)
    return Value == Floor(Value) and Value ~= math.huge and Value ~= -math.huge and Value == Value
end

local function NumNode(Value)
    return {
        type = "NumericLiteral",
        value = Value,
        raw = tostring(Value),
    }
end

local function StringNode(Str)
    return {
        type = "StringLiteral",
        value = Str,
        raw = '"' .. Str .. '"',
    }
end

local function UnaryLenNode(Arg)
    return {
        type = "UnaryExpression",
        operator = "#",
        argument = Arg,
    }
end

local function BinaryNode(Op, Left, Right)
    return {
        type = "BinaryExpression",
        operator = Op,
        left = Left,
        right = Right,
    }
end

local MAX_K = 2 ^ 31 - 1

local function BitCall(Operator, Args)
    return {
        type = "CallExpression",
        base = {
            type = "MemberExpression",
            indexer = ".",
            identifier = { type = "Identifier", name = Operator, isLocal = false },
            base = { type = "Identifier", name = "bit32", isLocal = false },
        },
        arguments = Args,
    }
end

local MAX_UNIQUE_VALUES = 40

local function GenBitExpr(Value, Depth)
	if Depth <= 0 then
		return NumNode(Value)
	end

	if not IsInteger(Value) then
		return NumNode(Value)
	end

	if Value < 0 or Value >= 2 ^ 32 then
		if Value < 0 then
			return {
				type = "UnaryExpression",
				operator = "-",
				argument = GenBitExpr(-Value, Depth),
			}
		end
		return NumNode(Value)
	end

	local EffectiveDepth = Value >= 1000000 and 1 or Depth

	local Strategy = Random(1, Value >= 1 and 6 or 5)

	if Strategy == 1 then
		local K = Random(0, MAX_K)
		return BitCall("bxor", {
			BitCall("bxor", { GenBitExpr(Value, EffectiveDepth - 1), NumNode(K) }),
			NumNode(K),
		})
	elseif Strategy == 2 then
		local M = Random(0, MAX_K)
		return BitCall("bor", {
			BitCall("band", { GenBitExpr(Value, EffectiveDepth - 1), NumNode(M) }),
			BitCall("band", { NumNode(Value), BitCall("bnot", { NumNode(M) }) }),
		})
	elseif Strategy == 3 then
		local K = Random(1, 8)
		if Value > 0 and Value % (2 ^ K) == 0 then
			return BitCall("lshift", {
				BitCall("rshift", { GenBitExpr(Value, EffectiveDepth - 1), NumNode(K) }),
				NumNode(K),
			})
		elseif Value * (2 ^ K) < 2 ^ 32 then
			return BitCall("rshift", {
				BitCall("lshift", { GenBitExpr(Value, EffectiveDepth - 1), NumNode(K) }),
				NumNode(K),
			})
		else
			local K2 = Random(0, MAX_K)
			return BitCall("bxor", {
				BitCall("bxor", { NumNode(Value), NumNode(K2) }),
				NumNode(K2),
			})
		end
	elseif Strategy == 4 then
		local K = Random(0, MAX_K)
		return BitCall("bxor", {
			GenBitExpr(Value, EffectiveDepth - 1),
			BitCall("bxor", { NumNode(K), NumNode(K) }),
		})
	elseif Strategy == 5 then
		local MaxLen = math.min(15, math.max(1, Value))
		local Len = Random(1, MaxLen)
		local Str = string.rep("x", Len)
		local Diff = Value - Len
		return BinaryNode("+", UnaryLenNode(StringNode(Str)), GenBitExpr(Diff, EffectiveDepth - 1))
	else
		local K = Random(1, 1000)
		return BinaryNode("-", BinaryNode("+", GenBitExpr(Value, EffectiveDepth - 1), NumNode(K)), NumNode(K))
	end
end

function NumbersToExpressions:apply(ast, pipeline)
    local Literals = {}
    CollectLiterals(ast, Literals)

    if #Literals == 0 then
        return ast
    end

    local Seen = {}
    local UniqueValues = {}
    for _, Node in ipairs(Literals) do
        if Node.type == "NumericLiteral" then
            local Value = tonumber(Node.value)
            if Value ~= nil and not Seen[Value] then
                Seen[Value] = true
                table.insert(UniqueValues, Value)
            end
        end
    end

    local Transformable = {}
    if #UniqueValues > MAX_UNIQUE_VALUES then
        local Shuffled = {}
        for I, V in ipairs(UniqueValues) do Shuffled[I] = V end
        for I = #Shuffled, 2, -1 do
            local J = Random(1, I)
            Shuffled[I], Shuffled[J] = Shuffled[J], Shuffled[I]
        end
        for I = 1, MAX_UNIQUE_VALUES do
            Transformable[Shuffled[I]] = true
        end
    else
        for _, V in ipairs(UniqueValues) do
            Transformable[V] = true
        end
    end

    local Collected = {}
    local ValueToId = {}

    for _, Node in ipairs(Literals) do
        if Node.type == "NumericLiteral" then
            local Value = tonumber(Node.value)
            if Value ~= nil and Transformable[Value] then
                local Id = ValueToId[Value]
                if not Id then
                    Id = #Collected + 1
                    Collected[Id] = GenBitExpr(Value, 2)
                    ValueToId[Value] = Id
                end

                for Key in next, Node do
                    Node[Key] = nil
                end
                Node.type = "IndexExpression"
                Node.base = { type = "Identifier", name = "Numbers", isLocal = true }
                Node.index = { type = "NumericLiteral", value = Id, raw = tostring(Id) }
                Node.indexer = "["
            end
        end
    end

    if #Collected == 0 then
        return ast
    end

    local Entries = {}
    for Index, Expr in ipairs(Collected) do
        Entries[Index] = {
            type = "TableValue",
            value = Expr,
        }
    end

    local NumbersDecl = {
        type = "LocalStatement",
        variables = { { type = "Identifier", name = "Numbers", isLocal = true } },
        init = {
            {
                type = "TableConstructorExpression",
                fields = Entries,
            },
        },
    }

    table.insert(ast.body, 1, NumbersDecl)

    pipeline.Tables = pipeline.Tables or {}
    table.insert(pipeline.Tables, 1, "Numbers")

    return ast
end

return NumbersToExpressions