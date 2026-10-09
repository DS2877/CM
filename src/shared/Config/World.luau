--!strict
-- World layout (built in code by WorldBuilder).

local World = {
	FarmCount = 8,
	FarmRingRadius = 150, -- distance from market (origin) to each farm center (6x6 farms, ~17 stud gaps)
	PlotSize = 7,
	PlotGap = 3,
	FarmPadding = 9, -- grass between plots and fence (room for the spawn pad and pedestal)

	-- Grid cell (col, row) for each plot index, in unlock order. The farm grows outward:
	-- 4 = 2x2, 9 = 3x3, 16 = 4x4, 25 = 5x5, 36 = 6x6 (with the in-between steps filling a side).
	PlotCells = {
		{ -0.5, -0.5 },
		{ 0.5, -0.5 },
		{ -0.5, 0.5 },
		{ 0.5, 0.5 },
		{ 1.5, -0.5 },
		{ 1.5, 0.5 },
		{ -0.5, 1.5 },
		{ 0.5, 1.5 },
		{ 1.5, 1.5 },
		{ -1.5, -0.5 },
		{ -1.5, 0.5 },
		{ -1.5, 1.5 },
		{ -1.5, -1.5 },
		{ -0.5, -1.5 },
		{ 0.5, -1.5 },
		{ 1.5, -1.5 },
		{ 2.5, -1.5 },
		{ 2.5, -0.5 },
		{ 2.5, 0.5 },
		{ 2.5, 1.5 },
		{ -1.5, 2.5 },
		{ -0.5, 2.5 },
		{ 0.5, 2.5 },
		{ 1.5, 2.5 },
		{ 2.5, 2.5 },
		{ -2.5, -1.5 },
		{ -2.5, -0.5 },
		{ -2.5, 0.5 },
		{ -2.5, 1.5 },
		{ -2.5, 2.5 },
		{ -2.5, -2.5 },
		{ -1.5, -2.5 },
		{ -0.5, -2.5 },
		{ 0.5, -2.5 },
		{ 1.5, -2.5 },
		{ 2.5, -2.5 },
	},

	-- Fixed places in the world (design: selling and upgrading are trips, not HUD buttons).
	-- Sell: step onto one of the SELL pads in front of the market counters (one per side, so
	-- every farm path leads to one) and the whole basket sells. Walking across the plaza doesn't.
	-- The Bunny Market: four farmers-market stalls around the BOOM EXCHANGE tower in the middle,
	-- each with a giant bunny buyer. You sell by stepping on the mat in front of a stall.
	SellPadAngles = { 0, 90, 180, 270 }, -- degrees around the plaza, one stall + mat per side
	SellPadDistance = 25, -- mat center from the plaza center
	SellPadRadius = 4,
	BunnyStallDistance = 18, -- stall center from the plaza center (the mat is in front of it)
	BunnyNames = { "Mr. Fluff", "Bun-Bun", "Clover", "Sir Hops" }, -- one per stall, same order
	-- Places just outside the plaza where some bots hang out (Server/Services/WorldFun builds them,
	-- Server/Services/Bots uses them): a campsite roasting marshmallows and a fishing lake.
	CampAngle = 157.5, -- degrees, between two farm paths
	CampRadius = 78,
	LakeAngle = 292.5,
	LakeRadius = 80,
	LakeSize = 22, -- water diameter
	-- Bots: Roblox-style farmers walking around the plaza and the paths (server, just for life).
	Bots = 8, -- 3 at the campfire, 1 fishing, the rest walking around
	BotWalkSpeed = 12,
	-- Upgrade Shops on the plaza, facing the market, so "sell, then upgrade" is two steps.
	UpgradeStallAngles = { 112.5, 292.5 }, -- degrees around the market (between farm paths)
	UpgradeStallDistance = 33, -- stall center from the market center (at the plaza edge)
	UpgradePadOffset = 6, -- the pad sits this far in front of the stall (toward the market)
	UpgradePadRadius = 4, -- standing on the pad opens the Upgrades panel
	UpgradeServerSlack = 5, -- extra distance the server accepts (lag)
	-- Farm Level board left of each farm gate; stand on its pad to open the Farm Level panel.
	FarmLevelPadOffset = 4.2, -- pad center in front of the board (toward the plaza)
	FarmLevelPadRadius = 2.6,
	FarmLevelServerSlack = 4,
	-- Plots: you walk to a plot to plant or harvest it (flat distance from you to the plot center).
	PlotReach = 13,
	PlotReachSlack = 4, -- extra the server accepts (lag)
	WalkSpeed = 22, -- a bit faster than Roblox's 16: trips to the market feel snappy

	-- Fun stuff (Server/Services/WorldFun, Client/Controllers/Ambience)
	MushroomAngles = { 67.5, 112.5, 202.5, 337.5 }, -- degrees, between farm paths
	MushroomRadius = 58,
	MushroomBounce = 105, -- upward speed when you land on a big bouncy mushroom (~28 studs high)
	MushroomBounceSmall = 60,
	BuntingRadius = 38, -- posts with flags and balloons around the plaza
	TulipSpacing = 7, -- tulips along both sides of every farm path
	Bunnies = 6, -- hopping around near the camera (client only)
	Birds = 5,
	Clouds = 14,

	TreeCount = 46,
	Seed = 2026,
}

-- Where each SELL pad is (shared by server checks, world build and client).
function World.sellPads(): { Vector3 }
	local out = {}
	for _, deg in World.SellPadAngles do
		local a = math.rad(deg)
		table.insert(out, Vector3.new(math.sin(a), 0, math.cos(a)) * World.SellPadDistance)
	end
	return out
end

-- Index (1..#SellPadAngles) of the SELL pad nearest to a position.
function World.nearestSellPadIndex(pos: Vector3): number
	local best, bestDist = 1, math.huge
	for i, pad in World.sellPads() do
		local d = Vector3.new(pos.X - pad.X, 0, pos.Z - pad.Z).Magnitude
		if d < bestDist then
			best, bestDist = i, d
		end
	end
	return best
end

-- Nearest SELL pad to a position (flat distance), and how far it is.
function World.nearestSellPad(pos: Vector3): (Vector3, number)
	local best, bestDist = Vector3.zero, math.huge
	for _, pad in World.sellPads() do
		local d = Vector3.new(pos.X - pad.X, 0, pos.Z - pad.Z).Magnitude
		if d < bestDist then
			best, bestDist = pad, d
		end
	end
	return best, bestDist
end

-- Where each Upgrade Shop's pad is (shared by server checks, world build and client).
function World.upgradePads(): { Vector3 }
	local out = {}
	for _, deg in World.UpgradeStallAngles do
		local a = math.rad(deg)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		table.insert(out, dir * (World.UpgradeStallDistance - World.UpgradePadOffset))
	end
	return out
end

return World
