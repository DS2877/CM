--!strict
-- Game passes and developer products (design doc §8). The Roblox IDs were created through Open Cloud
-- by tools/ops/roblox_setup.py (push a branch named ops/* to run it; it only creates what's missing
-- and writes the IDs back here). An ID of 0 means "not created": the button says "Coming soon".
-- Rules (design doc §11): everything sold for Robux has KNOWN contents (no Mystery Seeds, no
-- random rewards), boosts count PLAY time only, no fake countdowns, no offers after a loss.
-- `price` is only a display fallback: the real price comes from Roblox when the ID is set.

export type PassDef = {
	id: string,
	name: string,
	description: string,
	price: number,
	passId: number,
	giftProductId: number, -- developer product used to gift this pass to a friend
	emoji: string,
	color: { number },
}

export type BoostGrant = { boost: string, seconds: number }
export type SeedGrant = { seed: string, amount: number }

export type ProductDef = {
	id: string,
	name: string,
	description: string,
	price: number,
	productId: number,
	kind: string, -- "boost" | "serverBoost" | "instantGrow" | "seeds" | "bundle"
	boosts: { BoostGrant }?,
	seeds: { SeedGrant }?,
	once: boolean?, -- can only be bought once (Starter Bundle)
	emoji: string,
	color: { number },
}

export type BoostDef = { id: string, stat: string, mult: number, name: string, emoji: string, aura: boolean? }

local Products = {
	-- Timed boosts. Several luck boosts don't stack: the strongest active one counts.
	-- Value boosts multiply into the value formula's boost term, capped at Economy.BoostCap (x6).
	Boosts = {
		{ id = "Luck2", stat = "Luck", mult = 2, name = "Luck x2", emoji = "🍀" },
		{ id = "Luck4", stat = "Luck", mult = 4, name = "Super Luck x4", emoji = "🍀" },
		{ id = "Luck8", stat = "Luck", mult = 8, name = "Mega Luck x8", emoji = "🌟", aura = true },
		{ id = "Value2", stat = "Value", mult = 2, name = "Value x2", emoji = "💰" },
	} :: { BoostDef },

	ServerLuckMult = 2,
	ServerLuckSeconds = 600,

	-- Pass effects
	GrowthPassMult = 2, -- 2x Growth: grow time / 2
	GrowthPassMinTime = 1.5, -- absolute floor with the pass
	BigBasketMult = 3, -- Big Basket: 3x basket capacity
	VipDaily = { seed = "Golden", amount = 3 }, -- Market VIP daily bonus

	-- Contextual offers
	OfferPityHide = 0.9, -- no offers when the pity meter is at least 90 % full (reward is near anyway)

	GamePasses = {
		{
			id = "Growth2x",
			name = "2x Growth",
			description = "All carrots grow twice as fast",
			price = 399,
			passId = 2021984252,
			giftProductId = 3717302097,
			emoji = "⏩",
			color = { 90, 200, 255 },
		},
		{
			id = "AutoHarvest",
			name = "Auto Harvest",
			description = "Ready carrots harvest and replant themselves while you play",
			price = 349,
			passId = 2019272446,
			giftProductId = 3717302101,
			emoji = "🤖",
			color = { 150, 130, 255 },
		},
		{
			id = "MarketVIP",
			name = "Market VIP",
			description = "VIP name tag, VIP lounge at the market, 3 Golden Seeds every day",
			price = 499,
			passId = 2019776428,
			giftProductId = 3717302107,
			emoji = "⭐",
			color = { 255, 200, 50 },
		},
		{
			id = "BigBasket",
			name = "Big Basket",
			description = "3x basket size",
			price = 299,
			passId = 2021018285,
			giftProductId = 3717302112,
			emoji = "🧺",
			color = { 210, 150, 90 },
		},
		{
			id = "Scanner",
			name = "Carrot Scanner",
			description = "See your exact odds for the next harvest",
			price = 199,
			passId = 2019062459,
			giftProductId = 3717302114,
			emoji = "🔍",
			color = { 90, 220, 200 },
		},
	} :: { PassDef },

	DeveloperProducts = {
		{
			id = "LuckBoost",
			name = "Luck Boost",
			description = "2x luck for 15 minutes of play",
			price = 49,
			productId = 3717302117,
			kind = "boost",
			boosts = { { boost = "Luck2", seconds = 900 } },
			emoji = "🍀",
			color = { 110, 225, 90 },
		},
		{
			id = "ValueBoost",
			name = "Value Boost",
			description = "2x carrot value for 15 minutes of play",
			price = 79,
			productId = 3717302121,
			kind = "boost",
			boosts = { { boost = "Value2", seconds = 900 } },
			emoji = "💰",
			color = { 255, 205, 50 },
		},
		{
			id = "InstantGrow",
			name = "Instant Grow",
			description = "Every growing carrot on your farm is ready now",
			price = 29,
			productId = 3717302123,
			kind = "instantGrow",
			emoji = "⚡",
			color = { 255, 230, 80 },
		},
		{
			id = "SuperLuck",
			name = "Super Luck",
			description = "4x luck for 15 minutes of play",
			price = 149,
			productId = 3717302124,
			kind = "boost",
			boosts = { { boost = "Luck4", seconds = 900 } },
			emoji = "🍀",
			color = { 80, 200, 120 },
		},
		{
			id = "ServerLuck",
			name = "Server Luck",
			description = "2x luck for EVERYONE in the server for 10 minutes – with your name in lights!",
			price = 199,
			productId = 3717302127,
			kind = "serverBoost",
			emoji = "🌍",
			color = { 80, 170, 255 },
		},
		{
			id = "MegaLuck",
			name = "Mega Luck",
			description = "8x luck for 30 minutes of play, with a glowing aura",
			price = 249,
			productId = 3717302129,
			kind = "boost",
			boosts = { { boost = "Luck8", seconds = 1800 } },
			emoji = "🌟",
			color = { 255, 150, 220 },
		},
		{
			id = "GoldenSeedPack",
			name = "Golden Seed Pack",
			description = "10 Golden Seeds (always Golden x3)",
			price = 99,
			productId = 3717302131,
			kind = "seeds",
			seeds = { { seed = "Golden", amount = 10 } },
			emoji = "⭐",
			color = { 255, 205, 50 },
		},
		{
			-- Deliberately cheap (25 R$): the first purchase is the big step for a player.
			id = "StarterBundle",
			name = "Starter Bundle",
			description = "20 Rare Seeds + 5 Golden Seeds + Luck x2 for 15 min. One time only!",
			price = 25,
			productId = 3717302133,
			kind = "bundle",
			once = true,
			seeds = { { seed = "Rare", amount = 20 }, { seed = "Golden", amount = 5 } },
			boosts = { { boost = "Luck2", seconds = 900 } },
			emoji = "🎁",
			color = { 255, 120, 160 },
		},
		{
			id = "LuckyFarmer",
			name = "Lucky Farmer",
			description = "Mega Luck x8 for 30 min + 20 Golden Seeds",
			price = 299,
			productId = 3717302135,
			kind = "bundle",
			seeds = { { seed = "Golden", amount = 20 } },
			boosts = { { boost = "Luck8", seconds = 1800 } },
			emoji = "🍀",
			color = { 110, 225, 90 },
		},
		{
			id = "MarketTycoon",
			name = "Market Tycoon",
			description = "Value x2 for 1 hour + Super Luck x4 for 1 hour + 40 Golden Seeds",
			price = 799,
			productId = 3717302136,
			kind = "bundle",
			seeds = { { seed = "Golden", amount = 40 } },
			boosts = { { boost = "Value2", seconds = 3600 }, { boost = "Luck4", seconds = 3600 } },
			emoji = "🏆",
			color = { 255, 170, 50 },
		},
	} :: { ProductDef },
}

return Products
