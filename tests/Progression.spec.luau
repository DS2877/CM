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

	-- First purchase is a real goal (not one carrot) but inside the first basket: 40 Commons pay it.
	local first = Progression.cost(growth, 0)
	assert(first > Economy.StartingCash + 4 * 10, "first upgrade takes more than a few carrots")
	assert(first <= Economy.BasketCapacity * 10 * 2, "first upgrade within one starting basket")

	-- Farm Level (FarmSize track): 20 levels, 4 plots at level 1 -> 36 at level 20
	local farm = track("FarmSize")
	local top = Progression.maxLevel(farm)
	assert(top == 39, "farm levels 1..40")
	assert(#(farm.levels :: { number }) == top, "a plot count for every farm level")
	assert(Progression.plots(farm, 0, Economy.StartingPlots) == 4, "4 plots at start")
	assert(Progression.plots(farm, top, Economy.StartingPlots) == Economy.MaxPlots, "64 plots at max")
	assert(Progression.isMaxed(farm, top) and not Progression.isMaxed(farm, top - 1), "farm size max")
	assert(Progression.cost(farm, top) == math.huge, "no cost past max")
	-- Every level's plot count has a cell in the world, and costs only go up
	local World = require("../src/shared/Config/World")
	assert(#World.PlotCells >= Economy.MaxPlots, "a world cell for every plot")
	for l = 1, top - 1 do
		assert(Progression.cost(farm, l) > Progression.cost(farm, l - 1), "farm costs rise")
	end

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
