local EnableAmbience = true
local SpoofColor = Color3.new(1, 1, 1)

local Lighting = game:GetService("Lighting")
	-- Lighting does not need to be clonerefed because: Find out later brah
local Ambience = Lighting.Ambient

local OldIndex
OldIndex = hookmetamethod(game, "__index", newcclosure(function(Object, Property)
    if not EnableAmbience then
        return OldIndex(Object, Property)
    end

    if Object == Lighting and Property == "Ambient" then
        return Ambience
    end

    return OldIndex(Object, Property)
end))

Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
    local Current = OldIndex(Lighting, "Ambient")

    if Current ~= SpoofColor then
        Ambience = Current
    end
end)

Lighting.Ambient = SpoofColor

-- print(Lighting.Ambient)
	-- Returns the original game value