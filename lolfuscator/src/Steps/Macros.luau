local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Logger = ModuleHandler:GetModule("Logger")

local Macros = StepHandler:AddStep("Macros")

local FunctionMacros = {
	JEW_CFF = true,
	JEW_VM = true,
	JEW_JIT = true,
	JEW_JIT_MAX = true,
	JEW_NO_VIRTUALIZE = true,
	JEW_NO_UPVALUES = true,
	JEW_INLINE = true,
	JEW_OMIT = true,
	JEW_OMIT_FUNCTION = true,
	JEW_OMIT_CFF = true,
	JEW_OMIT_VM = true,
	JEW_ENC_FUNC = true,
	JEW_ENCFUNC = true,
}

local ExpressionMacros = {
	JEW_OBFUSCATED = function(_, _)
		return { type = "BooleanLiteral", value = true, raw = "true" }
	end,
	JEW_LINE = function(Node, _)
		local Loc = Node.loc or {}
		local Line = Loc.start and Loc.start.line or 0
		return { type = "NumericLiteral", value = Line, raw = tostring(Line) }
	end,
	JEW_CRASH = function(_, _)
		return {
			type = "ReturnStatement",
			arguments = {
				{
					type = "CallExpression",
					base = {
						type = "NilLiteral",
						value = nil,
						raw = "nil",
						inParens = true,
					},
					arguments = {},
				},
			},
		}
	end,
	JEW_ENCSTR = function(Node, _)
		local Args = Node.arguments
		if Args and Args[1] then
			return Args[1]
		end
		return nil
	end,
	JEW_ENC_STR = function(Node, _)
		local Args = Node.arguments
		if Args and Args[1] then
			return Args[1]
		end
		return nil
	end,
	JEW_ENCNUM = function(Node, _)
		local Args = Node.arguments
		if Args and Args[1] then
			return Args[1]
		end
		return nil
	end,
	JEW_COMPRESS = function(Node, _)
		local Args = Node.arguments
		if Args and Args[1] then
			return Args[1]
		end
		return nil
	end,
	JEW_INDEX_TO_NUM = function(Node, _)
		local Args = Node.arguments
		if Args and Args[1] then
			return Args[1]
		end
		return nil
	end,
}

local function IsNode(Value)
	return type(Value) == "table" and type(Value.type) == "string"
end

local function WalkReplace(Node, ReplaceFn)
	if not IsNode(Node) then return end
	ReplaceFn(Node)

	for _, Child in ipairs(Node) do
		if IsNode(Child) then
			WalkReplace(Child, ReplaceFn)
		end
	end

	for Key, Value in next, Node do
		if type(Key) == "string" then
			if IsNode(Value) then
				WalkReplace(Value, ReplaceFn)
			elseif type(Value) == "table" then
				for _, Item in ipairs(Value) do
					if IsNode(Item) then
						WalkReplace(Item, ReplaceFn)
					end
				end
			end
		end
	end
end

local function SpliceIntoParent(Node, Replacement)
	for K in next, Node do
		Node[K] = nil
	end
	for K, V in next, Replacement do
		Node[K] = V
	end
end

local function EvaluateCondition(Node)
	if not IsNode(Node) then return nil end
	if Node.type == "BooleanLiteral" then return Node.value end
	if Node.type == "UnaryExpression" and Node.operator == "not" then
		local Inner = EvaluateCondition(Node.argument)
		if Inner ~= nil then return not Inner end
	end
	if Node.type == "BinaryExpression" and Node.operator == "and" then
		local Left = EvaluateCondition(Node.left)
		local Right = EvaluateCondition(Node.right)
		if Left ~= nil and Right ~= nil then return Left and Right end
		if Left ~= nil then return Left and Right end
		if Right ~= nil then return Left and Right end
	end
	if Node.type == "BinaryExpression" and Node.operator == "or" then
		local Left = EvaluateCondition(Node.left)
		local Right = EvaluateCondition(Node.right)
		if Left ~= nil and Right ~= nil then return Left or Right end
		if Left ~= nil and Left == true then return true end
		if Right ~= nil and Right == true then return true end
	end
	return nil
end

