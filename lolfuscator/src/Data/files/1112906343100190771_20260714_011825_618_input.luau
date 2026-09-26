local services = loadstring(game:HttpGet(
    "https://website-iota-ivory-12.vercel.app/code/loader/u/vars.lua"
))()

local _game = services["marketplace"]:GetProductInfo(game.PlaceId).Name

local Rayfield = loadstring(game:HttpGet(
    "https://website-iota-ivory-12.vercel.app/code/loader/u/ui/rayfield.lua"
))()

local lp = services["player"]
local rep = services["rep"]
local http = services["http"]

local window = Rayfield:CreateWindow({
    Name = _game,
    LoadingTitle = "fah you",
    LoadingSubtitle = "subtitle",
})

local tabs = {
    main = window:CreateTab("Main", 4483362458),
    settings = window:CreateTab("Settings", 4483362458),
}

local connections = {
    communication = {},
    table = {},
    gameplay = {},
}

local states = {
    runtime = {},

    values = {
        InTable = false,
        TableValue = nil,
        Word = nil,
        AutoSolve = false,
        Delay = 0.1,
        Model = "mistral",

        communication = Instance.new("BindableEvent"),
    },
}

local responses = {}

local function SetValue(obj, key, value)
    obj[key] = value
    states.values.communication:Fire({
        Object = obj,
        Key = key,
        Value = value,
    })
end

local function addConnection(category, name, connection)
    if category[name] then
        pcall(function()
            if typeof(category[name]) == "RBXScriptConnection" then
                category[name]:Disconnect()
            else
                task.cancel(category[name])
            end
        end)
    end

    category[name] = connection
    states.runtime[name] = true
end

local function removeConnection(category, name)
    if not category[name] then return end

    pcall(function()
        if typeof(category[name]) == "RBXScriptConnection" then
            category[name]:Disconnect()
        else
            task.cancel(category[name])
        end
    end)

    category[name] = nil
    states.runtime[name] = false
end

tabs.main:CreateLabel("Auto Hit")

tabs.main:CreateButton({
    Name = "Get Word",
    Callback = function()
        local word = getword()
        if word then setclipboard(word) end
    end,
})

tabs.main:CreateButton({
    Name = "Solve",
    Callback = function()
        local word = states.values.Word or getword()
        if word then solve(word) end
    end,
})

tabs.main:CreateToggle({
    Name = "Auto Solve",
    CurrentValue = false,
    Callback = function(value)
        SetValue(states.values, "AutoSolve", value)
    end,
})

tabs.main:CreateDropdown({
    Name = "Model",
    Options = { "mistral", "openai", "claude" },
    CurrentOption = "mistral",
    Callback = function(option)
        SetValue(states.values, "Model", option)
    end,
})

tabs.settings:CreateLabel("Settings")

tabs.settings:CreateSlider({
    Name = "Solve Delay",
    Range = { 0, 1 },
    Increment = 0.05,
    CurrentValue = 0.1,
    Callback = function(value)
        SetValue(states.values, "Delay", value)
    end,
})

tabs.settings:CreateToggle({
    Name = "Debug Mode",
    CurrentValue = false,
    Callback = function(value)
        SetValue(states.values, "Debug", value)
    end,
})

tabs.settings:CreateButton({
    Name = "Clear Response Cache",
    Callback = function()
        responses = {}
        Rayfield:Notify({
            Title = "Cache",
            Content = "Response cache cleared.",
            Duration = 3,
            Image = 4483362458,
        })
    end,
})

Rayfield:Notify({
    Title = _game,
    Content = "successfully loaded!",
    Duration = 5,
    Image = 4483362458,
})