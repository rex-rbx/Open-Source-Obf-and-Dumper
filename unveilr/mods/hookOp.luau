local parser = require("@std/syntax/parser")
local process = require("@lute/process")
local fs = require("@std/fs")
local writeStringToFile = fs.writeStringToFile
local prettyPrint = true

local function splitLines(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end

local WHILE_LIMIT = 1_000_000

type Statement = {
    kind: string,
    value: any,
    tag: string,
    [string]: any
}

local constantCollection, inf_loops
local format = string.format

local maxNum, tab, visited, callId = 2 ^ 64, "    ", {}, nil;

local bytes = {}
local beautify;
for i = string.byte("A"), string.byte("z") do
    bytes[tostring(i)] = string.char(i)
end

local beautifyHandlers = {
    table = function(data, tabs, shouldMinify)
        if visited[data] then return "{ 'recursive table' }" end

        tabs = shouldMinify and 0 or tabs or 1

        local newline = shouldMinify and "" or "\n"
        local out = "{" .. newline
        local p = string.rep(tab, tabs);

        visited[data] = true

        for i, v in next, data do
            out ..= `{p}[{beautify(i, tabs + 1, shouldMinify)}] = {beautify(v, tabs + 1, shouldMinify)},` .. newline
        end

        visited[data] = false

        if #out == 2 then return "{}" end

        return out:sub(1, -3 + (shouldMinify and 2 or 0)) .. newline .. string.rep(tab, tabs - 1) .. "}"
    end,
    string = function(data, style, depth)
        if (style == 'block') then
            local equals = string.rep("=", depth or 1)
            return format("[%s[%s]%s]", equals, data, equals)
        else
            local quote = style == "double" and '"' or style == "interp" and "`" or "'"
            if prettyPrint then
                data = data:gsub(
                    "\\(%d+)",
                    bytes
                )
            end
            return quote .. data .. quote
        end
    end,
    number = function(data)
        local str = tostring(data)
        if str == "nan" then return "0/0" elseif str == "inf" then return "math.huge" elseif str == "-inf" then return "-math.huge" end

        return str
    end
}

beautify = function(data: any, ...): string
    local type = typeof(data);

    local f = beautifyHandlers[type] or tostring
    return f(data, ...);
end

local function callFormat(...)
    return callId .. format(...)
end

local unparser = {
    binaryOperatorNames = {
        ["and"] = "CHECKAND",
        ["or"] = "CHECKOR",
        [">"] = "COMPG",
        ["<"] = "COMPL",
        [">="] = "COMPGE",
        ["<="] = "COMPLE",
        ["=="] = "CHECKEQ",
        ["~="] = "CHECKNEQ",
        [".."] = "CONCAT",
    },
    unaryOperatorNames = {
        ["#"] = "CHECKLEN",
        ["-"] = "CHECKUNM",
        ["not"] = "CHECKNOT"
    }
}

local forId, ifId, whileId = 0, 0, 0;
local lines = {}

local function readParams(statement)
    local code = "("

    local params = statement.parameters

    for i, param in params do
        code ..= (i > 1 and ", " or "") .. unparser:readexpr(param)
    end
    if statement.hasVararg then
        code ..= (#params == 0 and "" or ",") .. "..."
    end

    return code .. ")", statement.hasVararg ~= nil
end

local function getValue(op, v1, v2): any?
    if op == "+" then return v1 + v2
    elseif op == "-" then return v1 - v2
    elseif op == "*" then return v1 * v2
    elseif op == "/" then return v1 / v2
    elseif op == "^" then return v1 ^ v2
    elseif op == "%" then return v1 % v2
    elseif op == ".." then return v1 .. v2
    elseif op == "//" then return v1 // v2
    elseif op == "and" then return v1 and v2
    elseif op == "or" then return v1 or v2
    elseif op == "==" then return v1 == v2
    elseif op == "~=" then return v1 ~= v2
    elseif op == ">" then return v1 > v2
    elseif op == "<" then return v1 < v2
    elseif op == ">=" then return v1 >= v2
    elseif op == "<=" then return v1 <= v2
    end
    return nil;
end

function unparser:construct(statement: { [any]: any }): { [string]: string }
    if statement.token then
        return {
            class = "constant"
        }
    end

    if statement.kind == "stat" then
        return {
            class = "statement",
            kind = statement.tag
        }
    elseif statement.kind == "expr" then
        return {
            class = "expression",
            kind = statement.tag
        }
    end

    return {
        class = "other"
    }
end

local function is(statement, tag, deepSearch)
    if not statement then return false end
    if statement.tag == tag then return statement end
    if statement.expression then
        return is(statement.expression, tag)
    end
    if statement.lhsOperand then
        return is(statement.lhsOperand, tag)
    end
    if statement.tag == "unary" then
        return is(statement.operand, tag)
    end
    if deepSearch then
        if statement.rhsOperand then
            return is(statement.rhsOperand, tag)
        end
    end
end

local Spied = {}

local function Spy(statement)
    local tag = statement.tag
    if tag == "global" or tag == "call" or tag == "index" or tag == "indexname" then
        Spied[statement] = true
    end
end

local function isSpiedVar(statement, dontIncludeLocals)
    local Binary = is(statement, "binary")
    if (Binary) then
        if (isSpiedVar(Binary.lhsOperand) or isSpiedVar(Binary.rhsOperand)) then
            return true;
        end
    end

    return
        is(statement, "global") or
        is(statement, "call") or
        is(statement, "index") or
        is(statement, "indexname") or
        (not dontIncludeLocals and statement.tag == "local") or
        Spied[statement];
end

local function getLength(thing)
    local count = 0;
    if thing.tag == "table" then
        for i in thing.entries do
            count += 1
        end
    elseif thing.tag == "string" then
        count = thing.value and thing.value.text and #thing.value.text or thing.token and thing.token.text and #thing.token.text or #thing.text
    end
    return count
end

local function getRawValue(statement: Statement): (any, boolean)
    if typeof(statement) ~= "table" then return nil, false end

    local tag = statement.tag;

    if tag == "binary" then
        local rhs, rhsSuccess = getRawValue(statement.rhsOperand)
        local lhs, lhsSuccess = getRawValue(statement.lhsOperand)
        local operator = statement.operator.text

        if not rhsSuccess or not lhsSuccess then return nil, false end

        local s, value = pcall(getValue, operator, lhs, rhs)

        if not s or typeof(value) == "number" and value >= maxNum then
            return nil, false;
        end

        return value, true;
    elseif tag == "group" then
        return getRawValue(statement.expression)
    elseif tag == "unary" then
        local v, s = getRawValue(statement.operand)
        if not s then return nil, false end

        if statement.operator.text == "-" and typeof(v) == "number" then
            return -v, true
        elseif statement.operator.text == "not" then
            return not v, true
        elseif statement.operator.text == "#" then
            return #v, true
        end
    elseif tag == "table" then
        local values = {}
        for _, entry in next, statement.entries do
            local v, s = getRawValue(entry.value)
            if not s then return nil, false end

            values[#values + 1] = v
        end
        return values, true;
    elseif tag == "nil" then
        return nil, true
    end

    if statement.value then
        return statement.value, true
    end
    
    return statement, false;
end

function unparser:readstatementF(statement, args)
    args = args or {}

    local tag = statement.tag
    local dontAddDo = args.dontAddDo

    Spy(statement)

    if tag == "local" or tag == 'const' then
        local code = "local ";
        local DoSpy;
        
        for i, var in statement.variables do
            local variable = var.node.name.text
            local annotation = ""
            if var.node.annotation then
                annotation = ": " .. self:readexpr(var.node.annotation)
            end
            code ..= (i > 1 and "," or "") .. variable .. annotation
        end
        if #statement.values == 0 then return code end
        code ..= " = "
        for i, val in statement.values do
            code ..= (i > 1 and "," or "") .. self:readexpr(val, args)
            DoSpy = DoSpy or Spied[val]
        end
        Spied[statement] = Spied[statement] or DoSpy
        return code
    elseif tag == "assign" then
        local code = "";

        for i, var in statement.variables do
            code ..= (i > 1 and ", " or "") .. self:readexpr(var, {
                dontHook = true
            })
        end

        code ..= " = "

        for i, val in statement.values do
            local node = val
            local var = statement.variables[i]
            if constantCollection and ((var and is(var, "index")) or is(node, "index") or is(node, "string")) then
                code ..= callFormat("GET(%s)", self:readexpr(node))
            else
                code ..= self:readexpr(node)
            end
            if (i ~= #statement.values) then code ..= "," end
        end
        return code
    elseif tag == "compoundassign" then
        return format("%s%s%s", self:readexpr(statement.variable, {
            dontHook = true
        }), statement.operator.text, self:readexpr(statement.value))
    elseif tag == "expression" then
        return self:readexpr(statement.expression, args)
    elseif tag == "function" then
        local funcNode = statement.func or statement
        local params, vararg = readParams(funcNode)
        local code = "function " .. self:readexpr(statement.name, {
            dontHook = true,
            superDuperDontHook = true,
            isInVararg = true
        }) .. params

        local body = funcNode.body
        code ..= self:readexpr(body, {
            isInVararg = vararg,
            dontHook = true
        }) .. "end"

        return code
    elseif tag == "do" then
        local code = "do "
        local body = statement.body or statement
        local stmts = body.statements or {}
        for _, stat in stmts do
            local str = self:readexpr(stat, {
                dontAddDo = typeof(dontAddDo) == "string" and dontAddDo or nil,
                isInVararg = args.isInVararg
            })
            code ..= str .. (str ~= "..." and str:sub(#str) ~= ";" and ";" or "")
        end
        return code .. "end;"
    elseif tag == "block" then
        local code = ""

        for _, stat in statement.statements do
            local str = self:readexpr(stat, {
                dontAddDo = typeof(dontAddDo) == "string" and dontAddDo or nil,
                isInVararg = args.isInVararg
            })
            code ..= str .. (str ~= "..." and str:sub(#str) ~= ";" and ";" or "")
        end
        return code
    elseif tag == "localfunction" then
        local name = self:readexpr(statement.name)
        local funcNode = statement.func or statement
        local params, vararg = readParams(funcNode)
        local body = funcNode.body
        local code = "local function " .. name .. params
        code ..= self:readexpr(body, {
            dontAddDo = true,
            isInVararg = vararg
        }) .. "end"

        return code
    elseif tag == "conditional" then
        ifId += 1

        local elseBlock = statement.elseBlock
        local condition = self:readexpr(statement.condition)
        local Thing, Path;

        local Elseifs = statement.elseifs
        local _, s = getRawValue(statement.condition)

        if (s) then
            Thing = condition
        else
            Thing = callFormat("CHECKIF(%s,%d,%d)", condition, ifId, elseBlock and 1 or 0)
            Path = callFormat("CHECKIFEND(%d)", ifId)
        end

        local code = format("if %s then %s", Thing, self:readstatement(statement.thenBlock, {
            dontAddDo = Path
        }))

        for _, elif in next, Elseifs do
            local OtherThing = callFormat("CHECKIF(%s,%d)", self:readexpr(elif.condition), ifId)

            code ..= format("elseif %s then %s", OtherThing, self:readstatement(elif.thenBlock, {
                dontAddDo = Path
            }))
        end

        if elseBlock then
            code ..= format("else %s", self:readexpr(elseBlock, Path))
        end

        return code .. "end" .. (Path and ";" .. Path or "");
    elseif tag == "while" then
        whileId += 1

        local Cond = self:readexpr(statement.condition)

        local While = callFormat("CHECKWHILE(%s,%d)", Cond, whileId)
        local WhileEnd = callFormat("CHECKWHILEEND(%d)", whileId)

        local _, s = getRawValue(statement.condition)

        if s then
            local var = callId .. "vmeow" .. whileId
            return format(
                "local %s=0;while(%s)do %s+=1 if %s>%d then error('infinite_loop_err')end;%send",
                var,
                Cond,
                var,
                var,
                WHILE_LIMIT,
                self:readstatement(statement.body)
            )
        elseif not s then
            return format(
                "while %s do %send;%s",
                While,
                self:readstatement(statement.body, WhileEnd),
                WhileEnd
            )
        else
            return format(
                "while %s do %send",
                Cond,
                self:readstatement(statement.body)
            )
        end
    elseif tag == "return" then
        local Start = "return " .. callFormat("RETURN(")

        if #statement.expressions == 0 then
            return Start .. ")"
        end

        local args = ""
        for i, node in statement.expressions do
            args = args .. (i > 1 and ", " or "") .. self:readexpr(node)
        end

        Start = Start .. args

        return Start .. ")"
    elseif tag == "for" then
        forId += 1

        local stepCode = statement.step
        stepCode = stepCode and "," .. self:readexpr(stepCode) or "";

        local from, to = self:readexpr(statement.from), self:readexpr(statement.to)
        local var = statement.variable.name.text
        local vFrom, sFrom = getRawValue(statement.from)
        local vTo, sTo = getRawValue(statement.to)

        local body = self:readstatement(statement.body, {
            dontAddDo = true
        })

        if sFrom and sTo then
            return format("for %s=%s,%s%s do %s end", var, if sFrom then vFrom else from, if sTo then vTo else to, stepCode, body)
        end

        local code =
            callFormat("FORINFO(%d,%s,%s%s)", forId, from, to, stepCode)

        code ..= `for {var}={callFormat("FORSTEP1(%d)", forId)},{callFormat("FORSTEP2(%d)", forId)}{stepCode} do {body}end`

        return code
    elseif tag == "forin" then
        local code = "for "
        for i, node in statement.variables do
            code ..= (i > 1 and ", " or "") .. node.name.text
        end
        local forin = ""
        for i, val in statement.values do
            forin = forin .. (i > 1 and ", " or "") .. self:readexpr(val)
        end

        code ..= format(" in %s do %send", forin, self:readstatement(statement.body, {
            dontAddDo = true
        }))
        return code
    elseif tag == "repeat" then
        return format(
            "repeat %s%s until %s",
            callFormat("REPEAT();"),
            self:readexpr(statement.body, {
                dontAddDo = true
            }),
            self:readexpr(statement.condition)
        )
    elseif tag == "typealias" then
        return format("export type %s = %s", statement.name.text, self:readexpr(statement.type, nil, nil, true))
    end

    print(beautify(statement))
    error("unsupported statement '" .. (statement.tag or "???") .. "'")
end

function unparser:readstatement(...)
    local statement = ...
    local stat = self:readstatementF(...)

    if (prettyPrint) then
        stat = "\n" .. stat
    end
    return stat .. ((stat:sub(#stat) == ";" or (statement.tag == "block" or statement.tag == "do") and #(statement.statements or {}) == 0) and '' or ";")
end

function unparser:readexpr(statement, args)
    local expr = self:construct(statement)

    if expr.class == "statement" then
        return self:readstatement(statement, args)
    elseif statement.token and not statement.tag then
        if statement.value ~= nil then return beautify(statement.value, statement.quoteStyle) end

        return beautify(statement.token.text, statement.quoteStyle)
    end

    local node = statement.node
    if node then statement = node end

    local tag = statement.tag or statement.kind;

    args = args or {}

    local dontHook, superDuperDontHook, isInVararg = args.dontHook, args.superDuperDontHook, args.isInVararg

    local dontLogConstruct = args.dontLogConstruct
    if dontLogConstruct == nil then dontLogConstruct = not constantCollection end

    if tag == "number" then
        return statement.value or statement.token.text
    elseif tag == "string" then
        return beautify(statement.token.text, statement.quoteStyle, statement.blockDepth)
    elseif tag == "nil" then
        return "nil"
    elseif tag == "vararg" then
        return "..."
    elseif tag == "break" then
        return "break"
    elseif tag == "continue" then
        return "continue"
    elseif tag == "bool" or tag == "boolean" then
        return tostring(statement.value)
    elseif tag == "call" then
        local start = ""
        local callArgs = {
            dontHook = statement.self
        }

        local func = self:readexpr(statement.func, callArgs)

        if statement.func.tag == "group" and not statement.self then
            local code = func .. "("

            for i, arg in statement.arguments do
                local data = self:readexpr(arg, args)

                code ..= (i > 1 and "," or "") .. data
            end
            return code .. ")"
        elseif statement.self then
            start = callFormat("NAMECALL(%s", func)
        else
            start = callFormat("CALL((%s)", func)
        end

        local code = start

        for i, arg in statement.arguments do
            local comma = ","
            local data = self:readexpr(arg, callArgs)

            code ..= comma .. data
        end

        return code .. ")"
    elseif tag == "local" or tag == "global" then
        return (statement.name or statement.token).text
    elseif tag == "table" then
        local code = "{";
        local len = #statement.entries

        for i, entry in statement.entries do
            local key = entry.key
            if true then
                local _, s = getRawValue(key)
                local _, s2 = getRawValue(entry.value)

                if (not s or not s2) then
                    dontLogConstruct = dontLogConstruct or false
                elseif dontLogConstruct == nil then
                    dontLogConstruct = true
                end
            end

            if key then
                if entry.value.tag == "reference" then
                    code ..= format("%s: %s%s", key.text, self:readexpr(entry.value), (i ~= len and ";" or ""))
                    continue
                end
                code ..= format("[%s]=", self:readexpr(entry.key))
            end
            code ..= self:readexpr(entry.value) .. (i ~= len and ";" or "")
        end

        code ..= "}"

        if not dontLogConstruct and #statement.entries > 0 then
            code = callFormat("CONSTRUCT(%s)", code)
        end

        return code
    elseif tag == "binary" then
        local rhs, lhs = statement.rhsOperand, statement.lhsOperand

        local rhsValue, rhsSuccess = getRawValue(rhs)
        local lhsValue, lhsSuccess = getRawValue(lhs)

        local operator = statement.operator.text

        local Lhs = self:readexpr(lhs)
        local Rhs = self:readexpr(rhs)

        local Default = format("%s %s %s", Lhs, operator, Rhs)

        if (not rhsSuccess or not lhsSuccess) then
            local name = self.binaryOperatorNames[operator]
            local kind = rhs.tag

            local WrappedRhs = if not rhsSuccess and kind ~= "global" and kind ~= "local" then "function(...)return " .. Rhs .. " end" else Rhs;

            if name then
                local IsAnd = name == "CHECKAND"
                local IsComp = IsAnd or name == "CHECKOR"
                if IsComp then
                    if lhsSuccess and if IsAnd then not lhsValue else lhsValue then
                        return Lhs
                    end

                    local IsWrapped = WrappedRhs ~= Rhs
                    local trailer = tostring(IsWrapped) .. (isInVararg and ",..." or "")
                    return callFormat(
                        "%s(%s,%s%s)",
                        name,
                        Lhs,
                        WrappedRhs,
                        (not IsWrapped and not isInVararg and "" or ", " .. trailer)
                    )
                elseif name == "CONCAT" then
                    if constantCollection and (isSpiedVar(rhs) or is(rhs, "string") or isSpiedVar(lhs) or is(lhs, "string")) then
                        return callFormat(name .. "(%s,%s)", Lhs, Rhs)
                    end
                    return Default
                else
                    return callFormat("%s(%s, %s)", name, Lhs, Rhs)
                end
            end

            return Default
        end

        local value, s = getRawValue(statement)

        if not s then
            return Default
        end

        return beautify(value)
    elseif tag == "unary" then
        local operator = statement.operator.text

        local value, success = getRawValue(statement)
        if success then return tostring(value) end

        return callFormat("%s(%s)", self.unaryOperatorNames[operator], self:readexpr(statement.operand))
    elseif tag == "group" then
        local Value = self:readexpr(statement.expression)
        return format("(%s)", Value)
    elseif tag == "indexname" then
        local accessor = statement.accessor.text
        local parent = self:readexpr(statement.expression, nil, true)
        local index = statement.index.text

        if superDuperDontHook or (not dontHook and (not constantCollection) and not isSpiedVar(statement)) then
            return format("%s%s%s", parent, accessor, index)
        end

        if dontHook then
            return accessor == ":" and format("%s,%q", parent, index) or format("%s%s%s", parent, accessor, index)
        end

        return format("%s%s%s", parent, accessor, index)
    elseif tag == "index" then
        local base, index = self:readexpr(statement.expression, {
            dontHook = true
        }), self:readexpr(statement.index)

        if dontHook then
            return format("%s[%s]", base, index)
        end

        return callFormat("CHECKINDEX(%s, %s)",
            base,
            index
        )
    elseif tag == "function" then
        local funcNode = if statement.parameters then statement elseif statement.func then statement.func else statement
        local params, vararg = readParams(funcNode)
        local body = funcNode.body
        local code = format("function%s%send", params, self:readexpr(body, {
            isInVararg = vararg
        }))

        return code
    elseif tag == "conditional" then
        local code = format("if %s then %s ", self:readexpr(statement.condition), self:readexpr(statement.thenExpr))

        for _, elif in statement.elseifs do
            code ..= format("elseif %s then %s ", self:readexpr(elif.condition), self:readexpr(elif.thenExpr))
        end

        code ..= format("else %s", self:readexpr(statement.elseExpr))
        return code
    elseif tag == "interpolatedstring" then
        local list = {}
        for _, str in statement.strings do
            table.insert(list, {
                kind = "string",
                at = str.location.beginColumn,  -- Changed from str.location.begin.column
                expr = str.text
            })
        end

        for _, expr in statement.expressions do
            table.insert(list, {
                kind = "expr",
                at = expr.location.beginColumn,  -- Changed from expr.location.begin.column
                expr = expr
            })
        end

        table.sort(list, function(a, b) return a.at < b.at end)

        local code = {}
        for _, v in next, list do
            local Expr = v.expr;
            if typeof(Expr) == "string" then
                table.insert(code, beautify(Expr))
            else
                table.insert(code, self:readexpr(Expr))
            end
        end
        return callFormat("TEMPLATE_STRING(%s)", table.concat(code, ", "))
    elseif tag == "cast" then
        print("cast")
        return ""
    elseif tag == "reference" then
        return statement.name.text
    end

    print(beautify(statement))
    error("unsupported expression '" .. (statement.tag or "???") .. "'")
end

local args = {...}

local input = args[2]
print("Input file:", input)
local out = args[3]
print("Output file:", out)
callId = args[4] or ""
constantCollection = args[5] == "1"
inf_loops = args[6] == "1"
WHILE_LIMIT = tonumber(args[7]) or WHILE_LIMIT;

if callId == "0" then callId = "" end

print("Constant collection:", constantCollection)

local output = {}
local function readfile(path : string) : string?
    assert(fs.exists(path), "invalid argument #1 to 'readfile', file does not exist.")
    local handle = fs.open(path, "r")
    local content = fs.read(handle)
    fs.close(handle)
    return content
end

local source = readfile(input)
lines = splitLines(source)

local s = os.clock()
local parsed = parser.parse(source)
if not parsed or not parsed.root or not parsed.root.statements then
    error("parser.parse returned no root statements")
end
for _, v in parsed.root.statements do
    output[#output + 1] = unparser:readexpr(v)
end
print("finished everything in", os.clock() - s, "seconds, file size:", #source / 1024, "kb.")
writeStringToFile(out, table.concat(output, " "))