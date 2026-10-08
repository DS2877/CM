--!strict
local OfflinePlan = require("../src/shared/OfflinePlan")
local Economy = require("../src/shared/Config/Economy")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

local cfg = {
	minSeconds = Economy.OfflineMinSeconds,
	capSeconds = Economy.OfflineCapSeconds,
	maxCarrots = Economy.OfflineMaxCarrots,
	rate = Economy.OfflineRate,
}

return function()
	-- The reported bug: nothing planted, away for hours -> nothing at all.
	local empty = OfflinePlan.make({}, 8 * 3600, cfg)
	check(empty.total == 0 and not empty.credited, "empty farm must produce nothing offline")
	check(#empty.plots == 0, "empty farm restores nothing")

	-- Short break: plots come back with their progress, no reveal.
	local short = OfflinePlan.make({
		{ index = 1, remaining = 8, growTime = 12 },
		{ index = 2, remaining = 2, growTime = 12 },
	}, 5, cfg)
	check(not short.credited and short.total == 0, "short break gives no reveal")
	check(short.plots[1].restoreRemaining == 3, "plot 1 keeps growing with 3 s left")
	check(short.plots[2].restoreRemaining == 0, "plot 2 comes back ready to tap")

	-- Longer break: saved carrot always finishes, extras at the reduced rate.
	local away = 3600
	local long = OfflinePlan.make({ { index = 1, remaining = 6, growTime = 12 } }, away, cfg)
	local expectedExtra = math.floor((away - 6) / (12 / cfg.rate))
	check(long.credited, "long break is credited")
	check(long.plots[1].finishSaved, "saved carrot finishes")
	check(long.plots[1].extra == math.min(expectedExtra, cfg.maxCarrots - 1), "extras at offline rate")
	check(long.plots[1].replant, "plot replants afterwards")

	-- Offline never beats playing: per plot it is at most `rate` of the online harvests.
	check(cfg.rate < 1, "offline rate must be below online speed")

	-- Cap: many plots for 8 h stay at maxCarrots, saved carrots kept.
	local many = {}
	for i = 1, 16 do
		table.insert(many, { index = i, remaining = 1, growTime = 3 })
	end
	local capped = OfflinePlan.make(many, 8 * 3600, cfg)
	check(capped.total == cfg.maxCarrots, "total capped at maxCarrots, got " .. capped.total)
	local sum = 0
	for _, p in capped.plots do
		check(p.finishSaved, "every saved carrot is kept")
		sum += 1 + p.extra
	end
	check(sum == capped.total, "plot counts add up to the total")

	-- Clock skew (negative away) behaves like no time passed.
	local skew = OfflinePlan.make({ { index = 1, remaining = 4, growTime = 12 } }, -50, cfg)
	check(skew.plots[1].restoreRemaining == 4 and skew.total == 0, "negative away is treated as 0")
end
