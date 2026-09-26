local ModuleHandler = require("../Modules/ModuleHandler")
local StepHandler = ModuleHandler:GetModule("StepHandler")

local ConstantArray = StepHandler:AddStep("ConstantArray")

local function IsNode(Value)
    return type(Value) == "table" and type(Value.type) == "string"
end

local function DeepCopy(Node)
    if type(Node) ~= "table" then
        return Node
    end
    local Copy = {}
    for Key, Value in next, Node do
        Copy[Key] = DeepCopy(Value)
    end
    return Copy
end

local function IsGlobalBase(Node)
    if Node.type == "Identifier" then
        return Node.isLocal == false
    end
    if Node.type == "CallExpression" and Node.base and Node.base.type == "Identifier" then
        return Node.base.isLocal == false
    end
    return false
end

local function BaseGlobalName(Node)
    if Node.type == "Identifier" then
        return Node.name
    end
    if Node.type == "CallExpression" and Node.base and Node.base.type == "Identifier" then
        return Node.base.name
    end
    return nil
end

local function MemberKey(Node)
    local baseName = BaseGlobalName(Node.base)
    if not baseName then
        return nil
    end
    return baseName .. "." .. Node.identifier.name
end

function ConstantArray:apply(ast, pipeline)
    local Collected = {}
    local IndexByKey = {}
    local Nodes = {}

    local function Visit(Node)
        if
            Node.type == "MemberExpression"
            and IsGlobalBase(Node.base)
        then
            local Key = MemberKey(Node)
            if Key then
                if not IndexByKey[Key] then
                    IndexByKey[Key] = #Collected + 1
                    Collected[IndexByKey[Key]] = Node
                end
                table.insert(Nodes, Node)
            end
        end
    end

    local function Walk(Node)
        for _, Child in ipairs(Node) do
            if IsNode(Child) then
                Visit(Child)
                Walk(Child)
            elseif type(Child) == "table" then
                Walk(Child)
            end
        end
        for Field, Value in next, Node do
            if type(Field) == "string" then
                if IsNode(Value) then
                    Visit(Value)
                    Walk(Value)
                elseif type(Value) == "table" then
                    Walk(Value)
                end
            end
        end
    end

    Walk(ast)

    if #Collected == 0 then
        return ast
    end

    local SeenGlobals = {}
    for _, G in ipairs(ast.globals) do
        SeenGlobals[G.name] = true
    end

    local Entries = {}
    for Index, OrigNode in ipairs(Collected) do
        Entries[Index] = {
            type = "TableValue",
            value = DeepCopy(OrigNode),
        }

        local BaseName = BaseGlobalName(OrigNode.base)
        if BaseName and not SeenGlobals[BaseName] then
            SeenGlobals[BaseName] = true
            table.insert(ast.globals, { type = "Identifier", name = BaseName, isLocal = false })
        end
    end

    for _, Node in ipairs(Nodes) do
        local Key = MemberKey(Node)
        local Id = IndexByKey[Key]
        for Field in next, Node do
            Node[Field] = nil
        end
        Node.type = "IndexExpression"
        Node.base = { type = "Identifier", name = "Globals", isLocal = true }
        Node.index = { type = "NumericLiteral", value = Id, raw = tostring(Id) }
        Node.indexer = "["
    end

    local GlobalsDecl = {
        type = "LocalStatement",
        variables = { { type = "Identifier", name = "Globals", isLocal = true } },
        init = {
            {
                type = "TableConstructorExpression",
                fields = Entries,
            },
        },
    }

    table.insert(ast.body, 1, GlobalsDecl)

    pipeline.Tables = pipeline.Tables or {}
    table.insert(pipeline.Tables, 1, "Globals")

    return ast
end

return ConstantArray