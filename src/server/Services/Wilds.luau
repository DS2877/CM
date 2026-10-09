--!strict
-- The Wilds: the countryside ring between the town square and the farms. Each sector between two
-- farm roads has its own little place to discover, linked to the square by a dirt trail with a
-- signpost at the square's edge:
--   * 🍄 Mushroom Forest - the bouncy mushrooms (WorldFun) in a ring of trees and tiny mushrooms
--   * 🎣 Lake - island with a palm and a bunny statue, a rowboat (the dock & fisher: WorldFun/Bots)
--   * ⛺ Campfire - the campfire clearing (WorldFun) inside a ring of pine trees
--   * 🪁 Kite Hill & Picnic (WorldFun) - a gentle meadow
--   * 🌊 Waterfall - a rocky cliff with a waterfall, a pool and a SLIDE down from the top
--     (parts named "Slide" with a SlideDir attribute; the client slides you down them)
--   * 🌻 Flower Fields - striped flower rows, beehives with buzzing bees, a giant sunflower

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local Landscape = require(script.Parent.Landscape)

local Wilds = {}

local C = {
	dirt = Color3.fromRGB(196, 150, 100),
	dirtEdge = Color3.fromRGB(160, 120, 80),
	wood = Color3.fromRGB(190, 132, 78),
	darkWood = Color3.fromRGB(120, 78, 46),
	trunk = Color3.fromRGB(128, 86, 54),
	pine = Color3.fromRGB(60, 140, 75),
	pineLight = Color3.fromRGB(90, 170, 90),
	leaf = Color3.fromRGB(72, 158, 64),
	rock = Color3.fromRGB(150, 140, 130),
	rockDark = Color3.fromRGB(120, 112, 105),
	grass = Color3.fromRGB(110, 185, 75),
	water = Color3.fromRGB(80, 175, 235),
	foam = Color3.fromRGB(225, 245, 255),
	sand = Color3.fromRGB(235, 215, 160),
	white = Color3.fromRGB(255, 252, 245),
	yellow = Color3.fromRGB(255, 214, 60),
	slide = Color3.fromRGB(80, 170, 255),
}
local FLOWERS = {
	Color3.fromRGB(255, 105, 150),
	Color3.fromRGB(255, 205, 50),
	Color3.fromRGB(175, 120, 255),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(255, 255, 255),
}

local rng = Random.new(World.Seed + 7)

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Upright cylinder centered at `cf`.
local function cyl(parent: Instance, name: string, height: number, d: number, cf: CFrame, color: Color3): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, d, d),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	})
end

local function ball(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, { Name = name, Size = size, CFrame = cf, Color = color, CanCollide = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function signText(p: BasePart, face: Enum.NormalId, text: string, stroke: Color3)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.CanvasSize = Vector2.new(320, 80)
	g.LightInfluence = 0.2
	g.MaxDistance = 160
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -12, 1, -8)
	l.Position = UDim2.fromOffset(6, 4)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = C.white
	l.TextStrokeColor3 = stroke
	l.TextStrokeTransparency = 0
	l.Parent = g
end

local function pineTree(parent: Instance, pos: Vector3, scale: number)
	cyl(parent, "PineTrunk", 4 * scale, 1.2 * scale, CFrame.new(pos + Vector3.new(0, 2 * scale, 0)), C.trunk).Material =
		Enum.Material.Wood
	for k = 0, 3 do
		local d = (8 - k * 1.8) * scale
		local h = 3 * scale
		local p = cyl(
			parent,
			"PineTier",
			h,
			d,
			CFrame.new(pos + Vector3.new(0, (4 + k * 2.6) * scale, 0)),
			if k % 2 == 0 then C.pine else C.pineLight
		)
		p.CastShadow = true
	end
	ball(
		parent,
		"PineTop",
		Vector3.one * 1.6 * scale,
		CFrame.new(pos + Vector3.new(0, 13.2 * scale, 0)),
		C.pineLight
	)
end

local function roundTree(parent: Instance, pos: Vector3, scale: number)
	cyl(parent, "Trunk", 7 * scale, 1.4 * scale, CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)), C.trunk).Material =
		Enum.Material.Wood
	local top = pos + Vector3.new(0, 9 * scale, 0)
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 9 * scale,
		CFrame = CFrame.new(top),
		Color = C.leaf,
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 6 * scale,
		CFrame = CFrame.new(top + Vector3.new(2 * scale, 2.5 * scale, -1 * scale)),
		Color = C.leaf:Lerp(Color3.new(1, 1, 1), 0.15),
		CanCollide = false,
	})
