--!strict
-- Upgrade tracks. Default cost(level) = round(baseCost * costGrowth ^ level), level = current level.
-- A track with `costs` uses those explicit prices instead (Farm Size), and `maxLevel` = #costs.
-- Effects (see shared Progression.luau):
--   GrowthSpeed  grow time * perLevel ^ level (floor Economy.MinGrowTime)
--   Luck         luck = 1 + perLevel * level (non-Common rarity weights and mutation chance)
--   Value        value bonus = perLevel * level, i.e. value * (1 + bonus)
--   FarmSize     plots = levels[level] (level 0 = Economy.StartingPlots)
--   HarvestPower size luck = 1 + perLevel * level (Large/Huge/Giant weights)

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
	emoji: string,
	color: { number },
}

local Upgrades: { UpgradeDef } = {
	{
		id = "GrowthSpeed",
		name = "Growth Speed",
		description = "Carrots grow faster",
		enabled = true,
		baseCost = 50,
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
		baseCost = 500,
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
		baseCost = 250,
		costGrowth = 1.5,
		maxLevel = 100,
		perLevel = 0.10,
		emoji = "💰",
		color = { 255, 205, 50 },
	},
	{
		id = "FarmSize",
		name = "Farm Size",
		description = "More plots on your farm",
		enabled = true,
		baseCost = 0,
		costGrowth = 1,
		maxLevel = 4,
		perLevel = 0,
		costs = { 1500, 20000, 200000, 1500000 },
		levels = { 6, 9, 12, 16 },
		emoji = "🌱",
		color = { 255, 140, 60 },
	},
	{
		id = "HarvestPower",
		name = "Harvest Power",
		description = "Bigger carrots",
		enabled = true,
		baseCost = 800,
		costGrowth = 1.6,
		maxLevel = 40,
		perLevel = 0.08,
		emoji = "💪",
		color = { 255, 110, 160 },
	},
}

return Upgrades
