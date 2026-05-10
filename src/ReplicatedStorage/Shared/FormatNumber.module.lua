local SUFFIXES = {
	{ Value = 1e21, Suffix = "sx" },
	{ Value = 1e18, Suffix = "qn" },
	{ Value = 1e15, Suffix = "qd" },
	{ Value = 1e12, Suffix = "t" },
	{ Value = 1e9, Suffix = "b" },
	{ Value = 1e6, Suffix = "m" },
	{ Value = 1e3, Suffix = "k" },
}

local function trimTrailingZero(text)
	return text:gsub("%.0$", "")
end

local function FormatNumber(value)
	local number = tonumber(value) or 0
	local sign = number < 0 and "-" or ""
	local absolute = math.abs(number)

	if absolute < 1000 then
		if absolute % 1 == 0 then
			return sign .. tostring(math.floor(absolute))
		end

		return sign .. trimTrailingZero(string.format("%.1f", absolute))
	end

	for _, suffixData in SUFFIXES do
		if absolute >= suffixData.Value then
			local shortened = absolute / suffixData.Value
			return sign .. trimTrailingZero(string.format("%.1f", shortened)) .. suffixData.Suffix
		end
	end

	return sign .. tostring(math.floor(absolute))
end

return FormatNumber
