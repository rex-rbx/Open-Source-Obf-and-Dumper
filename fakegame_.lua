local wildcard
wildcard = setmetatable({}, {
    __index = function(t, k)
        return wildcard
    end,
    __newindex = function(t, k, v)
    end,
    __call = function(t, ...)
        return wildcard
    end,
    __tostring = function()
        return "wildcard"
    end
})

return {}, wildcard