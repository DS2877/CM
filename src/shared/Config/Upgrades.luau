--!strict
-- Upgrade tracks. Default cost(level) = round(baseCost * costGrowth ^ level), level = current level.
-- A track with `costs` uses those explicit prices instead (Farm Size), and `maxLevel` = #costs.
-- Effects (see shared Progression.luau):
--   GrowthSpeed  grow time * perLevel ^ level (floor Economy.MinGrowTime)
--   Luck         luck = 1 + perLevel * level (non-Common rarity weights and mutation chance)
--   Value        value bonus = perLevel * level, i.e. value * (1 + bonus)
--   FarmSize     farm level - 1; plots = levels[level] (level 0 = Economy.StartingPlots)
--   HarvestPower size luck = 1 + perLevel * level (Large/Huge/Giant weights)
--   BasketSize   basket capacity = levels[level] (level 0 = Economy.BasketCapacity)

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	enabled: boolean,
	baseCost: number,
	costGrowth: number,
	maxLevel: number,
	perLevel: number,
	costs: { number }?,
	levels: { number }?,
	soldAt: string?, -- "farm" = bought at your farm's Farm Level sign, not in the Upgrade Shop
	emoji: string,
	color: { number },
}

local Upgrades: { UpgradeDef } = {
	{
		id = "GrowthSpeed",
		name = "Growth Speed",
		description = "Carrots grow faster",
		enabled = true,
		baseCost = 600,
		costGrowth = 1.65,
		maxLevel = 25,
		perLevel = 0.95,
		emoji = "⏩",
		color = { 90, 200, 255 },
	},
	{
		id = "Luck",
		name = "Luck",
		description = "Rarer carrots and more mutations",
		enabled = true,
		baseCost = 3000,
		costGrowth = 1.65,
		maxLevel = 40,
		perLevel = 0.05,
		emoji = "🍀",
		color = { 110, 225, 90 },
	},
	{
		id = "Value",
		name = "Value",
		description = "Carrots sell for more",
		enabled = true,
		baseCost = 1500,
		costGrowth = 1.5,
		maxLevel = 100,
		perLevel = 0.10,
		emoji = "💰",
		color = { 255, 205, 50 },
	},
	{
		-- FARM LEVEL. Bought at the sign by your own farm gate (not in the Upgrade Shop).
		-- Farm level = this track's level + 1 (level 1 = a fresh farm). Each level adds plots
		-- (`levels`) and makes the farm look more alive (Config/FarmLevels). 20 levels now; to
		-- add levels 21-40, append to `costs`/`levels` (plots can stay at 36) and add decor there.
		id = "FarmSize",
		name = "Farm Level",
		description = "More plots and a livelier farm",
		enabled = true,
		baseCost = 0,
		costGrowth = 1,
		maxLevel = 19,
		perLevel = 0,
		-- price to reach farm level 2, 3, ... 20
		costs = {
			1500,
			4000,
			9000,
			20000,
			45000,
			100000,
			220000,
			480000,
			1000000,
			2200000,
			5000000,
			11000000,
			25000000,
			55000000,
			120000000,
			260000000,
			560000000,
			1200000000,
			2600000000,
		},
		-- plots at farm level 2, 3, ... 20 (level 1 = Economy.StartingPlots)
		levels = { 5, 6, 7, 8, 9, 10, 12, 13, 14, 16, 18, 20, 22, 24, 26, 28, 30, 33, 36 },
		soldAt = "farm",
		emoji = "🏡",
		color = { 255, 140, 60 },
	},
	{
		id = "HarvestPower",
		name = "Harvest Power",
		description = "Bigger carrots",
		enabled = true,
		baseCost = 5000,
		costGrowth = 1.6,
		maxLevel = 40,
		perLevel = 0.08,
		emoji = "💪",
		color = { 255, 110, 160 },
	},
	{
		id = "BasketSize",
		name = "Basket Size",
		description = "Store more carrots for the next boom",
		enabled = true,
		baseCost = 0,
		costGrowth = 1,
		maxLevel = 5,
		perLevel = 0,
		costs = { 4000, 30000, 250000, 2000000, 16000000 },
		levels = { 80, 160, 320, 640, 1280 },
		emoji = "🧺",
		color = { 200, 140, 90 },
	},
}

return Upgrades
