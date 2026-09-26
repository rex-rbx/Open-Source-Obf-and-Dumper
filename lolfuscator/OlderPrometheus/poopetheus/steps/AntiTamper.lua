local Step = require("../step");
local Parser = require("../parser");
local Enums = require("../enums");
local logger = require("../../logger");
local AntiTamper = Step:extend();
AntiTamper.Description = "This will crash when modified. Only works on LuaU in Roblox.";
AntiTamper.Name = "Anti Tamper";
AntiTamper.SettingsDescriptor = {
}
function AntiTamper:init(settings)
end
function AntiTamper:apply(ast, pipeline)
	if pipeline.PrettyPrint then
		logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
		return ast;
	end
	local code = [[
		do
			pcall(string.find, true, true)
			if math.nan == math.nan then
				local t = {}
				while true do
					t[#t+1] = (" "):rep(20000):find((".*"):rep(20000))
				end
				return (nil)()
			end
			if ({})[game] ~= nil then
				local t = {}
				while true do
					t[#t+1] = (" "):rep(20000):find((".*"):rep(20000))
				end
				return (nil)()
			end
			local Sub = ("").sub
			local A1, A2 = {1}, {2}
			if Sub(tostring(A1), 8, 15) == Sub(tostring(A2), 8, 15) then
				local t = {}
				while true do
					t[#t+1] = (" "):rep(20000):find((".*"):rep(20000))
				end
				return (nil)()
			end
			Sub = nil
			A1 = nil
			A2 = nil
		end
	]];
	local parsed = Parser:new({
		LuaVersion = Enums.LuaVersion.Lua51
	}):parse(code);
	local doStat = parsed.body.statements[1];
	doStat.body.scope:setParent(ast.body.scope);
	table.insert(ast.body.statements, 1, doStat);
	return ast;
end
return AntiTamper;