--!strict
-- Seed types (phase 2: Rare, Golden, Mystery, Secret). Phase 1 only plants Basic.

export type SeedDef = {
	id: string,
	name: string,
	price: number,
	luckMult: number,
}

local Seeds: { SeedDef } = {
	{ id = "Basic", name = "Basic Seed", price = 0, luckMult = 1 },
}

return Seeds
