--!strict
-- The living ground (Server/Services/Landscape): terrain grass, hills, water and wind.

local Landscape = {
	GrassLength = 0.9, -- terrain grass blades (0.1 - 1)
	GrassColor = { 112, 196, 72 }, -- bright, juicy green
	LeafyGrassColor = { 88, 176, 66 },
	GroundColor = { 205, 160, 108 }, -- under paths and buildings (matches the dirt paths)
	SandColor = { 238, 218, 165 },
	RockColor = { 165, 158, 150 },
	WaterColor = { 50, 175, 225 },
	WaterTransparency = 0.35,
	WaterWaveSize = 0.15,
	WaterWaveSpeed = 8,
	WaterReflectance = 0.5,
	Wind = Vector3.new(7, 0, 4), -- makes the grass sway (and drifting particles follow it)

	HillCount = 46,
	MoundCount = 40,
	LeafyPatches = 120,
	WildflowerClusters = 420, -- little clusters of flowers dotted over the grass
}

return Landscape
