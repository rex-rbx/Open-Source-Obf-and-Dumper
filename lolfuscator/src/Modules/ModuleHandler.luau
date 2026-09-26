local ModuleHandler = {}

local Modules = {}

function ModuleHandler:AddModule(Name)
	local Module = { Name = Name }
	Modules[Name] = Module
	return Module
end

function ModuleHandler:GetModule(Name)
	return Modules[Name]
end

function ModuleHandler:GetModules()
	return Modules
end

return ModuleHandler