end

-- Trails & signposts ------------------------------------------------------------------

type Spot = { name: string, angle: number, radius: number }
local SPOTS: { Spot } = {
	{ name = "🍄 MUSHROOM FOREST", angle = 30, radius = World.MushroomRadius - 18 },
	{ name = "🎣 LAKE", angle = World.LakeAngle, radius = World.LakeRadius - World.LakeSize / 2 - 6 },
	{ name = "⛺ CAMPFIRE", angle = World.CampAngle, radius = World.CampRadius - 12 },
	{ name = "🪁 KITE HILL", angle = 213, radius = 140 },
	{ name = "🌊 WATERFALL", angle = World.WaterfallAngle, radius = World.WaterfallRadius - 26 },
	{ name = "🌻 FLOWER FIELDS", angle = World.FlowerAngle, radius = World.FlowerRadius - 22 },
}

local function buildTrails(parent: Instance)
	local f = folder("Trails", parent)
	for _, s in SPOTS do
		local dir = World.dirOf(s.angle)
		local from = dir * (World.PlazaRadius + 3)
		local to = dir * s.radius
		local mid = (from + to) / 2
		local len = (to - from).Magnitude
		local cf = CFrame.lookAt(mid, mid + dir)
		Landscape.flatBlock(cf, 8, len)
		part(f, {
			Name = "TrailEdge",
			Size = Vector3.new(6.6, 0.12, len),
			CFrame = cf * CFrame.new(0, 0.06, 0),
			Color = C.dirtEdge,
			Material = Enum.Material.Ground,
			CanCollide = false,
		})
		part(f, {
			Name = "Trail",
			Size = Vector3.new(5.4, 0.16, len),
			CFrame = cf * CFrame.new(0, 0.08, 0),
			Color = C.dirt,
			Material = Enum.Material.Ground,
			CanCollide = false,
		})
		-- stepping stones along the trail
		for d = 6, len - 4, 7 do
			local p = from
				+ dir * d
				+ Vector3.new(-dir.Z, 0, dir.X) * (if math.floor(d / 7) % 2 == 0 then 1 else -1)
			cyl(
				f,
				"SteppingStone",
				0.2,
				1.6,
				CFrame.new(p + Vector3.new(0, 0.18, 0)),
				Color3.fromRGB(205, 200, 190)
			).CanCollide =
				false
		end
		-- signpost at the square's edge
		local postPos = from + dir * 4 + Vector3.new(-dir.Z, 0, dir.X) * 5
		part(f, {
			Name = "SignPost",
			Size = Vector3.new(0.6, 7, 0.6),
			CFrame = CFrame.new(postPos + Vector3.new(0, 3.5, 0)),
			Color = C.darkWood,
			Material = Enum.Material.Wood,
		})
		local board = part(f, {
			Name = "SignBoard",
			Size = Vector3.new(8, 1.8, 0.3),
			CFrame = CFrame.lookAt(
				postPos + Vector3.new(0, 6, 0),
				postPos + Vector3.new(0, 6, 0) + Vector3.new(dir.Z, 0, -dir.X)
			),
			Color = C.wood,
			Material = Enum.Material.WoodPlanks,
		})
		signText(board, Enum.NormalId.Front, s.name, C.darkWood)
		signText(board, Enum.NormalId.Back, s.name, C.darkWood)
	end
