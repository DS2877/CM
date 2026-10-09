--!strict
-- Asset IDs. An empty string means "not uploaded yet": the game falls back to primitives / silence.
-- `rbxasset://` entries are built into the Roblox client (no upload needed) and are placeholders
-- until proper sounds are uploaded. Missing assets are listed in STATUS.md.

local Assets = {
	-- Sound cues (behavior and mix in Config/Audio). A string or a list of variations.
	-- All IDs are from Roblox's licensed Creator Store partners (APMOfficial production music,
	-- ProSoundEffects, DistroKid/TooLost official), usable in any experience. Names in comments so
	-- anyone can find and audition them. Cues with "" borrow another cue (Audio fallback).
	Sounds = {
		-- UI: soft bubble "bloops" pitched up, so UI feels like part of the same world
		Click = "rbxassetid://9112872070", -- Small Bubbles Water Surface Float Up Pop 4 (SFX)
		Open = "rbxassetid://9112872058", -- Small Bubbles ... Pop 3 (SFX)
		Purchase = "rbxassetid://9117244567", -- Pay Phone Dropping Dimes Into Coin Slot 5 (SFX)
		Denied = "",
		GoalReady = "",
		-- Farm
		Plant = {
			"rbxassetid://9114083260", -- Dirt Dig Dirt Throws From Shovel 1 (SFX)
			"rbxassetid://9114083746", -- Dirt Dig Dirt Throws From Shovel 12 (SFX)
		},
		Harvest = { -- juicy little plops, five takes so streaks never repeat exactly
			"rbxassetid://9112872239", -- Small Bubbles ... Pop 5 (SFX)
			"rbxassetid://9112872244", -- Small Bubbles ... Pop 6 (SFX)
			"rbxassetid://9112872235", -- Small Bubbles ... Pop 7 (SFX)
			"rbxassetid://9112872058", -- Small Bubbles ... Pop 3 (SFX)
			"rbxassetid://9112872070", -- Small Bubbles ... Pop 4 (SFX)
		},
		HarvestRare = "rbxassetid://1841572433", -- Straw Hat Boy Sting c (APM, 3 s)
		HarvestEpic = "rbxassetid://9038578394", -- Good Good Times (sting a) (APM, 4 s)
		HarvestLegendary = "rbxassetid://1836860398", -- Winning Spirit (APM, 6 s)
		HarvestMythic = "rbxassetid://1841173427", -- Magical (c) (APM, 6 s)
		Mutation = "rbxassetid://9114369623", -- Fairy Dust 1 (SFX)
		Discover = "rbxassetid://1841185885", -- Whistle Along (APM / KPM, 6 s)
		Shimmer = "rbxassetid://9114369623", -- Fairy Dust 1 (SFX), quiet + positional
		Sparks = "",
		Pillar = "rbxassetid://1841324037", -- Summer Town Sting (b) (APM, 6 s)
		Water = {
			"rbxassetid://9117947034", -- Puddle Stomps Small Water Splashes 9 (SFX)
			"rbxassetid://9117946658", -- Puddle Stomps Small Water Splashes 2 (SFX)
		},
		-- Economy
		Sell = {
			"rbxassetid://9125444889", -- Coins Drop 3 Inch Medallions Metal Hits (SFX)
			"rbxassetid://9125445531", -- Coins Drop 3 Inch Medallions Metal Hits (SFX)
		},
		SellBoom = "rbxassetid://1843090702", -- The Joyous Return - Hook (APM, 3 s)
		Upgrade = "rbxassetid://9040476898", -- Early Bird - Hit1 (APM, 2 s)
		-- Market & social
		Bell = "rbxassetid://9125935023", -- Shop Door Bell Ceramic Mug Cowbell Hits Ring (SFX)
		BoomEnd = "rbxassetid://1841186475", -- Goodnight Mr Uke (APM / KPM, 5 s)
		Announce = "rbxassetid://1841390412", -- Bouncy Bouncy Sting 1 (APM, 6 s)
	},
	-- Music playlists per state (Controllers/Music). Tracks play in order, then wrap.
	Music = {
		Farm = {
			"rbxassetid://9047156510", -- Cheery Ukulele A (APM, John Epping, 1:57)
			"rbxassetid://78804894697787", -- Ukulele Sunshine (Happy Vlog Music) (DistroKid, 2:55)
			"rbxassetid://9047156515", -- Cheery Ukulele C (APM, John Epping, 1:33)
			"rbxassetid://101647477431808", -- Hawaiian Breeze Peaceful Chords (DistroKid, 2:44)
		},
		Boom = {
			"rbxassetid://1838909565", -- Lively Country (APM, Lionel Wendling, 2:51)
			"rbxassetid://1838909209", -- Energetic Folk (APM, Lionel Wendling, 2:10)
		},
	},
	-- Looping ambience beds
	Ambience = {
		Meadow = "rbxassetid://131156639937742", -- Birds Concert, Pt. 31 (TooLost official)
		Market = "rbxassetid://9112841064", -- Outdoor Walla 2 (SFX), positional at the market
	},
	Meshes = {
		Carrot = "",
	},
	-- HUD icons. Empty = an emoji fallback is drawn instead (see client Util/UI.icon).
	Images = {
		Cash = "",
		Carrot = "",
		Basket = "",
		Upgrade = "",
		Seeds = "",
		Index = "",
		Crown = "",
		Shop = "",
		Admin = "",
		Scanner = "",
		Icon = "",
	},
}

return Assets
