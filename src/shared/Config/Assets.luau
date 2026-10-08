--!strict
-- Asset IDs. An empty string means "not uploaded yet": the game falls back to primitives / silence.
-- `rbxasset://` entries are built into the Roblox client (no upload needed) and are placeholders
-- until proper sounds are uploaded. Missing assets are listed in STATUS.md.

local Assets = {
	-- Sound cues (behavior and mix in Config/Audio). A string or a list of variations.
	-- rbxasset:// entries ship with the Roblox client and are placeholders; cues with no ID borrow
	-- another cue's sound at a different pitch (Audio.Cues[x].fallback). The full brief for the
	-- real sounds is in STATUS.md ("Ljud – brief").
	Sounds = {
		Click = "rbxasset://sounds/clickfast.wav",
		Open = "",
		Purchase = "rbxasset://sounds/electronicpingshort.wav",
		Denied = "",
		GoalReady = "",
		Plant = "rbxasset://sounds/action_jump_land.mp3",
		Harvest = "rbxasset://sounds/snap.wav",
		HarvestRare = "",
		HarvestEpic = "",
		HarvestLegendary = "rbxasset://sounds/victory.wav",
		HarvestMythic = "",
		Mutation = "",
		Discover = "rbxasset://sounds/electronicpingshort.wav",
		Shimmer = "rbxasset://sounds/swoosh.wav",
		Sparks = "",
		Pillar = "rbxasset://sounds/victory.wav",
		Water = "rbxasset://sounds/impact_water.mp3",
		Sell = "rbxasset://sounds/electronicpingshort.wav",
		SellBoom = "",
		Upgrade = "",
		Bell = "rbxasset://sounds/electronicpingshort.wav",
		BoomEnd = "",
		Announce = "",
		RevealTick = "",
	},
	-- Looping music per state (Controllers/Music). Empty = no music for that state yet.
	Music = {
		Farm = "", -- calm folk-pop loop, 90-105 bpm (see STATUS.md brief)
		Boom = "", -- upbeat market/bluegrass loop, 125-140 bpm
	},
	-- Looping ambience beds
	Ambience = {
		Meadow = "", -- birds + soft wind, under everything
		Market = "", -- light crowd chatter, positional at the market
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
		Scanner = "",
		Icon = "",
	},
}

return Assets
