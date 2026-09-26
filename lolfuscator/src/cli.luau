local Fs = require("@lune/fs")
local Process = require("@lune/process")
local ModuleHandler = require("./Modules/ModuleHandler")

require("./Modules/Timing")
require("./Modules/Logger")
require("./Modules/Config")
require("./Modules/FileHandler")
require("./Modules/Parser")
require("./Modules/StepHandler")
require("./Modules/VmCompiler")

local Timing = ModuleHandler:GetModule("Timing")
Timing:ResetAll()

local Logger = ModuleHandler:GetModule("Logger")
local Config = ModuleHandler:GetModule("Config")

local Obfuscator = require("./Main")

local Args = Process.args or {}

local Help, Debug = false, false
local Positional = {}
local Macros = {}
for _, Arg in ipairs(Args) do
	if Arg == "--help" then
		Help = true
	elseif Arg == "--debug" then
		Debug = true
	else
		local eq = string.find(Arg, "=", 1, true)
		if eq then
			local key = string.sub(Arg, 1, eq - 1)
			local val = string.sub(Arg, eq + 1)
			if val == "true" then
				Macros[key] = true
			elseif val == "false" then
				Macros[key] = false
			elseif tonumber(val) then
				Macros[key] = tonumber(val)
			else
				Macros[key] = val
			end
		else
			table.insert(Positional, Arg)
		end
	end
end

if Help then
    Logger:Info("Usage: obfuscator <input> <output> [userId] [--help] [--debug]")
    Logger:Info("Example: obfuscator Input.luau Output.luau 123456789 --debug")
    Process.exit(0)
end

local Input = Positional[1] or "./src/Input.luau"
local Output = Positional[2] or "./src/Temp/Output.luau"
local Id = Positional[3] or "Default"

if not Fs.isFile(Input) then
    Logger:Error("Input file not found:", Input)
    Process.exit(1)
end

if Debug and Config:Get("Debug/ConsoleOutput") == false then
    Logger:Ignore(true)
end

local Source = Fs.readFile(Input)
local UserConfig = Config:GetConfig(Id)

for key, val in pairs(Macros) do
	local dotPos = string.find(key, "%.")
	if dotPos then
		local parts = {}
		for part in string.gmatch(key, "[^%.]+") do
			table.insert(parts, part)
		end
		local current = UserConfig.Steps
		for i = 1, #parts - 1 do
			if type(current) ~= "table" then break end
			if current[parts[i]] == nil then
				current[parts[i]] = {}
			end
			current = current[parts[i]]
		end
		if type(current) == "table" then
			current[parts[#parts]] = val
		end
	else
		UserConfig[key] = val
	end
end

local Parser = ModuleHandler:GetModule("Parser")
Parser.EnsureServer()

local Result = Obfuscator.Obfuscate(Source, UserConfig)

Fs.writeFile(Output, Result)

Input = ModuleHandler:GetModule("FileHandler"):GetFileName(Input)
local EndTime = Timing:Stop("cli")

return { Output, EndTime }
