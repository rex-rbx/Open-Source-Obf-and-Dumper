local DatabaseHandler = {}

local FileHandler = require("./Modules/FileHandler")
local Config = require("./Modules/Config")

local Database = FileHandler:GetFile("Data/Obfuscated.db")

function DatabaseHandler:GetDatabase()
    return Database
end

function DatabaseHandler:GetItem(Key: string)
    return Database[Key]
end

function DatabaseHandler:AddItem(Key: string, Value: any)
    Database[Key] = Value
end

function DatabaseHandler:SetItem(Key: string, Value: any)
    Database[Key] = Value
end

function DatabaseHandler:HasItem(Key: string)
    return Database[Key] ~= nil
end

return DatabaseHandler