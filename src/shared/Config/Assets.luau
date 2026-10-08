--!strict
-- Asset IDs. An empty string means "not uploaded yet": the game falls back to primitives / silence.
-- `rbxasset://` entries are built into the Roblox client (no upload needed) and are placeholders
-- until proper sounds are uploaded. Missing assets are listed in STATUS.md.

local Assets = {
	Sounds = {
		Plant = "",
		Pop = "rbxasset://sounds/electronicpingshort.wav",
		Harvest = "rbxasset://sounds/electronicpingshort.wav",
		RareHarvest = "",
		Legendary = "rbxasset://sounds/victory.wav",
		Shimmer = "",
		Pillar = "",
		Sell = "rbxasset://sounds/electronicpingshort.wav",
		Purchase = "rbxasset://sounds/electronicpingshort.wav",
		Discover = "",
		Bell = "rbxasset://sounds/electronicpingshort.wav",
		Water = "",
		Click = "",
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
		Icon = "",
	},
}

return Assets
