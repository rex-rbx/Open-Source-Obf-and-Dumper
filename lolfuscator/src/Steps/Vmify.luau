local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Parser      = ModuleHandler:GetModule("Parser")
local Config      = ModuleHandler:GetModule("Config")
local Logger      = ModuleHandler:GetModule("Logger")
local VmCompiler  = ModuleHandler:GetModule("VmCompiler")

local Vmify = StepHandler:AddStep("Vmify")

-- Buffer of extra statements to splice into proto 0 before compilation.
Vmify.InjectedStatements = {}

-- Build a registry of available macros from Config.json (DeveloperSettings.Macros.MacroList).
-- Recorded onto pipeline.Macros as { Available = set, Used = map }.
local function BuildMacroRegistry(pipeline)
	local MacroList = pipeline.Config.DeveloperSettings.Macros.MacroList
	local Available = {}
	
	for Name in pairs(MacroList) do
		Available[Name] = true
	end
	pipeline.Macros.Available = Available

	-- Detect which macros are actually referenced in comments.
	local Used = {}
	local comments = pipeline.Ast and pipeline.Ast.comments or {}
	
	for _, comment in ipairs(comments) do
		local Text = comment.value or comment.raw or ""
		for Name in string.gmatch(Text, "@(%w+)") do
			if Available[Name] then
				Used[Name] = true
			end
		end
	end
	
	pipeline.Macros.Used = Used
	return Available, Used
end

-- Inject raw source code so it executes inside the VM (proto 0).
-- Defaults to running BEFORE the user's own logic. Order controls latency; pass last=true to append after.
function Vmify:inject(Code: string, last: boolean?)
	if Code == nil or Code == "" then
		return
	end
	
	local Parsed = Parser:Parse(Code)
	local Body = Parsed.body
	local Target = self.InjectedStatements
	
	if last then
		for _, statement in ipairs(Body) do
			table.insert(Target, statement)
		end
	else
		for _, statement in ipairs(Body) do
			table.insert(Target, 1, statement)
		end
	end
end

function Vmify:apply(ast, pipeline)
	pipeline.Ast = ast
	BuildMacroRegistry(pipeline)

	-- Splice injected statements at the head of the chunk so they execute first inside proto 0.
	if #self.InjectedStatements > 0 then
		local NewBody = {}
		
		for _, statement in ipairs(self.InjectedStatements) do
			table.insert(NewBody, statement)
		end
		
		for _, statement in ipairs(ast.body) do
			table.insert(NewBody, statement)
		end
		
		ast.body = NewBody
		self.InjectedStatements = {}
	end

	if pipeline.Config.Debug.TempFiles then
		local FileSystem = require("@lune/fs")
		local Serde = require("@lune/serde")
		FileSystem.writeFile("src/Temp/TempVmifyAst.json", Serde.encode("json", ast, true))
	end
	
	local OutputSource = VmCompiler.CompileChunk(ast)
	require("@lune/fs").writeFile("src/Temp/CrashOutput.luau", OutputSource)
	local NewAst = Parser:Parse(OutputSource)

	-- Replace the chunk in-place: keep globals fresh from the parsed runtime, but preserve old comments (like watermarks)
	ast.body = NewAst.body
	ast.globals = NewAst.globals
	
	if ast.comments then
		for _, comment in ipairs(NewAst.comments or {}) do
			table.insert(ast.comments, comment)
		end
	else
		ast.comments = NewAst.comments
	end

	return ast
end

return Vmify