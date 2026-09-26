local ModuleHandler = require("./ModuleHandler")

local Parser = ModuleHandler:AddModule("Parser")

local Process = require("@lune/process")
local Net = require("@lune/net")
local Serde = require("@lune/serde")

local BridgePath do
	local ModulePath = debug.info(1, "s")
	local ModuleDir = ModulePath:match("^(.*)[/\\]") or ""
	local SrcDir = ModuleDir:match("^(.*)[/\\]") or ""
	BridgePath = (SrcDir ~= "" and SrcDir .. "/" or "") .. "Ast/ast_bridge.js"
end

local SERVER_PORT = 41337
local SERVER_URL = "http://127.0.0.1:" .. SERVER_PORT
local ServerProcess = nil
local ServerReady = false

local function StartServer()
	if ServerProcess then return end
	ServerProcess = Process.create("node", { BridgePath, "--server" })
end

local function PingServer()
	local Ok, _ = pcall(function()
		Net.request({
			url = SERVER_URL,
			method = "POST",
			headers = { ["Content-Type"] = "application/json" },
			body = '{"mode":"ping"}',
		})
	end)
	return Ok
end

local function EnsureServer()
	if ServerReady then return true end

	StartServer()

	for _ = 1, 100 do
		if PingServer() then
			ServerReady = true
			return true
		end
	end

	local Logger = ModuleHandler:GetModule("Logger")
	Logger:Error("ast_bridge server failed to start")
	return false
end

function Parser.EnsureServer()
	return EnsureServer()
end

EnsureServer()

local function CallBridge(Payload: string): string
	EnsureServer()

	local Response = Net.request({
		url = SERVER_URL,
		method = "POST",
		headers = { ["Content-Type"] = "application/json" },
		body = Payload,
	})

	return Response.body or "{}"
end

function Parser:Parse(Source: string): table
	local Logger = ModuleHandler:GetModule("Logger")
	local Timing = ModuleHandler:GetModule("Timing")
	local Script = debug.info(2, "s") .. "Parser"
	Timing:Start(Script, true)
	local Payload = Serde.encode("json", { mode = "parse", src = Source, locations = true })
	local Out = CallBridge(Payload)
	local Decoded = Serde.decode("json", Out)

	if not Decoded.ok then
		Timing:Stop(Script)
		error("Parser:Parse failed: " .. tostring(Decoded.err))
	end

	Timing:Stop(Script)

	return Decoded.ast
end

function Parser:ToSource(Ast: table, Minify: boolean?): string
	local Logger = ModuleHandler:GetModule("Logger")
	local Timing = ModuleHandler:GetModule("Timing")
	if Minify == nil then Minify = true end
	local Payload = Serde.encode("json", { mode = "render", ast = Ast, minify = Minify })
	Timing:Start("Minifer", true)
	local Out = CallBridge(Payload)
	Timing:Stop("Minifer")
	local Decoded = Serde.decode("json", Out)

	if not Decoded.ok then
		Timing:Stop("Minifer")
		error("Parser:ToSource failed: " .. tostring(Decoded.err))
	end

	return Decoded.src
end

return Parser
