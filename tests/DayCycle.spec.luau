--!strict
local DayCycle = require("../src/shared/Config/DayCycle")

local function check(ok: boolean, what: string)
	if not ok then
		error(what, 2)
	end
end

return function()
	local len = DayCycle.CycleSeconds
	local c0, p0, d0 = DayCycle.at(0)
	check(p0 == "Morning" and c0 > 5 and c0 < 6, "cycle starts at dawn")
	check(d0 > 0.5, "dawn is still darkish")
	local c1, p1, d1 = DayCycle.at(len * 0.4)
	check(p1 == "Day" and c1 > 9 and c1 < 16.5 and d1 == 0, "midday is bright")
	local _, p2, d2 = DayCycle.at(len * 0.9)
	check(p2 == "Night" and d2 == 1, "night is night")
	local c3 = DayCycle.at(len * 2 + 1)
	check(math.abs(c3 - c0) < 0.1, "the cycle repeats")
	for k = 0, 99 do
		local c = DayCycle.at(len * k / 100)
		check(c >= 0 and c < 24, "clock in range")
	end
end
