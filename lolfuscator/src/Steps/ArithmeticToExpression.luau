local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local ArithmeticToExpression = StepHandler:AddStep("ArithmeticToExpression")

local Random = math.random

local function NumNode(Value)
	return { type = "NumericLiteral", value = Value, raw = tostring(Value) }
end

local function BinOp(Op, Left, Right)
	return { type = "BinaryExpression", operator = Op, left = Left, right = Right, inParens = true }
end

local function UnaryOp(Op, Arg)
	return { type = "UnaryExpression", operator = Op, argument = Arg }
end

local function Bit32Call(Func, ...)
	return {
		type = "CallExpression",
		base = {
			type = "MemberExpression",
			indexer = ".",
			identifier = { type = "Identifier", name = Func, isLocal = false },
			base = { type = "Identifier", name = "bit32", isLocal = false },
		},
		arguments = { ... },
	}
end

local function CloneNode(Node)
	local Copy = {}
	for K, V in next, Node do
		Copy[K] = V
	end
	return Copy
end

local function TransformAddition(Left, Right)
	local Strategy = Random(1, 5)
	if Strategy == 1 then
		-- a + b = (a XOR b) + 2*(a AND b)
		return BinOp("+",
			Bit32Call("bxor", CloneNode(Left), CloneNode(Right)),
			Bit32Call("lshift", Bit32Call("band", CloneNode(Left), CloneNode(Right)), NumNode(1))
		)
	elseif Strategy == 2 then
		-- a + b = (a OR b) + (a AND b)
		return BinOp("+",
			Bit32Call("bor", CloneNode(Left), CloneNode(Right)),
			Bit32Call("band", CloneNode(Left), CloneNode(Right))
		)
	elseif Strategy == 3 then
		-- a + b = a - (-b)
		return BinOp("-", CloneNode(Left), UnaryOp("-", CloneNode(Right)))
	elseif Strategy == 4 then
		-- a + b = b - (-a)
		return BinOp("-", CloneNode(Right), UnaryOp("-", CloneNode(Left)))
	else
		-- a + b = a + b * 1
		return BinOp("+", CloneNode(Left), BinOp("*", CloneNode(Right), NumNode(1)))
	end
end

local function TransformSubtraction(Left, Right)
	if Random(1, 2) == 1 then
		-- a - b = a + (-b)
		return BinOp("+", CloneNode(Left), UnaryOp("-", CloneNode(Right)))
	else
		-- a - b = (a XOR b) - 2*(bnot(a) AND b)
		return BinOp("-",
			Bit32Call("bxor", CloneNode(Left), CloneNode(Right)),
			Bit32Call("lshift", Bit32Call("band", Bit32Call("bnot", CloneNode(Left)), CloneNode(Right)), NumNode(1))
		)
	end
end

local function TransformNegation(Arg)
	if Random(1, 3) == 1 then
		-- -x = bnot(x) + 1 (two's complement)
		return BinOp("+", Bit32Call("bnot", CloneNode(Arg)), NumNode(1))
	elseif Random(1, 2) == 1 then
		-- -x = xor(x, -1) + 1
		return BinOp("+", Bit32Call("bxor", CloneNode(Arg), NumNode(-1)), NumNode(1))
	else
		-- -x = 0 - x
		return BinOp("-", NumNode(0), CloneNode(Arg))
	end
end

local function TransformEquality(Left, Right)
	if Random(1, 2) == 1 then
		-- a == b = xor(a, b) == 0
		return BinOp("==", Bit32Call("bxor", CloneNode(Left), CloneNode(Right)), NumNode(0))
	else
		-- a == b = not (a ~= b)
		return UnaryOp("not", BinOp("~=", CloneNode(Left), CloneNode(Right)))
	end
end

local function TransformInequality(Left, Right)
	if Random(1, 2) == 1 then
		-- a ~= b = xor(a, b) ~= 0
		return BinOp("~=", Bit32Call("bxor", CloneNode(Left), CloneNode(Right)), NumNode(0))
	else
		-- a ~= b = not (a == b)
		return UnaryOp("not", BinOp("==", CloneNode(Left), CloneNode(Right)))
	end
end

local function IsNode(Value)
	return type(Value) == "table" and type(Value.type) == "string"
end

local function WalkTransform(Node)
	if type(Node) ~= "table" then return end

	for _, Child in ipairs(Node) do
		if IsNode(Child) then
			WalkTransform(Child)
		elseif type(Child) == "table" then
			WalkTransform(Child)
		end
	end
	for Field, Value in next, Node do
		if type(Field) == "string" then
			if IsNode(Value) then
				WalkTransform(Value)
			elseif type(Value) == "table" then
				WalkTransform(Value)
			end
		end
	end

	if Node.type == "BinaryExpression" then
		if Random(1, 3) ~= 1 then return end

		local Op = Node.operator
		local Replacement
		if Op == "+" then
			Replacement = TransformAddition(Node.left, Node.right)
		elseif Op == "-" then
			Replacement = TransformSubtraction(Node.left, Node.right)
		elseif Op == "==" then
			Replacement = TransformEquality(Node.left, Node.right)
		elseif Op == "~=" then
			Replacement = TransformInequality(Node.left, Node.right)
		end

		if Replacement then
			for Key in next, Node do Node[Key] = nil end
			for Key, Value in next, Replacement do Node[Key] = Value end
		end
	elseif Node.type == "UnaryExpression" and Node.operator == "-" then
		if Random(1, 4) ~= 1 then return end

		local Replacement = TransformNegation(Node.argument)
		for Key in next, Node do Node[Key] = nil end
		for Key, Value in next, Replacement do Node[Key] = Value end
	end
end

function ArithmeticToExpression:apply(ast, pipeline)
	WalkTransform(ast)
	return ast
end

return ArithmeticToExpression
