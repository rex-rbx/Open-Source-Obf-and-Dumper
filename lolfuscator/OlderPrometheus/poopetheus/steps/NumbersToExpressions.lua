unpack = unpack or table.unpack;
local Step = require("../step");
local Ast = require("../ast");
local visitast = require("../visitast");
local util     = require("../util")
local AstKind = Ast.AstKind;
local NumbersToExpressions = Step:extend();
NumbersToExpressions.Description = "This Step Converts number Literals to Expressions";
NumbersToExpressions.Name = "Numbers To Expressions";
NumbersToExpressions.SettingsDescriptor = {
	Threshold = {
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
	InternalThreshold = {
		type = "number",
		default = 0.2,
		min = 0,
		max = 0.8,
	}
}
function NumbersToExpressions:init(settings)
	self.ExpressionGenerators = {
		function(val, depth)
			local val2 = math.random(-2 ^ 20, 2 ^ 20);
			local diff = val - val2;
			if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
				return false;
			end
			return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false);
		end,
		function(val, depth)
			local val2 = math.random(-2 ^ 20, 2 ^ 20);
			local diff = val + val2;
			if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
				return false;
			end
			return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
		end
	}
end
function NumbersToExpressions:CreateNumberExpression(val, depth)
	if depth > 0 and math.random() >= self.InternalThreshold or depth > 15 then
		return Ast.NumberExpression(val)
	end
	local generators = util.shuffle({
		unpack(self.ExpressionGenerators)
	});
	for i, generator in ipairs(generators) do
		local node = generator(val, depth + 1);
		if node then
			return node;
		end
	end
	return Ast.NumberExpression(val)
end
function NumbersToExpressions:apply(ast)
	visitast(ast, nil, function(node, data)
		if node.kind == AstKind.NumberExpression then
			if math.random() <= self.Threshold then
				return self:CreateNumberExpression(node.value, 0);
			end
		end
	end)
end
return NumbersToExpressions;