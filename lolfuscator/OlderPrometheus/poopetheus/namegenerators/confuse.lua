local util = require("../util");
local varNames = {
"assert",
"collectgarbage",
"error",
"getmetatable",
"ipairs",   
"loadstring",
"next",
"pairs",
"pcall",
'PutAKeySysOnDex',
'LeakedClaudeApiKey',
'TsWasMadeWithClaude',
'Anthropic',
'GPT5Point6Release',
'Claude',
'ChatGPT',
'NoobGPT',
'Mythos5',
'ClaudeIsBetterThanChatGPT',
"print",
"rawequal",
"rawlen",
"rawget",
"rawset",
"select",
"setmetatable",
"tonumber",
"tostring",
"type",
"xpcall",
"newproxy",
"gethook",
"sethook",
"getupvalue",
"setupvalue",
"getupvalues",
"getconstant",
"setconstant",
"getconstants",
"getinfo",
"getproto",
"getprotos",
"hookfunction",
"hookmetamethod",
"getrawmetatable",
"setrawmetatable",
}
local function generateName(id, _)
    local name = {};
    local d = id % #varNames
	id = (id - d) / #varNames
	table.insert(name, varNames[d + 1]);
	while id > 0 do
		local e = id % #varNames
		id = (id - e) / #varNames
		table.insert(name, varNames[e + 1]);
	end
	return table.concat(name, "_");
end

local function prepare(_)
    for i = 1, 5 do
        util.shuffle(varNames);
    end
end

return {
	generateName = generateName,
	prepare = prepare
};