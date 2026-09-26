local GenerateIdentifer = {}

local Char = string.char
local Random = math.random
local Concat = table.concat

function GenerateIdentifer.GenerateString(Length: number): string
	local Result = table.create(Length)

	for Index = 1, Length do
		Result[Index] = Char(Random(65, 90))
	end

	return Concat(Result)
end

function GenerateIdentifer.GenerateLowercase(Length: number): string
	local Result = table.create(Length)

	for Index = 1, Length do
		Result[Index] = Char(Random(97, 122))
	end

	return Concat(Result)
end

function GenerateIdentifer.GenerateAlias(UsedNames: { [string]: boolean }): string
	local Alias
	repeat
		Alias = "_" .. Char(Random(97, 122)) .. Random(10000, 99999)
	until not UsedNames[Alias]
	UsedNames[Alias] = true
	return Alias
end

return GenerateIdentifer