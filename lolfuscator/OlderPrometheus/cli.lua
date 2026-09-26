local luau = require("@lute/luau")
local loadstring = function(str, chunkName)
	return luau.load(luau.compile(str), chunkName)
end
local fs = require("@std/fs")
local process = require("@lute/process")
local seed = 0
local handle = process.run({
	'openssl',
	'rand',
	'-hex',
	'4'
})
if handle and handle.ok and handle.exitcode == 0 then
	seed = tonumber(handle.stdout, 16)
else
	seed = os.time() * math.random()
end
math.randomseed(seed)
local arg = table.clone(process.args)
table.remove(arg, 1)
local Poopetheus = require("./poopetheushld");
Poopetheus.Pipeline.DefaultSettings.Seed = seed;
Poopetheus.Logger.logLevel = Poopetheus.Logger.LogLevel.Info;
local file_exists = fs.exists
local config;
local sourceFile;
local outFile;
local luaVersion;
local prettyPrint;
Poopetheus.colors.enabled = true;
local i = 1;
while i <= #arg do
	local curr = arg[i];
	if curr:sub(1, 2) == "--" then
		if curr == "--preset" or curr == "--p" then
			if config then
				Poopetheus.Logger:warn("The config was set multiple times");
			end
			i = i + 1;
			local preset = Poopetheus.Presets[arg[i]];
			if not preset then
				Poopetheus.Logger:error(string.format("A Preset with the name \"%s\" was not found!", tostring(arg[i])));
			end
			config = preset;
		elseif curr == "--config" or curr == "--c" then
			i = i + 1;
			local filename = tostring(arg[i]);
			if not file_exists(filename) then
				Poopetheus.Logger:error(string.format("The config file \"%s\" was not found!", filename));
			end
			local content = fs.readFileToString(filename);
			local func = loadstring(content, filename);
			config = func();
		elseif curr == "--out" or curr == "--o" then
			i = i + 1;
			if (outFile) then
				Poopetheus.Logger:warn("The output file was specified multiple times!");
			end
			outFile = arg[i];
		elseif curr == "--nocolors" then
			Poopetheus.colors.enabled = false;
		elseif curr == "--Lua51" then
			luaVersion = "Lua51";
		elseif curr == "--pretty" then
			prettyPrint = true;
		elseif curr == "--saveerrors" then
			Poopetheus.Logger.errorCallback =  function(...)
				print(Poopetheus.colors(Poopetheus.Config.NameUpper .. ": " .. ..., "red"))
				local args = {
					...
				};
				local message = table.concat(args, " ");
				local fileName = sourceFile:sub(-4) == ".lua" and sourceFile:sub(0, -5) .. ".error.txt" or sourceFile .. ".error.txt";
				fs.writeStringToFile(fileName, message);
			end;
		else
			Poopetheus.Logger:warn(string.format("The option \"%s\" is not valid and therefore ignored", curr));
		end
	else
		if sourceFile then
			Poopetheus.Logger:error(string.format("Unexpected argument \"%s\"", arg[i]));
		end
		sourceFile = tostring(arg[i]);
	end
	i = i + 1;
end
if not sourceFile then
	Poopetheus.Logger:error("No input file was specified!")
end
if not config then
	Poopetheus.Logger:warn("No config was specified, falling back to Strong LuaU preset");
	config = Poopetheus.Presets.Strong;
end
config.LuaVersion = luaVersion or "LuaU";
config.PrettyPrint = prettyPrint ~= nil and prettyPrint or config.PrettyPrint;
if not file_exists(sourceFile) then
	Poopetheus.Logger:error(string.format("The File \"%s\" was not found!", sourceFile));
end
if not outFile then
	if sourceFile:sub(-4) == ".lua" then
		outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua";
	else
		outFile = sourceFile .. ".obfuscated.lua";
	end
end
local source = fs.readFileToString(sourceFile)
local pipeline = Poopetheus.Pipeline:fromConfig(config);
local out = pipeline:apply(source, sourceFile);
Poopetheus.Logger:info(string.format("Writing output to \"%s\"", outFile));
fs.writeStringToFile(outFile, out);