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
	-- Special color treatment where a single color isn't enough:
	-- "rainbow" (Divine) cycles every hue, "mono" (Secret) pulses black <-> white.
	style: string?,
	revealTier: number,
	announce: number,
	-- Particle aura around a ready/harvested carrot: better carrots sparkle much more.
	-- rate = particles/s, size = studs, speed = studs/s, light = PointLight range (0 = none),
	-- rising = extra upward sparkle stream (particles/s).
	aura: { rate: number, size: number, speed: number, light: number, rising: number },
}

-- Nine tiers, Common -> Divine. Each step up is roughly 4-10x rarer and 3-8x more valuable,
-- so every new tier is a genuine "WHAT?!" moment. Odds (1 in X, before luck):
-- Common 1.4, Uncommon 5, Rare 14, Epic 40, Legendary 222, Mythic 2 500, Cosmic 11 111,
-- Secret 111 111, Divine 1 000 000.
local Rarity: { RarityDef } = {
	{
		id = "Common",
		name = "Common",
		order = 1,
		chance = 0.70,
		baseValue = 10,
		color = { 95, 200, 70 }, -- green
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
		color = { 175, 245, 130 }, -- light green
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
		color = { 60, 140, 255 }, -- blue
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
		color = { 175, 80, 255 }, -- purple
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
		color = { 255, 196, 40 }, -- gold
		revealTier = 3,
		announce = 2,
		aura = { rate = 45, size = 0.6, speed = 2.4, light = 14, rising = 24 },
	},
	{
		id = "Mythic",
		name = "Mythic",
		order = 6,
		chance = 0.0004,
		baseValue = 60000,
		color = { 255, 55, 55 }, -- red
		revealTier = 3,
		announce = 3,
		aura = { rate = 60, size = 0.7, speed = 3, light = 16, rising = 34 },
	},
	{
		id = "Cosmic",
		name = "Cosmic",
		order = 7,
		chance = 0.00009,
		baseValue = 400000,
		color = { 40, 225, 255 }, -- cyan / electric blue
		revealTier = 3,
		announce = 3,
		aura = { rate = 70, size = 0.75, speed = 3.2, light = 18, rising = 40 },
	},
	{
		id = "Secret",
		name = "Secret",
		order = 8,
		chance = 0.000009,
		baseValue = 2500000,
		color = { 245, 245, 245 }, -- black + white
		style = "mono",
		revealTier = 3,
		announce = 3,
		aura = { rate = 80, size = 0.8, speed = 3.4, light = 18, rising = 44 },
	},
	{
		id = "Divine",
		name = "Divine",
		order = 9,
		chance = 0.000001,
		baseValue = 20000000,
		color = { 255, 120, 220 }, -- rainbow (style); this is the fallback tint
		style = "rainbow",
		revealTier = 3,
		announce = 3,
		aura = { rate = 100, size = 0.9, speed = 3.8, light = 22, rising = 60 },
	},
}

return Rarity
