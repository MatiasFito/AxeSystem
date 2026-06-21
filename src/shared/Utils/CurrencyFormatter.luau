--!strict

local CurrencyFormatter = {}

function CurrencyFormatter.formatGold(amount: number?): string
	return tostring(math.max(0, math.floor(amount or 0)))
end

return CurrencyFormatter
