local ModuleHandler = require("./ModuleHandler")

local FileHandler = ModuleHandler:AddModule("FileHandler")

local Fs = require("@lune/fs")
local Luau = require("@lune/luau")

function FileHandler:GetFileName(Path: string, ExcludeExtension: boolean): string
    local FileName = Path:match("([^/\\]+)$") or Path

    if ExcludeExtension then
        FileName = FileName:match("^(.+)%.[^%.]*$")
    end

    return FileName
end

function FileHandler:GetFile(Path: string)
    local ModulePath = debug.info(1, "s")
    local ModuleDir = ModulePath:match("^(.*)[/\\]") or ""
    local SrcDir = ModuleDir:match("^(.*)[/\\]") or ""
    return require(SrcDir .. "/" .. Path)
end

function FileHandler:RunFile(File)
    local Source = Fs.readFile(File)
    local Chunk = Luau.load(Source, File)

    return Chunk
end

function FileHandler:MakeFile(File: string, Content)
    -- Fs.writeFile(File, Content)
end

return FileHandler