local function DeadCodeElimination(Node)
	if not IsNode(Node) then return end

	if Node.type == "IfStatement" then
		local Clauses = Node.clauses
		if Clauses then
			for Idx, Clause in ipairs(Clauses) do
				if IsNode(Clause) and (Clause.type == "IfClause" or Clause.type == "ElseifClause") then
					local CondValue = EvaluateCondition(Clause.condition)
					if CondValue ~= nil then
						if CondValue then
							local Body = Clause.body or {}
							for K in next, Node do Node[K] = nil end
							Node.type = "DoStatement"
							Node.body = Body
							DeadCodeElimination(Node)
							return
						else
							local FallbackBody = nil
							for J = Idx + 1, #Clauses do
								local NextClause = Clauses[J]
								if IsNode(NextClause) then
									if NextClause.type == "ElseClause" then
										FallbackBody = NextClause.body or {}
										break
									elseif NextClause.type == "IfClause" or NextClause.type == "ElseifClause" then
										local NextCond = EvaluateCondition(NextClause.condition)
										if NextCond == nil then
											break
										elseif NextCond then
											FallbackBody = NextClause.body or {}
											break
										end
									end
								end
							end
							for K in next, Node do Node[K] = nil end
							Node.type = "DoStatement"
							Node.body = FallbackBody or {}
							DeadCodeElimination(Node)
							return
						end
					end
				end
			end
		end
	end

	for _, Child in ipairs(Node) do
		if IsNode(Child) then
			DeadCodeElimination(Child)
		end
	end
	for Key, Value in next, Node do
		if type(Key) == "string" then
			if IsNode(Value) then
				DeadCodeElimination(Value)
			elseif type(Value) == "table" then
				for _, Item in ipairs(Value) do
					if IsNode(Item) then
						DeadCodeElimination(Item)
					end
				end
			end
		end
	end
end

function Macros:apply(ast, pipeline)
	local MacroList = pipeline.Config.DeveloperSettings and pipeline.Config.DeveloperSettings.Macros
		and pipeline.Config.DeveloperSettings.Macros.MacroList or {}
	local Available = {}
	for Name in pairs(MacroList) do
		Available[Name] = true
	end

	local function ReplaceMacro(Node)
		if Node.type == "CallExpression" and Node.base and Node.base.type == "Identifier" then
			local Name = Node.base.name
			if not Available[Name] then return end

			if FunctionMacros[Name] then
				local FnArg = Node.arguments and Node.arguments[1]
				if FnArg and IsNode(FnArg) then
					FnArg.MacroMetadata = FnArg.MacroMetadata or {}
					FnArg.MacroMetadata[Name] = true
					SpliceIntoParent(Node, FnArg)
				end
				return
			end

			local Handler = ExpressionMacros[Name]
			if Handler then
				local Replacement = Handler(Node, nil)
				if Replacement then
					SpliceIntoParent(Node, Replacement)
				end
			end
			return
		end

		if Node.type == "Identifier" and Available[Node.name] and ExpressionMacros[Node.name] then
			local Replacement = ExpressionMacros[Node.name](Node, nil)
			if Replacement then
				SpliceIntoParent(Node, Replacement)
			end
		end
	end

	for _, Stmt in ipairs(ast.body or {}) do
		if IsNode(Stmt) then
			WalkReplace(Stmt, ReplaceMacro)
		end
	end

	DeadCodeElimination(ast)

	pipeline.MacroMetadata = {}
	local function CollectMetadata(Node)
		if not IsNode(Node) then return end
		if Node.type == "FunctionDeclaration" and Node.MacroMetadata then
			pipeline.MacroMetadata[Node] = Node.MacroMetadata
		end
		for _, Child in ipairs(Node) do
			if IsNode(Child) then
				CollectMetadata(Child)
			end
		end
		for Key, Value in next, Node do
			if type(Key) == "string" then
				if IsNode(Value) then
					CollectMetadata(Value)
				elseif type(Value) == "table" then
					for _, Item in ipairs(Value) do
						if IsNode(Item) then
							CollectMetadata(Item)
						end
					end
				end
			end
		end
	end
	CollectMetadata(ast)

	return ast
end

return Macros
