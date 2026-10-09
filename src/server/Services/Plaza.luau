--!strict
-- The town square's districts (Config/World angles), built around the BOOM EXCHANGE tower:
--   * center: a fountain ring around the tower, cobbled inner circle, flower planters
--   * Upgrade Workshop: a big brick workshop with a teal roof, chimney smoke and a spinning
--     gear; its pad in front opens the Upgrades panel
--   * Seed Store: a glass greenhouse shop (its pad opens the Seeds menu - prepared for buying
--     seeds in the world later)
--   * Hall of Fame: a golden arch behind the leaderboards, with a trophy podium
--   * Fun Fair: a turning carousel, food carts and picnic tables
--   * Stage: a party stage with a DJ bunny, speakers and lights (dances during booms)
--   * Bunny Launchers at both ends of every farm road
-- The Bunny Market (stalls + hall) and the tower are built by BunnyMarket.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.Config.World)
local BunnyMarket = require(script.Parent.BunnyMarket)
local Landscape = require(script.Parent.Landscape)

local Plaza = {}

local C = {
	wood = Color3.fromRGB(190, 132, 78),
	darkWood = Color3.fromRGB(120, 78, 46),
	white = Color3.fromRGB(255, 252, 245),
	cream = Color3.fromRGB(255, 244, 222),
	brick = Color3.fromRGB(205, 120, 80),
	stone = Color3.fromRGB(200, 196, 188),
	teal = Color3.fromRGB(60, 175, 215),
	tealDark = Color3.fromRGB(30, 110, 140),
	gold = Color3.fromRGB(255, 200, 60),
	pink = Color3.fromRGB(255, 160, 185),
	water = Color3.fromRGB(90, 180, 240),
	glass = Color3.fromRGB(200, 240, 220),
	leaf = Color3.fromRGB(80, 170, 70),
	purple = Color3.fromRGB(160, 100, 240),
	black = Color3.fromRGB(35, 32, 40),
}
local CANDY = {
	Color3.fromRGB(255, 105, 150),
	Color3.fromRGB(255, 205, 50),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(120, 220, 110),
	Color3.fromRGB(175, 120, 255),
}

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

local function cyl(parent: Instance, name: string, height: number, d: number, cf: CFrame, color: Color3): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, d, d),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	})
end

local function ball(parent: Instance, name: string, d: number, cf: CFrame, color: Color3): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		CFrame = cf,
		Color = color,
		CanCollide = false,
	})
end

local function sign(
	p: BasePart,
	face: Enum.NormalId,
	canvas: Vector2,
	text: string,
	stroke: Color3,
	color: Color3?
)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.CanvasSize = canvas
	g.LightInfluence = 0.15
	g.MaxDistance = 350
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -20, 1, -12)
	l.Position = UDim2.fromOffset(10, 6)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color or C.white
	l.TextStrokeColor3 = stroke
	l.TextStrokeTransparency = 0
	l.Parent = g
end

