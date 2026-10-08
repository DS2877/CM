--!strict
-- CarrotDex rewards. Layer 1 = carrot types found, layer 2 = type+mutation stamps.
-- Rewards are granted automatically the moment a milestone is reached.

export type Milestone = { count: number, seed: string, amount: number }

local Dex = {
	TypeMilestones = {
		{ count = 4, seed = "Rare", amount = 5 },
		{ count = 8, seed = "Golden", amount = 3 },
		{ count = 12, seed = "Mystery", amount = 5 },
		{ count = 16, seed = "Secret", amount = 1 },
		{ count = 20, seed = "Secret", amount = 2 },
		{ count = 24, seed = "Secret", amount = 5 },
		{ count = 28, seed = "Secret", amount = 10 }, -- the whole Dex, Divine included
	} :: { Milestone },
	StampMilestones = {
		{ count = 5, seed = "Golden", amount = 3 },
		{ count = 15, seed = "Secret", amount = 1 },
		{ count = 30, seed = "Secret", amount = 2 },
		{ count = 50, seed = "Secret", amount = 3 },
		{ count = 72, seed = "Secret", amount = 5 },
		{ count = 84, seed = "Secret", amount = 10 }, -- every type x every mutation
	} :: { Milestone },
}

return Dex
