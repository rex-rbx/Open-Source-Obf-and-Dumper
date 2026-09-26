local Step = require("../step");
local Ast = require("../ast");
local visitast = require("../visitast");
local AstKind = Ast.AstKind;
local AddVararg = Step:extend();
AddVararg.Description = "This step adds variadic arguments to all functions";
AddVararg.Name = "Add Vararg";
AddVararg.SettingsDescriptor = {
}
function AddVararg:init(settings)
end
function AddVararg:apply(ast)
	visitast(ast, nil, function(node)
		if node.kind == AstKind.FunctionDeclaration or node.kind == AstKind.LocalFunctionDeclaration or node.kind == AstKind.FunctionLiteralExpression then
			if #node.args < 1 or node.args[#node.args].kind ~= AstKind.VarargExpression then
				node.args[#node.args + 1] = Ast.VarargExpression();
			end
		end
	end)
end
return AddVararg;