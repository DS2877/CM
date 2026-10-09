--!strict
-- Farm Level: what each level adds to the look of a farm (plots and prices are the FarmSize track
-- in Config/Upgrades; farm level = that track's level + 1). Every level adds something you can
-- see from the path, so it's easy to tell who is ahead. Built by Server/Services/FarmDecor.
--
-- 40 levels in tiers: 1-20 the farm grows up, 21-25 Country Estate, 26-30 Carrot Kingdom,
-- 31-35 Sky Farm, 36-40 Carrot Cosmos. Unknown ids are skipped (config can run ahead of art).
-- Pure module (no Roblox APIs).

export type Unlock = {
	level: number, -- farm level that unlocks it (2 = first level-up)
	id: string, -- FarmDecor builder id
	name: string,
	emoji: string,
}

local FarmLevels = {}

FarmLevels.MaxLevel = 40

-- Reaching these levels is announced to the whole server (and the barn changes).
FarmLevels.Milestones = { 5, 10, 15, 18, 20, 25, 30, 35, 38, 40 }

-- Tier names shown in announcements when a farm enters a new tier.
FarmLevels.Tiers = {
	{ from = 21, name = "COUNTRY ESTATE" },
	{ from = 26, name = "CARROT KINGDOM" },
	{ from = 31, name = "SKY FARM" },
	{ from = 36, name = "CARROT COSMOS" },
}

FarmLevels.Unlocks = {
	{ level = 2, id = "Flowers", name = "Flower boxes", emoji = "🌷" },
	{ level = 3, id = "Scarecrow", name = "Scarecrow", emoji = "🎃" },
	{ level = 4, id = "Lanterns", name = "Gate lanterns & mailbox", emoji = "🏮" },
	{ level = 5, id = "HayBales", name = "Hay bales", emoji = "🌾" },
	{ level = 6, id = "Chickens", name = "Chickens", emoji = "🐔" },
	{ level = 7, id = "Well", name = "Water well", emoji = "🪣" },
	{ level = 8, id = "AppleTrees", name = "Apple trees", emoji = "🍎" },
	{ level = 9, id = "Windmill", name = "Windmill", emoji = "🌬️" },
	{ level = 10, id = "WhiteFence", name = "White picket fence", emoji = "🤍" },
	{ level = 11, id = "Silo", name = "Silo", emoji = "🏗️" },
	{ level = 12, id = "Pond", name = "Duck pond", emoji = "🦆" },
	{ level = 13, id = "Cow", name = "Cow", emoji = "🐄" },
	{ level = 14, id = "Greenhouse", name = "Greenhouse", emoji = "🪴" },
	{ level = 15, id = "Banners", name = "Corner banners", emoji = "🚩" },
	{ level = 16, id = "Tractor", name = "Tractor", emoji = "🚜" },
	{ level = 17, id = "Fountain", name = "Fountain", emoji = "⛲" },
	{ level = 18, id = "GoldTrim", name = "Gold gate & lamp posts", emoji = "✨" },
	{ level = 19, id = "Rainbow", name = "Rainbow arch", emoji = "🌈" },
	{ level = 20, id = "GoldenCarrot", name = "Giant golden carrot", emoji = "🥕" },
	-- The big "wow" steps: the barn grows and changes, and the farm starts to glow
	{ level = 5, id = "Barn", name = "Painted barn", emoji = "🛖" },
	{ level = 10, id = "Barn", name = "BIG barn", emoji = "🏠" },
	{ level = 12, id = "StringLights", name = "String lights", emoji = "💡" },
	{ level = 15, id = "Barn", name = "Farmhouse with gold roof", emoji = "🏡" },
	{ level = 16, id = "GlowBorder", name = "Glowing farm border", emoji = "✨" },
	{ level = 18, id = "SkyBeams", name = "Sky beams (seen from everywhere!)", emoji = "🔦" },
	{ level = 20, id = "Barn", name = "GOLDEN MANOR", emoji = "🏰" },
	{ level = 20, id = "Fireworks", name = "Fireworks", emoji = "🎆" },
	-- 21-25 COUNTRY ESTATE
	{ level = 21, id = "StoneWall", name = "Stone estate wall", emoji = "🧱" },
	{ level = 22, id = "GiantWindmill", name = "Giant windmill", emoji = "🌬️" },
	{ level = 23, id = "Orchard", name = "Fruit orchard", emoji = "🍑" },
	{ level = 24, id = "Stable", name = "Horse stable & horses", emoji = "🐴" },
	{ level = 25, id = "EstateArch", name = "Grand estate arch", emoji = "🏛️" },
	{ level = 25, id = "Barn", name = "ESTATE MANOR", emoji = "🏯" },
	-- 26-30 CARROT KINGDOM
	{ level = 26, id = "CastleWalls", name = "Castle walls & towers", emoji = "🏰" },
	{ level = 27, id = "Moat", name = "Moat", emoji = "🌊" },
	{ level = 28, id = "Knights", name = "Knight guards & royal banners", emoji = "🛡️" },
	{ level = 29, id = "Topiary", name = "Bunny topiary garden", emoji = "🌳" },
	{ level = 30, id = "FloatingCrown", name = "Giant floating crown", emoji = "👑" },
	{ level = 30, id = "Barn", name = "CARROT CASTLE", emoji = "🏰" },
	-- 31-35 SKY FARM
	{ level = 31, id = "SkyIslands", name = "Floating sky islands", emoji = "🏝️" },
	{ level = 32, id = "SkyWaterfall", name = "Sky waterfall", emoji = "💦" },
	{ level = 33, id = "Balloons", name = "Hot-air balloons", emoji = "🎈" },
	{ level = 34, id = "RainbowBridge", name = "Rainbow bridge", emoji = "🌈" },
	{ level = 35, id = "CloudCastle", name = "Cloud castle in the sky", emoji = "☁️" },
	{ level = 35, id = "Barn", name = "SKY PALACE", emoji = "🕌" },
	-- 36-40 CARROT COSMOS
	{ level = 36, id = "Crystals", name = "Glowing crystal garden", emoji = "💎" },
	{ level = 37, id = "Aurora", name = "Aurora over your farm", emoji = "🌌" },
	{ level = 38, id = "GoldenBunny", name = "Giant golden bunny statue", emoji = "🐰" },
	{ level = 39, id = "Planets", name = "Orbiting planets", emoji = "🪐" },
	{ level = 40, id = "Cosmos", name = "STARFIELD FARM + cosmic beam", emoji = "🌠" },
	{ level = 40, id = "Barn", name = "COSMIC PALACE", emoji = "✨" },
} :: { Unlock }

-- The barn behind the farm grows with the level (sizes in studs at scale 1: 12 x 7 x 8).
-- style: "plain" (bare wood shed), "painted" (farm color), "trim" (white trim + windows),
-- "gold" (gold roof, glowing windows), "golden" (gold everything + towers), "estate" (stone
-- manor), "castle" (keep with battlements), "sky" (white & gold palace), "cosmic" (starlit).
export type BarnTier = { from: number, name: string, scale: number, style: string }
FarmLevels.BarnTiers = {
	{ from = 1, name = "Shed", scale = 0.75, style = "plain" },
	{ from = 5, name = "Barn", scale = 1.0, style = "painted" },
	{ from = 10, name = "Big Barn", scale = 1.3, style = "trim" },
	{ from = 15, name = "Farmhouse", scale = 1.6, style = "gold" },
	{ from = 20, name = "Golden Manor", scale = 1.9, style = "golden" },
	{ from = 25, name = "Estate Manor", scale = 2.1, style = "estate" },
	{ from = 30, name = "Carrot Castle", scale = 2.3, style = "castle" },
	{ from = 35, name = "Sky Palace", scale = 2.4, style = "sky" },
	{ from = 40, name = "Cosmic Palace", scale = 2.6, style = "cosmic" },
} :: { BarnTier }

function FarmLevels.barnTier(level: number): BarnTier
	local best = FarmLevels.BarnTiers[1]
	for _, t in FarmLevels.BarnTiers do
		if level >= t.from then
			best = t
		end
	end
	return best
end

-- Everything a farm at `level` has (in unlock order).
function FarmLevels.unlocked(level: number): { Unlock }
	local out = {}
	for _, u in FarmLevels.Unlocks do
		if u.level <= level then
			table.insert(out, u)
		end
	end
	return out
end

-- What reaching `level` adds (usually one thing).
function FarmLevels.at(level: number): { Unlock }
	local out = {}
	for _, u in FarmLevels.Unlocks do
		if u.level == level then
			table.insert(out, u)
		end
	end
	return out
end

return FarmLevels
