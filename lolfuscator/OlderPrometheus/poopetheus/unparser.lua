local Base85
do
    local a,b,c={},'~>',85 local function d(e,f,g,h)return bit32.bor(bit32.lshift(e,24),bit32.lshift(f,16),bit32.lshift(g,8),h)end local function e(f)return{bit32.band(bit32.rshift(f,24),0xff),bit32.band(bit32.rshift(f,16),0xff),bit32.band(bit32.rshift(f,8),0xff),bit32.band(f,0xff)}end local function f(g)local h={}for i=5,1,-1 do local j=g%c h[i]=string.char(j+33)g=math.floor(g/c)end return table.concat(h)end function a.encode(g)if not g or#g==0 then return''end local h,i,j={},1,#g while i<=j do local k,l,m,n,o=string.byte(g,i)or 0,string.byte(g,i+1)or 0,string.byte(g,i+2)or 0,string.byte(g,i+3)or 0,math.min(4,j-i+1)local p=d(k,l,m,n)if p==0 and o==4 then table.insert(h,'z')else local q=f(p)if o<4 then local r=5-(o+1)q=q:sub(1,5-r)end table.insert(h,q)end i=i+4 end return table.concat(h)..b end local function g(h)local i=0 for j=1,#h do local k=string.byte(h,j)-33 if k<0 or k>84 then error('Invalid Base85 character at position '..j..': '..string.char(k+33))end i=i*c+k end return i end function a.decode(h)if not h or#h==0 then return''end local i=h:gsub('%s+','')if i:sub(-2)==b then i=i:sub(1,-3)end if#i==0 then return''end local j,k,l={},1,#i while k<=l do local m=i:sub(k,k)if m=='z'then table.insert(j,string.char(0,0,0,0))k=k+1 else local n=i:sub(k,k+4)local o=#n if o<5 then n=n..string.rep('u',5-o)end local p=g(n)local q,r=e(p),nil if o==1 then r=0 elseif o==2 then r=1 elseif o==3 then r=2 elseif o==4 then r=3 else r=4 end if r>=1 then table.insert(j,string.char(q[1]))end if r>=2 then table.insert(j,string.char(q[2]))end if r>=3 then table.insert(j,string.char(q[3]))end if r>=4 then table.insert(j,string.char(q[4]))end k=k+5 end end return table.concat(j)end
    Base85 = a
