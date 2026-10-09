--!strict
-- World layout: Carrot Valley v2 (built in code by WorldBuilder, BunnyMarket, Plaza, WorldFun).
--
--   * The town square (radius PlazaRadius) in the middle: BOOM EXCHANGE tower in the center and
--     six districts between the farm paths (Bunny Market, Upgrade Workshop, Hall of Fame, Seed
--     Store, Fun Fair, Stage & VIP).
--   * The Wilds: a ring of countryside between the square and the farms (lake, campsite,
--     mushroom forest, kite hill, waterfall, flower fields) where the bots hang out.
--   * Six big farms on the outer ring, each with its own path to the square and a Bunny Launcher
--     at both ends (step on it and a giant bunny flings you over the valley).
-- Angles are degrees around the origin (0 = +Z). Farm i sits at angle (i - 1) * 360 / FarmCount.

local World = {
	FarmCount = 6,
	FarmRingRadius = 280, -- distance from the square's center to each farm center
	FarmGrid = 8, -- plots per side at the biggest farm (8 x 8 = 64)
	PlotSize = 7,
	PlotGap = 3,
	FarmPadding = 9, -- grass between plots and fence (room for the spawn pad and pedestal)

	-- Ground & edges
	MapHalf = 700, -- the ground is 2 * MapHalf wide; invisible walls a bit inside
	HillRadius = 600, -- rolling hills frame the valley

	-- The town square
	PlazaRadius = 90,
	TowerScale = 2, -- BOOM EXCHANGE size (1 = the old plaza tower)
	SpawnDistance = 40, -- the plain spawn (before you're moved to your farm), toward farm 1

	-- District angles (between the farm paths, which are at 0, 60, 120 …)
	MarketAngle = 30,
	WorkshopAngle = 90,
	HallOfFameAngle = 150,
	SeedStoreAngle = 210,
	FunFairAngle = 270,
	StageAngle = 330,

	-- Bunny Market: four stalls side by side in an open hall, mats in front (toward the tower)
	MarketDistance = 72, -- the stall row's distance from the center (clear of the farm roads)
	StallSpacing = 13, -- between stall centers along the row
	SellMatOffset = 9, -- the SELL mat sits this far in front of its stall
	SellPadRadius = 4,
	BunnyNames = { "Mr. Fluff", "Bun-Bun", "Clover", "Sir Hops" }, -- one per stall, left to right

	-- Upgrade Workshop (one big building) and its pad
	UpgradeStallAngles = { 90 }, -- = WorkshopAngle; a list so more workshops are possible
	UpgradeStallDistance = 70, -- building center from the square's center
	UpgradePadOffset = 17, -- the pad sits this far in front of the building (toward the tower)
	UpgradePadRadius = 5, -- standing on the pad opens the Upgrades panel
	UpgradeServerSlack = 5, -- extra distance the server accepts (lag)

	-- Seed Store (prepared for buying seeds in the world later; its pad opens the Seeds menu)
	SeedStoreDistance = 70,
	SeedPadOffset = 16,
	SeedPadRadius = 5,

	-- VIP lounge (Market VIP pass) next to the stage
	VipAngle = 345,
	VipDistance = 72,
	-- Hall of Fame: leaderboards side by side
	LeaderboardRadius = 74,
	LeaderboardSpread = 15, -- degrees between neighbouring boards

	-- Bunny Launchers: one beside each farm gate (to the square) and one beside the square's end of
	-- each farm road (to that farm). Flights are client-side movement only.
	LauncherRadius = 4,
	LaunchSeconds = 3.2,
	LaunchHeight = 70, -- peak height of the arc
	LauncherGateOffset = 14, -- farm launcher: this far outside the gate
	LauncherPlazaOutset = 12, -- road-end launcher: this far outside the square's edge
	LauncherSideOffset = 14, -- launchers stand beside the road, never on it (no accidental launches)
	-- "HOME" launchers right next to the market and the workshop: always fly you to your own farm
	HomeLaunchers = { { angle = 47, distance = 44 }, { angle = 73, distance = 44 } },

	-- Farm Level board left of each farm gate; stand on its pad to open the Farm Level panel.
	FarmLevelPadOffset = 4.2, -- pad center in front of the board (toward the square)
	FarmLevelPadRadius = 2.6,
	FarmLevelServerSlack = 4,
	-- Plots: you walk to a plot to plant or harvest it (flat distance from you to the plot center).
	PlotReach = 13,
	PlotReachSlack = 4, -- extra the server accepts (lag)
	WalkSpeed = 22, -- a bit faster than Roblox's 16: trips feel snappy

	-- The Wilds (sector angles sit between farm paths; distances from the center)
	WildsRadius = 165,
	MushroomAngles = { 18, 30, 42 }, -- the mushroom forest
	MushroomRadius = 160,
	MushroomBounce = 105, -- upward speed when you land on a big bouncy mushroom (~28 studs high)
	MushroomBounceSmall = 60,
	LakeAngle = 90,
	LakeRadius = 165,
	LakeSize = 48, -- water diameter
	CampAngle = 150,
	CampRadius = 160,
	KiteAngle = 205,
	KiteRadius = 165,
	PicnicAngle = 222,
	PicnicRadius = 150,
	WaterfallAngle = 270,
	WaterfallRadius = 175,
	PaintAngle = 258,
	PaintRadius = 140,
	SlideSpeed = 70, -- how fast the waterfall slide shoots you down
	FlowerAngle = 330,
	FlowerRadius = 165,

	BuntingRadius = 93, -- posts with flags and balloons around the square
	TulipSpacing = 9, -- tulips along both sides of every farm path
	Bunnies = 6, -- hopping around near the camera (client only)
	Birds = 6,
	Clouds = 18,
	-- Bots: Roblox-style farmers with something to do in the Wilds (server, just for life).
	Bots = 8, -- 3 at the campfire, 1 fishing, 2 at the picnic, 1 flying a kite, 1 painting
	BotWalkSpeed = 12,

	TreeCount = 140,
	Seed = 2026,
}

-- Grid cell (col, row) for each plot index, in unlock order. The farm grows outward from the
-- middle: 4 = 2x2, 9, 16, 25, 36 = 6x6 (the original order, so saved farms keep their plots),
-- then a full outer ring to 8 x 8 = 64 (right side, back row, left side, front row last).
local function plotCells(): { { number } }
	local cells = {
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
	}
	for z = -3.5, 3.5 do -- right column
		table.insert(cells, { 3.5, z })
	end
	for x = 2.5, -3.5, -1 do -- back row
		table.insert(cells, { x, 3.5 })
	end
	for z = 2.5, -3.5, -1 do -- left column
		table.insert(cells, { -3.5, z })
	end
	for x = -2.5, 2.5 do -- front row (nearest the gate) last
		table.insert(cells, { x, -3.5 })
	end
	return cells
end
World.PlotCells = plotCells()

local function dirOf(deg: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end
World.dirOf = dirOf

-- Farm i's direction from the center.
function World.farmAngle(id: number): number
	return (id - 1) * 360 / World.FarmCount
end

-- Half the width of a farm's fenced area.
function World.farmHalf(): number
	local cell = World.PlotSize + World.PlotGap
	return (World.FarmGrid / 2) * cell - World.PlotGap / 2 + World.FarmPadding
end

-- The Bunny Market stalls (CFrame at the stall's floor center, -Z/LookVector toward the tower).
function World.marketStalls(): { CFrame }
	local dir = dirOf(World.MarketAngle)
	local side = Vector3.new(dir.Z, 0, -dir.X)
	local center = dir * World.MarketDistance
	local out = {}
	local n = #World.BunnyNames
	for i = 1, n do
		local pos = center + side * ((i - (n + 1) / 2) * World.StallSpacing)
		table.insert(out, CFrame.lookAt(pos, pos - dir))
	end
	return out
end

-- Where each SELL mat is (shared by server checks, world build and client).
function World.sellPads(): { Vector3 }
	local out = {}
	for _, cf in World.marketStalls() do
		local p = cf.Position + cf.LookVector * World.SellMatOffset
		table.insert(out, Vector3.new(p.X, 0, p.Z))
	end
	return out
end

-- Index of the SELL mat nearest to a position.
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

-- Nearest SELL mat to a position (flat distance), and how far it is.
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

-- Where each Upgrade Workshop's pad is (shared by server checks, world build and client).
function World.upgradePads(): { Vector3 }
	local out = {}
	for _, deg in World.UpgradeStallAngles do
		table.insert(out, dirOf(deg) * (World.UpgradeStallDistance - World.UpgradePadOffset))
	end
	return out
end

-- The Seed Store's pad.
function World.seedPad(): Vector3
	return dirOf(World.SeedStoreAngle) * (World.SeedStoreDistance - World.SeedPadOffset)
end

-- HOME launcher spots (their target is the flying player's own farm, decided by the client).
function World.homeLaunchers(): { Vector3 }
	local out = {}
	for _, h in World.HomeLaunchers do
		table.insert(out, dirOf(h.angle) * h.distance)
	end
	return out
end

-- Bunny Launchers: { from, to } positions on the ground (flat), one pair per farm.
export type Launcher = { from: Vector3, to: Vector3, farmId: number, toFarm: boolean }
function World.launchers(): { Launcher }
	local out: { Launcher } = {}
	local half = World.farmHalf()
	for id = 1, World.FarmCount do
		local dir = dirOf(World.farmAngle(id))
		-- beside the road (the right-hand side when you face the square), on the grass
		local beside = Vector3.new(dir.Z, 0, -dir.X) * World.LauncherSideOffset
		local gate = dir * (World.FarmRingRadius - half - World.LauncherGateOffset) + beside
		local plazaEnd = dir * (World.PlazaRadius + World.LauncherPlazaOutset) + beside
		-- farm -> square: land on the open ring in front of the Bunny Market
		local market = dirOf(World.MarketAngle) * (World.MarketDistance - World.SellMatOffset - 14)
		local side = Vector3.new(-dir.Z, 0, dir.X) * ((id % 3) - 1) * 6
		table.insert(out, { from = gate, to = market + side, farmId = id, toFarm = false })
		-- square -> farm: land inside the farm, on its spawn pad
		local spawn = dir * (World.FarmRingRadius - half + 4)
		table.insert(out, { from = plazaEnd, to = spawn, farmId = id, toFarm = true })
	end
	return out
end

return World
