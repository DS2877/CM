--!strict
-- Size roll. `mult` affects value, `scale` affects how big the carrot looks.

export type SizeDef = {
	id: string,
	name: string,
	order: number,
	chance: number,
	mult: number,
	scale: number,
}

local Sizes: { SizeDef } = {
	{ id = "Small", name = "Small", order = 1, chance = 0.25, mult = 0.8, scale = 0.8 },
	{ id = "Normal", name = "Normal", order = 2, chance = 0.50, mult = 1, scale = 1 },
	{ id = "Large", name = "Large", order = 3, chance = 0.18, mult = 1.5, scale = 1.35 },
	{ id = "Huge", name = "Huge", order = 4, chance = 0.06, mult = 2.5, scale = 1.9 },
	{ id = "Giant", name = "Giant", order = 5, chance = 0.01, mult = 5, scale = 3.2 },
}

return Sizes
