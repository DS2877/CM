--!strict
-- The living ground: Roblox terrain instead of a flat green slab.
--   * Grass terrain with decoration on: thousands of little grass blades that sway in the wind
--     (workspace.GlobalWind), so the whole valley moves.
--   * Rolling terrain hills around the edge, lush leafy patches in the countryside.
--   * Real terrain water for the lake (animated waves, reflections).
--   * Under roads, the square, farms and anything built flat on the ground the terrain is plain
--     ground, so grass blades never poke through paths or plots.
-- Numbers live in Config/Landscape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local World = require(Config.World)
local L = require(Config.Landscape)

local Landscape = {}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local terrain: Terrain = workspace.Terrain

-- Every terrain call is guarded: a terrain hiccup must never stop the world from being built.
local function safe(what: string, fn: () -> ())
	local ok, err = pcall(function()
		fn()
	end)
	if not ok then
		warn("Landscape: " .. what .. " failed:", err)
	end
end

-- Make the top layer under a flat area plain ground (no grass blades). `cf` is at ground level.
function Landscape.flatBlock(cf: CFrame, sizeX: number, sizeZ: number, material: Enum.Material?)
	safe("flatBlock", function()
		terrain:FillBlock(
			cf * CFrame.new(0, -1, 0),
			Vector3.new(sizeX, 2, sizeZ),
			material or Enum.Material.Ground
		)
	end)
end

function Landscape.flatDisc(pos: Vector3, radius: number, material: Enum.Material?)
	safe("flatDisc", function()
		terrain:FillCylinder(CFrame.new(pos.X, -1, pos.Z), 2, radius, material or Enum.Material.Ground)
	end)
end

-- A terrain lake: sandy bed and shore, real water up to ground level.
function Landscape.lake(pos: Vector3, radius: number, depth: number)
	safe("lake", function()
		terrain:FillCylinder(CFrame.new(pos.X, -1, pos.Z), 2, radius + 3, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(pos.X, -depth - 1, pos.Z), 2, radius, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(pos.X, -depth / 2, pos.Z), depth, radius, Enum.Material.Water)
	end)
end

function Landscape.build()
	terrain:Clear()
	-- Animated grass (Terrain.Decoration) can't be set from a script: it's switched on in
	-- default.project.json. The rest is set here; each one guarded so a property Roblox refuses
	-- can never stop the world from being built.
	local function set(prop: string, value: any)
		local ok, err = pcall(function()
			(terrain :: any)[prop] = value
		end)
		if not ok then
			warn("Landscape: could not set Terrain." .. prop, err)
		end
	end
	set("GrassLength", L.GrassLength)
	set("WaterColor", rgb(L.WaterColor))
	set("WaterTransparency", L.WaterTransparency)
	set("WaterWaveSize", L.WaterWaveSize)
	set("WaterWaveSpeed", L.WaterWaveSpeed)
	set("WaterReflectance", L.WaterReflectance)
	terrain:SetMaterialColor(Enum.Material.Grass, rgb(L.GrassColor))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, rgb(L.LeafyGrassColor))
	terrain:SetMaterialColor(Enum.Material.Ground, rgb(L.GroundColor))
	terrain:SetMaterialColor(Enum.Material.Sand, rgb(L.SandColor))
	terrain:SetMaterialColor(Enum.Material.Rock, rgb(L.RockColor))
	pcall(function()
		workspace.GlobalWind = L.Wind
	end)

	-- the valley floor: top of the grass at y = 0
	-- (filled in tiles: one giant fill can be refused)
	local tile = 200
	for x = -World.MapHalf, World.MapHalf - 1, tile do
		for z = -World.MapHalf, World.MapHalf - 1, tile do
			terrain:FillBlock(
				CFrame.new(x + tile / 2, -6, z + tile / 2),
				Vector3.new(tile, 12, tile),
				Enum.Material.Grass
			)
		end
	end

	-- rolling hills around the edge, some with rocky tops
	local rng = Random.new(World.Seed + 11)
	for i = 0, L.HillCount - 1 do
		local a = (i + rng:NextNumber() * 0.7) * (2 * math.pi / L.HillCount)
		local r = World.HillRadius + rng:NextNumber() * 70
		local radius = 70 + rng:NextNumber() * 70
		local height = 35 + rng:NextNumber() * 60
		local center = Vector3.new(math.sin(a) * r, height - radius, math.cos(a) * r)
		terrain:FillBall(center, radius, Enum.Material.Grass)
		if rng:NextNumber() < 0.3 then
			terrain:FillBall(
				center + Vector3.new(0, radius - 6, 0),
				10 + rng:NextNumber() * 6,
				Enum.Material.Rock
			)
		end
	end
	-- a few soft mounds in the countryside (between the square and the farms' outer ring)
	for _ = 1, L.MoundCount do
		local a = rng:NextNumber() * 2 * math.pi
		local r = World.PlazaRadius + 40 + rng:NextNumber() * (World.MapHalf - World.PlazaRadius - 120)
		local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if Landscape.isOpen and Landscape.isOpen(pos) then
			local radius = 12 + rng:NextNumber() * 14
			terrain:FillBall(
				pos - Vector3.new(0, radius - 3 - rng:NextNumber() * 2, 0),
				radius,
				Enum.Material.Grass
			)
		end
	end
	-- lush leafy-grass patches for color variety (no blades there: a nice texture change)
	for _ = 1, L.LeafyPatches do
		local a = rng:NextNumber() * 2 * math.pi
		local r = World.PlazaRadius + 20 + rng:NextNumber() * (World.MapHalf - World.PlazaRadius - 60)
		local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		terrain:FillCylinder(
			CFrame.new(pos.X, -0.6, pos.Z),
			1.2,
			6 + rng:NextNumber() * 10,
			Enum.Material.LeafyGrass
		)
	end
	-- the town square
	Landscape.flatDisc(Vector3.zero, World.PlazaRadius + 6)
end

-- Set by WorldBuilder: is a spot free of farms, roads and buildings (for the mounds)?
Landscape.isOpen = nil :: ((Vector3) -> boolean)?

return Landscape
