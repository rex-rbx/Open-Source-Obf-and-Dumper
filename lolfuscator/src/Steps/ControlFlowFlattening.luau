local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Logger = ModuleHandler:GetModule("Logger")

local CFF = StepHandler:AddStep("ControlFlowFlattening")

local UnhandledTypes = {
	WhileStatement = true,
	RepeatStatement = true,
	ForNumericStatement = true,
	ForGenericStatement = true,
	BreakStatement = true,
}

local function IsNode(Value)
	return type(Value) == "table" and type(Value.type) == "string"
end

local function Shuffle(List)
	for Index = #List, 2, -1 do
		local SwapIndex = math.random(1, Index)
		List[Index], List[SwapIndex] = List[SwapIndex], List[Index]
	end
end

local function ContainsUnhandled(Body)
	for _, Statement in ipairs(Body or {}) do
		if IsNode(Statement) then
			if UnhandledTypes[Statement.type] then return true end
			if Statement.type == "DoStatement" and ContainsUnhandled(Statement.body) then return true end
			if Statement.type == "IfStatement" then
				for _, Clause in ipairs(Statement.clauses or {}) do
					if ContainsUnhandled(Clause.body) then return true end
				end
			end
		end
	end
	return false
end

local function FlattenBody(Body)
	local Blocks = {}
	local NextId = 1
	local function NewBlock()
		local Block = { id = NextId, stmts = {} }
		NextId += 1
		Blocks[#Blocks + 1] = Block
		return Block
	end
	local function Process(Statements, CurrentBlock)
		for _, Statement in ipairs(Statements) do
			if not IsNode(Statement) then continue end
			if Statement.type == "ReturnStatement" then
				CurrentBlock.stmts[#CurrentBlock.stmts + 1] = {
					type = "AssignmentStatement",
					variables = { { type = "Identifier", name = "CffReturn", isLocal = true } },
					init = { (Statement.arguments and Statement.arguments[1]) or { type = "NilLiteral" } },
				}
				CurrentBlock.returns = true
				CurrentBlock = NewBlock()
			elseif Statement.type == "IfStatement" then
				local AfterBlock = NewBlock()
				local Clauses = {}
				for _, Clause in ipairs(Statement.clauses or {}) do
					local ClauseBlock = Process(Clause.body or {}, NewBlock())
					local ClauseBody = ClauseBlock.stmts
					ClauseBody[#ClauseBody + 1] = {
						type = "AssignmentStatement",
						variables = { { type = "Identifier", name = "CffState", isLocal = true } },
						init = { { type = "NumericLiteral", value = ClauseBlock.returns and -1 or AfterBlock.id, raw = tostring(ClauseBlock.returns and -1 or AfterBlock.id) } },
					}
					if ClauseBlock.returns then
						ClauseBody[#ClauseBody + 1] = {
							type = "AssignmentStatement",
							variables = { { type = "Identifier", name = "CffHasReturn", isLocal = true } },
							init = { { type = "BooleanLiteral", value = true, raw = "true" } },
						}
					end
					local NewClause = { type = Clause.type, body = ClauseBody }
					if Clause.type ~= "ElseClause" then NewClause.condition = Clause.condition end
					Clauses[#Clauses + 1] = NewClause
				end
				if #Clauses > 0 then CurrentBlock.stmts[#CurrentBlock.stmts + 1] = { type = "IfStatement", clauses = Clauses } end
				CurrentBlock = AfterBlock
			elseif Statement.type == "DoStatement" then
				CurrentBlock = Process(Statement.body or {}, CurrentBlock)
			else
				CurrentBlock.stmts[#CurrentBlock.stmts + 1] = Statement
			end
		end
		return CurrentBlock
	end
	Process(Body, NewBlock())
	while #Blocks > 0 and #Blocks[#Blocks].stmts == 0 and not Blocks[#Blocks].returns do table.remove(Blocks) end
	return Blocks
end

local function BuildStateMachine(Blocks)
	local StateBase = math.random(100000, 800000)
	local StateStride = math.random(17, 97)
	local StateMask = math.random(11, 97)
	local TerminalState = StateBase - StateStride
	local StateValues = {}
	for Index = 1, #Blocks do StateValues[Index] = StateBase + (Index - 1) * StateStride end
	Shuffle(StateValues)
	local function StateValue(Id)
		return StateValues[Id]
	end
	local function StateCondition(Value)
		return {
			type = "BinaryExpression", operator = "==",
			left = { type = "Identifier", name = "CffState", isLocal = true },
			right = { type = "BinaryExpression", operator = "-",
				left = { type = "BinaryExpression", operator = "+",
					left = { type = "NumericLiteral", value = Value, raw = tostring(Value) },
					right = { type = "NumericLiteral", value = StateMask, raw = tostring(StateMask) } },
				right = { type = "NumericLiteral", value = StateMask, raw = tostring(StateMask) } },
		}
	end
	local function Encode(Node)
		if type(Node) ~= "table" then return end
		if Node.type == "AssignmentStatement" and Node.variables and Node.variables[1]
			and Node.variables[1].name == "CffState" and Node.init and Node.init[1]
			and Node.init[1].type == "NumericLiteral" then
			local Value = Node.init[1].value
			if Value == -1 then Value = TerminalState elseif Value >= 1 and Value <= #Blocks then Value = StateValue(Value) end
			Node.init[1].value, Node.init[1].raw = Value, tostring(Value)
		end
		for _, Child in pairs(Node) do if type(Child) == "table" then Encode(Child) end end
	end
	for _, Block in ipairs(Blocks) do Encode(Block.stmts) end

	local Body = {
		{ type = "LocalStatement", variables = { { type = "Identifier", name = "CffReturn", isLocal = true }, { type = "Identifier", name = "CffHasReturn", isLocal = true } }, init = { { type = "NilLiteral" }, { type = "BooleanLiteral", value = false, raw = "false" } } },
		{ type = "LocalStatement", variables = { { type = "Identifier", name = "CffState", isLocal = true } }, init = { { type = "NumericLiteral", value = StateValue(1), raw = tostring(StateValue(1)) } } },
	}
	local Clauses = {}
	for _, Block in ipairs(Blocks) do
		local ClauseBody = Block.stmts
		if Block.returns then
			ClauseBody[#ClauseBody + 1] = { type = "AssignmentStatement", variables = { { type = "Identifier", name = "CffHasReturn", isLocal = true } }, init = { { type = "BooleanLiteral", value = true, raw = "true" } } }
			ClauseBody[#ClauseBody + 1] = { type = "AssignmentStatement", variables = { { type = "Identifier", name = "CffState", isLocal = true } }, init = { { type = "NumericLiteral", value = TerminalState, raw = tostring(TerminalState) } } }
		else
			local NextId = Block.id + 1
			if NextId <= #Blocks then ClauseBody[#ClauseBody + 1] = { type = "AssignmentStatement", variables = { { type = "Identifier", name = "CffState", isLocal = true } }, init = { { type = "NumericLiteral", value = StateValue(NextId), raw = tostring(StateValue(NextId)) } } } end
		end
		Clauses[#Clauses + 1] = { type = "IfClause", condition = StateCondition(StateValue(Block.id)), body = ClauseBody }
	end
	local NoiseBase = StateBase + (#Blocks + 3) * StateStride
	for Index = 1, 120 do
		local NoiseState = NoiseBase + Index * StateStride
		local Target = Index == 120 and TerminalState or NoiseState + StateStride
		Clauses[#Clauses + 1] = { type = "IfClause", condition = StateCondition(NoiseState), body = { { type = "AssignmentStatement", variables = { { type = "Identifier", name = "CffState", isLocal = true } }, init = { { type = "NumericLiteral", value = Target, raw = tostring(Target) } } } } }
	end
	Shuffle(Clauses)
	Clauses[#Clauses + 1] = { type = "IfClause", condition = StateCondition(TerminalState), body = { { type = "BreakStatement" } } }
	Body[#Body + 1] = { type = "WhileStatement", condition = { type = "BooleanLiteral", value = true, raw = "true" }, body = { { type = "IfStatement", clauses = Clauses } } }
	Body[#Body + 1] = { type = "IfStatement", clauses = { { type = "IfClause", condition = { type = "Identifier", name = "CffHasReturn", isLocal = true }, body = { { type = "ReturnStatement", arguments = { { type = "Identifier", name = "CffReturn", isLocal = true } } } } } } }
	return Body
end

function CFF:apply(ast, pipeline)
	local Metadata = pipeline.MacroMetadata or {}
	local function Walk(Node)
		if not IsNode(Node) then return end
		if Node.type == "FunctionDeclaration" then
			local Settings = pipeline.Config.Steps and pipeline.Config.Steps.ControlFlowFlattening or {}
			local Meta = Node.MacroMetadata or Metadata[Node] or {}
			local ShouldCff = Settings.ApplyToAllFunctions ~= false or Meta.CFF or false
			if ShouldCff and not Meta.OMIT and not Meta.OMIT_FUNCTION and not Meta.OMIT_CFF and Node.body then
				if ContainsUnhandled(Node.body) then Logger:Info("CFF skipped function: contains unhandled control flow") else
					local Blocks = FlattenBody(Node.body)
					if #Blocks > 1 then Node.body = BuildStateMachine(Blocks) end
				end
			end
		end
		for _, Child in pairs(Node) do if type(Child) == "table" then Walk(Child) end end
	end
	Walk(ast)
	return ast
end

return CFF
