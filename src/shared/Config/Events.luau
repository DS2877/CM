--!strict
-- Global market events (design doc §5). The schedule is computed from os.time(), so every server
-- agrees on which event is active without talking to each other (no server hopping, reliable
-- countdowns). Prices never go below base: every multiplier is >= 1.
--
-- Each cycle of `CycleSeconds` ends with a boom of `BoomSeconds`. Which boom it is comes from a
-- deterministic hash of the cycle number, weighted by `weight`. All selling happens at the
-- market (the green sell circle, Config/World.SellRadius) and always pays MarketBonus, plus the
-- boom multiplier during a boom: holding your basket for a boom is the decision.
-- The daily modifier picks one featured rarity per UTC day and applies everywhere.

export type BoomDef = {
	id: string,
	name: string,
	description: string,
	kind: string, -- "all" | "rarity" | "mutation" | "size"
	targets: { string }?, -- rarity ids / mutation ids / size ids
	mult: number,
	weight: number,
}

local Events = {
	Enabled = true,
	CycleSeconds = 600,
	BoomSeconds = 180,
	MarketRadius = 32, -- studs from the market center that count as "at the market"
	MarketBonus = 1.2, -- always paid when selling at the market (booms multiply on top)

	Booms = {
		{
			id = "Craze",
			name = "Carrot Craze",
			description = "ALL carrots x2",
			kind = "all",
			mult = 2,
			weight = 3,
		},
		{
			id = "RareRush",
			name = "Rare Rush",
			description = "Rare & Epic x3",
			kind = "rarity",
			targets = { "Rare", "Epic" },
			mult = 3,
			weight = 2,
		},
		{
			id = "GoldRush",
			name = "Gold Rush",
			description = "Mutated carrots x3",
			kind = "mutation",
			targets = { "Golden", "Frozen", "Rainbow" },
			mult = 3,
			weight = 2,
		},
		{
			id = "BigBonanza",
			name = "Big Bonanza",
			description = "Large, Huge & Giant x3",
			kind = "size",
			targets = { "Large", "Huge", "Giant" },
			mult = 3,
			weight = 2,
		},
		{
			id = "CommonCraze",
			name = "Common Craze",
			description = "Common & Uncommon x4",
			kind = "rarity",
			targets = { "Common", "Uncommon" },
			mult = 4,
			weight = 2,
		},
	} :: { BoomDef },

	-- Daily Market: one featured rarity per UTC day, same in every server.
	DailyMult = 1.25,
	DailyRarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
}

return Events