end

-- Mushroom Forest ---------------------------------------------------------------------

local function buildMushroomForest(parent: Instance)
	local f = folder("MushroomForest", parent)
	local center = World.dirOf(30) * World.MushroomRadius
	local colors = {
		Color3.fromRGB(235, 70, 80),
		Color3.fromRGB(255, 120, 190),
		Color3.fromRGB(175, 120, 255),
		Color3.fromRGB(255, 170, 60),
	}
	-- trees around (not on the trail side)
	for k = 0, 17 do
		local a = math.rad(k * 20 + rng:NextNumber(-6, 6))
		local r = 42 + rng:NextNumber(0, 18)
		local offset = Vector3.new(math.sin(a), 0, math.cos(a))
		local pos = center + offset * r
		local towardSquare = offset:Dot(-World.dirOf(30)) > 0.8 -- keep the trail side open
		if not towardSquare and pos.Magnitude < World.FarmRingRadius - 75 then
			roundTree(f, pos, 0.9 + rng:NextNumber() * 0.5)
		end
	end
	-- little mushrooms everywhere (decor, not bouncy) and a fairy ring
	for _ = 1, 40 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 12 + rng:NextNumber() * 34
		local pos = center + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		local s = 0.6 + rng:NextNumber() * 0.9
		cyl(f, "TinyStem", 1.2 * s, 0.5 * s, CFrame.new(pos + Vector3.new(0, 0.6 * s, 0)), C.white).CanCollide =
			false
		ball(
			f,
			"TinyCap",
			Vector3.new(1.6, 0.8, 1.6) * s,
			CFrame.new(pos + Vector3.new(0, 1.25 * s, 0)),
			colors[rng:NextInteger(1, #colors)]
		)
	end
	-- floating sparkles (fairy dust) over the forest
	local dust = part(f, {
		Name = "FairyDust",
		Size = Vector3.new(60, 1, 60),
		CFrame = CFrame.new(center + Vector3.new(0, 4, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(200, 160, 255))
	e.LightEmission = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 12
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = dust
end

-- Lake extras ---------------------------------------------------------------------------

local function buildLakeIsland(parent: Instance)
	local f = folder("LakeIsland", parent)
	local dir = World.dirOf(World.LakeAngle)
	local c = dir * World.LakeRadius
	local side = Vector3.new(-dir.Z, 0, dir.X)
	-- the island on the far side of the lake
	local isl = c + dir * (World.LakeSize / 2 - 9)
	cyl(f, "IslandSand", 1.4, 11, CFrame.new(isl + Vector3.new(0, 0.5, 0)), C.sand).Material =
		Enum.Material.Sand
	cyl(f, "IslandGrass", 0.4, 7, CFrame.new(isl + Vector3.new(0, 1.3, 0)), C.grass).Material =
		Enum.Material.Grass
	-- a curvy palm tree
	local base = isl + Vector3.new(-1, 1.4, 0)
	local p = base
	for k = 0, 5 do
		local nextP = p + Vector3.new(0.35, 1.6, 0.15)
		part(f, {
			Name = "PalmTrunk",
			Size = Vector3.new(0.9 - k * 0.06, 1.75, 0.9 - k * 0.06),
			CFrame = CFrame.lookAt((p + nextP) / 2, nextP) * CFrame.Angles(math.rad(90), 0, 0),
			Color = C.trunk,
			Material = Enum.Material.Wood,
		})
		p = nextP
	end
	for k = 0, 5 do
		local a = k * math.pi / 3
		part(f, {
			Name = "PalmLeaf",
			Size = Vector3.new(1.4, 0.2, 5),
			CFrame = CFrame.new(p)
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, -0.6, 2.2)
				* CFrame.Angles(math.rad(25), 0, 0),
			Color = C.leaf,
			CanCollide = false,
		})
	end
	for k = 0, 2 do
		ball(
			f,
			"Coconut",
			Vector3.one * 0.7,
			CFrame.new(p + Vector3.new(math.cos(k * 2) * 0.5, -0.5, math.sin(k * 2) * 0.5)),
			C.trunk
		)
	end
	-- a golden bunny statue on the island
	local s = isl + Vector3.new(2, 1.5, 0)
	ball(
		f,
		"StatueBody",
		Vector3.new(1.6, 1.8, 1.6),
		CFrame.new(s + Vector3.new(0, 0.9, 0)),
		Color3.fromRGB(255, 200, 60)
	).Material =
		Enum.Material.Foil
	ball(
		f,
		"StatueHead",
		Vector3.new(1.2, 1.1, 1.1),
		CFrame.new(s + Vector3.new(0, 2.2, -0.2)),
		Color3.fromRGB(255, 200, 60)
	).Material =
		Enum.Material.Foil
	for _, sx in { -1, 1 } do
		ball(
			f,
			"StatueEar",
			Vector3.new(0.35, 1.3, 0.25),
			CFrame.new(s + Vector3.new(sx * 0.3, 3.2, -0.2)),
			Color3.fromRGB(255, 200, 60)
		).Material =
			Enum.Material.Foil
	end
	-- a rowboat with oars
	local boat = c + side * (World.LakeSize / 2 - 8)
	local bcf = CFrame.lookAt(boat + Vector3.new(0, 0.55, 0), boat + Vector3.new(0, 0.55, 0) + dir)
	part(f, {
		Name = "BoatHull",
		Size = Vector3.new(3, 0.9, 6.5),
		CFrame = bcf,
		Color = Color3.fromRGB(235, 90, 80),
		Material = Enum.Material.WoodPlanks,
	})
	part(f, {
		Name = "BoatInside",
		Size = Vector3.new(2.4, 0.3, 5.8),
		CFrame = bcf * CFrame.new(0, 0.35, 0),
		Color = C.wood,
		Material = Enum.Material.WoodPlanks,
	})
	part(f, {
		Name = "BoatSeat",
		Size = Vector3.new(2.6, 0.25, 0.8),
		CFrame = bcf * CFrame.new(0, 0.7, 0),
		Color = C.darkWood,
	})
	for _, sx in { -1, 1 } do
		part(f, {
			Name = "Oar",
			Size = Vector3.new(0.2, 0.2, 4),
			CFrame = bcf
				* CFrame.new(sx * 2.4, 0.7, 0)
				* CFrame.Angles(0, sx * 0.6, 0)
				* CFrame.Angles(-0.2, 0, 0),
			Color = C.darkWood,
			CanCollide = false,
		})
	end
end

-- Campfire forest ------------------------------------------------------------------------

local function buildCampForest(parent: Instance)
	local f = folder("CampForest", parent)
	local dir = World.dirOf(World.CampAngle)
	local c = dir * World.CampRadius
	for k = 0, 15 do
		local a = math.rad(k * 22.5)
		local offset = Vector3.new(math.sin(a), 0, math.cos(a))
		-- keep the side toward the square open (that's where the trail comes in)
		if offset:Dot(-dir) < 0.75 then
			local r = 20 + rng:NextNumber(0, 6)
			pineTree(f, c + offset * r, 1 + rng:NextNumber() * 0.4)
		end
	end
	-- a log pile and a chopping stump with an axe
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local pile = c - side * 11
	for k = 0, 4 do
		local row = if k < 3 then 0 else 1
		local x = (if row == 0 then k - 1 else k - 3.5) * 1.3
		cyl(
			f,
			"PileLog",
			4,
			1.2,
			CFrame.lookAt(pile, pile + dir)
				* CFrame.new(x, 0.6 + row * 1.05, 0)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(0, math.rad(90), 0),
			C.trunk
		).Material =
			Enum.Material.Wood
	end
	local stump = c + side * 11 - dir * 3
	cyl(f, "Stump", 1.6, 2.4, CFrame.new(stump + Vector3.new(0, 0.8, 0)), C.trunk).Material =
		Enum.Material.Wood
	part(f, {
		Name = "AxeHandle",
		Size = Vector3.new(0.25, 2.4, 0.25),
		CFrame = CFrame.new(stump + Vector3.new(0.2, 2.4, 0)) * CFrame.Angles(0, 0, 0.3),
		Color = C.wood,
		CanCollide = false,
	})
	part(f, {
		Name = "AxeHead",
		Size = Vector3.new(0.9, 0.6, 0.15),
		CFrame = CFrame.new(stump + Vector3.new(-0.15, 1.7, 0)),
		Color = Color3.fromRGB(170, 170, 180),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
end

-- Waterfall hill with a slide ---------------------------------------------------------------

local function buildWaterfall(parent: Instance)
	local f = folder("Waterfall", parent)
	local dir = World.dirOf(World.WaterfallAngle)
	local c = dir * World.WaterfallRadius
	local cf = CFrame.lookAt(c, c - dir) -- -Z faces the square
	local W, H, D = 44, 26, 26
	-- the cliff: a big rock block with rounded boulders around it and a grass top
	part(f, {
		Name = "Cliff",
		Size = Vector3.new(W, H, D),
		CFrame = cf * CFrame.new(0, H / 2, 0),
		Color = C.rock,
		Material = Enum.Material.Slate,
	})
	part(f, {
		Name = "CliffTop",
		Size = Vector3.new(W + 1, 1.2, D + 1),
		CFrame = cf * CFrame.new(0, H + 0.6, 0),
		Color = C.grass,
		Material = Enum.Material.Grass,
	})
	for k = 0, 9 do
		local x = -W / 2 + k * W / 9
		local s = 6 + rng:NextNumber() * 6
		part(f, {
			Name = "Boulder",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s,
			CFrame = cf * CFrame.new(x, s * 0.3, -D / 2 + 1),
			Color = C.rockDark,
			Material = Enum.Material.Slate,
		})
	end
	-- trees on top
	for _, x in { -14, -4, 12 } do
		pineTree(f, (cf * CFrame.new(x, H + 1.2, 6)).Position, 0.8)
	end
	-- the waterfall pouring down the front into a pool
	local fall = part(f, {
		Name = "Fall",
		Size = Vector3.new(8, H, 0.6),
		CFrame = cf * CFrame.new(-6, H / 2 + 0.6, -D / 2 - 0.4),
		Color = C.water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
	})
	local stream = Instance.new("ParticleEmitter")
	stream.Color = ColorSequence.new(C.foam)
	stream.Transparency = NumberSequence.new(0.3, 0.8)
	stream.Size = NumberSequence.new(1.2, 2)
	stream.Lifetime = NumberRange.new(1.2, 1.6)
	stream.Rate = 40
	stream.Speed = NumberRange.new(14, 18)
	stream.EmissionDirection = Enum.NormalId.Bottom
	stream.Parent = fall
	local pool = cyl(f, "Pool", 0.5, 22, cf * CFrame.new(-6, 0.3, -D / 2 - 10), C.water)
	pool.Material = Enum.Material.Glass
	pool.Transparency = 0.2
	pool.CanCollide = false
	cyl(f, "PoolRim", 0.4, 24, cf * CFrame.new(-6, 0.2, -D / 2 - 10), C.sand).Material = Enum.Material.Sand
	local mist = part(f, {
		Name = "Mist",
		Size = Vector3.new(10, 1, 4),
		CFrame = cf * CFrame.new(-6, 1, -D / 2 - 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local m = Instance.new("ParticleEmitter")
	m.Color = ColorSequence.new(C.foam)
	m.Transparency = NumberSequence.new(0.4, 1)
	m.Size = NumberSequence.new(2, 5)
	m.Lifetime = NumberRange.new(1.5, 2.5)
	m.Rate = 15
	m.Speed = NumberRange.new(2, 4)
	m.SpreadAngle = Vector2.new(60, 60)
	m.EmissionDirection = Enum.NormalId.Top
	m.Parent = mist
	-- a ramp up the left side to the top
	local steps = 26
	for k = 0, steps - 1 do
		local y = (k + 1) * (H / steps)
		part(f, {
			Name = "Ramp",
			Size = Vector3.new(6, 1, 4.2),
			CFrame = cf * CFrame.new(-W / 2 - 3.5, y - 0.5, -D / 2 + 2 + k * (D - 4) / (steps - 1) - 2),
			Color = C.wood,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- the SLIDE: a blue chute from the top-right corner down into the pool area
	local top = (cf * CFrame.new(W / 2 - 6, H + 1.2, -D / 2 + 3)).Position
	local bottom = (cf * CFrame.new(W / 2 + 4, 1, -D / 2 - 26)).Position
	local seg = 8
	local slides = folder("Slides", f)
	for k = 0, seg - 1 do
		local a = top:Lerp(bottom, k / seg)
		local b = top:Lerp(bottom, (k + 1) / seg)
		-- curve: a little wave sideways
		local wave = Vector3.new(-dir.Z, 0, dir.X) * math.sin(k / seg * math.pi) * 4
		local wave2 = Vector3.new(-dir.Z, 0, dir.X) * math.sin((k + 1) / seg * math.pi) * 4
		a += wave
		b += wave2
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 0.3
		local scf = CFrame.lookAt(mid, b)
		local chute =
			part(slides, { Name = "Slide", Size = Vector3.new(4, 0.4, len), CFrame = scf, Color = C.slide })
		chute:SetAttribute("SlideDir", (b - a).Unit)
		for _, sx in { -1, 1 } do
			part(slides, {
				Name = "SlideRail",
				Size = Vector3.new(0.4, 1.2, len),
				CFrame = scf * CFrame.new(sx * 2.1, 0.6, 0),
				Color = Color3.fromRGB(255, 220, 60),
				CanCollide = true,
			})
		end
	end
	-- sign on the cliff
	local board = part(f, {
		Name = "SlideSign",
		Size = Vector3.new(10, 2.4, 0.4),
		CFrame = cf * CFrame.new(W / 2 - 6, H + 4, -D / 2 + 1),
		Color = C.slide,
	})
	signText(board, Enum.NormalId.Front, "🌊 SUPER SLIDE!", Color3.fromRGB(10, 50, 110))
end

-- Flower Fields ---------------------------------------------------------------------------

local function buildFlowerFields(parent: Instance)
	local f = folder("FlowerFields", parent)
	local dir = World.dirOf(World.FlowerAngle)
	local c = dir * World.FlowerRadius
	local cf = CFrame.lookAt(c, c - dir)
	-- striped rows of flowers, one color per row
	local rows, perRow = 8, 14
	for r = 0, rows - 1 do
		local color = FLOWERS[(r % #FLOWERS) + 1]
		for k = 0, perRow - 1 do
			local pos = (cf * CFrame.new(
				-perRow * 1.2 + k * 2.4 + rng:NextNumber(-0.3, 0.3),
				0,
				-rows * 1.5 + r * 3
			)).Position
			part(f, {
				Name = "Stem",
				Size = Vector3.new(0.18, 1.5, 0.18),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.75, 0)),
				Color = C.leaf,
				CanCollide = false,
				CanQuery = false,
			})
			ball(f, "Bloom", Vector3.new(1, 0.7, 1), CFrame.new(pos + Vector3.new(0, 1.6, 0)), color)
		end
	end
	-- a low fence around the field
	local w, d = perRow * 2.4 + 6, rows * 3 + 6
	for _, side in
		{ { 0, -d / 2, w, 0.3 }, { 0, d / 2, w, 0.3 }, { -w / 2, 0, 0.3, d }, { w / 2, 0, 0.3, d } }
	do
		part(f, {
			Name = "FieldFence",
			Size = Vector3.new(side[3], 1.2, side[4]),
			CFrame = cf * CFrame.new(side[1], 0.9, side[2]),
			Color = C.white,
			CanCollide = false,
		})
	end
	-- beehives with bees
	for k = 0, 2 do
		local hcf = cf * CFrame.new(w / 2 + 6, 0, -6 + k * 6)
		part(f, {
			Name = "HiveStand",
			Size = Vector3.new(2.6, 1, 2.6),
			CFrame = hcf * CFrame.new(0, 0.5, 0),
			Color = C.darkWood,
		})
		for j = 0, 2 do
			part(f, {
				Name = "Hive",
				Size = Vector3.new(2.4, 0.9, 2.4),
				CFrame = hcf * CFrame.new(0, 1.45 + j * 0.95, 0),
				Color = if j % 2 == 0 then C.white else C.yellow,
			})
		end
		local hiveTop = part(f, {
			Name = "HiveRoof",
			Size = Vector3.new(2.8, 0.3, 2.8),
			CFrame = hcf * CFrame.new(0, 4.4, 0),
			Color = C.darkWood,
		})
		local bees = Instance.new("ParticleEmitter")
		bees.Color = ColorSequence.new(C.yellow)
		bees.Size = NumberSequence.new(0.25)
		bees.Lifetime = NumberRange.new(2, 3)
		bees.Rate = 4
		bees.Speed = NumberRange.new(2, 3)
		bees.SpreadAngle = Vector2.new(180, 180)
		bees.RotSpeed = NumberRange.new(-180, 180)
		bees.Parent = hiveTop
	end
	-- a giant sunflower
	local sun = (cf * CFrame.new(-w / 2 - 7, 0, 0)).Position
	cyl(f, "SunflowerStem", 14, 0.8, CFrame.new(sun + Vector3.new(0, 7, 0)), C.leaf)
	for _, s in { -1, 1 } do
		part(f, {
			Name = "SunflowerLeaf",
			Size = Vector3.new(3, 0.2, 1.4),
			CFrame = CFrame.new(sun + Vector3.new(s * 1.5, 6 + s, 0)) * CFrame.Angles(0, 0, s * 0.4),
			Color = C.leaf,
			CanCollide = false,
		})
	end
	local face = CFrame.lookAt(sun + Vector3.new(0, 14.5, 0), sun + Vector3.new(0, 14.5, 0) - dir)
	cyl(f, "SunflowerCenter", 0.6, 4, face * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(120, 75, 35))
	for k = 0, 11 do
		local a = k * math.pi / 6
		ball(
			f,
			"Petal",
			Vector3.new(1.4, 2.6, 0.4),
			face * CFrame.Angles(0, 0, a) * CFrame.new(0, 3, 0.1),
			C.yellow
		)
	end
end

function Wilds.build(world: Instance)
	local wilds = folder("Wilds", world)
	buildTrails(wilds)
	buildMushroomForest(wilds)
	buildLakeIsland(wilds)
	buildCampForest(wilds)
	buildWaterfall(wilds)
	buildFlowerFields(wilds)
end

-- Spots the random decor (trees, bushes, rocks) must keep clear of.
function Wilds.blocked(flat: Vector3): boolean
	for _, s in SPOTS do
		local dir = World.dirOf(s.angle)
		-- the trail
		local along = flat:Dot(dir)
		if along > World.PlazaRadius and along < s.radius + 4 and (flat - dir * along).Magnitude < 6 then
			return true
		end
	end
	local function near(angle: number, radius: number, r: number): boolean
		return (flat - World.dirOf(angle) * radius).Magnitude < r
	end
	return near(30, World.MushroomRadius, 62)
		or near(World.WaterfallAngle, World.WaterfallRadius, 48)
		or near(World.FlowerAngle, World.FlowerRadius, 36)
		or near(World.CampAngle, World.CampRadius, 30)
end

return Wilds
