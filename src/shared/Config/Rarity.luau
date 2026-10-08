--!strict
-- Rarity tiers, in order. `chance` values must sum to 1.
-- `revealTier`: how far the growth reveal escalates (0 none, 1 shimmer, 2 sparks, 3 light pillar).
-- `announce`: 0 none, 1 toast to the finder, 2 whole server, 3 whole server + all servers (phase 3).

export type RarityDef = {
	id: string,
	name: string,
	order: number,
	chance: number,
	baseValue: number,
	color: { number },
	revealTier: number,
	announce: number,
}

local Rarity: { RarityDef } = {
	{
		id = "Common",
		name = "Common",
		order = 1,
		chance = 0.70,
		baseValue = 10,
		color = { 225, 225, 225 },
		revealTier = 0,
		announce = 0,
	},
	{
		id = "Uncommon",
		name = "Uncommon",
		order = 2,
		chance = 0.20,
		baseValue = 30,
		color = { 110, 230, 90 },
		revealTier = 0,
		announce = 0,
	},
	{
		id = "Rare",
		name = "Rare",
		order = 3,
		chance = 0.07,
		baseValue = 120,
		color = { 70, 160, 255 },
		revealTier = 1,
		announce = 0,
	},
	{
		id = "Epic",
		name = "Epic",
		order = 4,
		chance = 0.025,
		baseValue = 600,
		color = { 190, 90, 255 },
		revealTier = 2,
		announce = 1,
	},
	{
		id = "Legendary",
		name = "Legendary",
		order = 5,
		chance = 0.0045,
		baseValue = 5000,
		color = { 255, 190, 40 },
		revealTier = 3,
		announce = 2,
	},
	{
		id = "Mythic",
		name = "Mythic",
		order = 6,
		chance = 0.00049,
		baseValue = 80000,
		color = { 255, 70, 110 },
		revealTier = 3,
		announce = 3,
	},
	{
		id = "Secret",
		name = "Secret",
		order = 7,
		chance = 0.00001,
		baseValue = 2000000,
		color = { 40, 255, 230 },
		revealTier = 3,
		announce = 3,
	},
}

return Rarity
