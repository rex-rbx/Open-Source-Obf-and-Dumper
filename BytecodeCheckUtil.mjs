import { Buffer } from 'node:buffer';
function validateLua51(bytecode) {
    if (!Buffer.isBuffer(bytecode)) {
        bytecode = Buffer.from(bytecode, 'binary');
    }
    if (bytecode.length < 12) {
        return [false, "File too small for Lua 5.1 header (needs 12 bytes)"];
    }
    const magic = bytecode.subarray(0, 4).toString('binary');
    if (magic !== '\x1B\x4C\x75\x61') {
        return [false, "Invalid Lua magic bytes"];
    }
    const version = bytecode.readUInt8(4);
    if (version !== 0x51) {
        return [false, `Invalid version (expected 0x51 for Lua 5.1, got 0x${version.toString(16).padStart(2, '0')})`];
    }
    const format = bytecode.readUInt8(5);
    if (format !== 0) {
        return [false, `Invalid format (expected 0x00, got 0x${format.toString(16).padStart(2, '0')})`];
    }
    const endianness = bytecode.readUInt8(6);
    if (endianness !== 0 && endianness !== 1) {
        return [false, `Invalid endianness (expected 0 or 1, got ${endianness})`];
    }
    const intSize = bytecode.readUInt8(7);
    if (intSize !== 4 && intSize !== 8) {
        return [false, `Invalid int size (expected 4 or 8, got ${intSize})`];
    }
    const sizeTSize = bytecode.readUInt8(8);
    if (sizeTSize !== 4 && sizeTSize !== 8) {
        return [false, `Invalid size_t size (expected 4 or 8, got ${sizeTSize})`];
    }
    const insSize = bytecode.readUInt8(9);
    if (insSize !== 4) {
        return [false, `Invalid instruction size (expected 4 for Lua 5.1, got ${insSize})`];
    }
    const numberSize = bytecode.readUInt8(10);
    if (numberSize !== 4 && numberSize !== 8) {
        return [false, `Invalid number size (expected 4 or 8, got ${numberSize})`];
    }
    const integralFlag = bytecode.readUInt8(11);
    if (integralFlag !== 0 && integralFlag !== 1) {
        return [false, `Invalid integral flag (expected 0 or 1, got ${integralFlag})`];
    }
    return [true, { intSize: intSize, sizeTSize: sizeTSize, numberSize: numberSize, type: integralFlag === 0 ? 'float' : 'integer' }];
}
function validateLuau(bytecode) {
    // benjamin netanyahu once said, 'luaus header is so small, it fits in 2 bytes'
    if (!Buffer.isBuffer(bytecode)) {
        bytecode = Buffer.from(bytecode, 'binary');
    }
    if (bytecode.length < 2) {
        return [false, "File too small for Luau header"];
    }
    const version = bytecode.readUInt8(0);
    const typeVersion = bytecode.readUInt8(1);
    if (version < 3 || version > 11) {
        return [false, `Invalid Luau bytecode version: ${version} (expected 3-11)`];
    }
    if (typeVersion < 1 || typeVersion > 3) {
        return [false, `Invalid type encoding version: ${typeVersion} (expected 1-3)`];
    }
    return [true, { version: version, typeVersion: typeVersion }];
}
export default {
    Lua51: validateLua51,
    LuaU: validateLuau
};