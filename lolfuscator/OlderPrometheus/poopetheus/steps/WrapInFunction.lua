local Step = require("../step");
local Ast = require("../ast");
local Scope = require("../scope");
local WrapInFunction = Step:extend();
WrapInFunction.Description = "This step wraps the entire script into a IIFE";
WrapInFunction.Name = "Wrap in Function";
WrapInFunction.SettingsDescriptor = {
	Iterations = {
		name = "Iterations",
		description = "The Number Of Iterations",
		type = "number",
		default = 1,
		min = 1,
		max = nil,
	}
}
function WrapInFunction:init(settings)
end
function WrapInFunction:apply(ast)
	for i = 1, self.Iterations, 1 do
		local body = ast.body;
		local scope = Scope:new(ast.globalScope);
		body.scope:setParent(scope);
		ast.body = Ast.Block({
			Ast.ReturnStatement({
				Ast.FunctionCallExpression(Ast.FunctionLiteralExpression({
					Ast.VarargExpression()
				}, body), {
					Ast.VarargExpression()
				})
			});
		}, scope);
	end
end
return WrapInFunction;