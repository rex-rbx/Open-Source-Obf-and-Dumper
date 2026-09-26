local parser = require("@std/syntax/parser")
local utils = require("@std/syntax/utils")
local fs = require("@std/fs")

local function writeFileCompat(path, content)
    if fs.writeFile then return fs.writeFile(path, content) end
    if fs.writestringtofile then return fs.writestringtofile(path, content) end
    if fs.writefile then return fs.writefile(path, content) end
    if fs.open and fs.write and fs.close then
        local handle = fs.open(path, "w")
        fs.write(handle, content)
        fs.close(handle)
        return
    end
    error("No fs write function available")
end

local function splitLines(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end

local prettyPrint = true

type Statement = {
    kind: string,
    value: any,
    tag: string,
    [string] : any
}

local constantCollection, inf_loops
local format = string.format
local WHILE_LIMIT = 1_000_000

local function readfile(path : string) : string?
    assert(fs.exists(path), "invalid argument #1 to 'readfile', file does not exist.")
    local handle = fs.open(path, "r")
    local content = fs.read(handle)
    fs.close(handle)
    return content
end

local maxNum, tab, visited, callId = 2^64, "    ", {}, nil

local bytes = {}
local beautify
for i = 0, 255 do bytes[tostring(i)] = string.char(i) end

local beautifyHandlers = {
    table = function(data, tabs, shouldMinify)
        if visited[data] then return "{ 'recursive table' }" end
        tabs = shouldMinify and 0 or tabs or 1
        local newline = shouldMinify and "" or "\n"
        local out = "{" .. newline
        local p = string.rep(tab, tabs)
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
                data = data:gsub("\\(%d+)", bytes)
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

beautify = function(data : any, ...) : string
    local type = typeof(data)
    local f = beautifyHandlers[type] or tostring
    return f(data, ...)
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
        [".."] = "CONCAT"
    },
    unaryOperatorNames = {
        ["#"] = "CHECKLEN",
        ["-"] = "CHECKUNM",
        ["not"] = "CHECKNOT"
    }
}

local function getText(node)
    if not node then return nil end
    if type(node) == "string" then return node end
    if type(node) == "table" then
        if node.text ~= nil then return node.text end
        if node.value ~= nil and type(node.value) == "string" then return node.value end
        if node.token then return getText(node.token) end
        if node.name then return getText(node.name) end
    end
    return tostring(node)
end

local function getOperatorText(operator)
    if not operator then return nil end
    if type(operator) == "string" then return operator end
    if type(operator) == "table" then
        if operator.text ~= nil then return operator.text end
        if operator.value ~= nil then return tostring(operator.value) end
        if operator.token then return getOperatorText(operator.token) end
    end
    return tostring(operator)
end

local forId, ifId, whileId = 0, 0, 0
local lines = {}

