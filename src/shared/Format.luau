--!strict
-- Number formatting for a phone screen: 1,234 below 10K, then 12.3K, 4.56M, 7.89B, T, Qa, Qi...
-- Pure module (no Roblox APIs) so it can be tested with Lune.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local out = s
	while true do
		local replaced, count = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if count == 0 then
			break
		end
	end
	return out
end

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	local a = math.abs(n)
	local result: string
	if a < 10000 then
		result = withCommas(math.floor(a))
	else
		local tier = math.floor(math.log10(a) / 3)
		if tier > #SUFFIXES then
			tier = #SUFFIXES
		end
		local scaled = a / 10 ^ (tier * 3)
		-- Round down to 3 significant digits so we never show more than the player has.
		local text: string
		if scaled >= 100 then
			text = tostring(math.floor(scaled))
		elseif scaled >= 10 then
			text = trimZeros(string.format("%.1f", math.floor(scaled * 10) / 10))
		else
			text = trimZeros(string.format("%.2f", math.floor(scaled * 100) / 100))
		end
		result = text .. SUFFIXES[tier]
	end
	return if negative then "-" .. result else result
end

function Format.cash(n: number): string
	if n < 0 then
		return "-$" .. Format.number(-n)
	end
	return "$" .. Format.number(n)
end

-- 0.0045 -> "0.45%", 0.00001 -> "0.001%"
function Format.percent(p: number): string
	local pct = p * 100
	local text: string
	if pct >= 10 then
		text = string.format("%.0f", pct)
	elseif pct >= 1 then
		text = trimZeros(string.format("%.1f", pct))
	else
		local digits = math.max(2, -math.floor(math.log10(pct)) + 1)
		text = trimZeros(string.format("%." .. digits .. "f", pct))
	end
	return text .. "%"
end

-- 0.0045 -> "1 in 222"
function Format.oneIn(p: number): string
	if p <= 0 then
		return "never"
	end
	return "1 in " .. Format.number(math.floor(1 / p + 0.5))
end

-- 75 -> "1:15", 9.2 -> "9.2s"
function Format.duration(seconds: number): string
	if seconds < 10 then
		return trimZeros(string.format("%.1f", math.max(0, seconds))) .. "s"
	elseif seconds < 60 then
		return tostring(math.floor(seconds)) .. "s"
	end
	local s = math.floor(seconds)
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

return Format