-- A round pad on the ground with text painted on it (readable for someone walking toward
-- `facing` direction).
local function pad(
	parent: Instance,
	name: string,
	pos: Vector3,
	radius: number,
	color: Color3,
	rim: Color3,
	text: string,
	facing: Vector3
)
	cyl(parent, name .. "Rim", 0.3, radius * 2 + 1.2, CFrame.new(pos + Vector3.new(0, 0.45, 0)), rim).CanCollide =
		false
	local p = cyl(parent, name, 0.32, radius * 2, CFrame.new(pos + Vector3.new(0, 0.48, 0)), color)
	p.CanCollide = false
	local plate = part(parent, {
		Name = name .. "Plate",
		Size = Vector3.new(radius * 1.6, 0.05, radius * 0.9),
		CFrame = CFrame.lookAt(pos + Vector3.new(0, 0.68, 0), pos + Vector3.new(0, 0.68, 0) + facing),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	sign(plate, Enum.NormalId.Top, Vector2.new(300, 160), text, color:Lerp(Color3.new(0, 0, 0), 0.6))
	return p
end

local function districtCF(angle: number, distance: number): CFrame
	local dir = World.dirOf(angle)
	local pos = dir * distance
	return CFrame.lookAt(pos, pos - dir) -- -Z (LookVector) toward the tower
end

-- Center ------------------------------------------------------------------------

local function buildCenter(parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "Center"
	f.Parent = parent
	-- cobbled inner circle and a fountain ring around the tower
	cyl(f, "InnerCircle", 0.2, 64, CFrame.new(0, 0.6, 0), Color3.fromRGB(225, 205, 175)).Material =
		Enum.Material.Cobblestone
	cyl(f, "FountainRim", 1.6, 40, CFrame.new(0, 1.3, 0), C.stone).Material = Enum.Material.Marble
	local water = cyl(f, "FountainWater", 0.4, 37, CFrame.new(0, 1.9, 0), C.water)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.2
	water.CanCollide = false
	-- water jets around the ring
	for k = 0, 7 do
		local a = k * math.pi / 4
		local jet = part(f, {
			Name = "Jet",
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = CFrame.new(math.cos(a) * 16, 2.2, math.sin(a) * 16),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
		e.Size = NumberSequence.new(0.5, 0.15)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Lifetime = NumberRange.new(1, 1.3)
		e.Rate = 25
		e.Speed = NumberRange.new(9, 11)
		e.SpreadAngle = Vector2.new(6, 6)
		e.Acceleration = Vector3.new(0, -20, 0)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = jet
	end
	-- flower planters on the inner circle, between the farm roads
	for k = 0, World.FarmCount - 1 do
		local a = math.rad((k + 0.5) * 360 / World.FarmCount)
		local pos = Vector3.new(math.sin(a) * 28, 0, math.cos(a) * 28)
		cyl(f, "Planter", 1.4, 6, CFrame.new(pos + Vector3.new(0, 1, 0)), C.brick).Material =
			Enum.Material.Brick
		for j = 0, 5 do
			local b = j * math.pi / 3
			ball(
				f,
				"Flower",
				1.1,
				CFrame.new(pos + Vector3.new(math.cos(b) * 1.6, 2.1, math.sin(b) * 1.6)),
				CANDY[(j % #CANDY) + 1]
			)
		end
		ball(f, "Bush", 2.6, CFrame.new(pos + Vector3.new(0, 2.4, 0)), C.leaf)
	end
end

-- Upgrade Workshop ----------------------------------------------------------------

local function buildWorkshop(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "UpgradeShop"
	local angle = World.UpgradeStallAngles[1] or World.WorkshopAngle
	local cf = districtCF(angle, World.UpgradeStallDistance)
	local W, D, H = 30, 16, 13
	part(m, {
		Name = "Floor",
		Size = Vector3.new(W, 0.6, D),
		CFrame = cf * CFrame.new(0, 0.6, 0),
		Color = C.wood,
		Material = Enum.Material.WoodPlanks,
	})
	-- brick walls on three sides, open front
	part(m, {
		Name = "Wall",
		Size = Vector3.new(W, H, 1),
		CFrame = cf * CFrame.new(0, H / 2, D / 2),
		Color = C.brick,
		Material = Enum.Material.Brick,
	})
	for _, sx in { -1, 1 } do
		part(m, {
			Name = "Wall",
			Size = Vector3.new(1, H, D),
			CFrame = cf * CFrame.new(sx * W / 2, H / 2, 0),
			Color = C.brick,
			Material = Enum.Material.Brick,
		})
		-- front pillars
		part(m, {
			Name = "Pillar",
			Size = Vector3.new(2, H, 2),
			CFrame = cf * CFrame.new(sx * (W / 2 - 0.5), H / 2, -D / 2),
			Color = C.cream,
			Material = Enum.Material.Concrete,
		})
	end
	-- teal roof
	for _, sz in { -1, 1 } do
		part(m, {
			Name = "Roof",
			Size = Vector3.new(W + 3, 0.8, D * 0.62),
			CFrame = cf * CFrame.new(0, H + 2.4, sz * D * 0.25) * CFrame.Angles(math.rad(sz * 30), 0, 0),
			Color = C.teal,
		})
	end
	-- chimney with smoke
	local chimney = part(m, {
		Name = "Chimney",
		Size = Vector3.new(2.6, 8, 2.6),
		CFrame = cf * CFrame.new(W / 2 - 5, H + 4, 4),
		Color = C.brick,
		Material = Enum.Material.Brick,
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(235, 235, 240)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = chimney
	-- workbench counter with tools
	part(m, {
		Name = "Counter",
		Size = Vector3.new(W - 6, 3.2, 2),
		CFrame = cf * CFrame.new(0, 2.2, -D / 2 + 3),
		Color = C.wood,
		Material = Enum.Material.WoodPlanks,
	})
	part(m, {
		Name = "CounterTop",
		Size = Vector3.new(W - 5, 0.4, 2.6),
		CFrame = cf * CFrame.new(0, 4, -D / 2 + 3),
		Color = C.darkWood,
	})
	part(m, {
		Name = "Toolbox",
		Size = Vector3.new(2.2, 1.1, 1.2),
		CFrame = cf * CFrame.new(-8, 4.75, -D / 2 + 3),
		Color = Color3.fromRGB(220, 70, 60),
	})
	cyl(m, "WateringCan", 1.6, 1.4, cf * CFrame.new(8, 5, -D / 2 + 3), C.teal)
	ball(m, "SeedSack", 2, cf * CFrame.new(0, 5.1, -D / 2 + 3), Color3.fromRGB(220, 190, 130))
	-- the sign and a big spinning gear above it
	local board = part(m, {
		Name = "NameBoard",
		Size = Vector3.new(W - 4, 3.6, 0.5),
		CFrame = cf * CFrame.new(0, H - 1, -D / 2 - 0.4),
		Color = C.tealDark,
	})
	sign(board, Enum.NormalId.Front, Vector2.new(640, 90), "⬆ UPGRADE WORKSHOP", Color3.fromRGB(10, 50, 70))
	-- axle along the building's facing (cyl() turns X up, so turn it back and then toward us)
	local hub = cyl(
		m,
		"GearHub",
		1.2,
		3,
		cf
			* CFrame.new(0, H + 7, -D / 2 + 1)
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.Angles(0, 0, math.rad(-90)),
		C.gold
	)
	hub.Material = Enum.Material.Metal
	hub.CanCollide = false
	for k = 0, 7 do
		local tooth = part(m, {
			Name = "GearTooth",
			Size = Vector3.new(1.4, 7, 1),
			CFrame = hub.CFrame * CFrame.Angles(k * math.pi / 8, 0, 0),
			Color = C.gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Anchored = false,
			Massless = true,
		})
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = tooth
		w.Parent = tooth
	end
	TweenService:Create(
		hub,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ CFrame = hub.CFrame * CFrame.Angles(math.pi / 4, 0, 0) }
	):Play()
	-- the pad
	local padPos = World.upgradePads()[1]
	pad(m, "UpgradePad", padPos, World.UpgradePadRadius, C.teal, C.white, "⬆ UPGRADES", -cf.LookVector)
	m.Parent = parent
end

-- Seed Store ------------------------------------------------------------------------

local function buildSeedStore(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "SeedStore"
	local cf = districtCF(World.SeedStoreAngle, World.SeedStoreDistance)
	local W, D, H = 26, 14, 9
	part(m, {
		Name = "Base",
		Size = Vector3.new(W, 1.2, D),
		CFrame = cf * CFrame.new(0, 0.6, 0),
		Color = C.stone,
		Material = Enum.Material.Concrete,
	})
	-- glass walls with white frames
	local glass = part(m, {
		Name = "Glass",
		Size = Vector3.new(W - 1, H, D - 1),
		CFrame = cf * CFrame.new(0, 1.2 + H / 2, 0),
		Color = C.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		CanCollide = false,
	})
	glass.CastShadow = false
	for k = 0, 6 do
		local x = -W / 2 + 0.5 + k * (W - 1) / 6
		part(m, {
			Name = "Frame",
			Size = Vector3.new(0.4, H, D),
			CFrame = cf * CFrame.new(x, 1.2 + H / 2, 0),
			Color = C.white,
			CanCollide = false,
		})
	end
	-- arched glass roof (a long half-cylinder look made of a flattened cylinder)
	local roof =
		cyl(m, "Roof", W, D, cf * CFrame.new(0, 1.2 + H, 0) * CFrame.Angles(0, 0, math.rad(-90)), C.glass)
	roof.Material = Enum.Material.Glass
	roof.Transparency = 0.45
	roof.CanCollide = false
	-- plants inside
	for i = -2, 2 do
		for _, z in { -3, 3 } do
			ball(m, "Plant", 2.6, cf * CFrame.new(i * 4.5, 3.2, z), C.leaf)
			ball(m, "Bloom", 0.9, cf * CFrame.new(i * 4.5 + 0.6, 4.4, z - 0.4), CANDY[((i + 3) % #CANDY) + 1])
		end
	end
	-- sign
	local board = part(m, {
		Name = "NameBoard",
		Size = Vector3.new(16, 3.4, 0.5),
		CFrame = cf * CFrame.new(0, H + 4.5, -D / 2 + 1),
		Color = Color3.fromRGB(90, 180, 80),
	})
	sign(board, Enum.NormalId.Front, Vector2.new(520, 100), "🌱 SEED STORE", Color3.fromRGB(20, 70, 25))
	-- seed sacks and pots out front
	for k, x in { -9, -6, 6, 9 } do
		ball(m, "Sack", 2.2, cf * CFrame.new(x, 2.2, -D / 2 - 1.5), Color3.fromRGB(220, 190, 130))
		ball(m, "SackSeeds", 0.9, cf * CFrame.new(x, 3.3, -D / 2 - 1.5), CANDY[k])
	end
	pad(
		m,
		"SeedPad",
		World.seedPad(),
		World.SeedPadRadius,
		Color3.fromRGB(110, 210, 90),
		C.white,
		"🌱 SEEDS",
		-cf.LookVector
	)
	m.Parent = parent
end

-- Hall of Fame (the leaderboards themselves are built by WorldBuilder) -----------------

local function buildHallOfFame(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "HallOfFame"
	local cf = districtCF(World.HallOfFameAngle, World.LeaderboardRadius + 9)
	-- golden arch behind the boards
	for _, sx in { -1, 1 } do
		cyl(m, "ArchPillar", 26, 3, cf * CFrame.new(sx * 30, 13, 0), C.cream).Material = Enum.Material.Marble
		ball(m, "ArchTop", 4, cf * CFrame.new(sx * 30, 27, 0), C.gold).Material = Enum.Material.Foil
	end
	local beam = part(m, {
		Name = "ArchBeam",
		Size = Vector3.new(64, 4, 2),
		CFrame = cf * CFrame.new(0, 25, 0),
		Color = C.gold,
		Material = Enum.Material.Foil,
	})
	sign(
		beam,
		Enum.NormalId.Front,
		Vector2.new(900, 70),
		"🏆 HALL OF FAME 🏆",
		Color3.fromRGB(110, 70, 0)
	)
	-- trophy podium in front
	local front = districtCF(World.HallOfFameAngle, World.LeaderboardRadius - 14)
	cyl(m, "Podium", 2, 8, front * CFrame.new(0, 1, 0), C.cream).Material = Enum.Material.Marble
	cyl(m, "PodiumTop", 0.4, 8.6, front * CFrame.new(0, 2.2, 0), C.gold)
	cyl(m, "TrophyStem", 2.4, 0.8, front * CFrame.new(0, 3.6, 0), C.gold).Material = Enum.Material.Foil
	cyl(m, "TrophyCup", 2.6, 3, front * CFrame.new(0, 6, 0), C.gold).Material = Enum.Material.Foil
	for _, sx in { -1, 1 } do
		ball(m, "TrophyHandle", 1.2, front * CFrame.new(sx * 1.8, 6.4, 0), C.gold).Material =
			Enum.Material.Foil
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 140))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = m:FindFirstChild("TrophyCup")
	m.Parent = parent
end

-- Fun Fair: carousel, food carts, tables -----------------------------------------------

local function buildFunFair(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "FunFair"
	local cf = districtCF(World.FunFairAngle, 64)
	-- Carousel: base, center pole, striped roof; horses (well, bunnies) on poles, turning
	cyl(m, "CarouselBase", 1, 22, cf * CFrame.new(0, 0.9, 0), C.cream).Material = Enum.Material.WoodPlanks
	local hub = cyl(m, "CarouselHub", 12, 2.2, cf * CFrame.new(0, 7, 0), C.gold)
	hub.Material = Enum.Material.Metal
	for i = 0, 11 do
		local wedge = part(m, {
			Name = "CarouselRoof",
			Size = Vector3.new(6, 0.5, 12),
			CFrame = cf * CFrame.new(0, 13.5, 0) * CFrame.Angles(0, i * math.pi / 6, 0) * CFrame.new(
				0,
				0,
				5.6
			) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(235, 80, 90) else C.white,
			Anchored = false,
			Massless = true,
			CanCollide = false,
		})
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = wedge
		w.Parent = wedge
	end
	for i = 0, 5 do
		local a = i * math.pi / 3
		local rider = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 8)
		local pole = part(m, {
			Name = "CarouselPole",
			Size = Vector3.new(0.4, 11, 0.4),
			CFrame = rider * CFrame.new(0, 7, 0),
			Color = C.gold,
			Material = Enum.Material.Metal,
			Anchored = false,
			Massless = true,
			CanCollide = false,
		})
		local bunny = part(m, {
			Name = "CarouselBunny",
			Size = Vector3.new(1.8, 1.8, 3),
			CFrame = rider * CFrame.new(0, 4.2, 0),
			Color = CANDY[(i % #CANDY) + 1],
			Anchored = false,
			Massless = true,
			CanCollide = false,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bunny
		for _, p in { pole, bunny } do
			local w = Instance.new("WeldConstraint")
			w.Part0 = hub
			w.Part1 = p
			w.Parent = p
		end
	end
	-- turn forever (a sixth of a turn repeats seamlessly)
	TweenService:Create(
		hub,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ CFrame = hub.CFrame * CFrame.Angles(math.pi / 3, 0, 0) }
	):Play()
	-- food carts
	local carts: { { label: string, color: Color3 } } = {
		{ label = "🍿 POPCORN", color = Color3.fromRGB(235, 80, 90) },
		{ label = "🍦 ICE CREAM", color = Color3.fromRGB(255, 150, 200) },
		{ label = "🥕 CARROT JUICE", color = Color3.fromRGB(255, 150, 40) },
	}
	for k, cart in carts do
		local x = (k - 2) * 16
		local ccf = cf * CFrame.new(x, 0, -17) * CFrame.Angles(0, math.pi, 0)
		part(m, {
			Name = "Cart",
			Size = Vector3.new(6, 3.4, 3),
			CFrame = ccf * CFrame.new(0, 2.2, 0),
			Color = C.white,
		})
		for _, sx in { -1, 1 } do
			cyl(
				m,
				"Wheel",
				0.5,
				2,
				ccf * CFrame.new(sx * 2.4, 1, 1.6) * CFrame.Angles(0, 0, math.rad(-90)),
				C.black
			)
		end
		for i = 0, 3 do
			part(m, {
				Name = "CartAwning",
				Size = Vector3.new(1.5, 0.3, 3.6),
				CFrame = ccf * CFrame.new(-2.25 + i * 1.5, 7, 0.3) * CFrame.Angles(math.rad(-10), 0, 0),
				Color = if i % 2 == 0 then cart.color else C.white,
			})
		end
		for _, sx in { -1, 1 } do
			part(m, {
				Name = "CartPole",
				Size = Vector3.new(0.25, 3.4, 0.25),
				CFrame = ccf * CFrame.new(sx * 2.8, 5.4, 0),
				Color = C.white,
			})
		end
		local board = part(m, {
			Name = "CartSign",
			Size = Vector3.new(5.6, 1.4, 0.2),
			CFrame = ccf * CFrame.new(0, 3, -1.6),
			Color = cart.color,
		})
		sign(board, Enum.NormalId.Front, Vector2.new(300, 70), cart.label, Color3.fromRGB(60, 20, 20))
	end
	for k = 0, 3 do
		BunnyMarket.table(m, (cf * CFrame.new(-21 + k * 14, 0, 16)).Position, k)
	end
	m.Parent = parent
end

-- Stage with a DJ bunny ------------------------------------------------------------------

local function buildStage(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Stage"
	local cf = districtCF(World.StageAngle - 12, 70)
	part(m, {
		Name = "StageFloor",
		Size = Vector3.new(26, 3, 14),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = C.darkWood,
		Material = Enum.Material.WoodPlanks,
	})
	part(m, {
		Name = "Backdrop",
		Size = Vector3.new(26, 14, 1),
		CFrame = cf * CFrame.new(0, 10, 6.5),
		Color = C.purple,
	})
	local board = part(m, {
		Name = "StageSign",
		Size = Vector3.new(20, 3.4, 0.4),
		CFrame = cf * CFrame.new(0, 14.5, 5.8),
		Color = C.purple,
	})
	sign(
		board,
		Enum.NormalId.Front,
		Vector2.new(600, 100),
		"🎵 BUNNY BEATS 🎵",
		Color3.fromRGB(50, 10, 80),
		Color3.fromRGB(255, 230, 120)
	)
	-- speakers and lights
	for _, sx in { -1, 1 } do
		part(m, {
			Name = "Speaker",
			Size = Vector3.new(3.4, 6, 3),
			CFrame = cf * CFrame.new(sx * 11, 6, 3),
			Color = C.black,
		})
		for _, y in { 4.5, 7.5 } do
			cyl(
				m,
				"Cone",
				0.3,
				2.2,
				cf
					* CFrame.new(sx * 11, y, 1.45)
					* CFrame.Angles(0, math.rad(90), 0)
					* CFrame.Angles(0, 0, math.rad(-90)),
				Color3.fromRGB(90, 90, 100)
			)
		end
		part(m, {
			Name = "LightBar",
			Size = Vector3.new(0.6, 16, 0.6),
			CFrame = cf * CFrame.new(sx * 13, 8, -6),
			Color = Color3.fromRGB(80, 80, 90),
			Material = Enum.Material.Metal,
		})
	end
	for k = 0, 5 do
		local lamp = ball(m, "StageLight", 1.2, cf * CFrame.new(-10 + k * 4, 16, -6), CANDY[(k % #CANDY) + 1])
		lamp.Material = Enum.Material.Neon
	end
	part(m, {
		Name = "LightTruss",
		Size = Vector3.new(27, 0.6, 0.6),
		CFrame = cf * CFrame.new(0, 16, -6),
		Color = Color3.fromRGB(80, 80, 90),
		Material = Enum.Material.Metal,
	})
	-- DJ desk and the DJ bunny with headphones
	part(m, {
		Name = "DJDesk",
		Size = Vector3.new(8, 3, 2.4),
		CFrame = cf * CFrame.new(0, 4.5, -2),
		Color = C.black,
	})
	for _, sx in { -1, 1 } do
		cyl(m, "Turntable", 0.2, 2, cf * CFrame.new(sx * 2, 6.1, -2), Color3.fromRGB(60, 60, 70))
	end
	local dj = Instance.new("Model")
	dj.Name = "DJBunny"
	local base = cf * CFrame.new(0, 3, 1)
	local fur = Color3.fromRGB(250, 250, 255)
	local function blob(name: string, size: Vector3, offset: CFrame, color: Color3)
		local p =
			part(dj, { Name = name, Size = size, CFrame = base * offset, Color = color, CanCollide = false })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	blob("Body", Vector3.new(4, 4.6, 3.6), CFrame.new(0, 2.4, 0), fur)
	blob("Head", Vector3.new(3.4, 3, 3), CFrame.new(0, 5.6, -0.3), fur)
	for _, sx in { -1, 1 } do
		blob(
			"Ear",
			Vector3.new(0.9, 3.6, 0.6),
			CFrame.new(sx * 0.8, 8.2, -0.2) * CFrame.Angles(0, 0, -sx * 0.15),
			fur
		)
		blob("Eye", Vector3.new(0.5, 0.7, 0.3), CFrame.new(sx * 0.75, 5.9, -1.7), C.black)
		blob("Headphone", Vector3.new(0.8, 1.4, 1.4), CFrame.new(sx * 1.75, 5.7, -0.3), C.purple)
	end
	blob("Nose", Vector3.new(0.45, 0.35, 0.3), CFrame.new(0, 5.4, -1.8), C.pink)
	part(dj, {
		Name = "HeadphoneBand",
		Size = Vector3.new(3.8, 0.4, 0.5),
		CFrame = base * CFrame.new(0, 7.1, -0.3),
		Color = C.purple,
		CanCollide = false,
	})
	dj.Parent = m
	-- tables in front of the stage
	for k = 0, 1 do
		BunnyMarket.table(m, (cf * CFrame.new(-8 + k * 16, 0, -16)).Position, k + 2)
	end
	m.Parent = parent
end

-- Bunny Launchers ------------------------------------------------------------------------

local function buildLaunchers(parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "Launchers"
	f.Parent = parent
	for i, l in World.launchers() do
		local m = Instance.new("Model")
		m.Name = "Launcher_" .. i
		m:SetAttribute("Index", i)
		m:SetAttribute("FarmId", l.farmId)
		m:SetAttribute("ToFarm", l.toFarm)
		local toward = Vector3.new(l.to.X - l.from.X, 0, l.to.Z - l.from.Z).Unit
		Landscape.flatDisc(l.from, World.LauncherRadius + 2)
		local cf = CFrame.lookAt(l.from, l.from + toward)
		-- springy pad: stacked rings and a purple top with a white bunny face
		for k = 0, 2 do
			cyl(
				m,
				"Spring",
				0.35,
				World.LauncherRadius * 2 - k * 0.8,
				cf * CFrame.new(0, 0.3 + k * 0.45, 0),
				if k % 2 == 0 then C.gold else C.white
			)
		end
		local top = cyl(m, "LaunchPad", 0.4, World.LauncherRadius * 2, cf * CFrame.new(0, 1.6, 0), C.purple)
		top.Material = Enum.Material.SmoothPlastic
		top.CanCollide = false
		top:SetAttribute("Launcher", i)
		local plate = part(m, {
			Name = "LaunchPlate",
			Size = Vector3.new(World.LauncherRadius * 1.6, 0.05, World.LauncherRadius * 1.0),
			CFrame = cf * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, math.pi, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		sign(plate, Enum.NormalId.Top, Vector2.new(300, 180), "🐰 LAUNCH!", Color3.fromRGB(60, 20, 100))
		-- a big bunny-ear arch over the pad with a destination sign
		for _, sx in { -1, 1 } do
			local ear = cf
				* CFrame.new(sx * (World.LauncherRadius + 0.8), 6, 0)
				* CFrame.Angles(0, 0, math.rad(-sx * 10))
			local p = part(m, {
				Name = "ArchEar",
				Size = Vector3.new(1.8, 11, 1.2),
				CFrame = ear,
				Color = C.white,
				CanCollide = false,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			local inner = part(m, {
				Name = "ArchEarInner",
				Size = Vector3.new(0.9, 8.5, 0.4),
				CFrame = ear * CFrame.new(0, 0, -0.5),
				Color = C.pink,
				CanCollide = false,
			})
			local mesh2 = Instance.new("SpecialMesh")
			mesh2.MeshType = Enum.MeshType.Sphere
			mesh2.Parent = inner
		end
		local board = part(m, {
			Name = "LaunchSign",
			Size = Vector3.new(9, 1.8, 0.3),
			CFrame = cf * CFrame.new(0, 10.5, 0) * CFrame.Angles(0, math.pi, 0),
			Color = C.purple,
		})
		local text = if l.toFarm then "🐰 → FARM " .. l.farmId else "🐰 → MARKET"
		sign(board, Enum.NormalId.Front, Vector2.new(360, 72), text, Color3.fromRGB(50, 10, 80))
		sign(board, Enum.NormalId.Back, Vector2.new(360, 72), text, Color3.fromRGB(50, 10, 80))
		m.Parent = f
	end
end

-- HOME launchers: same spring pad, gold sign (the client flies you to your own farm).
local function buildHomeLaunchers(parent: Instance)
	local existing = parent:FindFirstChild("Launchers")
	local f: Instance = if existing then existing else Instance.new("Folder")
	f.Name = "Launchers"
	f.Parent = parent
	for i, pos in World.homeLaunchers() do
		local m = Instance.new("Model")
		m.Name = "HomeLauncher_" .. i
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
		for k = 0, 2 do
			cyl(
				m,
				"Spring",
				0.35,
				World.LauncherRadius * 2 - k * 0.8,
				cf * CFrame.new(0, 0.3 + k * 0.45, 0),
				if k % 2 == 0 then C.gold else C.white
			)
		end
		local top = cyl(m, "LaunchPad", 0.4, World.LauncherRadius * 2, cf * CFrame.new(0, 1.6, 0), C.gold)
		top.CanCollide = false
		local plate = part(m, {
			Name = "LaunchPlate",
			Size = Vector3.new(World.LauncherRadius * 1.6, 0.05, World.LauncherRadius * 1.0),
			CFrame = cf * CFrame.new(0, 1.85, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		sign(plate, Enum.NormalId.Top, Vector2.new(300, 180), "🏡 HOME", Color3.fromRGB(110, 70, 0))
		local postL = part(m, {
			Name = "SignPost",
			Size = Vector3.new(0.4, 9, 0.4),
			CFrame = cf * CFrame.new(-4.2, 4.5, 0),
			Color = C.white,
		})
		postL.CanCollide = false
		local postR = part(m, {
			Name = "SignPost",
			Size = Vector3.new(0.4, 9, 0.4),
			CFrame = cf * CFrame.new(4.2, 4.5, 0),
			Color = C.white,
		})
		postR.CanCollide = false
		local board = part(m, {
			Name = "LaunchSign",
			Size = Vector3.new(9, 1.8, 0.3),
			CFrame = cf * CFrame.new(0, 8.6, 0),
			Color = C.gold,
		})
		sign(board, Enum.NormalId.Front, Vector2.new(360, 72), "🐰 → HOME", Color3.fromRGB(110, 70, 0))
		sign(board, Enum.NormalId.Back, Vector2.new(360, 72), "🐰 → HOME", Color3.fromRGB(110, 70, 0))
		m.Parent = f
	end
end

function Plaza.build(world: Instance)
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	buildCenter(plaza)
	buildWorkshop(plaza)
	buildSeedStore(plaza)
	buildHallOfFame(plaza)
	buildFunFair(plaza)
	buildStage(plaza)
	buildLaunchers(plaza)
	buildHomeLaunchers(plaza)
	plaza.Parent = world
end

return Plaza
