local ModuleHandler = require("./ModuleHandler")

local Config = ModuleHandler:AddModule("Config")

local Fs = require("@lune/fs")
local Serde = require("@lune/serde")

local Configs = Serde.decode("json", Fs.readFile("./src/Data/Config.json"))
local UserConfigs = Serde.decode("json", Fs.readFile("./src/Data/UserConfigs.json"))

function Config:Get(key)
    local Current = Configs
    for Part in string.gmatch(key, "[^/]+") do
        if type(Current) ~= "table" then
            return nil
        end
        Current = Current[Part]
    end
    return Current
end

function Config:GetConfig(Id)
	Id = tostring(Id)
	if Id == "Default" then
		return Configs
	end
	local userConfig = UserConfigs[Id]
	if userConfig == nil then
		return Configs
	end
	local merged = {}
	for k, v in pairs(Configs) do
		merged[k] = v
	end
	for k, v in pairs(userConfig) do
		merged[k] = v
	end
	return merged
end

return Config