end
local LZ4
do
    local a={}local function b(c,d)return string.find(c,d,0,true)end local function c(d)local e={}e.Offset=0 e.Source=d e.Length=string.len(d)e.IsFinished=false e.LastUnreadBytes=0 function e.read(f,g,h)local i,j=g or 1,(h~=nil and{h}or{true})[1]local k=string.sub(f.Source,f.Offset+1,f.Offset+i)local l=string.len(k)local m=i-l if j then f:seek(i)end f.LastUnreadBytes=m return k end function e.seek(f,g)local h=g or 1 f.Offset=math.clamp(f.Offset+h,0,f.Length)f.IsFinished=f.Offset>=f.Length end function e.append(f,g)f.Source=f.Source..g f.Length=string.len(f.Source)f:seek(0)end function e.toEnd(f)f:seek(f.Length)end return e end function a.compress(d)local e,f={},c(d)if f.Length>12 then local g=f:read(4)local h,i,j,k,l=g,g,'','',true repeat l=true local m=f:read()if b(h,m)then local n=f:read(3,false)if string.len(n)<3 then k=m..n f:seek(3)else j=m..n local o=b(h,j)if o then f:seek(3)repeat local p=f:read(1,false)local q=j..p local r=b(h,q)if r then j=q o=r f:seek(1)end until not b(h,q)or f.IsFinished local p,q=string.len(j),true if f.Length-f.Offset<=5 then k=j q=false end if q then l=false local r=string.len(h)-o h=h..j table.insert(e,{Literal=i,LiteralLength=string.len(i),MatchOffset=r+1,MatchLength=p})i=''end else k=m end end else k=m end if l then i=i..k h=h..m end until f.IsFinished table.insert(e,{Literal=i,LiteralLength=string.len(i)})else local g=f.Source e[1]={Literal=g,LiteralLength=string.len(g)}end local g=string.rep('\0',4)local function h(i)g=g..i end for i,j in e do local k,l=j.LiteralLength,(j.MatchLength or 4)-4 local m,n=math.clamp(k,0,15),math.clamp(l,0,15)local o=bit32.lshift(m,4)+n h(string.pack('<I1',o))if k>=15 then k=k-15 repeat local p=math.clamp(k,0,0xff)h(string.pack('<I1',p))if p==0xff then k=k-255 end until p<0xff end h(j.Literal)if i~=#e then h(string.pack('<I2',j.MatchOffset))if l>=15 then l=l-15 repeat local p=math.clamp(l,0,0xff)h(string.pack('<I1',p))if p==0xff then l=l-255 end until p<0xff end end end local i,j=string.len(g)-4,f.Length return string.pack('<I4',i)..string.pack('<I4',j)..g end function a.decompress(d)local e=c(d)local f,g=string.unpack('<I4',e:read(4)),string.unpack('<I4',e:read(4))string.unpack('<I4',e:read(4))if f==0 then return e:read(g)end local h=c''repeat local i=string.byte(e:read())local j,k=bit32.rshift(i,4),bit32.band(i,15)+4 if j>=15 then repeat local l=string.byte(e:read())j=j+l until l~=0xff end local l=e:read(j)h:append(l)h:toEnd()if h.Length<g then local m=string.unpack('<I2',e:read(2))if k>=19 then repeat local n=string.byte(e:read())k=k+n until n~=0xff end h:seek(-m)local n,o,p,q=h.Offset,h:read(k),h.LastUnreadBytes,nil if p then repeat h.Offset=n q=h:read(p)p=h.LastUnreadBytes o=o..q until p<=0 end h:append(o)h:toEnd()end until h.Length>=g return h.Source end
    LZ4 = a
