return {
["Strong"] = {
LuaVersion = "LuaU";
VarNamePrefix = "";
NameGenerator = "Mangled";
PrettyPrint = false;
Steps = {
    {Name = "Vmify", Settings = {}},
    {Name = "EncryptStrings", Settings = {}},
    {Name = "WrapInFunction", Settings = {Iterations = 6}},
},
},
["Lua51"] = {
LuaVersion = "Lua51";
VarNamePrefix = "";
NameGenerator = "Confuse";
PrettyPrint = false;
Steps = {
    {Name = "Vmify", Settings = {}},
    {Name = "EncryptStrings", Settings = {}},
    {Name = "Vmify", Settings = {}},
    {Name = "WrapInFunction", Settings = {Iterations = 6}},
},
},
["BasicLua51"] = {
LuaVersion = "Lua51";
VarNamePrefix = "";
NameGenerator = "Confuse";
PrettyPrint = false;
Steps = {
    {Name = "EncryptStrings", Settings = {}},
    {Name = "ProxifyLocals", Settings = {}},
    {Name = "AddVararg", Settings = {}},
},
},
["Basic"] = {
LuaVersion = "LuaU";
VarNamePrefix = "";
NameGenerator = "Confuse";
PrettyPrint = false;
Steps = {
    {Name = "EncryptStrings", Settings = {}},
    {Name = "ProxifyLocals", Settings = {}},
    {Name = "AddVararg", Settings = {}},
},
}
}