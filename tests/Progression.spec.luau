--!strict
local Progression = require("../src/shared/Progression")
local Upgrades = require("../src/shared/Config/Upgrades")
local Economy = require("../src/shared/Config/Economy")
local Seeds = require("../src/shared/Config/Seeds")

local function track(id: string): Upgrades.UpgradeDef
	for _, t in Upgrades do
		if t.id == id then
			return t
		end
	end
	error("missing track " .. id)
end

return function()
	local growth = track("GrowthSpeed")
	assert(Progression.cost(growth, 0) == growth.baseCost, "level 0 costs the base cost")
	assert(
		Progression.cost(growth, 3) == math.floor(growth.baseCost * growth.costGrowth ^ 3 + 0.5 + 1e-7),
		"cost curve"
	)
	assert(Progression.cost(growth, 1) > Progression.cost(growth, 0), "costs rise")

	local base = Progression.growTime(Economy.BaseGrowTime, Economy.MinGrowTime, growth, 0, 1)
	assert(base == Economy.BaseGrowTime, "level 0 grow time is the base")
	local lvl1 = Progression.growTime(Economy.BaseGrowTime, Economy.MinGrowTime, growth, 1, 1)
	assert(math.abs(lvl1 - Economy.BaseGrowTime * growth.perLevel) < 1e-9, "level 1 applies perLevel once")
	local floor = Progression.growTime(Economy.BaseGrowTime, Economy.MinGrowTime, growth, 200, 1)
	assert(floor == Economy.MinGrowTime, "grow time never below floor")

	-- First purchase reachable quickly: starting cash + four smallest carrots >= first cost.
	assert(Economy.StartingCash + 4 * 8 >= Progression.cost(growth, 0), "first upgrade within ~4 harvests")

	-- Farm Size: explicit costs and plot counts, 4 -> 6 -> 9 -> 12 -> 16
	local farm = track("FarmSize")
	assert(Progression.maxLevel(farm) == 4, "farm size has 4 levels")
	assert(Progression.plots(farm, 0, Economy.StartingPlots) == 4, "4 plots at start")
	assert(Progression.plots(farm, 4, Economy.StartingPlots) == Economy.MaxPlots, "16 plots at max")
	assert(Progression.isMaxed(farm, 4) and not Progression.isMaxed(farm, 3), "farm size max")
	assert(Progression.cost(farm, 4) == math.huge, "no cost past max")

	-- Luck/Value/Harvest Power effects
	assert(Progression.multiplier(track("Luck"), 0) == 1, "no luck at level 0")
	assert(Progression.bonus(track("Value"), 0) == 0, "no value bonus at level 0")
	assert(Progression.mutationLuck(3, 0.5) == 2, "mutation luck factor")
	assert(Progression.seedPrice(100, 0.5) == 150, "seed price scales with value bonus")

	-- Seeds: Basic exists and is free; Mystery odds point at real seeds; nothing is sold for Robux here
	local byId = {}
	for _, s in Seeds do
		byId[s.id] = s
	end
	assert(byId.Basic and byId.Basic.basePrice == 0, "Basic seed is free")
	for _, s in Seeds do
		if s.mystery then
			for _, o in s.mystery do
				assert(byId[o.seed], "mystery outcome " .. o.seed .. " exists")
			end
		end
	end
end
