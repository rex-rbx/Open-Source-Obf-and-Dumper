local SecureEq = function(a, b)
	return ({
		[a] = false,
		[b] = true,
	})[a]
end
local NilCallSuccess, NilCallResult = pcall(function()
	return (nil)()
end)
local NIdxSuccess, NIdxResult = pcall(function()
	({})[nil] = nil
end)
local ArgFuckerySuccess, ArgFuckeryResult = pcall(function()
	(...)[...] = ...
end)
if NilCallSuccess then
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end
if NIdxSuccess then
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end
if ArgFuckerySuccess then
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end

local function MustEqOrCrash(NP_210, ...)
	local ID_210 = {
		...,
	}
	for ID_212 = 1, select("#", ...) do
		if NP_210 == ID_210[ID_212] then
			return true
		end
	end
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end

local function RunAntiBeautifyChecks(ErrorStr)
	local Smatch = string.match(ErrorStr, ":(%d+)[:\r\n]")
	local Gmatch = string.gmatch(ErrorStr, ":(%d+)[:\r\n]")()
	local Gsub = nil
	local SfindStart, SfindEnd = string.find(ErrorStr, ":(%d+)[:\r\n]")
	if not SfindStart then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	if not SfindEnd then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	local Ssub = string.sub(ErrorStr, SfindStart + 1, SfindEnd - 1)
	local Scharbytesub = string.char(string.byte(ErrorStr, SfindStart + 1, SfindEnd - 1))
	string.gsub(ErrorStr, ":(%d+)[:\r\n]", function(ErrorLineNo)
		Gsub = ErrorLineNo
	end)
	if not Smatch then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	if not Gmatch then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	if not Ssub then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	if not Scharbytesub then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	if not Gsub then
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end
	MustEqOrCrash(Smatch, Gmatch)
	MustEqOrCrash(Gmatch, Ssub)
	MustEqOrCrash(Ssub, Scharbytesub)
	MustEqOrCrash(Scharbytesub, Gsub)
	MustEqOrCrash(Smatch, Gmatch)
	MustEqOrCrash(Gmatch, Ssub)
	MustEqOrCrash(Ssub, Scharbytesub)
	MustEqOrCrash(Scharbytesub, Gsub)
	return Smatch
end
local SmatchRfa = RunAntiBeautifyChecks(RfaResult)
local SmatchNIdx = RunAntiBeautifyChecks(NIdxResult)
local SmatchArgFuckery = RunAntiBeautifyChecks(ArgFuckeryResult)
MustEqOrCrash(SmatchRfa, SmatchNIdx)
MustEqOrCrash(SmatchNIdx, SmatchArgFuckery)
MustEqOrCrash(SmatchArgFuckery, SmatchRfa)
MustEqOrCrash(SmatchArgFuckery, SmatchNIdx)
local ReturnItself = function(...)
	return ...
end
local TrapMt = {
	["__tostring"] = function()
		("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
		return (nil)()
	end,
	["__call"] = ReturnItself,
	["__add"] = ReturnItself,
	["__sub"] = ReturnItself,
	["__mul"] = ReturnItself,
	["__div"] = ReturnItself,
	["__mod"] = ReturnItself,
	["__pow"] = ReturnItself,
	["__eq"] = ReturnItself,
	["__lt"] = ReturnItself,
	["__le"] = ReturnItself,
	["__concat"] = ReturnItself,
	["__index"] = ReturnItself,
	["__newindex"] = ReturnItself,
	["__metatable"] = false,
}
local TrapTable = setmetatable({}, TrapMt)
MustEqOrCrash(SecureEq(TrapTable, TrapTable(TrapTable, TrapTable, TrapTable(TrapTable), TrapTable())), true)
MustEqOrCrash(SecureEq(TrapTable, TrapTable(TrapTable .. TrapTable, TrapTable .. "", "" .. TrapTable)), true)
MustEqOrCrash(SecureEq(TrapTable, TrapTable + TrapTable - TrapTable * TrapTable / TrapTable % TrapTable ^ TrapTable), true)
MustEqOrCrash(
	SecureEq(TrapTable, TrapTable(TrapTable, TrapTable, TrapTable(), TrapTable(TrapTable), TrapTable(TrapTable, TrapTable))),
	true
)
TrapTable[TrapTable] = MustEqOrCrash(SecureEq(TrapTable, TrapTable), true)
TrapTable[TrapTable] = MustEqOrCrash(SecureEq(TrapTable[TrapTable], TrapTable), true)
MustEqOrCrash(
	SecureEq(
		TrapTable,
		(function(...)
	return ..., TrapTable
end)(TrapTable, TrapTable)
	),
	true
)
TrapTable[""] = TrapTable[""]
TrapMt["__tostring"] = nil
if math.nan == math.nan then
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end;
if not SecureEq(({})[game], nil) then
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end;
local a1, a2 = {
	1
}, {
	2
}
local Sub = ("").sub;
if SecureEq(Sub(tostring(a1), 8, 15), Sub(tostring(a2), 8, 15)) then
	("sigma"):rep(20000):match(".*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*");
	return (nil)()
end