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
		Click = "",
	},
	Meshes = {
		Carrot = "",
	},
	Images = {
		Cash = "",
		Icon = "",
	},
}

return Assets