local function readParams(statement)
    local code = "("
    local params = statement.parameters
    for i, param in params do
        code = code .. (i > 1 and ", " or "") .. unparser:readexpr(param)
    end
    if statement.vararg then
        code = code .. (#params == 0 and "" or ",") .. "..."
    end
    return code .. ")", statement.vararg
end

local function getValue(op, v1, v2) : any?
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
    return nil
end

function unparser:construct(statement : { [any]: any }) : { [string]: string }
    if not statement then
        return { class = "other" }
    end
    if statement.istoken then
        return { class = "constant" }
    end
    if statement.kind == "stat" then
        return { class = "statement", kind = statement.tag }
    elseif statement.kind == "expr" then
        return { class = "expression", kind = statement.tag }
    end
    return { class = "other" }
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
    if deepSearch and statement.rhsOperand then
        return is(statement.rhsOperand, tag)
    end
    return false
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
    if Binary then
        if isSpiedVar(Binary.lhsOperand) or isSpiedVar(Binary.rhsOperand) then
            return true
        end
    end
    return
        is(statement, "global") or
        is(statement, "call") or
        is(statement, "index") or
        is(statement, "indexname") or
        (not dontIncludeLocals and statement.tag == "local") or
        Spied[statement]
end

local function getRawValue(statement : Statement) : (any, boolean)
    if typeof(statement) ~= "table" then return nil, false end
    local tag = statement.tag

    if tag == "binary" then
        local rhs, rhsSuccess = getRawValue(statement.rhsOperand)
        local lhs, lhsSuccess = getRawValue(statement.lhsOperand)
        local operator = getOperatorText(statement.operator)
        if not operator or not rhsSuccess or not lhsSuccess then return nil, false end
        local s, value = pcall(getValue, operator, lhs, rhs)
        if not s or typeof(value) == "number" and value >= maxNum then
            return nil, false
        end
        return value, true
    elseif tag == "unary" then
        local v, s = getRawValue(statement.operand)
        if not s then return nil, false end
        local operator = getOperatorText(statement.operator)
        if operator == "-" and typeof(v) == "number" then
            return -v, true
        elseif operator == "not" then
            return not v, true
        elseif operator == "#" then
            return #v, true
        end
    elseif tag == "table" then
        local values = {}
        for _, entry in next, statement.entries do
            local v, s = getRawValue(entry.value)
            if not s then return nil, false end
            values[#values+1] = v
        end
        return values, true
    end

    if statement.value ~= nil then
        return statement.value, true
    end

    return statement, false
end

function unparser:readstatementF(statement, args)
    args = args or {}
    local tag = statement.tag
    local dontAddDo = args.dontAddDo

    Spy(statement)

    if tag == "local" then
        local code = "local "
        local DoSpy
        for i, var in statement.variables do
            -- CstStatLocal has variables as array of CstLocal
            -- CstLocal has name field which is CstToken<string>
            local variable = getText(var.name) or getText(var.token) or ""
            code = code .. (i > 1 and "," or "") .. variable
        end
        if #statement.values == 0 then return code end
        code = code .. " = "
        for i, val in statement.values do
            code = code .. (i > 1 and "," or "") .. self:readexpr(val)
            DoSpy = DoSpy or Spied[val]
        end
        Spied[statement] = Spied[statement] or DoSpy
        return code
    elseif tag == "assign" then
        local code = ""
        for i, var in statement.variables do
            code = code .. (i > 1 and ", " or "") .. self:readexpr(var, { dontHook = true })
        end
        code = code .. " = "
        for i, val in statement.values do
            local var = statement.variables[i]
            if constantCollection and ((var and is(var, "index")) or is(val, "index") or is(val, "string")) then
                code = code .. callFormat("GET(%s)", self:readexpr(val))
            else
                code = code .. self:readexpr(val)
            end
            if i ~= #statement.values then code = code .. "," end
        end
        return code
    elseif tag == "compoundassign" then
        local operator = getOperatorText(statement.operator) or ""
        return format("%s%s%s", self:readexpr(statement.variable, { dontHook = true }), operator, self:readexpr(statement.value))
    elseif tag == "expression" then
        return self:readexpr(statement.expression, args)
    elseif tag == "function" then
        local params, vararg = readParams(statement.func)
        local code = "function " .. self:readexpr(statement.name, { dontHook = true, superDuperDontHook = true, isInVararg = true }) .. params
        code = code .. self:readexpr(statement.func.body, { isInVararg = vararg, dontHook = true }) .. "end"
        return code
    elseif tag == "block" then
        local shouldAddDo = false
        if statement.doKeyword then
            shouldAddDo = true
        end
        if not shouldAddDo and statement.location and statement.location.begin and lines and lines[statement.location.begin.line + 1] then
            local location = statement.location.begin
            local content = lines[location.line + 1]
            if content then
                local col = location.column or 0
                shouldAddDo = content:sub(col + 1, col + 2) == "do"
            end
        end
        local code = shouldAddDo and "do " or ""
        for _, stat in statement.statements do
            local str = self:readexpr(stat, { dontAddDo = typeof(dontAddDo) == "string" and dontAddDo or nil })
            code = code .. str .. (str ~= "..." and str:sub(#str) ~= ";" and ";" or "")
        end
        return code .. (shouldAddDo and "end;" or "")
    elseif tag == "localfunction" then
        local name = getText(statement.name) or ""
        local params, vararg = readParams(statement.func)
        local code = "local function " .. name .. params
        code = code .. self:readexpr(statement.func.body, { dontAddDo = true, isInVararg = vararg }) .. "end"
        return code
    elseif tag == "conditional" then
        ifId += 1

        local _, s = getRawValue(statement.condition)

        local function ConstructCode(statement, isDuplicate)
            local elseblock = statement.elseBlock
            local condition = self:readexpr(statement.condition)
            local Thing, Path

            if s then
                Thing = condition
            else
                Thing = callFormat("CHECKIF(%s,%d,%d%s)", condition, ifId, elseblock and 1 or 0, isDuplicate and ",true" or "")
                Path = callFormat("CHECKIFEND(%d)", ifId)
            end

            local code = format("if %s then %s", Thing, self:readstatement(statement.thenBlock, { dontAddDo = Path }))

            for _, elif in next, statement.elseifs do
                local OtherThing = callFormat("CHECKIF(%s,%d)", self:readexpr(elif.condition), ifId)
                code = code .. format("elseif %s then %s", OtherThing, self:readstatement(elif.thenBlock, { dontAddDo = Path }))
            end

            if elseblock then
                code = code .. format("else %s", self:readexpr(elseblock, Path))
            end

            return code .. "end" .. (Path and ";" .. Path or "")
        end

        local code = ConstructCode(statement)
        if not s then code = code .. ";" .. ConstructCode(statement, true) end
        return code
    elseif tag == "while" then
        whileId += 1

        local Cond = self:readexpr(statement.condition)
        local value, s = getRawValue(statement.condition)

        if s then
            local var = callId .. "vmeow" .. whileId
            return format("local %s=0;while(%s)do %s+=1 if %s>%d then error('infinite_loop_err')end;%send", var, Cond, var, var, WHILE_LIMIT, self:readstatement(statement.body))
        elseif (not s or inf_loops) then
            local While = callFormat("CHECKWHILE(%s,%d)", Cond, whileId)
            local WhileEnd = callFormat("CHECKWHILEEND(%d)", whileId)
            return format("while %s do %send;%s", While, self:readstatement(statement.body, WhileEnd), WhileEnd)
        elseif value or not inf_loops then
            return format("while %s do %send;", Cond, self:readstatement(statement.body))
        else
            return "while(false)do end;"
        end
    elseif tag == "return" then
        local Start = "return "
        if #statement.expressions == 0 then
            return Start
        end
        local args = ""
        for i, node in statement.expressions do
            args = args .. (i > 1 and ", " or "") .. self:readexpr(node)
        end
        return Start .. args
    elseif tag == "for" then
        forId += 1
        local stepCode = statement.step and "," .. self:readexpr(statement.step) or ""
        local from, to = self:readexpr(statement.from), self:readexpr(statement.to)
        local var = getText(statement.variable.name) or getText(statement.variable.token) or ""
        local vFrom, sFrom = getRawValue(statement.from)
        local vTo, sTo = getRawValue(statement.to)
        local body = self:readstatement(statement.body, { dontAddDo = true })
        
        if sFrom and sTo then
            return format("for %s=%s,%s%s do %s end", var, sFrom and vFrom or from, sTo and vTo or to, stepCode, body)
        end
        
        local code = callFormat("FORINFO(%d,%s,%s%s)", forId, from, to, stepCode)
        code = code .. `for {var}={callFormat("FORSTEP1(%d)", forId)},{callFormat("FORSTEP2(%d)", forId)}{stepCode} do {body}end`
        return code
    elseif tag == "forin" then
        local code = "for "
        for i, node in statement.variables do
            local name = getText(node.name) or getText(node.token) or ""
            code = code .. (i > 1 and ", " or "") .. name
        end
        local forin = ""
        for i, val in statement.values do
            forin = forin .. (i > 1 and ", " or "") .. self:readexpr(val)
        end
        code = code .. format(" in %s do %send", forin, self:readstatement(statement.body, { dontAddDo = true }))
        return code
    elseif tag == "repeat" then
        return format("repeat %s%s until %s", (inf_loops and callFormat("REPEAT();") or ""), self:readexpr(statement.body, { dontAddDo = true }), self:readexpr(statement.condition))
    elseif tag == "typealias" then
        local name = getText(statement.name) or ""
        return format("export type %s = %s", name, self:readexpr(statement.type, nil, nil, true))
    end

    print(beautify(statement))
    error("unsupported statement '" .. (statement.tag or "???") .. "'")
end

function unparser:readstatement(...)
    local statement = ...
    local stat = self:readstatementF(...)
    if prettyPrint then
        stat = "\n" .. stat
    end
    return stat .. ((stat:sub(#stat) == ";" or statement.tag == "block" and #statement.statements == 0) and '' or ";")
end

function unparser:readexpr(statement, args)
    if not statement then return "" end
    local expr = self:construct(statement)

    if expr.class == "statement" then
        return self:readstatement(statement, args)
    elseif statement.istoken and not statement.tag then
        if statement.value ~= nil then return beautify(statement.value, statement.quoteStyle) end
        return beautify(statement.text, statement.quoteStyle)
    end

    local node = statement.node
    if node then statement = node end

    local tag = statement.tag or statement.kind
    args = args or {}

    local dontHook, superDuperDontHook, isInVararg = args.dontHook, args.superDuperDontHook, args.isInVararg
    local dontLogConstruct = args.dontLogConstruct
    if dontLogConstruct == nil then dontLogConstruct = not constantCollection end

    if tag == "number" then
        return statement.value or statement.text
    elseif tag == "string" then
        local value = statement.value
        if value then
            return beautify(getText(value), statement.quoteStyle, statement.blockDepth)
        end
        return beautify(statement.text, statement.quoteStyle, statement.blockDepth)
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
        local callArgs = { dontHook = statement.self }
        local func = self:readexpr(statement.func, callArgs)

        if statement.func.tag == "group" and not statement.self then
            local code = func .. "("
            for i, arg in statement.arguments do
                code = code .. (i > 1 and "," or "") .. self:readexpr(arg, args)
            end
            return code .. ")"
        elseif statement.self then
            start = callFormat("NAMECALL(%s", func)
        else
            start = callFormat("CALL((%s)", func)
        end

        local code = start
        for i, arg in statement.arguments do
            code = code .. "," .. self:readexpr(arg, callArgs)
        end
        return code .. ")"
    elseif tag == "local" or tag == "global" then
        return getText(statement.name) or getText(statement.token) or ""
    elseif tag == "table" then
        local code = "{"
        local len = #statement.entries

        for i, entry in statement.entries do
            local key = entry.key
            if true then
                local _, s = getRawValue(key)
                local _, s2 = getRawValue(entry.value)
                if not s or not s2 then
                    dontLogConstruct = dontLogConstruct or false
                elseif dontLogConstruct == nil then
                    dontLogConstruct = true
                end
            end

            if key then
                if entry.value.tag == "reference" then
                    code = code .. format("%s: %s%s", getText(key), self:readexpr(entry.value), (i ~= len and ";" or ""))
                    continue
                end
                code = code .. format("[%s]=", self:readexpr(entry.key))
            end
            code = code .. self:readexpr(entry.value) .. (i ~= len and ";" or "")
        end

        code = code .. "}"

        if not dontLogConstruct and #statement.entries > 0 then
            code = callFormat("CONSTRUCT(%s)", code)
        end

        return code
    elseif tag == "binary" then
    local rhs, lhs = statement.rhsOperand, statement.lhsOperand
    -- Guard against nil operands
    if not lhs or not rhs then
        return ""
    end
    local rhsValue, rhsSuccess = getRawValue(rhs)
    local lhsValue, lhsSuccess = getRawValue(lhs)
    local operator = getOperatorText(statement.operator)
    if not operator then
        return format("%s %s", self:readexpr(lhs), self:readexpr(rhs))
    end
    local Lhs = self:readexpr(lhs)
    local Rhs = self:readexpr(rhs)
    local Default = format("%s %s %s", Lhs, operator, Rhs)

    if not rhsSuccess or not lhsSuccess then
        local name = self.binaryOperatorNames[operator]
        local kind = rhs and rhs.tag or ""
        local WrappedRhs = if not rhsSuccess and kind ~= "global" and kind ~= "local" then "function(...)return " .. Rhs .. " end" else Rhs
        if name then
                local IsAnd = name == "CHECKAND"
                local IsComp = IsAnd or name == "CHECKOR"
                if IsComp then
                    if lhsSuccess and if IsAnd then not lhsValue else lhsValue then
                        return Lhs
                    end
                    local IsWrapped = WrappedRhs ~= Rhs
                    local trailer = tostring(IsWrapped) .. (isInVararg and ",..." or "")
                    return callFormat("%s(%s,%s%s)", name, Lhs, WrappedRhs, (not IsWrapped and not isInVararg and "" or ", " .. trailer))
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
        local operator = getOperatorText(statement.operator) or ""
        local value, success = getRawValue(statement)
        if success then return tostring(value) end
        return callFormat("%s(%s)", self.unaryOperatorNames[operator], self:readexpr(statement.operand))
    elseif tag == "group" then
        local Value = self:readexpr(statement.expression)
        return format("(%s)", Value)
    elseif tag == "indexname" then
        local accessor = getText(statement.accessor) or "."
        local parent = self:readexpr(statement.expression, nil, true)
        local index = getText(statement.index) or ""

        if superDuperDontHook or (not dontHook and (not constantCollection) and not isSpiedVar(statement)) then
            return format("%s%s%s", parent, accessor, index)
        end

        if dontHook then
            return accessor == ":" and format("%s,%q", parent, index) or format("%s%s%s", parent, accessor, index)
        end

        return format("%s%s%s", parent, accessor, index)
    elseif tag == "index" then
        local base, index = self:readexpr(statement.expression, { dontHook = true }), self:readexpr(statement.index)
        if dontHook then
            return format("%s[%s]", base, index)
        end
        return callFormat("CHECKINDEX(%s, %s)", base, index)
    elseif tag == "function" then
        local params, vararg = readParams(statement)
        local code = format("function%s%send", params, self:readexpr(statement.body, { isInVararg = vararg }))
        return code
    elseif tag == "conditional" then
        local code = format("if %s then %s ", self:readexpr(statement.condition), self:readexpr(statement.thenExpr))
        for _, elif in statement.elseifs do
            code = code .. format("elseif %s then %s ", self:readexpr(elif.condition), self:readexpr(elif.thenExpr))
        end
        code = code .. format("else %s", self:readexpr(statement.elseExpr))
        return code
    elseif tag == "interpolatedstring" then
        local list = {}
        local idx = 1
        for _, str in statement.strings do
            local col = idx -- fallback position
            if str and str.location and str.location.begin then
                col = str.location.begin.column
            end
            table.insert(list, { kind = "string", at = col, expr = getText(str) })
            idx = idx + 1
        end
        for _, expr in statement.expressions do
            local col = idx
            if expr and expr.location and expr.location.begin then
                col = expr.location.begin.column
            end
            table.insert(list, { kind = "expr", at = col, expr = expr })
            idx = idx + 1
        end
        table.sort(list, function(a, b) return (a.at or 0) < (b.at or 0) end)
        local code = "\""
        local exprs = {}
        for _, v in list do
            if v.kind == "expr" then
                code = code .. "%s"
                table.insert(exprs, self:readexpr(v.expr))
            else
                code = code .. v.expr
            end
        end
        return callFormat("TEMPLATE_STRING(%s,%s)", code .. "\"", (#exprs == 0 and "nil" or table.concat(exprs, ",")))
    elseif tag == "cast" then
        return self:readexpr(statement.operand) .. " :: " .. self:readexpr(statement.annotation)
    elseif tag == "reference" then
        return getText(statement.name) or ""
    end

    print(beautify(statement))
    error("unsupported expression '" .. (statement.tag or "???") .. "'")
end

local args = { ... }
local input = args[2]
local out = args[3]
prettyPrint = not args[4] or args[4] == ""
callId = args[4] or ""
constantCollection = args[5] == "1"
inf_loops = args[6] == "1"

if callId == "0" then callId = "" end

print("Constant collection:", constantCollection)

local output = {}
local source = readfile(input)
lines = splitLines(source)

local s = os.clock()
local parsed = parser.parse(source)
if not parsed or not parsed.root or not parsed.root.statements then
    error("parser.parse returned no root statements")
end

for _, v in parsed.root.statements do
    output[#output+1] = unparser:readexpr(v)
end

print("finished everything in", os.clock()-s, "seconds, file size:", #source / 1024, "kb.")

writeFileCompat(out, 'print(\'' .. table.concat(output, " ") .. '\')')