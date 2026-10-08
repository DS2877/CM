--!strict
-- Upgrade cost and effect math, shared so the client can preview exactly what the server charges.
-- Pure module (no Roblox APIs).

export type UpgradeLike = {
	baseCost: number,
	costGrowth: number,
	maxLevel: number,
	perLevel: number,
}

local Progression = {}

-- Cost to go from `level` to `level + 1`.
function Progression.cost(track: UpgradeLike, level: number): number
	-- Small epsilon so 57.4999999 (float error for 57.5) rounds like 57.5.
	return math.floor(track.baseCost * track.costGrowth ^ level + 0.5 + 1e-7)
end

function Progression.isMaxed(track: UpgradeLike, level: number): boolean
	return level >= track.maxLevel
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

return Progression
