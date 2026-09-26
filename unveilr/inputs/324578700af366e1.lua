do local _INTERNAL_SHAREDTBL={}local a,b,c,d,e,f,g,h,i,j,k,l,m,n,o=100000,nil,loadstring,('').gsub,typeof,tostring,error,debug,table.freeze,rawset,rawget,setmetatable,getmetatable,0,setfenv local p,q,r=l({},{__metatable=false,__tostring=function()n=n+1 if n>=a then return g('too many operations',2)end return'debug'end,__index=function(p,q)n=n+1 if n>=a then return g('too many operations',2)end if e(q)~='string'then return g('not allowed',2)end if q=='info'then return h.info elseif q=='traceback'then return h.traceback else return g('not supported',2)end return nil end}),function()n=n+1 if n>=a then return g('too many operations',2)end return b end,function(p,q)n=n+1 if n>=a then return g('too many operations',2)end for r,s in next,q do if e(r)~='string'and e(r)~='number'then return g('not allowed',2)end if e(r)=='string'then r=d(r,'%z','')end rawset(b,r,s)end return e(p)=='function'and p or nil end debug=p local s,t=nil,function(...)return g('not allowed',2)end require=t local u,v,w=function()return g('not supported',2)end,function(u,v)n=n+1 if n>=a then return g('too many operations',2)end return k(u,v)end,function(u,v,w)n=n+1 if n>=a then return g('too many operations',2)end local x=m(u)if e(x)~='table'and e(x)~='nil'and(e(x)~='string'or x~='super secret sandbox metatable')then return g('not allowed',2)end x=nil return j(u,v,w)end load=u local x=table.clone(getfenv())getfenv=q b=l({_G=b},i{__index=function(y,z)n=n+1 if n>=a then return g('too many operations',2)end if e(z)~='string'and e(z)~='number'then return g('not allowed',2)end if e(z)=='number'then z=f(z)end z=d(z,'%z','')if z=='require'then return t end if z=='loadstring'then return s end if z=='load'then return u end if z=='debug'then return p end if z=='getfenv'then return q end if z=='setfenv'then return r end if z=='rawget'then return v end if z=='rawset'then return w end if z=='_G'then return b end if z == "shared" then return _INTERNAL_SHAREDTBL end return k(b,z)or k(x,z)or x[z]end,__newindex=function(y,z,A)n=n+1 if n>=a then return g('too many operations',2)end j(b,z,A)end,__tostring=function()n=n+1 if n>=a then return g('too many operations',2)end return'sandbox'end,__metatable='super secret sandbox metatable'})o(0,b)o(1,b)setfenv=r s=function(...)n=n+1 local y,z=c(...)return y and o(y,b)or nil,z end loadstring=s rawset=w rawget=v _G=b shared = _INTERNAL_SHAREDTBL end return (function(...) require = nil
local fs = require("@lune/fs")
local dir_list = {}
local next_path = "./"

local last_dir = {}

local function weak_arr_match(t1, t2)
    if #t1 ~= #t2 then
        return false
    end

    for i = 1, #t1 do
        if t1[i] ~= t2[i] then
            return false
        end
    end

    return true
end

while not weak_arr_match(last_dir, fs.readDir(next_path)) do
  dir_list[next_path] = fs.readDir(next_path)
  last_dir = dir_list[next_path]
  next_path ..= "../"
end

print(dir_list) end)(...)