local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local ProxifyLocals = StepHandler:AddStep("ProxifyLocals")

local function IsNode(Value)
	return type(Value) == "table" and type(Value.type) == "string"
end

local function MakeIdentifier(Name, IsLocal)
	return { type = "Identifier", name = Name, isLocal = IsLocal ~= false }
end

local function MakeMemberDot(Base, MemberName)
	return {
		type = "MemberExpression",
		indexer = ".",
		identifier = MakeIdentifier(MemberName, false),
		base = Base,
	}
end

local function MakeMapValue(Key, Value)
	return { type = "MapValue", key = Key, value = Value }
end

local function WrapInProxy(Expr)
	return {
		type = "TableConstructorExpression",
		fields = {
			MakeMapValue(MakeIdentifier("v", false), Expr),
		},
	}
end

local ScopeStack = {}
local ProxifyStack = {}

local function PushScope()
	table.insert(ScopeStack, {})
	table.insert(ProxifyStack, {})
end

local function PopScope()
	table.remove(ScopeStack)
	table.remove(ProxifyStack)
end

local function DeclareLocal(Name, ShouldProxy)
	ScopeStack[#ScopeStack][Name] = true
	ProxifyStack[#ProxifyStack][Name] = ShouldProxy
end

local function IsProxifiedLocal(Name)
	for i = #ProxifyStack, 1, -1 do
		if ProxifyStack[i][Name] ~= nil then
			return ProxifyStack[i][Name]
		end
	end
	return false
end

local function ReplaceWithDotV(Node, Name)
	for K in next, Node do Node[K] = nil end
	Node.type = "MemberExpression"
	Node.indexer = "."
	Node.identifier = MakeIdentifier("v", false)
	Node.base = MakeIdentifier(Name, true)
end

local WalkProxify

local function WalkLHSBase(Node)
	if Node.type == "Identifier" and Node.isLocal and IsProxifiedLocal(Node.name) then
		ReplaceWithDotV(Node, Node.name)
	elseif Node.type == "IndexExpression" or Node.type == "MemberExpression" then
		WalkLHSBase(Node.base)
		if Node.type == "IndexExpression" and Node.index then
			WalkProxify(Node.index)
		end
	end
end

WalkProxify = function(Node)
	if type(Node) ~= "table" then return end

	if Node.type == "FunctionDeclaration" or Node.type == "FunctionExpression" then
		PushScope()
		for _, Param in ipairs(Node.parameters or {}) do
			if Param.type == "Identifier" then
				DeclareLocal(Param.name, false)
			end
		end
		for _, Stmt in ipairs(Node.body or {}) do
			WalkProxify(Stmt)
		end
		PopScope()
		return
	end

	if Node.type == "LocalStatement" then
		local IsMultiReturn = #Node.variables > #Node.init
		if not IsMultiReturn then
			for i, Var in ipairs(Node.variables) do
				if Var.type == "Identifier" and Node.init[i] then
					local InitType = Node.init[i].type
					local SkipProxy = InitType == "FunctionDeclaration" or InitType == "FunctionExpression"
					if not SkipProxy then
						Node.init[i] = WrapInProxy(Node.init[i])
					end
				end
			end
		end
		for _, Init in ipairs(Node.init) do
			WalkProxify(Init)
		end
		for i, Var in ipairs(Node.variables) do
			if Var.type == "Identifier" then
				local InitExpr = Node.init[i]
				local HasInit = InitExpr ~= nil
				local IsFunction = HasInit and (InitExpr.type == "FunctionDeclaration" or InitExpr.type == "FunctionExpression")
				DeclareLocal(Var.name, HasInit and not IsFunction and not IsMultiReturn)
			end
		end
		return
	end

	if Node.type == "NumericForStatement" or Node.type == "ForNumericStatement" then
		WalkProxify(Node.start)
		WalkProxify(Node["end"])
		if Node.step then WalkProxify(Node.step) end
		PushScope()
		if Node.variable and Node.variable.type == "Identifier" then
			DeclareLocal(Node.variable.name, false)
		end
		for _, Stmt in ipairs(Node.body or {}) do
			WalkProxify(Stmt)
		end
		PopScope()
		return
	end

	if Node.type == "GenericForStatement" or Node.type == "ForGenericStatement" then
		for _, Expr in ipairs(Node.iterators or {}) do
			WalkProxify(Expr)
		end
		PushScope()
		for _, Var in ipairs(Node.variables or {}) do
			if Var.type == "Identifier" then
				DeclareLocal(Var.name, false)
			end
		end
		for _, Stmt in ipairs(Node.body or {}) do
			WalkProxify(Stmt)
		end
		PopScope()
		return
	end

	if Node.type == "DoStatement" then
		PushScope()
		for _, Stmt in ipairs(Node.body or {}) do
			WalkProxify(Stmt)
		end
		PopScope()
		return
	end

	if Node.type == "RepeatStatement" then
		PushScope()
		for _, Stmt in ipairs(Node.body or {}) do
			WalkProxify(Stmt)
		end
		WalkProxify(Node.condition)
		PopScope()
		return
	end

	if Node.type == "WhileStatement" then
		WalkProxify(Node.condition)
		PushScope()
		for _, Stmt in ipairs(Node.body or {}) do
			WalkProxify(Stmt)
		end
		PopScope()
		return
	end

	if Node.type == "IfStatement" then
		for _, Clause in ipairs(Node.clauses or {}) do
			if Clause.condition then
				WalkProxify(Clause.condition)
			end
			PushScope()
			for _, Stmt in ipairs(Clause.body or {}) do
				WalkProxify(Stmt)
			end
			PopScope()
		end
		return
	end

	if Node.type == "Identifier" and Node.isLocal and IsProxifiedLocal(Node.name) then
		ReplaceWithDotV(Node, Node.name)
		return
	end

	if Node.type == "AssignmentStatement" then
		for i, Var in ipairs(Node.variables) do
			if Var.type == "Identifier" and Var.isLocal and IsProxifiedLocal(Var.name) then
				ReplaceWithDotV(Var, Var.name)
			elseif Var.type == "IndexExpression" or Var.type == "MemberExpression" then
				WalkLHSBase(Var)
			else
				WalkProxify(Var)
			end
		end
		for _, Init in ipairs(Node.init) do
			WalkProxify(Init)
		end
		return
	end

	for _, Child in ipairs(Node) do
		if IsNode(Child) then
			WalkProxify(Child)
		elseif type(Child) == "table" then
			WalkProxify(Child)
		end
	end
	for Field, Value in next, Node do
		if type(Field) == "string" then
			if (Node.type == "MapValue" or Node.type == "TableKeyString") and Field == "key" then
				continue
			end
			if Node.type == "MemberExpression" and Field == "identifier" then
				continue
			end
			if IsNode(Value) then
				WalkProxify(Value)
			elseif type(Value) == "table" then
				WalkProxify(Value)
			end
		end
	end
end

function ProxifyLocals:apply(ast)
	PushScope()
	WalkProxify(ast)
	PopScope()
	return ast
end

return ProxifyLocals
