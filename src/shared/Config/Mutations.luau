--!strict
-- Mutations are a separate roll from rarity and size.
-- Total mutation chance is the sum of `chance` (8 % at start). One mutation per carrot for now.

export type MutationDef = {
	id: string,
	name: string,
	chance: number,
	mult: number,
	color: { number },
}

local Mutations = {
	List = {
		{ id = "Golden", name = "Golden", chance = 0.05, mult = 3, color = { 255, 205, 50 } },
		{ id = "Frozen", name = "Frozen", chance = 0.02, mult = 6, color = { 160, 220, 255 } },
		{ id = "Rainbow", name = "Rainbow", chance = 0.01, mult = 10, color = { 255, 120, 220 } },
	} :: { MutationDef },

	-- Never let luck push the total mutation chance above this.
	MaxTotalChance = 0.5,
	-- How much of the Luck upgrade applies to mutation chance: mutationLuck = 1 + (luck - 1) * factor.
	LuckFactor = 0.5,
	MaxPerCarrot = 1,

	-- The first mutation is scripted: if a player has never had one, planting number
	-- `GuaranteedFirstAtPlanting` gets this mutation (~1–2 minutes into the first session).
	GuaranteedFirstAtPlanting = 18,
	GuaranteedFirstId = "Golden",
}

return Mutations
