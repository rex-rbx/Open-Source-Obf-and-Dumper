local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")
local Parser = ModuleHandler:GetModule("Parser")

local EncryptStrings = StepHandler:AddStep("EncryptStrings")

-- Slightly better for performance
local Floor = math.floor
local Byte = string.byte
local Char = string.char
local Repeat = string.rep

local Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz}~!#$%&()*+,-./:;<>?@^_"
local ByteMap = {}
for Index = 1, 85 do
    ByteMap[Index - 1] = Byte(Alphabet, Index)
end

-- "Hello, World!" takes 985 Nano Seconds to Enocde
local function Encode85(Str: string): (string, number)
    local Pad = (4 - #Str % 4) % 4
    local Padded = Str .. Repeat("\0", Pad)
    local Result = {}
    for I = 1, #Padded, 4 do
        local B1, B2, B3, B4 = Byte(Padded, I, I + 3)
        local Num = B1 * 16777216 + B2 * 65536 + B3 * 256 + B4
        
        Result[#Result + 1] = Char(
            ByteMap[Floor(Num / 52200625) % 85],
            ByteMap[Floor(Num / 614125) % 85],
            ByteMap[Floor(Num / 7225) % 85],
            ByteMap[Floor(Num / 85) % 85],
            ByteMap[Num % 85]
        )
    end
    return table.concat(Result), #Str
end

-- Generate timing report
-- Im lead to believe this is quite slow, althought im not sure.
local DecoderSource = [=[
local Base85Alphabet = "]=] .. Alphabet .. [=["
local function Decode85(EncodedString, OriginalLength)
    local AlphabetBuffer = buffer.fromstring(Base85Alphabet)
    local LookupTable = table.create(256, 0)
    for Index = 0, 84 do 
        LookupTable[buffer.readu8(AlphabetBuffer, Index)] = Index 
    end
    
    local Result = {}
    local Floor = math.floor
    local Byte = string.byte
    local Char = string.char
    for Index = 1, #EncodedString, 5 do
        local B1, B2, B3, B4, B5 = Byte(EncodedString, Index, Index + 4)
        local Value = LookupTable[B1] * 52200625 +
                      LookupTable[B2] * 614125 +
                      LookupTable[B3] * 7225 +
                      LookupTable[B4] * 85 +
                      LookupTable[B5]
                      
        Result[#Result + 1] = Char(
            Floor(Value / 16777216) % 256,
            Floor(Value / 65536) % 256,
            Floor(Value / 256) % 256,
            Value % 256
        )
    end
    
    local DecodedString = table.concat(Result)
    return OriginalLength and string.sub(DecodedString, 1, OriginalLength) or DecodedString
end
]=]

local function IsNode(Value)
    return type(Value) == "table" and type(Value.type) == "string"
end

local function WalkChildren(Node, Visit, Parent, Key)
    for Index, Child in ipairs(Node) do
        if IsNode(Child) then
            Visit(Child, Node, Index)
            WalkChildren(Child, Visit, Node, Index)
        elseif type(Child) == "table" then
            WalkChildren(Child, Visit, Node, Index)
        end
    end
    for Field, Value in next, Node do
        if type(Field) == "string" then
            if IsNode(Value) then
                Visit(Value, Node, Field)
                WalkChildren(Value, Visit, Node, Field)
            elseif type(Value) == "table" then
                WalkChildren(Value, Visit, Node, Field)
            end
        end
    end
end

local function MakeDecodeCall(Encoded: string, Length: number)
    return {
        type = "CallExpression",
        base = { type = "Identifier", name = "Decode85", isLocal = true },
        arguments = {
            { type = "StringLiteral", value = Encoded, raw = '"' .. Encoded .. '"' },
            { type = "NumericLiteral", value = Length, raw = tostring(Length) },
        },
    }
end

EncryptStrings.Collected = {}
EncryptStrings.Seen = {}

function EncryptStrings:RegisterString(StrValue)
    local Id = self.Seen[StrValue]
    if not Id then
        Id = #self.Collected + 1
        self.Collected[Id] = StrValue
        self.Seen[StrValue] = Id
    end
    return Id
end

function EncryptStrings:apply(ast, pipeline)
    if pipeline.Config.Steps.Vmify and pipeline.Config.Steps.Vmify.Enabled then
        return ast
    end

    local function Encrypt(Node)
        local Id = self:RegisterString(Node.value)
        for Key in next, Node do
            Node[Key] = nil
        end
        Node.type = "IndexExpression"
        Node.base = { type = "Identifier", name = "Strings", isLocal = true }
        Node.index = { type = "NumericLiteral", value = Id, raw = tostring(Id) }
        Node.indexer = "["
    end

    WalkChildren(ast, function(Node, Parent, Key)
        if Node.type ~= "StringLiteral" then
            return
        end

        if Parent.type == "StringCallExpression" and Key == "argument" then
            Parent.type = "CallExpression"
            Parent.arguments = { Node }
            Parent.argument = nil
        end

        if Parent.type == "MemberCallExpression" and Key == "argument" then
            Parent.type = "CallExpression"
            Parent.arguments = { Node }
            Parent.argument = nil
        end

            Encrypt(Node)
        end)

    if #self.Collected == 0 then
        return ast
    end

	if not EncryptStrings.CachedDecoderAst then
		EncryptStrings.CachedDecoderAst = Parser:Parse(DecoderSource)
	end
	local DecoderAst = EncryptStrings.CachedDecoderAst

	for _, G in ipairs(DecoderAst.globals) do
        local Found = false
        for _, Existing in ipairs(ast.globals) do
            if Existing.name == G.name then
                Found = true
                break
            end
        end
        if not Found then
            table.insert(ast.globals, G)
        end
    end

    local DecoderCount = #DecoderAst.body
    for I = #DecoderAst.body, 1, -1 do
        table.insert(ast.body, 1, DecoderAst.body[I])
    end

    local Entries = {}
    for _, StringValue in ipairs(self.Collected) do
        local Encoded, Length = Encode85(StringValue)
        Entries[#Entries + 1] = {
            type = "TableValue",
            value = MakeDecodeCall(Encoded, Length),
        }
    end

    local StringsDecl = {
        type = "LocalStatement",
        variables = { { type = "Identifier", name = "Strings", isLocal = true } },
        init = {
            {
                type = "TableConstructorExpression",
                fields = Entries,
            },
        },
    }

    table.insert(ast.body, DecoderCount + 1, StringsDecl)

    table.insert(pipeline.Tables, "Decode85")
    table.insert(pipeline.Tables, "Strings")

    return ast
end

EncryptStrings.Encode85 = Encode85
EncryptStrings.DecoderSource = DecoderSource
EncryptStrings.Alphabet = Alphabet

return EncryptStrings