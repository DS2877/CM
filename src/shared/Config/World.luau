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
	-- Sell: walk onto the green circle around the market and the whole basket sells.
	SellRadius = 17, -- studs from the market center (the green sell circle)
	-- Upgrade Shops on the plaza, facing the market, so "sell, then upgrade" is two steps.
	UpgradeStallAngles = { 112.5, 292.5 }, -- degrees around the market (between farm paths)
	UpgradeStallDistance = 27, -- stall center from the market center
	UpgradePadOffset = 6.5, -- the pad sits this far in front of the stall (toward the market)
	UpgradePadRadius = 4.5, -- standing on the pad opens the Upgrades panel
	UpgradeServerSlack = 5, -- extra distance the server accepts (lag)
	WalkSpeed = 22, -- a bit faster than Roblox's 16: trips to the market feel snappy

	TreeCount = 46,
	Seed = 2026,
}

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
