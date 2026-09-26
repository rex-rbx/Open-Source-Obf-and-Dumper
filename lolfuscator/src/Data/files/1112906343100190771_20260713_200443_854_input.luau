local a = JEW_LINE()
local b = JEW_OBFUSCATED()
print(a)
print(b)

if JEW_OBFUSCATED then
	print("dead code elim works")
else
	print("this should never run")
end

if not JEW_OBFUSCATED then
	print("this should never run either")
end

local fn = JEW_OMIT(function()
	print("omit works")
end)
fn()

local vmFn = JEW_VM(function()
	print("vm works")
end)
vmFn()

local cffFn = JEW_CFF(function()
	print("cff works")
end)
cffFn()

print(JEW_ENCSTR("encstr works"))
print(JEW_ENC_STR("encstr works"))
print(JEW_ENCNUM(12345))
print(JEW_COMPRESS("compress works"))
