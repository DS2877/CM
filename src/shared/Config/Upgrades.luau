--!strict
-- Upgrade tracks. cost(level) = floor(baseCost * costGrowth ^ level), where level is the current level.
-- Only `enabled` tracks are shown and purchasable. Phase 1 ships Growth Speed only.

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	enabled: boolean,
	baseCost: number,
	costGrowth: number,
	maxLevel: number,
	-- Effect per level. Meaning depends on the track (see Progression.luau).
	perLevel: number,
}

local Upgrades: { UpgradeDef } = {
	{
		id = "GrowthSpeed",
		name = "Growth Speed",
		description = "Carrots grow faster",
		enabled = true,
		baseCost = 50,
		costGrowth = 1.15,
		maxLevel = 60,
		perLevel = 0.95, -- grow time multiplier per level (-5 %)
	},
	{
		id = "Luck",
		name = "Luck",
		description = "Better rarity and mutation odds",
		enabled = false,
		baseCost = 150,
		costGrowth = 1.20,
		maxLevel = 50,
		perLevel = 0.10,
	},
	{
		id = "Value",
		name = "Value",
		description = "Carrots sell for more",
		enabled = false,
		baseCost = 120,
		costGrowth = 1.18,
		maxLevel = 100,
		perLevel = 0.10,
	},
	{
		id = "HarvestPower",
		name = "Harvest Power",
		description = "Bigger carrots",
		enabled = false,
		baseCost = 200,
		costGrowth = 1.15,
		maxLevel = 40,
		perLevel = 0.05,
	},
}

return Upgrades
