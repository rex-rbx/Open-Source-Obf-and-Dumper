--discord.gg/boronide, code generated using luamin.js™




local Step = require("../step");
local Compiler = require("../compiler/compiler");
local Vmify = Step:extend();
Vmify.Description = "This will compile your script into a state machine.";
Vmify.Name = "Vmify";
Vmify.SettingsDescriptor = {
}
function Vmify:init(settings)
end
function Vmify:apply(ast)
	local compiler = Compiler:new();
	return compiler:compile(ast);
end
return Vmify;