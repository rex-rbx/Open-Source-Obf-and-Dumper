return {Lua51 = function (bytecode)
    if typeof(bytecode) ~= "buffer" then
        return false, "bytecode must be a buffer"
    end
    local A, B, C, D = buffer.readstring(bytecode, 0, 4):byte(1, 4)
    if A >= 3 and A <= 11 and (B >= 1 and B <= 3) and C <= 255 and D == 1 then
    end
    if buffer.len(bytecode) < 12 then
        return false, "File too small for Lua 5.1 header (needs 12 bytes)"
    end
    local magic = buffer.readstring(bytecode, 0, 4)
    if magic ~= "\x1B\x4C\x75\x61" then
        return false, "Invalid Lua magic bytes"
    end
    local version = buffer.readu8(bytecode, 4)
    if version ~= 0x51 then
        return false, string.format("Invalid version (expected 0x51 for Lua 5.1, got 0x%02X)", version)
    end
    local format = buffer.readu8(bytecode, 5)
    if format ~= 0 then
        return false, string.format("Invalid format (expected 0x00, got 0x%02X)", format)
    end
    local endianness = buffer.readu8(bytecode, 6)
    if endianness ~= 1 and endianness ~= 0 then
        return false, string.format("Invalid endianness (expected 0 or 1, got %d)", endianness)
    end
    local intSize = buffer.readu8(bytecode, 7)
    if intSize ~= 4 and intSize ~= 8 then
        return false, string.format("Invalid int size (expected 4 or 8, got %d)", intSize)
    end
    local sizeTSize = buffer.readu8(bytecode, 8)
    if sizeTSize ~= 4 and sizeTSize ~= 8 then
        return false, string.format("Invalid size_t size (expected 4 or 8, got %d)", sizeTSize)
    end
    local insSize = buffer.readu8(bytecode, 9)
    if insSize ~= 4 then
        return false, string.format("Invalid instruction size (expected 4 for Lua 5.1, got %d)", insSize)
    end
    local numberSize = buffer.readu8(bytecode, 10)
    if numberSize ~= 8 and numberSize ~= 4 then
        return false, string.format("Invalid number size (expected 4 or 8, got %d)", numberSize)
    end
    local integralFlag = buffer.readu8(bytecode, 11)
    if integralFlag ~= 0 and integralFlag ~= 1 then
        return false, string.format("Invalid integral flag (expected 0 or 1, got %d)", integralFlag)
    end
    return true, string.format("Valid Lua 5.1 bytecode (int: %d, size_t: %d, number: %d, %s)",
        intSize, sizeTSize, numberSize,
        integralFlag == 0 and "float" or "integer")
end, LuaU = function(bytecode)
    if typeof(bytecode) ~= "buffer" then
        return false, "bytecode must be a buffer"
    end
    
    if buffer.len(bytecode) < 2 then
        return false, "File too small for Luau header"
    end
    
    local version = buffer.readu8(bytecode, 0)
    local typeVersion = buffer.readu8(bytecode, 1)
    
    if version < 3 or version > 11 then
        return false, string.format("Invalid Luau bytecode version: %d (expected 3-11)", version)
    end
    
    if typeVersion < 1 or typeVersion > 3 then
        return false, string.format("Invalid type encoding version: %d (expected 1-3)", typeVersion)
    end
    
    return true, string.format("Valid Luau bytecode (version: %d, type version: %d)", version, typeVersion)
end
}