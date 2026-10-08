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
	-- Particle aura around a ready/harvested carrot: better carrots sparkle much more.
	-- rate = particles/s, size = studs, speed = studs/s, light = PointLight range (0 = none),
	-- rising = extra upward sparkle stream (particles/s).
	aura: { rate: number, size: number, speed: number, light: number, rising: number },
}

local Rarity: { RarityDef } = {
	{
		id = "Common",
		name = "Common",
		order = 1,
		chance = 0.70,
		baseValue = 10,
		color = { 255, 245, 200 },
		revealTier = 0,
		announce = 0,
		aura = { rate = 5, size = 0.28, speed = 0.7, light = 0, rising = 0 },
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
		aura = { rate = 10, size = 0.34, speed = 1, light = 0, rising = 3 },
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
		aura = { rate = 18, size = 0.42, speed = 1.3, light = 7, rising = 8 },
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
		aura = { rate = 30, size = 0.5, speed = 1.8, light = 10, rising = 14 },
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
		aura = { rate = 45, size = 0.6, speed = 2.4, light = 14, rising = 24 },
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
		aura = { rate = 60, size = 0.7, speed = 3, light = 16, rising = 34 },
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
		aura = { rate = 80, size = 0.8, speed = 3.4, light = 18, rising = 44 },
	},
}

return Rarity
