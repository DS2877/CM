--!strict
-- Core economy and timing numbers. Change balance here, not in logic.

local Economy = {
	-- DataStore name. CM_Dev_v1 during development, CM_Live_v1 at soft launch.
	DataStoreName = "CM_Dev_v2",
	ProfileVersion = 5,

	StartingCash = 20,

	-- Growth
	BaseGrowTime = 12, -- seconds, before upgrades
	MinGrowTime = 3,
	-- Per-plot multiplier so plots finish at different times (staggered harvest: ~10–18 s at start).
	PlotGrowFactors = {
		0.85,
		1.0,
		1.2,
		1.45,
		0.95,
		1.3,
		1.1,
		1.5,
		0.9,
		1.25,
		1.05,
		1.4,
		1.15,
		0.8,
		1.35,
		1.0,
	},
	GrowJitter = 0.08, -- +/- random fraction added per planting
	HarvestTolerance = 0.25, -- seconds of latency forgiveness when harvesting

	-- Harvesting immediately replants a Basic seed so a plot is never idle.
	AutoReplant = true,

	-- Farm
	StartingPlots = 4,
	MaxPlots = 16,

	-- Basket (harvested carrots waiting to be sold). If full, harvests auto-sell at base price.
	-- Starting capacity; the Basket Size upgrade raises it (Config/Upgrades).
	BasketCapacity = 40,

	-- Bad-luck protection: guaranteed Legendary or better after this many plantings without one.
	PityLegendary = 250,
	PityRarity = "Legendary",

	-- Offline growth: only plots that were growing when you left keep going (empty plots make
	-- nothing). The carrot already in the ground finishes as rolled; after that each plot replants
	-- Basic seeds at OfflineRate of online speed, into a capped basket revealed on login.
	-- Away less than OfflineMinSeconds: plots come back as they were (finished ones ready to tap),
	-- no reveal. OfflineRate < 1 so leaving and rejoining never beats playing.
	OfflineCapSeconds = 8 * 3600,
	OfflineMaxCarrots = 100,
	OfflineMinSeconds = 5 * 60,
	OfflineRate = 0.25,
	-- A plot never makes an offline carrot faster than this, whatever its upgrades
	OfflineMinCycle = 240,
	-- Extra offline carrots per hour away (all plots), so 10 min ~ 6 carrots, 1 h ~ 30,
	-- the 100 cap after ~3 h. A short break is a treat; a night away fills the basket.
	OfflinePerHour = 30,

	-- Global cap for combined boost multipliers in the value formula.
	BoostCap = 6,

	-- Remote rate limits (tokens per second, burst)
	RateLimits = {
		PlotAction = { rate = 12, burst = 20 },
		SellAll = { rate = 3, burst = 4 },
		BuyUpgrade = { rate = 6, burst = 8 },
		BuySeed = { rate = 6, burst = 8 },
		SelectSeed = { rate = 4, burst = 6 },
		WaterFarm = { rate = 3, burst = 4 },
		SetGiftTarget = { rate = 2, burst = 4 },
		Track = { rate = 4, burst = 8 },
	},
}

return Economy
