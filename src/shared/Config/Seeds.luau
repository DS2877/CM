--!strict
-- Seed types. The selected seed is used for the next planting (manual or auto-replant) while
-- the player has any; otherwise Basic. Seeds are bought with in-game cash only, never Robux
-- (design doc §11). Mystery Seeds turn into one of `mystery` when planted; odds are shown.
-- Prices scale with the player's Value upgrade so seeds stay relevant all game:
--   price = basePrice * (1 + valueBonus)

export type MysteryOutcome = { seed: string, weight: number }

export type SeedDef = {
	id: string,
	name: string,
	description: string,
	basePrice: number,
	buyable: boolean,
	luck: number, -- multiplies luck from upgrades
	mutationLuck: number,
	minRarity: string?,
	forceMutation: string?,
	mystery: { MysteryOutcome }?,
	emoji: string,
	color: { number },
}

local Seeds: { SeedDef } = {
	{
		id = "Basic",
		name = "Basic Seed",
		description = "Free and endless",
		basePrice = 0,
		buyable = false,
		luck = 1,
		mutationLuck = 1,
		emoji = "🌱",
		color = { 140, 210, 100 },
	},
	{
		id = "Rare",
		name = "Rare Seed",
		description = "Never Common, 3x luck",
		basePrice = 250,
		buyable = true,
		luck = 3,
		mutationLuck = 1.5,
		minRarity = "Uncommon",
		emoji = "💎",
		color = { 80, 170, 255 },
	},
	{
		id = "Golden",
		name = "Golden Seed",
		description = "Always Golden (x3), 2x luck",
		basePrice = 2000,
		buyable = true,
		luck = 2,
		mutationLuck = 1,
		forceMutation = "Golden",
		emoji = "⭐",
		color = { 255, 205, 50 },
	},
	{
		id = "Mystery",
		name = "Mystery Seed",
		description = "Becomes a Rare, Golden or Secret seed",
		basePrice = 700,
		buyable = true,
		luck = 1,
		mutationLuck = 1,
		mystery = {
			{ seed = "Rare", weight = 60 },
			{ seed = "Golden", weight = 37 },
			{ seed = "Secret", weight = 3 },
		},
		emoji = "❓",
		color = { 190, 110, 255 },
	},
	{
		id = "Secret",
		name = "Secret Seed",
		description = "Legendary or better, 20x luck",
		basePrice = 0,
		buyable = false,
		luck = 20,
		mutationLuck = 3,
		minRarity = "Legendary",
		emoji = "🌌",
		color = { 60, 230, 220 },
	},
}

return Seeds
