--!strict
-- Core economy and timing numbers. Change balance here, not in logic.

local Economy = {
	-- DataStore name. CM_Dev_v1 during development, CM_Live_v1 at soft launch.
	DataStoreName = "CM_Dev_v2",
	ProfileVersion = 7,

	StartingCash = 20,

	-- Growth
	BaseGrowTime = 12, -- seconds, before upgrades
	MinGrowTime = 3,
	-- Per-plot multiplier so plots finish at different times (staggered harvest: ~10–18 s at start).
	-- One per plot, up to MaxPlots.
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
		1.2,
		0.9,
		1.45,
		1.05,
		0.85,
		1.3,
		1.1,
		1.4,
		0.95,
		1.25,
		1.0,
		1.5,
		0.9,
		1.15,
		1.35,
		0.8,
		1.2,
		1.05,
		1.45,
		0.95,
		1.1,
		0.85,
		1.35,
		0.95,
		1.25,
		1.5,
		0.9,
		1.15,
		1.4,
		0.8,
		1.05,
		1.3,
		1.2,
		0.9,
		1.45,
		1.0,
		0.85,
		1.25,
		1.1,
		1.4,
		0.95,
		1.35,
		1.05,
		0.8,
		1.2,
		1.5,
		1.0,
		1.15,
	},
	GrowJitter = 0.08, -- +/- random fraction added per planting
	HarvestTolerance = 0.25, -- seconds of latency forgiveness when harvesting

	-- Planting is the player's move (and a seed choice), so harvesting leaves the plot empty.
	-- The Auto Harvest game pass harvests AND replants while you're in the game.
	AutoReplant = false,

	-- Farm
	StartingPlots = 4,
	MaxPlots = 64,

	-- Basket (harvested carrots waiting to be sold at the market). When it's full, ready carrots
	-- wait on their plots (nothing is lost) until you've sold. Starting capacity; the Basket Size
	-- upgrade and the Big Basket pass raise it.
	BasketCapacity = 40,

	-- Bad-luck protection: guaranteed Legendary or better after this many plantings without one.
	PityLegendary = 250,
	PityRarity = "Legendary",

	-- Offline: the carrots you planted keep growing while you're away (Server/Offline). No extra
	-- carrots, nothing harvested for you; no settings needed.

	-- Global cap for combined boost multipliers in the value formula.
	BoostCap = 6,

	-- Remote rate limits (tokens per second, burst)
	RateLimits = {
		PlotAction = { rate = 12, burst = 20 },
		BuyUpgrade = { rate = 6, burst = 8 },
		BuySeed = { rate = 6, burst = 8 },
		SelectSeed = { rate = 4, burst = 6 },
		WaterFarm = { rate = 3, burst = 4 },
		SetGiftTarget = { rate = 2, burst = 4 },
		Track = { rate = 4, burst = 8 },
		TogglePerk = { rate = 3, burst = 5 },
		SetMusic = { rate = 2, burst = 4 },
		RedeemCode = { rate = 0.5, burst = 3 },
		DailyClaim = { rate = 2, burst = 4 },
		TutorialDone = { rate = 0.2, burst = 1 },
	},
}

return Economy