end
local VMCompressionLoader = [===[return({LoadLZ4=function(self)local LZ4 do local a={}local function b(c,d)return string.find(c,d,0,true)end local function c(d)local e={}e.Offset=0 e.Source=d e.Length=string.len(d)e.IsFinished=false e.LastUnreadBytes=0 function e.read(f,g,h)local i,j=g or 1,(h~=nil and{h}or{true})[1]local k=string.sub(f.Source,f.Offset+1,f.Offset+i)local l=string.len(k)local m=i-l if j then f:seek(i)end f.LastUnreadBytes=m return k end function e.seek(f,g)local h=g or 1 f.Offset=math.clamp(f.Offset+h,0,f.Length)f.IsFinished=f.Offset>=f.Length end function e.append(f,g)f.Source=f.Source..g f.Length=string.len(f.Source)f:seek(0)end function e.toEnd(f)f:seek(f.Length)end return e end function a.compress(d)local e,f={},c(d)if f.Length>12 then local g=f:read(4)local h,i,j,k,l=g,g,'','',true repeat l=true local m=f:read()if b(h,m)then local n=f:read(3,false)if string.len(n)<3 then k=m..n f:seek(3)else j=m..n local o=b(h,j)if o then f:seek(3)repeat local p=f:read(1,false)local q=j..p local r=b(h,q)if r then j=q o=r f:seek(1)end until not b(h,q)or f.IsFinished local p,q=string.len(j),true if f.Length-f.Offset<=5 then k=j q=false end if q then l=false local r=string.len(h)-o h=h..j table.insert(e,{Literal=i,LiteralLength=string.len(i),MatchOffset=r+1,MatchLength=p})i=''end else k=m end end else k=m end if l then i=i..k h=h..m end until f.IsFinished table.insert(e,{Literal=i,LiteralLength=string.len(i)})else local g=f.Source e[1]={Literal=g,LiteralLength=string.len(g)}end local g=string.rep('\0',4)local function h(i)g=g..i end for i,j in e do local k,l=j.LiteralLength,(j.MatchLength or 4)-4 local m,n=math.clamp(k,0,15),math.clamp(l,0,15)local o=bit32.lshift(m,4)+n h(string.pack('<I1',o))if k>=15 then k=k-15 repeat local p=math.clamp(k,0,0xff)h(string.pack('<I1',p))if p==0xff then k=k-255 end until p<0xff end h(j.Literal)if i~=#e then h(string.pack('<I2',j.MatchOffset))if l>=15 then l=l-15 repeat local p=math.clamp(l,0,0xff)h(string.pack('<I1',p))if p==0xff then l=l-255 end until p<0xff end end end local i,j=string.len(g)-4,f.Length return string.pack('<I4',i)..string.pack('<I4',j)..g end function a.decompress(d)local e=c(d)local f,g=string.unpack('<I4',e:read(4)),string.unpack('<I4',e:read(4))string.unpack('<I4',e:read(4))if f==0 then return e:read(g)end local h=c''repeat local i=string.byte(e:read())local j,k=bit32.rshift(i,4),bit32.band(i,15)+4 if j>=15 then repeat local l=string.byte(e:read())j=j+l until l~=0xff end local l=e:read(j)h:append(l)h:toEnd()if h.Length<g then local m=string.unpack('<I2',e:read(2))if k>=19 then repeat local n=string.byte(e:read())k=k+n until n~=0xff end h:seek(-m)local n,o,p,q=h.Offset,h:read(k),(h.LastUnreadBytes)if p then repeat h.Offset=n q=h:read(p)p=h.LastUnreadBytes o=o..q until p<=0 end h:append(o)h:toEnd()end until h.Length>=g return h.Source end LZ4=a end self.LZ4=LZ4 end,LoadBase85=function(self)local Base85 do local a,b,c={},'~>',85 local function d(e,f,g,h)return bit32.bor(bit32.lshift(e,24),bit32.lshift(f,16),bit32.lshift(g,8),h)end local function e(f)return{bit32.band(bit32.rshift(f,24),0xff),bit32.band(bit32.rshift(f,16),0xff),bit32.band(bit32.rshift(f,8),0xff),bit32.band(f,0xff)}end local function f(g)local h={}for i=5,1,-1 do local j=g%c h[i]=string.char(j+33)g=math.floor(g/c)end return table.concat(h)end function a.encode(g)if not g or#g==0 then return''end local h,i,j={},1,#g while i<=j do local k,l,m,n,o=string.byte(g,i)or 0,string.byte(g,i+1)or 0,string.byte(g,i+2)or 0,string.byte(g,i+3)or 0,math.min(4,j-i+1)local p=d(k,l,m,n)if p==0 and o==4 then table.insert(h,'z')else local q=f(p)if o<4 then local r=5-(o+1)q=q:sub(1,5-r)end table.insert(h,q)end i=i+4 end return table.concat(h)..b end local function g(h)local i=0 for j=1,#h do local k=string.byte(h,j)-33 if k<0 or k>84 then error('Invalid Base85 character at position '..j..': '..string.char(k+33))end i=i*c+k end return i end function a.decode(h)if not h or#h==0 then return''end local i=h:gsub('%s+','')if i:sub(-2)==b then i=i:sub(1,-3)end if#i==0 then return''end local j,k,l={},1,#i while k<=l do local m=i:sub(k,k)if m=='z'then table.insert(j,string.char(0,0,0,0))k=k+1 else local n=i:sub(k,k+4)local o=#n if o<5 then n=n..string.rep('u',5-o)end local p=g(n)local q,r=(e(p))if o==1 then r=0 elseif o==2 then r=1 elseif o==3 then r=2 elseif o==4 then r=3 else r=4 end if r>=1 then table.insert(j,string.char(q[1]))end if r>=2 then table.insert(j,string.char(q[2]))end if r>=3 then table.insert(j,string.char(q[3]))end if r>=4 then table.insert(j,string.char(q[4]))end k=k+5 end end return table.concat(j)end Base85=a end self.Base85=Base85 end,Decode=function(self,str)if not self.Base85 then self:LoadBase85()end if not self.LZ4 then self:LoadLZ4()end local decoded=self.Base85.decode(str)local decompressed=self.LZ4.decompress(decoded)return decompressed end,Load=function(self)return(loadstring or load)(self:Decode([==[<INSERT>]==]))end}):Load()(...)]===]
local config, Ast, Enums, util, logger = require'../config', require'./ast', require'./enums', require'./util', require'../logger'
local lookupify, LuaVersion, AstKind, Unparser = util.lookupify, Enums.LuaVersion, Ast.AstKind, {}

Unparser.SPACE = config.SPACE
Unparser.TAB = config.TAB

function Unparser.new(self, settings)
    local LuaVersion = settings.LuaVersion or LuaVersion.LuaU
    local conventions = Enums.Conventions[LuaVersion]
    local unparser = {
        LuaVersion = LuaVersion,
        conventions = conventions,
        identCharsLookup = lookupify(conventions.IdentChars),
        numberCharsLookup = lookupify(conventions.NumberChars),
        prettyPrint = settings and settings.PrettyPrint or false,
        notIdentPattern = '[^' .. table.concat(conventions.IdentChars, '') .. ']',
        numberPattern = '^[' .. table.concat(conventions.NumberChars, '') .. ']',
        highlight = settings and settings.Highlight or false,
        keywordsLookup = lookupify(conventions.Keywords),
    }

    setmetatable(unparser, self)

    self.__index = self

    return unparser
end

local function escapeString(str)
    str = util.escape(str)

    return str
end
local function customescape(str)
    return str:gsub('.', function(char)
        if char == '\\' then
            return '\\\\'
        end
        if char == '\n' then
            return '\\n'
        end
        if char == '\r' then
            return '\\r'
        end
        if char == '"' then
            return '{"\\""}'
        end
        if char == '`' then
            return '{"`"}'
        end
        if char == '{' then
            return '\\{'
        end
        if char == '}' then
            return '\\}'
        end

        local b = string.byte(char)

        if b >= 127 or b <= 32 then
            return '{"' .. util.escape(char) .. '"}'
        end

        return char
    end)
end

function Unparser.isValidIdentifier(self, source)
    if (string.find(source, self.notIdentPattern)) then
        return false
    end
    if (string.find(source, self.numberPattern)) then
        return false
    end
    if self.keywordsLookup[source] then
        return false
    end

    return #source > 0
end
function Unparser.setPrettyPrint(self, prettyPrint)
    self.prettyPrint = prettyPrint
end
function Unparser.getPrettyPrint(self)
    return self.prettyPrint
end
function Unparser.tabs(self, i, ws_needed)
    return self.prettyPrint and string.rep(self.TAB, i) or ws_needed and self.SPACE or ''
end
function Unparser.newline(self, ws_needed)
    return self.prettyPrint and '\n' or ws_needed and self.SPACE or ''
end
function Unparser.whitespaceIfNeeded(self, following, ws)
    if (self.prettyPrint or self.identCharsLookup[string.sub(following, 1, 1)]) then
        return ws or self.SPACE
    end

    return ''
end
function Unparser.whitespaceIfNeeded2(self, leading, ws)
    if (self.prettyPrint or self.identCharsLookup[string.sub(leading, #leading, #leading)]) then
        return ws or self.SPACE
    end

    return ''
end
function Unparser.optionalWhitespace(self, ws)
    return self.prettyPrint and (ws or self.SPACE) or ''
end
function Unparser.whitespace(self, ws)
    return self.SPACE or ws
end
function Unparser.unparse(self, ast)
    if (ast.kind ~= AstKind.TopNode) then
        logger:error'Unparser:unparse expects a TopNode as first argument'
    end

    local CodeOutput = self:unparseBlock(ast.body)
    --[[local encoded = Base85.encode(LZ4.compress(CodeOutput))
    local escaped = encoded:gsub("%%", "%%%%")
    local Loader = VMCompressionLoader:gsub("<INSERT>", escaped)
    return Loader]]
return CodeOutput
end
function Unparser.unparseBlock(self, block, tabbing)
    local code = ''

    if (#block.statements < 1) then
        return self:whitespace()
    end

    for i, statement in ipairs(block.statements)do
        if (statement.kind ~= AstKind.NopStatement) then
            local statementCode = self:unparseStatement(statement, tabbing)

            if (not self.prettyPrint and #code > 0 and string.sub(statementCode, 1, 1) == '(') then
                statementCode = ';' .. statementCode
            end

            local ws = self:whitespaceIfNeeded2(code, self:whitespaceIfNeeded(statementCode, self:newline(true)))

            if i ~= 1 then
                code = code .. ws
            end
            if (self.prettyPrint) then
                statementCode = statementCode .. ';'
            end

            code = code .. statementCode
        end
    end

    return code
end
function Unparser.unparseStatement(self, statement, tabbing)
    tabbing = tabbing and tabbing + 1 or 0

    local code = ''

    if (statement.kind == AstKind.ContinueStatement) then
        code = 'continue'
    elseif (statement.kind == AstKind.BreakStatement) then
        code = 'break'
    elseif (statement.kind == AstKind.DoStatement) then
        local bodyCode = self:unparseBlock(statement.body, tabbing)

        code = 'do' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.WhileStatement) then
        local expressionCode, bodyCode = self:unparseExpression(statement.condition, tabbing), self:unparseBlock(statement.body, tabbing)

        code = 'while' .. self:whitespaceIfNeeded(expressionCode) .. expressionCode .. self:whitespaceIfNeeded2(expressionCode) .. 'do' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.RepeatStatement) then
        local expressionCode, bodyCode = self:unparseExpression(statement.condition, tabbing), self:unparseBlock(statement.body, tabbing)

        code = 'repeat' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode .. self:whitespaceIfNeeded2(bodyCode, self:newline() .. self:tabs(tabbing, true)) .. 'until' .. self:whitespaceIfNeeded(expressionCode) .. expressionCode
    elseif (statement.kind == AstKind.ForStatement) then
        local bodyCode = self:unparseBlock(statement.body, tabbing)

        code = 'for' .. self:whitespace() .. statement.scope:getVariableName(statement.id) .. self:optionalWhitespace() .. '='
        code = code .. self:optionalWhitespace() .. self:unparseExpression(statement.initialValue, tabbing) .. ','
        code = code .. self:optionalWhitespace() .. self:unparseExpression(statement.finalValue, tabbing) .. ','

        local incrementByCode = statement.incrementBy and self:unparseExpression(statement.incrementBy, tabbing) or '1'

        code = code .. self:optionalWhitespace() .. incrementByCode .. self:whitespaceIfNeeded2(incrementByCode) .. 'do' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.ForInStatement) then
        code = 'for' .. self:whitespace()

        for i, id in ipairs(statement.ids)do
            if (i ~= 1) then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. statement.scope:getVariableName(id)
        end

        code = code .. self:whitespace() .. 'in'

        local exprcode = self:unparseExpression(statement.expressions[1], tabbing)

        code = code .. self:whitespaceIfNeeded(exprcode) .. exprcode

        for i = 2, #statement.expressions, 1 do
            exprcode = self:unparseExpression(statement.expressions[i], tabbing)
            code = code .. ',' .. self:optionalWhitespace() .. exprcode
        end

        local bodyCode = self:unparseBlock(statement.body, tabbing)

        code = code .. self:whitespaceIfNeeded2(code) .. 'do' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.IfStatement) then
        local exprcode, bodyCode = self:unparseExpression(statement.condition, tabbing), self:unparseBlock(statement.body, tabbing)

        code = 'if' .. self:whitespaceIfNeeded(exprcode) .. exprcode .. self:whitespaceIfNeeded2(exprcode) .. 'then' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode

        for i, eif in ipairs(statement.elseifs)do
            exprcode = self:unparseExpression(eif.condition, tabbing)
            bodyCode = self:unparseBlock(eif.body, tabbing)
            code = code .. self:newline(false) .. self:whitespaceIfNeeded2(code, self:tabs(tabbing, true)) .. 'elseif' .. self:whitespaceIfNeeded(exprcode) .. exprcode .. self:whitespaceIfNeeded2(exprcode) .. 'then' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode
        end

        if (statement.elsebody) then
            bodyCode = self:unparseBlock(statement.elsebody, tabbing)
            code = code .. self:newline(false) .. self:whitespaceIfNeeded2(code, self:tabs(tabbing, true)) .. 'else' .. self:whitespaceIfNeeded(bodyCode, self:newline(true)) .. bodyCode
        end

        code = code .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.FunctionDeclaration) then
        local funcname = statement.scope:getVariableName(statement.id)

        for _, index in ipairs(statement.indices)do
            funcname = funcname .. '.' .. index
        end

        code = 'function' .. self:whitespace() .. funcname .. '('

        for i, arg in ipairs(statement.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end
            if (arg.kind == AstKind.VarargExpression) then
                code = code .. '...'
            else
                code = code .. arg.scope:getVariableName(arg.id)
            end
        end

        code = code .. ')'

        local bodyCode = self:unparseBlock(statement.body, tabbing)

        code = code .. self:newline(false) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.LocalFunctionDeclaration) then
        local funcname = statement.scope:getVariableName(statement.id)

        code = 'local' .. self:whitespace() .. 'function' .. self:whitespace() .. funcname .. '('

        for i, arg in ipairs(statement.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end
            if (arg.kind == AstKind.VarargExpression) then
                code = code .. '...'
            else
                code = code .. arg.scope:getVariableName(arg.id)
            end
        end

        code = code .. ')'

        local bodyCode = self:unparseBlock(statement.body, tabbing)

        code = code .. self:newline(false) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'
    elseif (statement.kind == AstKind.LocalVariableDeclaration) then
        code = 'local' .. self:whitespace()

        for i, id in ipairs(statement.ids)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. statement.scope:getVariableName(id)
        end

        if (#statement.expressions > 0) then
            code = code .. self:optionalWhitespace() .. '=' .. self:optionalWhitespace()

            for i, expr in ipairs(statement.expressions)do
                if i > 1 then
                    code = code .. ',' .. self:optionalWhitespace()
                end

                code = code .. self:unparseExpression(expr, tabbing + 1)
            end
        end
    elseif (statement.kind == AstKind.FunctionCallStatement) then
        if not (statement.base.kind == AstKind.IndexExpression or statement.base.kind == AstKind.VariableExpression) then
            code = '(' .. self:unparseExpression(statement.base, tabbing) .. ')'
        else
            code = self:unparseExpression(statement.base, tabbing)
        end

        code = code .. '('

        for i, arg in ipairs(statement.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. self:unparseExpression(arg, tabbing)
        end

        code = code .. ')'
    elseif (statement.kind == AstKind.PassSelfFunctionCallStatement) then
        if not (statement.base.kind == AstKind.IndexExpression or statement.base.kind == AstKind.VariableExpression) then
            code = '(' .. self:unparseExpression(statement.base, tabbing) .. ')'
        else
            code = self:unparseExpression(statement.base, tabbing)
        end

        code = code .. ':' .. statement.passSelfFunctionName
        code = code .. '('

        for i, arg in ipairs(statement.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. self:unparseExpression(arg, tabbing)
        end

        code = code .. ')'
    elseif (statement.kind == AstKind.AssignmentStatement) then
        for i, primary_expr in ipairs(statement.lhs)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. self:unparseExpression(primary_expr, tabbing)
        end

        code = code .. self:optionalWhitespace() .. '=' .. self:optionalWhitespace()

        for i, expr in ipairs(statement.rhs)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. self:unparseExpression(expr, tabbing + 1)
        end
    elseif (statement.kind == AstKind.ReturnStatement) then
        code = 'return'

        if (#statement.args > 0) then
            local exprcode = self:unparseExpression(statement.args[1], tabbing)

            code = code .. self:whitespaceIfNeeded(exprcode) .. exprcode

            for i = 2, #statement.args, 1 do
                exprcode = self:unparseExpression(statement.args[i], tabbing)
                code = code .. ',' .. self:optionalWhitespace() .. exprcode
            end
        end
    elseif self.LuaVersion == LuaVersion.LuaU then
        local compoundOperators = {
            [AstKind.CompoundAddStatement] = '+=',
            [AstKind.CompoundSubStatement] = '-=',
            [AstKind.CompoundMulStatement] = '*=',
            [AstKind.CompoundDivStatement] = '/=',
            [AstKind.CompoundModStatement] = '%=',
            [AstKind.CompoundPowStatement] = '^=',
            [AstKind.CompoundConcatStatement] = '..=',
        }
        local operator = compoundOperators[statement.kind]

        if operator then
            code = code .. self:unparseExpression(statement.lhs, tabbing) .. self:optionalWhitespace() .. operator .. self:optionalWhitespace() .. self:unparseExpression(statement.rhs, tabbing)
        else
            logger:error(string.format('"%s" is not a valid unparseable statement in %s!', statement.kind, self.LuaVersion))
        end
    end

    return self:tabs(tabbing, false) .. code
end
function Unparser.unparseExpression(self, expression, tabbing)
    local code = ''

    if (expression.kind == AstKind.BooleanExpression) then
        if (expression.value) then
            return 'true'
        else
            return 'false'
        end
    end
    if (expression.kind == AstKind.NumberExpression) then
        local str = tostring(expression.value)

        if (str == 'inf') then
            return '1/0'
        end
        if (str == '-inf') then
            return '-1/0'
        end
        if (str:sub(1, 2) == '0.') then
            str = str:sub(2)
        end

        return str
    end
    if (expression.kind == AstKind.VariableExpression or expression.kind == AstKind.AssignmentVariable) then
        return expression.scope:getVariableName(expression.id)
    end
    if (expression.kind == AstKind.StringExpression) then
        return (self.LuaVersion == LuaVersion.LuaU and '({`' .. customescape(expression.value) .. '`})[1]') or '"' .. escapeString(expression.value) .. '"'
    end
    if (expression.kind == AstKind.NilExpression) then
        return 'nil'
    end
    if (expression.kind == AstKind.VarargExpression) then
        return '...'
    end

    local k = AstKind.OrExpression

    if (expression.kind == k) then
        local lhs, rhs = self:unparseExpression(expression.lhs, tabbing), self:unparseExpression(expression.rhs, tabbing)

        return lhs .. self:whitespaceIfNeeded2(lhs) .. 'or' .. self:whitespaceIfNeeded(rhs) .. rhs
    end

    k = AstKind.AndExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:whitespaceIfNeeded2(lhs) .. 'and' .. self:whitespaceIfNeeded(rhs) .. rhs
    end

    k = AstKind.LessThanExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '<' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.GreaterThanExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '>' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.LessThanOrEqualsExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '<=' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.GreaterThanOrEqualsExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '>=' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.NotEqualsExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '~=' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.EqualsExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '==' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.StrCatExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end
        if (self.numberCharsLookup[string.sub(lhs, #lhs, #lhs)]) then
            lhs = lhs .. ' '
        end

        return lhs .. self:optionalWhitespace() .. '..' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.AddExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '+' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.SubExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end
        if string.sub(rhs, 1, 1) == '-' then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '-' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.MulExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '*' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.DivExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '/' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.ModExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '%' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.PowExpression

    if (expression.kind == k) then
        local lhs = self:unparseExpression(expression.lhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.lhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            lhs = '(' .. lhs .. ')'
        end

        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return lhs .. self:optionalWhitespace() .. '^' .. self:optionalWhitespace() .. rhs
    end

    k = AstKind.NotExpression

    if (expression.kind == k) then
        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return 'not' .. self:whitespaceIfNeeded(rhs) .. rhs
    end

    k = AstKind.NegateExpression

    if (expression.kind == k) then
        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end
        if string.sub(rhs, 1, 1) == '-' then
            rhs = '(' .. rhs .. ')'
        end

        return '-' .. rhs
    end

    k = AstKind.LenExpression

    if (expression.kind == k) then
        local rhs = self:unparseExpression(expression.rhs, tabbing)

        if (Ast.astKindExpressionToNumber(expression.rhs.kind) >= Ast.astKindExpressionToNumber(k)) then
            rhs = '(' .. rhs .. ')'
        end

        return '#' .. rhs
    end

    k = AstKind.IndexExpression

    if (expression.kind == k or expression.kind == AstKind.AssignmentIndexing) then
        local base = self:unparseExpression(expression.base, tabbing)

        if (Ast.astKindExpressionToNumber(expression.base.kind) > Ast.astKindExpressionToNumber(k)) then
            base = '(' .. base .. ')'
        end
        if (expression.index.kind == AstKind.StringExpression and self:isValidIdentifier(expression.index.value)) then
            return base .. '.' .. expression.index.value
        end

        local index = self:unparseExpression(expression.index, tabbing)

        return base .. '[' .. index .. ']'
    end

    k = AstKind.FunctionCallExpression

    if (expression.kind == k) then
        if not (expression.base.kind == AstKind.IndexExpression or expression.base.kind == AstKind.VariableExpression) then
            code = '(' .. self:unparseExpression(expression.base, tabbing) .. ')'
        else
            code = self:unparseExpression(expression.base, tabbing)
        end

        code = code .. '('

        for i, arg in ipairs(expression.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. self:unparseExpression(arg, tabbing)
        end

        code = code .. ')'

        return code
    end

    k = AstKind.PassSelfFunctionCallExpression

    if (expression.kind == k) then
        if not (expression.base.kind == AstKind.IndexExpression or expression.base.kind == AstKind.VariableExpression) then
            code = '(' .. self:unparseExpression(expression.base, tabbing) .. ')'
        else
            code = self:unparseExpression(expression.base, tabbing)
        end

        code = code .. ':' .. expression.passSelfFunctionName
        code = code .. '('

        for i, arg in ipairs(expression.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end

            code = code .. self:unparseExpression(arg, tabbing)
        end

        code = code .. ')'

        return code
    end

    k = AstKind.FunctionLiteralExpression

    if (expression.kind == k) then
        code = 'function('

        for i, arg in ipairs(expression.args)do
            if i > 1 then
                code = code .. ',' .. self:optionalWhitespace()
            end
            if (arg.kind == AstKind.VarargExpression) then
                code = code .. '...'
            else
                code = code .. arg.scope:getVariableName(arg.id)
            end
        end

        code = code .. ')'

        local bodyCode = self:unparseBlock(expression.body, tabbing)

        code = code .. self:newline(false) .. bodyCode .. self:newline(false) .. self:whitespaceIfNeeded2(bodyCode, self:tabs(tabbing, true)) .. 'end'

        return code
    end

    k = AstKind.TableConstructorExpression

    if (expression.kind == k) then
        if (#expression.entries == 0) then
            return '{}'
        end

        local inlineTable, tableTabbing = #expression.entries <= 3, tabbing + 1

        code = '{'

        if inlineTable then
            code = code .. self:optionalWhitespace()
        else
            code = code .. self:optionalWhitespace(self:newline() .. self:tabs(tableTabbing))
        end

        local p = false

        for i, entry in ipairs(expression.entries)do
            p = true

            local sep = self.prettyPrint and ',' or (math.random(1, 2) == 1 and ',' or ';')

            if i > 1 and not inlineTable then
                code = code .. sep .. self:optionalWhitespace(self:newline() .. self:tabs(tableTabbing))
            elseif i > 1 then
                code = code .. sep .. self:optionalWhitespace()
            end
            if (entry.kind == AstKind.KeyedTableEntry) then
                if (entry.key.kind == AstKind.StringExpression and self:isValidIdentifier(entry.key.value)) then
                    code = code .. entry.key.value
                else
                    code = code .. '[' .. self:unparseExpression(entry.key, tableTabbing) .. ']'
                end

                code = code .. self:optionalWhitespace() .. '=' .. self:optionalWhitespace() .. self:unparseExpression(entry.value, tableTabbing)
            else
                code = code .. self:unparseExpression(entry.value, tableTabbing)
            end
        end

        if inlineTable then
            return code .. self:optionalWhitespace() .. '}'
        end

        return code .. self:optionalWhitespace((p and ',' or '') .. self:newline() .. self:tabs(tabbing)) .. '}'
    end

    logger:error(string.format('"%s" is not a valid unparseable expression', expression.kind))
end

return Unparser
