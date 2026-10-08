--!strict
local Progression = require("../src/shared/Progression")
local Upgrades = require("../src/shared/Config/Upgrades")
local Economy = require("../src/shared/Config/Economy")

return function()
	local growth = Upgrades[1]
	assert(growth.id == "GrowthSpeed", "first track should be Growth Speed")
	assert(Progression.cost(growth, 0) == 50, "first Growth Speed level costs $50")
	assert(Progression.cost(growth, 1) == 58, "second level costs 50 * 1.15")
	assert(Progression.cost(growth, 10) == 202, "cost curve")

	local base = Progression.growTime(Economy.BaseGrowTime, Economy.MinGrowTime, growth, 0, 1)
	assert(base == 12, "base grow time is 12s")
	local lvl1 = Progression.growTime(Economy.BaseGrowTime, Economy.MinGrowTime, growth, 1, 1)
	assert(math.abs(lvl1 - 11.4) < 1e-9, "level 1 is -5 %")
	local floor = Progression.growTime(Economy.BaseGrowTime, Economy.MinGrowTime, growth, 200, 1)
	assert(floor == Economy.MinGrowTime, "grow time never below floor")

	-- First purchase must be reachable quickly: starting cash + four smallest carrots >= first cost.
	assert(Economy.StartingCash + 4 * 8 >= Progression.cost(growth, 0), "first upgrade within ~4 harvests")
end
