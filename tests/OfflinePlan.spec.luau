--!strict
local OfflinePlan = require("../src/shared/OfflinePlan")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

return function()
	-- The original bug: nothing planted, away for hours -> nothing at all.
	local empty = OfflinePlan.make({}, 8 * 3600)
	check(#empty.plots == 0 and empty.ready == 0, "empty farm stays empty")

	-- The rule: you never get more than you planted. 6 planted, away a whole night -> exactly the
	-- same 6 carrots, ready to harvest, nothing extra.
	local planted = {}
	for i = 1, 6 do
		table.insert(planted, { index = i, remaining = 2 + i })
	end
	local night = OfflinePlan.make(planted, 8 * 3600)
	check(#night.plots == 6, "exactly the planted plots come back, got " .. #night.plots)
	check(night.ready == 6, "all six are ready after a night")
	for _, p in night.plots do
		check(p.remaining == 0, "finished carrots come back ready")
	end

	-- Short break: they keep growing in real time.
	local short = OfflinePlan.make({
		{ index = 1, remaining = 8 },
		{ index = 2, remaining = 2 },
	}, 5)
	check(short.plots[1].remaining == 3, "plot 1 keeps growing with 3 s left")
	check(short.plots[2].remaining == 0, "plot 2 comes back ready to tap")
	check(short.ready == 1, "one ready")

	-- Clock skew (negative away) behaves like no time passed.
	local skew = OfflinePlan.make({ { index = 1, remaining = 4 } }, -50)
	check(skew.plots[1].remaining == 4, "negative away is treated as 0")
end
