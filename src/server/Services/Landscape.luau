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

-- Terrain is stored in 4-stud cells; the top layer of cells (y -4 .. 0) is the ground surface.
-- Roblox draws a full cell's surface a bit above the cell's top, which would bury everything
-- built at y = 0 (plots, fences, paths). So after filling, Landscape.build measures where the
-- surface really is (a raycast) and thins the top layer until the surface sits at y = 0.
-- Every later edit only changes the material of top cells and keeps that thickness.
local CELL = 4
local topOccupancy = 1

-- Every terrain call is guarded: a terrain hiccup must never stop the world from being built.
local function safe(what: string, fn: () -> ())
	local ok, err = pcall(function()
		fn()
	end)
	if not ok then
		warn("Landscape: " .. what .. " failed:", err)
	end
end

-- Edit every top-layer cell whose center (x, z) is inside the box and passes `inside`:
-- edit(material, occupancy) -> (material, occupancy)
local function editTop(
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	inside: (number, number) -> boolean,
	edit: (Enum.Material, number) -> (Enum.Material, number)
)
	local x0 = math.floor(minX / CELL) * CELL
	local z0 = math.floor(minZ / CELL) * CELL
	local x1 = math.ceil(maxX / CELL) * CELL
	local z1 = math.ceil(maxZ / CELL) * CELL
	local region = Region3.new(Vector3.new(x0, -CELL, z0), Vector3.new(x1, 0, z1))
	local mats: any, occs: any = terrain:ReadVoxels(region, CELL)
	local size: Vector3 = mats.Size
	for ix = 1, size.X do
		local cx = x0 + (ix - 0.5) * CELL
		for iz = 1, size.Z do
			local cz = z0 + (iz - 0.5) * CELL
			if inside(cx, cz) then
				mats[ix][1][iz], occs[ix][1][iz] = edit(mats[ix][1][iz], occs[ix][1][iz])
			end
		end
	end
	terrain:WriteVoxels(region, CELL, mats, occs)
end

-- Change the material of solid top cells (keeps the calibrated surface height)
local function paint(material: Enum.Material): (Enum.Material, number) -> (Enum.Material, number)
	return function(m: Enum.Material, o: number)
		if o > 0 and m ~= Enum.Material.Air and m ~= Enum.Material.Water then
			return material, o
		end
		return m, o
	end
end

-- Where is the terrain surface at (x, z)? (nil if the ray finds no terrain)
local function surfaceAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else nil
end

local function everywhere(_: number, _: number): boolean
	return true
end

-- Thin the top layer until the drawn surface sits at y = 0 (see the note at the top).
local function calibrate()
	local half = World.MapHalf
	for _ = 1, 4 do
		local h = surfaceAt(2, 2)
		if h == nil then
			warn("Landscape: could not measure the terrain surface")
			return
		end
		if math.abs(h) < 0.1 then
			break
		end
		topOccupancy = math.clamp(topOccupancy - h / CELL, 0.02, 1)
		editTop(-half, -half, half, half, everywhere, function(m: Enum.Material, _: number)
			return m, topOccupancy
		end)
	end
end

-- Make the top cells under a flat area plain ground (no grass blades). `cf` is at ground level.
function Landscape.flatBlock(cf: CFrame, sizeX: number, sizeZ: number, material: Enum.Material?)
	safe("flatBlock", function()
		local hx, hz = sizeX / 2, sizeZ / 2
		local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
		for _, c in
			{
				Vector3.new(hx, 0, hz),
				Vector3.new(-hx, 0, hz),
				Vector3.new(hx, 0, -hz),
				Vector3.new(-hx, 0, -hz),
			}
		do
			local w = cf:PointToWorldSpace(c)
			minX, maxX = math.min(minX, w.X), math.max(maxX, w.X)
			minZ, maxZ = math.min(minZ, w.Z), math.max(maxZ, w.Z)
		end
		editTop(minX, minZ, maxX, maxZ, function(x: number, z: number): boolean
			local l = cf:PointToObjectSpace(Vector3.new(x, cf.Y, z))
			return math.abs(l.X) <= hx and math.abs(l.Z) <= hz
		end, paint(material or Enum.Material.Ground))
	end)
end

function Landscape.flatDisc(pos: Vector3, radius: number, material: Enum.Material?)
	safe("flatDisc", function()
		editTop(
			pos.X - radius,
			pos.Z - radius,
			pos.X + radius,
			pos.Z + radius,
			function(x: number, z: number): boolean
				return (x - pos.X) ^ 2 + (z - pos.Z) ^ 2 <= radius * radius
			end,
			paint(material or Enum.Material.Ground)
		)
	end)
end

-- A terrain lake: sandy bed and shore, real water up to ground level.
function Landscape.lake(pos: Vector3, radius: number, depth: number)
	safe("lake", function()
		local d = math.max(CELL, math.ceil(depth / CELL) * CELL)
		terrain:FillCylinder(
			CFrame.new(pos.X, -(d + CELL) / 2, pos.Z),
			d + CELL,
			radius + 3,
			Enum.Material.Sand
		)
		terrain:FillCylinder(CFrame.new(pos.X, -d / 2, pos.Z), d, radius, Enum.Material.Water)
		-- the shore and the water surface at the same height as the ground around it
		local r = radius + 3
		editTop(pos.X - r, pos.Z - r, pos.X + r, pos.Z + r, function(x: number, z: number): boolean
			return (x - pos.X) ^ 2 + (z - pos.Z) ^ 2 <= r * r
		end, function(m: Enum.Material, o: number)
			return m, if o > 0 then topOccupancy else o
		end)
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

	-- the valley floor, in tiles (one giant fill can be refused), then levelled to y = 0
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
	safe("calibrate", calibrate)

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
		Landscape.flatDisc(pos, 6 + rng:NextNumber() * 10, Enum.Material.LeafyGrass)
	end
	-- the town square
	Landscape.flatDisc(Vector3.zero, World.PlazaRadius + 6)
end

-- Set by WorldBuilder: is a spot free of farms, roads and buildings (for the mounds)?
Landscape.isOpen = nil :: ((Vector3) -> boolean)?

return Landscape
