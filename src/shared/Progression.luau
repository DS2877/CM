--!strict
-- Upgrade cost and effect math, shared so the client can preview exactly what the server charges
-- and the simulator (tools/simulate.luau) uses the same numbers. Pure module (no Roblox APIs).

export type UpgradeLike = {
	baseCost: number,
	costGrowth: number,
	maxLevel: number,
	perLevel: number,
	costs: { number }?,
	levels: { number }?,
}

local Progression = {}

-- Cost to go from `level` to `level + 1`.
function Progression.cost(track: UpgradeLike, level: number): number
	local costs = track.costs
	if costs then
		return costs[level + 1] or math.huge
	end
	-- Small epsilon so 57.4999999 (float error for 57.5) rounds like 57.5.
	return math.floor(track.baseCost * track.costGrowth ^ level + 0.5 + 1e-7)
end

function Progression.maxLevel(track: UpgradeLike): number
	local costs = track.costs
	return if costs then #costs else track.maxLevel
end

function Progression.isMaxed(track: UpgradeLike, level: number): boolean
	return level >= Progression.maxLevel(track)
end

-- Grow time for a plot: base * plotFactor * perLevel^level, never below minimum.
function Progression.growTime(
	baseGrowTime: number,
	minGrowTime: number,
	growthTrack: UpgradeLike,
	growthLevel: number,
	plotFactor: number
): number
	return math.max(minGrowTime, baseGrowTime * plotFactor * growthTrack.perLevel ^ growthLevel)
end

-- Linear "1 + perLevel * level" multiplier (Luck, Harvest Power).
function Progression.multiplier(track: UpgradeLike, level: number): number
	return 1 + track.perLevel * level
end

-- Additive bonus "perLevel * level" (Value: value * (1 + bonus)).
function Progression.bonus(track: UpgradeLike, level: number): number
	return track.perLevel * level
end

-- Plot count for a Farm Size level (level 0 = starting plots).
function Progression.plots(track: UpgradeLike, level: number, startingPlots: number): number
	local levels = track.levels
	if not levels or level <= 0 then
		return startingPlots
	end
	return levels[math.min(level, #levels)]
end

-- Mutation luck from overall luck: 1 + (luck - 1) * factor.
function Progression.mutationLuck(luck: number, factor: number): number
	return 1 + (luck - 1) * factor
end

-- Seed price scales with the Value upgrade so seeds stay relevant.
function Progression.seedPrice(basePrice: number, valueBonus: number): number
	return math.floor(basePrice * (1 + valueBonus) + 0.5)
end

return Progression
