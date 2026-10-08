--!strict
-- The value formula (design doc §3), shared by server and client so previews always match.
--
--   value = base * size * mutation * market * (1 + valueUpgrade) * prestige * min(boosts, boostCap)
--
-- Pure module (no Roblox APIs) so it can be tested with Lune.

export type ValueParams = {
	base: number,
	size: number,
	mutation: number?,
	market: number?,
	valueUpgrade: number?,
	prestige: number?,
	boosts: number?,
	boostCap: number?,
}

local Value = {}

-- Product of several mutation multipliers (empty list = 1).
function Value.mutationMultiplier(mults: { number }): number
	local m = 1
	for _, v in mults do
		m *= v
	end
	return m
end

-- Combined boosts are multiplied together, then capped.
function Value.boostMultiplier(boosts: { number }, cap: number): number
	local m = 1
	for _, v in boosts do
		m *= v
	end
	return math.min(m, cap)
end

-- Exact (unrounded) value.
function Value.raw(p: ValueParams): number
	local boosts = p.boosts or 1
	local cap = p.boostCap or 6
	return p.base
		* p.size
		* (p.mutation or 1)
		* (p.market or 1)
		* (1 + (p.valueUpgrade or 0))
		* (p.prestige or 1)
		* math.min(boosts, cap)
end

-- Value in whole cash, at least 1.
function Value.compute(p: ValueParams): number
	return math.max(1, math.floor(Value.raw(p) + 0.5))
end

return Value
