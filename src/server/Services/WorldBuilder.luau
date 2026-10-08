--!strict
-- Builds the entire world in code at server start: ground, plaza, market kiosk, 8 farms with
-- 16 plot slots each, paths, trees, lighting and sky. Nothing is placed by hand in Studio.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local World = require(Config.World)
local Economy = require(Config.Economy)

export type FarmBuild = {
	id: number,
	model: Model,
	center: CFrame,
	plots: { BasePart },
	spawnCFrame: CFrame,
	signTitle: TextLabel,
	signSubtitle: TextLabel,
	likePrompt: ProximityPrompt,
	pedestalTop: BasePart,
}

export type LeaderboardRow = { name: TextLabel, value: TextLabel }
export type LeaderboardBuild = { id: string, rows: { LeaderboardRow } }

export type WorldBuild = {
	farms: { FarmBuild },
	marketCFrame: CFrame,
	leaderboards: { LeaderboardBuild },
}

-- Leaderboard boards around the plaza: id, title, header color, angle (degrees)
local LEADERBOARDS = {
	{
		id = "WeeklyBest",
		title = "🏆 Best Carrot This Week",
		color = Color3.fromRGB(255, 190, 40),
		angle = 22.5,
	},
	{ id = "BiggestSale", title = "💰 Biggest Sale", color = Color3.fromRGB(110, 220, 90), angle = 157.5 },
	{ id = "Dex", title = "📖 CarrotDex Masters", color = Color3.fromRGB(80, 170, 255), angle = 292.5 },
}
local LEADERBOARD_ROWS = 10

local WorldBuilder = {}

-- Art direction: sunny valley farmers' market. Warm and toy-like, but grounded enough that the
-- bright UI and the rare carrots are what pops. Hue roles: green = land, warm dirt = where you
-- walk, orange/cream = the market (the hero), dark soil = where carrots grow.
local COLORS = {
	grass = Color3.fromRGB(98, 176, 70),
	grassFar = Color3.fromRGB(80, 150, 60),
	farmGrass = Color3.fromRGB(122, 194, 80),
	farmGrassStripe = Color3.fromRGB(112, 184, 74),
	soil = Color3.fromRGB(96, 64, 42),
	soilFurrow = Color3.fromRGB(76, 50, 32),
	soilEdge = Color3.fromRGB(150, 104, 62),
	path = Color3.fromRGB(196, 150, 100),
	pathEdge = Color3.fromRGB(160, 120, 80),
	plaza = Color3.fromRGB(238, 222, 190),
	sellGreen = Color3.fromRGB(110, 200, 95),
	shopTeal = Color3.fromRGB(60, 175, 215),
	terracotta = Color3.fromRGB(205, 120, 80),
	wood = Color3.fromRGB(190, 132, 78),
	darkWood = Color3.fromRGB(120, 78, 46),
	fence = Color3.fromRGB(246, 238, 222),
	orange = Color3.fromRGB(255, 136, 36),
	cream = Color3.fromRGB(255, 244, 222),
	red = Color3.fromRGB(214, 74, 64),
	white = Color3.fromRGB(255, 252, 245),
	leaf = Color3.fromRGB(72, 158, 64),
	leafLight = Color3.fromRGB(122, 196, 78),
	trunk = Color3.fromRGB(128, 86, 54),
	rock = Color3.fromRGB(168, 168, 176),
	gold = Color3.fromRGB(255, 200, 60),
	chalk = Color3.fromRGB(40, 66, 54),
	-- One identity color per farm (barn + sign trim), so "the blue farm" is a place.
	barns = {
		Color3.fromRGB(214, 74, 64),
		Color3.fromRGB(70, 130, 220),
		Color3.fromRGB(250, 180, 40),
		Color3.fromRGB(150, 90, 210),
		Color3.fromRGB(60, 170, 120),
		Color3.fromRGB(240, 110, 160),
		Color3.fromRGB(60, 180, 210),
		Color3.fromRGB(240, 130, 50),
	},
	flowers = {
		Color3.fromRGB(255, 110, 170),
		Color3.fromRGB(255, 225, 60),
		Color3.fromRGB(175, 120, 255),
		Color3.fromRGB(100, 200, 255),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 140, 80),
	},
}

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
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

-- Flat disc (cylinder lying down) centered at `pos` with the top at pos.Y.
local function disc(
	name: string,
	pos: Vector3,
	diameter: number,
	thickness: number,
	props: { [string]: any },
	parent: Instance
): Part
	local p = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(pos - Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}, parent)
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Vertical cylinder from `bottom` going up `height`.
local function pillar(
	name: string,
	bottom: Vector3,
	height: number,
	diameter: number,
	props: { [string]: any },
	parent: Instance
): Part
	local p = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}, parent)
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function buildLighting()
	-- Early afternoon, slightly warm. Moderate saturation: the world should feel bright without
	-- turning neon on phone screens (which already boost saturation).
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(120, 112, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 160, 150)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.45

	for _, child in Lighting:GetChildren() do
		child:Destroy()
	end

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 9
	sky.MoonAngularSize = 9
	sky.StarCount = 2000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(205, 225, 245)
	atmosphere.Decay = Color3.fromRGB(150, 185, 230)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 2
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.12
	cc.Contrast = 0.1
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 249, 238)
	cc.Parent = Lighting
end

local function buildGround(world: Folder)
	part({
		Name = "Ground",
		Size = Vector3.new(760, 4, 760),
		CFrame = CFrame.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = COLORS.grass,
		CastShadow = false,
	}, world)

	-- Invisible walls so nobody walks off the edge.
	local half = 330
	for i = 0, 3 do
		local angle = i * math.pi / 2
		part({
			Name = "Boundary",
			Size = Vector3.new(2 * half, 120, 2),
			CFrame = CFrame.Angles(0, angle, 0) * CFrame.new(0, 60, half),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		}, world)
	end

	-- Plaza: terracotta rim, warm cream stone, and a compass of orange spokes that point at the
	-- eight farms, so the map explains itself from the spawn.
	disc("PlazaRing", Vector3.new(0, 0.2, 0), 70, 0.4, {
		Material = Enum.Material.Brick,
		Color = COLORS.terracotta,
		CastShadow = false,
	}, world)
	disc("Plaza", Vector3.new(0, 0.3, 0), 64, 0.5, {
		Material = Enum.Material.Slate,
		Color = COLORS.plaza,
		CastShadow = false,
	}, world)
	-- The sell circle: step onto the green ring around the market and your basket sells.
	disc("SellRing", Vector3.new(0, 0.34, 0), World.SellRadius * 2 + 1.6, 0.5, {
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.white,
		CastShadow = false,
	}, world)
	disc("SellZone", Vector3.new(0, 0.38, 0), World.SellRadius * 2, 0.5, {
		Material = Enum.Material.Slate,
		Color = COLORS.sellGreen,
		CastShadow = false,
	}, world)
	for i = 0, World.FarmCount - 1 do
		local a = i * (2 * math.pi / World.FarmCount)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		part({
			Name = "Spoke",
			Size = Vector3.new(2.2, 0.1, 13),
			CFrame = CFrame.lookAt(dir * 25 + Vector3.new(0, 0.33, 0), dir * 40 + Vector3.new(0, 0.33, 0)),
			Material = Enum.Material.Slate,
			Color = COLORS.orange,
			CastShadow = false,
			CanCollide = false,
		}, world)
	end
end

-- A big decorative carrot (tip down) made of primitives, used on top of the market.
local function statueCarrot(parent: Instance, top: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "CarrotStatue"
	local segments = 5
	local length = 7 * scale
	local radius = 1.6 * scale
	local segLen = length / segments
	for i = 0, segments - 1 do
		local r = radius * (1 - i * 0.17)
		pillar("Body", top - Vector3.new(0, (i + 1) * segLen, 0), segLen + 0.05, r * 2, {
			Color = COLORS.orange,
			Material = Enum.Material.SmoothPlastic,
		}, model)
	end
	part({
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 0.6,
		CFrame = CFrame.new(top - Vector3.new(0, length, 0)),
		Color = COLORS.orange,
	}, model)
	for i = 0, 4 do
		local a = i * (2 * math.pi / 5)
		part({
			Name = "Leaf",
			Size = Vector3.new(0.4 * scale, 3.4 * scale, 0.9 * scale),
			CFrame = CFrame.new(top)
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(math.rad(22), 0, 0)
				* CFrame.new(0, 1.5 * scale, 0),
			Color = COLORS.leaf,
			Material = Enum.Material.SmoothPlastic,
		}, model)
	end
	model.Parent = parent
end

-- Text on a physical board (SurfaceGui), so signs are part of the world instead of floating
-- billboards that cover the sky.
local function boardText(board: BasePart, face: Enum.NormalId, canvas: Vector2, props: { [string]: any })
	local surface = Instance.new("SurfaceGui")
	surface.Face = face
	surface.CanvasSize = canvas
	surface.LightInfluence = 0.2
	surface.MaxDistance = 220
	surface.Parent = board
	label(surface, props)
end

-- The market: the map's hero landmark, readable from every farm. Raised deck, red posts, four
-- counters with carrot crates, a tiered striped tent roof with a scalloped edge, a name board on
-- every side, and a giant carrot on top. Its price sign is a chalkboard on the spawn side; the
-- client draws the live board on it (PriceBoard) and a small boom timer above the roof.
local function buildMarket(world: Folder): CFrame
	local market = Instance.new("Model")
	market.Name = "Market"

	disc("Deck", Vector3.new(0, 0.9, 0), 26, 0.6, {
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
	}, market)
	disc("DeckRim", Vector3.new(0, 0.55, 0), 27.5, 0.4, {
		Material = Enum.Material.Wood,
		Color = COLORS.darkWood,
	}, market)

	local size = 18
	local h = size / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			pillar("Post", Vector3.new(sx * (h - 0.7), 0.9, sz * (h - 0.7)), 9.2, 1.3, {
				Color = COLORS.red,
				Material = Enum.Material.SmoothPlastic,
			}, market)
		end
	end
	-- Counters with crates of carrots (the crates sit on the counters, carrots poke out)
	for i = 0, 3 do
		local rot = CFrame.Angles(0, i * math.pi / 2, 0)
		part({
			Name = "Counter",
			Size = Vector3.new(size - 3, 3, 2.4),
			CFrame = rot * CFrame.new(0, 2.4, h - 1.2),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.wood,
		}, market)
		part({
			Name = "CounterTop",
			Size = Vector3.new(size - 2.4, 0.3, 2.8),
			CFrame = rot * CFrame.new(0, 4.05, h - 1.2),
			Material = Enum.Material.Wood,
			Color = COLORS.darkWood,
		}, market)
		for c = -1, 1 do
			local crate = part({
				Name = "Crate",
				Size = Vector3.new(3.2, 1.1, 1.9),
				CFrame = rot * CFrame.new(c * 4.6, 4.75, h - 1.2) * CFrame.Angles(0, (c * 0.07), 0),
				Material = Enum.Material.WoodPlanks,
				Color = COLORS.wood,
			}, market)
			for k = -1, 1 do
				for j = -1, 1, 2 do
					part({
						Name = "CrateCarrot",
						Size = Vector3.new(0.6, 1.2, 0.6),
						CFrame = crate.CFrame
							* CFrame.new(k * 0.95, 0.75, j * 0.42)
							* CFrame.Angles(math.rad(12 * j), 0, math.rad(10 * k)),
						Color = COLORS.orange,
						CastShadow = false,
						CanCollide = false,
					}, market)
				end
			end
		end
	end

	-- Tiered tent roof: alternating orange/cream tiers read as "market stall" from far away.
	local tiers = { { 22, 10.6 }, { 17, 11.8 }, { 12, 13 }, { 7, 14.2 } }
	for i, t in tiers do
		part({
			Name = "RoofTier",
			Size = Vector3.new(t[1], 1.2, t[1]),
			CFrame = CFrame.new(0, t[2], 0),
			Material = Enum.Material.Fabric,
			Color = if i % 2 == 1 then COLORS.orange else COLORS.cream,
		}, market)
	end
	-- Scalloped valance around the roof edge
	local edge = 11
	local step = 1.6
	local n = math.floor(edge * 2 / step)
	for side = 0, 3 do
		local rot = CFrame.Angles(0, side * math.pi / 2, 0)
		for k = 0, n - 1 do
			local x = -edge + step * (k + 0.5)
			part({
				Name = "Scallop",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.5, 1.5, 1.5),
				CFrame = rot * CFrame.new(x, 9.95, edge - 0.2),
				Material = Enum.Material.Fabric,
				Color = if k % 2 == 0 then COLORS.cream else COLORS.orange,
				CastShadow = false,
				CanCollide = false,
			}, market)
		end
	end

	-- Name boards under the roof edge on all four sides
	for side = 0, 3 do
		local rot = CFrame.Angles(0, side * math.pi / 2, 0)
		local board = part({
			Name = "NameBoard",
			Size = Vector3.new(15, 2.2, 0.5),
			CFrame = rot * CFrame.new(0, 8.6, h + 0.2),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.darkWood,
		}, market)
		boardText(board, Enum.NormalId.Back, Vector2.new(600, 88), {
			Size = UDim2.new(1, -24, 1, -12),
			Position = UDim2.fromOffset(12, 6),
			Text = "CARROT MARKET",
			Font = Enum.Font.LuckiestGuy,
			TextColor3 = Color3.fromRGB(255, 196, 80),
			TextStrokeColor3 = Color3.fromRGB(60, 25, 5),
			TextStrokeTransparency = 0,
		})
	end

	-- Giant carrot on top, slightly tilted for charm (tip resting on the roof)
	statueCarrot(market, Vector3.new(0, 26, 0), 1.6)
	for _, d in market:GetChildren() do
		if d:IsA("Model") and d.Name == "CarrotStatue" then
			d:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(8)) * d:GetPivot())
		end
	end

	-- Chalkboard price sign on an easel, on the spawn side, angled toward arriving players
	local boardCF = CFrame.new(0, 0, 16.5) * CFrame.Angles(0, 0, 0)
	for _, x in { -4.2, 4.2 } do
		part({
			Name = "EaselLeg",
			Size = Vector3.new(0.5, 9, 0.5),
			CFrame = boardCF * CFrame.new(x, 4.3, -0.4) * CFrame.Angles(math.rad(-6), 0, 0),
			Material = Enum.Material.Wood,
			Color = COLORS.darkWood,
		}, market)
	end
	part({
		Name = "PriceBoardFrame",
		Size = Vector3.new(9.6, 6.6, 0.4),
		CFrame = boardCF * CFrame.new(0, 5.2, -0.1),
		Material = Enum.Material.Wood,
		Color = COLORS.darkWood,
	}, market)
	part({
		Name = "PriceBoard",
		Size = Vector3.new(8.8, 5.8, 0.2),
		CFrame = boardCF * CFrame.new(0, 5.2, 0.15),
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.chalk,
		CastShadow = false,
	}, market)

	-- Anchor for the market's ambience sound (client Music controller)
	part({
		Name = "SellPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, market)

	market.Parent = world
	return CFrame.new(0, 0, 0)
end

-- Upgrade Shop: a small teal-roofed stall on the plaza facing the market. Standing on its pad
-- opens the Upgrades panel (client) and is where the server accepts upgrade purchases. Teal
-- roof = upgrades, orange roof = the market, so the two read apart from far away.
local function buildUpgradeStall(world: Folder, deg: number)
	local a = math.rad(deg)
	local dir = Vector3.new(math.sin(a), 0, math.cos(a))
	local center = dir * World.UpgradeStallDistance
	-- Front (-Z) faces the market
	local cf = CFrame.lookAt(center, Vector3.zero)
	local model = Instance.new("Model")
	model.Name = "UpgradeShop"
	local w, d = 10, 5
	part({
		Name = "Floor",
		Size = Vector3.new(w + 1, 0.5, d + 1),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
	}, model)
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		for _, z in { -d / 2 + 0.5, d / 2 - 0.5 } do
			part({
				Name = "Post",
				Size = Vector3.new(0.8, 8, 0.8),
				CFrame = cf * CFrame.new(x, 4.5, z),
				Material = Enum.Material.Wood,
				Color = COLORS.white,
			}, model)
		end
	end
	part({
		Name = "Counter",
		Size = Vector3.new(w - 1, 3, 1.6),
		CFrame = cf * CFrame.new(0, 2.2, -d / 2 + 1),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
	}, model)
	part({
		Name = "CounterTop",
		Size = Vector3.new(w - 0.4, 0.3, 2),
		CFrame = cf * CFrame.new(0, 3.85, -d / 2 + 1),
		Material = Enum.Material.Wood,
		Color = COLORS.darkWood,
	}, model)
	-- Goods on the counter: a watering can, a seed sack, a toolbox (simple shapes)
	part({
		Name = "Toolbox",
		Size = Vector3.new(1.8, 0.9, 1),
		CFrame = cf * CFrame.new(-3, 4.45, -d / 2 + 1),
		Color = COLORS.red,
	}, model)
	part({
		Name = "Sack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = cf * CFrame.new(0.2, 4.7, -d / 2 + 1),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(220, 190, 130),
	}, model)
	pillar("Can", (cf * CFrame.new(3, 4, -d / 2 + 1)).Position, 1.3, 1.2, {
		Color = COLORS.shopTeal,
	}, model)
	-- Striped teal/white awning roof, sloping down toward the front
	local stripes = 5
	for i = 0, stripes - 1 do
		local x = -w / 2 - 0.5 + (w + 1) * (i + 0.5) / stripes
		part({
			Name = "Awning",
			Size = Vector3.new((w + 1) / stripes, 0.4, d + 2.4),
			CFrame = cf * CFrame.new(x, 8.7, -0.4) * CFrame.Angles(math.rad(-14), 0, 0),
			Material = Enum.Material.Fabric,
			Color = if i % 2 == 0 then COLORS.shopTeal else COLORS.white,
		}, model)
	end
	-- Name board on both sides of the roof edge (front: the market side; back: arriving players)
	local board = part({
		Name = "NameBoard",
		Size = Vector3.new(w - 0.6, 2.2, 0.4),
		CFrame = cf * CFrame.new(0, 7.2, -d / 2 - 0.2),
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.shopTeal:Lerp(Color3.new(0, 0, 0), 0.35),
	}, model)
	local text = {
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = "⬆ UPGRADES",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = COLORS.white,
		TextStrokeColor3 = Color3.fromRGB(10, 50, 70),
		TextStrokeTransparency = 0,
	}
	boardText(board, Enum.NormalId.Front, Vector2.new(400, 88), text)
	local back = part({
		Name = "BackBoard",
		Size = Vector3.new(w - 0.6, 2.2, 0.4),
		CFrame = cf * CFrame.new(0, 7.2, d / 2 + 0.2),
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.shopTeal:Lerp(Color3.new(0, 0, 0), 0.35),
	}, model)
	boardText(back, Enum.NormalId.Back, Vector2.new(400, 88), text)
	-- The pad in front: stand here to shop
	local padPos = center - dir * World.UpgradePadOffset
	disc("UpgradePadRing", padPos + Vector3.new(0, 0.46, 0), World.UpgradePadRadius * 2 + 1, 0.12, {
		Color = COLORS.white,
		CanCollide = false,
		CastShadow = false,
	}, model)
	disc("UpgradePad", padPos + Vector3.new(0, 0.5, 0), World.UpgradePadRadius * 2, 0.12, {
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.shopTeal,
		CanCollide = false,
		CastShadow = false,
	}, model)
	model.Parent = world
end

local function buildTree(parent: Instance, pos: Vector3, scale: number, rng: Random)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	local trunkH = 6 * scale
	pillar("Trunk", pos, trunkH + 2 * scale, 1.5 * scale, {
		Material = Enum.Material.Wood,
		Color = COLORS.trunk,
	}, tree)
	-- Canopy: a darker base blob and two lighter blobs on top read as volume from any angle.
	local leaf = COLORS.leaf:Lerp(COLORS.leafLight, rng:NextNumber() * 0.6)
	local top = pos + Vector3.new(0, trunkH + 3 * scale, 0)
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 9.5 * scale,
		CFrame = CFrame.new(top),
		Material = Enum.Material.SmoothPlastic,
		Color = leaf:Lerp(Color3.new(0, 0.15, 0), 0.25),
	}, tree)
	for _, o in { Vector3.new(-1.8, 2.4, 1), Vector3.new(1.9, 2.8, -0.8) } do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (6.2 + rng:NextNumber()) * scale,
			CFrame = CFrame.new(top + o * scale),
			Material = Enum.Material.SmoothPlastic,
			Color = leaf,
			CastShadow = false,
		}, tree)
	end
	tree.Parent = parent
end

-- Rolling hills around the edge frame the valley and hide the end of the world.
local function buildHills(world: Folder, rng: Random)
	local hills = folder("Hills", world)
	local count = 30
	for i = 0, count - 1 do
		local a = (i + rng:NextNumber() * 0.6) * (2 * math.pi / count)
		local r = 335 + rng:NextNumber() * 30
		local w = 90 + rng:NextNumber() * 70
		local hgt = 40 + rng:NextNumber() * 45
		part({
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(w, w, w),
			CFrame = CFrame.new(math.sin(a) * r, -w / 2 + hgt, math.cos(a) * r),
			Material = Enum.Material.Grass,
			Color = COLORS.grassFar:Lerp(COLORS.grass, rng:NextNumber() * 0.5),
			CastShadow = false,
			CanCollide = false,
		}, hills)
	end
end

-- Is a point inside (or right next to) a farm, its barn, the plaza or a path? Decor stays out.
local FARM_KEEP_OUT = (3 * (World.PlotSize + World.PlotGap) + World.FarmPadding) * 1.5 + 6
local function blocked(pos: Vector3): boolean
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if flat.Magnitude < 40 then
		return true -- plaza
	end
	for i = 0, World.FarmCount - 1 do
		local a = i * (2 * math.pi / World.FarmCount)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local center = dir * World.FarmRingRadius
		if (flat - center).Magnitude < FARM_KEEP_OUT then
			return true
		end
		-- the path from the plaza to this farm
		local along = flat:Dot(dir)
		if along > 0 and along < World.FarmRingRadius and (flat - dir * along).Magnitude < 9 then
			return true
		end
	end
	return false
end

local function buildDecor(world: Folder)
	local decor = folder("Decor", world)
	local rng = Random.new(World.Seed)
	buildHills(world, rng)
	local angleStep = 2 * math.pi / World.FarmCount

	-- Trees between farms
	for i = 0, World.FarmCount - 1 do
		local a = (i + 0.5) * angleStep
		for _, r in { 95, 160, 215 } do
			local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
			if not blocked(pos) then
				buildTree(decor, pos, 0.9 + rng:NextNumber() * 0.4, rng)
			end
		end
	end

	-- Outer ring of trees
	local placed = 0
	local attempts = 0
	while placed < World.TreeCount and attempts < 1000 do
		attempts += 1
		local a = rng:NextNumber() * 2 * math.pi
		local r = 60 + rng:NextNumber() * 255
		local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if math.abs(pos.X) < 315 and math.abs(pos.Z) < 315 and not blocked(pos) then
			buildTree(decor, pos, 0.9 + rng:NextNumber() * 0.8, rng)
			placed += 1
		end
	end

	-- Flowering bushes: a soft green mound dotted with blossoms (reads as a plant, not as loose
	-- marbles on the grass).
	for _ = 1, 55 do
		local a = rng:NextNumber() * 2 * math.pi
		local r = 40 + rng:NextNumber() * 265
		local center = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if not blocked(center) then
			local color = COLORS.flowers[rng:NextInteger(1, #COLORS.flowers)]
			local bush = 2.2 + rng:NextNumber() * 1.4
			local mound = part({
				Name = "Bush",
				Size = Vector3.new(bush * 1.3, bush * 0.8, bush * 1.3),
				CFrame = CFrame.new(center + Vector3.new(0, bush * 0.25, 0)),
				Color = COLORS.leaf:Lerp(COLORS.leafLight, rng:NextNumber() * 0.5),
				CanCollide = false,
			}, decor)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = mound
			for k = 1, 5 do
				local ang = k * (2 * math.pi / 5) + rng:NextNumber()
				local off = Vector3.new(math.cos(ang) * bush * 0.42, bush * 0.52, math.sin(ang) * bush * 0.42)
				part({
					Name = "Blossom",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * (0.55 + rng:NextNumber() * 0.25),
					CFrame = CFrame.new(center + off),
					Color = color,
					CanCollide = false,
					CastShadow = false,
				}, decor)
			end
		end
	end

	-- Boulders: smooth, half-sunk stones in pairs (big + small), never loose floating cubes.
	for _ = 1, 18 do
		local a = rng:NextNumber() * 2 * math.pi
		local r = 45 + rng:NextNumber() * 250
		local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if not blocked(pos) then
			local s = 2.4 + rng:NextNumber() * 2.6
			for k, f in { 1, 0.5 } do
				local size = s * f
				local offset = if k == 1 then Vector3.zero else Vector3.new(s * 0.75, 0, s * 0.35)
				local rock = part({
					Name = "Rock",
					Size = Vector3.new(size * 1.5, size, size * 1.2),
					CFrame = CFrame.new(pos + offset + Vector3.new(0, size * 0.25, 0))
						* CFrame.Angles(0, rng:NextNumber() * 6, 0),
					Material = Enum.Material.Slate,
					Color = COLORS.rock:Lerp(Color3.fromRGB(130, 128, 120), rng:NextNumber()),
					CanCollide = false, -- the collision box would stick out of the round mesh
				}, decor)
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = rock
			end
		end
	end
end

local function buildFarm(farmsFolder: Folder, paths: Folder, id: number): FarmBuild
	local angle = (id - 1) * (2 * math.pi / World.FarmCount)
	local centerPos =
		Vector3.new(math.sin(angle) * World.FarmRingRadius, 0, math.cos(angle) * World.FarmRingRadius)
	-- Look toward the market: local -Z is the front (entrance side).
	local center = CFrame.lookAt(centerPos, Vector3.zero)

	local cell = World.PlotSize + World.PlotGap
	local half = 3 * cell - World.PlotGap / 2 + World.FarmPadding

	local model = Instance.new("Model")
	model.Name = "Farm_" .. id
	model:SetAttribute("FarmId", id)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")

	part({
		Name = "FarmGround",
		Size = Vector3.new(half * 2, 0.2, half * 2),
		CFrame = center * CFrame.new(0, 0.1, 0),
		Material = Enum.Material.Grass,
		Color = COLORS.farmGrass,
		CastShadow = false,
	}, model)
	-- Mowed stripes: the farm reads as cared-for land, distinct from the wild grass around it.
	local stripes = 6
	for k = 0, stripes - 1, 2 do
		local w = half * 2 / stripes
		part({
			Name = "MowStripe",
			Size = Vector3.new(w, 0.05, half * 2),
			CFrame = center * CFrame.new(-half + w * (k + 0.5), 0.22, 0),
			Material = Enum.Material.Grass,
			Color = COLORS.farmGrassStripe,
			CastShadow = false,
			CanCollide = false,
			CanQuery = false,
		}, model)
	end
	local identity = COLORS.barns[(id - 1) % #COLORS.barns + 1]

	-- Fence with an entrance at the front
	local fenceH = 3
	local entrance = 12
	local function fenceSide(localCF: CFrame, length: number)
		part({
			Name = "FenceRail",
			Size = Vector3.new(length, 0.4, 0.3),
			CFrame = center * localCF * CFrame.new(0, fenceH * 0.75, 0),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.fence,
		}, model)
		part({
			Name = "FenceRail",
			Size = Vector3.new(length, 0.4, 0.3),
			CFrame = center * localCF * CFrame.new(0, fenceH * 0.35, 0),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.fence,
		}, model)
		local posts = math.max(2, math.floor(length / 6) + 1)
		for i = 0, posts - 1 do
			local x = -length / 2 + length * i / (posts - 1)
			part({
				Name = "FencePost",
				Size = Vector3.new(0.6, fenceH + 0.4, 0.6),
				CFrame = center * localCF * CFrame.new(x, (fenceH + 0.4) / 2, 0),
				Material = Enum.Material.Wood,
				Color = COLORS.fence,
			}, model)
		end
	end
	fenceSide(CFrame.new(0, 0, half), half * 2) -- back
	fenceSide(CFrame.new(-half, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), half * 2) -- left
	fenceSide(CFrame.new(half, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), half * 2) -- right
	local frontPiece = half - entrance / 2
	fenceSide(CFrame.new(-half + frontPiece / 2, 0, -half), frontPiece)
	fenceSide(CFrame.new(half - frontPiece / 2, 0, -half), frontPiece)

	-- Plot slots (all 16 are built; the Farm service unlocks the owner's count)
	local plotsFolder = folder("Plots", model)
	local plots: { BasePart } = {}
	for index, c in World.PlotCells do
		local localPos = Vector3.new(c[1] * cell, 0, c[2] * cell)
		-- A raised bed of dark soil: reads as "something grows here", and makes every carrot
		-- color (especially the rare ones) pop against it.
		local plot = part({
			Name = "Plot_" .. index,
			Size = Vector3.new(World.PlotSize, 0.8, World.PlotSize),
			CFrame = center * CFrame.new(localPos + Vector3.new(0, 0.4, 0)),
			Material = Enum.Material.Ground,
			Color = COLORS.soil,
			CastShadow = false,
		}, plotsFolder)
		-- Three soil ridges on top
		for f = -1, 1 do
			part({
				Name = "Furrow",
				Size = Vector3.new(1.3, 0.25, World.PlotSize - 1.4),
				CFrame = center * CFrame.new(localPos + Vector3.new(f * 2.1, 0.88, 0)),
				Material = Enum.Material.Ground,
				Color = COLORS.soilFurrow,
				CastShadow = false,
				CanCollide = false,
			}, plot)
		end
		-- Wooden frame around the bed
		part({
			Name = "Rim",
			Size = Vector3.new(World.PlotSize + 0.9, 0.6, World.PlotSize + 0.9),
			CFrame = center * CFrame.new(localPos + Vector3.new(0, 0.3, 0)),
			Material = Enum.Material.Wood,
			Color = COLORS.soilEdge,
			CastShadow = false,
			CanQuery = false,
		}, plot)
		plot:SetAttribute("FarmId", id)
		plot:SetAttribute("PlotIndex", index)
		plot:SetAttribute("Unlocked", false)
		plot:SetAttribute("State", "Empty")
		plot:SetAttribute("PlantedAt", 0)
		plot:SetAttribute("GrowTime", 0)
		plot:SetAttribute("RevealTier", 0)
		plot:SetAttribute("Type", "")
		plot:SetAttribute("Size", "")
		plot:SetAttribute("Mutations", "")
		plot:SetAttribute("Rarity", "")
		plots[index] = plot
	end

	-- Entrance gate: two posts and a painted name board arching over the path, in the farm's
	-- identity color. Readable from the plaza, and it frames "your" farm when you walk in.
	local gateCF = center * CFrame.new(0, 0, -half)
	local gateHalf = entrance / 2 + 0.7
	for _, x in { -gateHalf, gateHalf } do
		part({
			Name = "GatePost",
			Size = Vector3.new(1.1, 10.5, 1.1),
			CFrame = gateCF * CFrame.new(x, 5.25, 0),
			Material = Enum.Material.Wood,
			Color = COLORS.darkWood,
		}, model)
		part({
			Name = "GatePostCap",
			Size = Vector3.new(1.5, 0.5, 1.5),
			CFrame = gateCF * CFrame.new(x, 10.75, 0),
			Material = Enum.Material.Wood,
			Color = identity,
		}, model)
	end
	part({
		Name = "GateBeam",
		Size = Vector3.new(gateHalf * 2 + 1.6, 0.7, 0.9),
		CFrame = gateCF * CFrame.new(0, 10.1, 0),
		Material = Enum.Material.Wood,
		Color = COLORS.darkWood,
	}, model)
	local board = part({
		Name = "SignBoard",
		Size = Vector3.new(gateHalf * 2 - 1.4, 3.2, 0.5),
		CFrame = gateCF * CFrame.new(0, 8, -0.1),
		Material = Enum.Material.SmoothPlastic,
		Color = identity,
	}, model)
	part({
		Name = "SignFrame",
		Size = Vector3.new(gateHalf * 2 - 0.8, 3.8, 0.35),
		CFrame = gateCF * CFrame.new(0, 8, 0.15),
		Material = Enum.Material.Wood,
		Color = COLORS.cream,
	}, model)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(500, 130)
	surface.LightInfluence = 0.2
	surface.MaxDistance = 260
	surface.Parent = board
	local title = label(surface, {
		Name = "Title",
		Size = UDim2.new(1, -24, 0.62, 0),
		Position = UDim2.fromOffset(12, 6),
		Text = "Free Farm",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = COLORS.white,
		TextStrokeColor3 = identity:Lerp(Color3.new(0, 0, 0), 0.6),
		TextStrokeTransparency = 0,
	})
	local subtitle = label(surface, {
		Name = "Subtitle",
		Size = UDim2.new(1, -24, 0.28, 0),
		Position = UDim2.new(0, 12, 0.66, 0),
		Text = "",
		TextColor3 = COLORS.white,
		TextStrokeColor3 = identity:Lerp(Color3.new(0, 0, 0), 0.6),
		TextStrokeTransparency = 0.2,
	})
	-- One heart per farm per day
	local likePrompt = Instance.new("ProximityPrompt")
	likePrompt.Name = "LikePrompt"
	likePrompt.ActionText = "Like ❤"
	likePrompt.ObjectText = "Farm"
	likePrompt.HoldDuration = 0
	likePrompt.MaxActivationDistance = 14
	likePrompt.RequiresLineOfSight = false
	likePrompt.KeyboardKeyCode = Enum.KeyCode.F
	likePrompt.Enabled = false
	likePrompt.Parent = board

	-- Pedestal for the owner's best carrot, in the front corner where passers-by see it
	local pedestalCF = center * CFrame.new(half - 3.6, 0, -half + 3.6)
	part({
		Name = "PedestalBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 5.4, 5.4),
		CFrame = pedestalCF * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.white,
	}, model)
	part({
		Name = "PedestalColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 3.6, 3.6),
		CFrame = pedestalCF * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = COLORS.cream,
	}, model)
	local pedestalTop = part({
		Name = "PedestalTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 4.6, 4.6),
		CFrame = pedestalCF * CFrame.new(0, 3.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.gold,
	}, model)
	pedestalTop:SetAttribute("FarmId", id)

	-- Spawn pad just inside the entrance, facing the plots
	local padPos = (center * CFrame.new(0, 0, -half + 4)).Position
	part({
		Name = "SpawnPad",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = CFrame.new(padPos + Vector3.new(0, 0.15, 0)) * center.Rotation,
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
		CastShadow = false,
	}, model)
	local spawnCFrame = CFrame.lookAt(padPos + Vector3.new(0, 3.5, 0), centerPos + Vector3.new(0, 3.5, 0))

	-- Barn behind the farm in the farm's identity color: a landmark you can name and find.
	local barnCF = center * CFrame.new(0, 0, half + 9)
	part({
		Name = "BarnBody",
		Size = Vector3.new(12, 7, 8),
		CFrame = barnCF * CFrame.new(0, 3.5, 0),
		Material = Enum.Material.WoodPlanks,
		Color = identity,
	}, model)
	for _, sx in { -1, 1 } do
		part({
			Name = "BarnRoof",
			Size = Vector3.new(7.4, 0.6, 9),
			CFrame = barnCF * CFrame.new(sx * 3.1, 9.1, 0) * CFrame.Angles(0, 0, math.rad(-sx * 38)),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.darkWood,
		}, model)
	end
	part({
		Name = "BarnGable",
		Size = Vector3.new(5, 2.2, 7.8),
		CFrame = barnCF * CFrame.new(0, 8.1, 0),
		Material = Enum.Material.WoodPlanks,
		Color = identity,
	}, model)
	part({
		Name = "BarnDoor",
		Size = Vector3.new(4.6, 5, 0.2),
		CFrame = barnCF * CFrame.new(0, 2.5, -4.05),
		Material = Enum.Material.Wood,
		Color = COLORS.white,
	}, model)
	for _, d in { 1, -1 } do
		part({
			Name = "BarnDoorX",
			Size = Vector3.new(0.4, 6.4, 0.25),
			CFrame = barnCF * CFrame.new(0, 2.5, -4.2) * CFrame.Angles(0, 0, math.rad(d * 42)),
			Material = Enum.Material.Wood,
			Color = identity:Lerp(Color3.new(0, 0, 0), 0.25),
			CanCollide = false,
		}, model)
	end

	-- Path from the plaza to the entrance
	local startPos = centerPos.Unit * 33
	local endPos = (center * CFrame.new(0, 0, -half)).Position
	local length = (endPos - startPos).Magnitude
	local pathCF = CFrame.lookAt((startPos + endPos) / 2, endPos)
	part({
		Name = "PathEdge",
		Size = Vector3.new(9.4, 0.16, length),
		CFrame = pathCF * CFrame.new(0, 0.08, 0),
		Material = Enum.Material.Slate,
		Color = COLORS.pathEdge,
		CastShadow = false,
	}, paths)
	part({
		Name = "Path",
		Size = Vector3.new(8, 0.2, length),
		CFrame = pathCF * CFrame.new(0, 0.1, 0),
		Material = Enum.Material.Sand,
		Color = COLORS.path,
		CastShadow = false,
	}, paths)

	model.Parent = farmsFolder
	return {
		id = id,
		model = model,
		center = center,
		plots = plots,
		spawnCFrame = spawnCFrame,
		signTitle = title,
		signSubtitle = subtitle,
		likePrompt = likePrompt,
		pedestalTop = pedestalTop,
	}
end

local function buildLeaderboard(
	parent: Instance,
	def: { id: string, title: string, color: Color3, angle: number }
): LeaderboardBuild
	local a = math.rad(def.angle)
	local pos = Vector3.new(math.sin(a) * 50, 0, math.cos(a) * 50)
	local cf = CFrame.lookAt(pos, Vector3.zero)
	local model = Instance.new("Model")
	model.Name = "Leaderboard_" .. def.id
	for _, x in { -7.4, 7.4 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.8, 14, 0.8),
			CFrame = cf * CFrame.new(x, 7, 0.3),
			Material = Enum.Material.Wood,
			Color = COLORS.darkWood,
		}, model)
	end
	local board = part({
		Name = "Board",
		Size = Vector3.new(14, 10, 0.6),
		CFrame = cf * CFrame.new(0, 8.5, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(255, 248, 230),
	}, model)
	-- Wooden frame and a little roof: a market notice board, not a floating whiteboard
	part({
		Name = "Frame",
		Size = Vector3.new(15, 11, 0.5),
		CFrame = cf * CFrame.new(0, 8.5, 0.3),
		Material = Enum.Material.Wood,
		Color = COLORS.darkWood,
	}, model)
	for _, sx in { -1, 1 } do
		part({
			Name = "Roof",
			Size = Vector3.new(9, 0.5, 2.4),
			CFrame = cf * CFrame.new(sx * 4, 15.1, 0.3) * CFrame.Angles(0, 0, math.rad(-sx * 14)),
			Material = Enum.Material.WoodPlanks,
			Color = def.color:Lerp(Color3.new(0, 0, 0), 0.25),
		}, model)
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(560, 400)
	surface.LightInfluence = 0.2
	surface.Parent = board
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundColor3 = def.color
	header.BorderSizePixel = 0
	header.Parent = surface
	label(header, {
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		Text = def.title,
		Font = Enum.Font.LuckiestGuy,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(60, 40, 10),
	})
	local rows: { LeaderboardRow } = {}
	local rowH = (400 - 70) / LEADERBOARD_ROWS
	for i = 1, LEADERBOARD_ROWS do
		local y = 66 + (i - 1) * rowH
		local rankColor = if i == 1
			then Color3.fromRGB(255, 190, 30)
			elseif i == 2 then Color3.fromRGB(170, 180, 200)
			elseif i == 3 then Color3.fromRGB(220, 140, 70)
			else Color3.fromRGB(120, 100, 80)
		label(surface, {
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.fromOffset(50, rowH - 2),
			Text = "#" .. i,
			Font = Enum.Font.LuckiestGuy,
			TextColor3 = rankColor,
			TextStrokeTransparency = 1,
		})
		local name = label(surface, {
			Position = UDim2.fromOffset(66, y),
			Size = UDim2.fromOffset(300, rowH - 2),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(70, 50, 30),
			TextStrokeTransparency = 1,
		})
		local value = label(surface, {
			Position = UDim2.fromOffset(370, y),
			Size = UDim2.fromOffset(180, rowH - 2),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.LuckiestGuy,
			TextColor3 = Color3.fromRGB(40, 150, 40),
			TextStrokeTransparency = 1,
		})
		rows[i] = { name = name, value = value }
	end
	model.Parent = parent
	return { id = def.id, rows = rows }
end

-- VIP lounge next to the plaza (Market VIP pass). The door is solid for everyone; VIP clients
-- turn its collision off locally.
local function buildVipLounge(parent: Instance)
	local a = math.rad(247.5)
	local pos = Vector3.new(math.sin(a) * 46, 0, math.cos(a) * 46)
	local cf = CFrame.lookAt(pos, Vector3.zero)
	local model = Instance.new("Model")
	model.Name = "VipLounge"
	local size = 16
	-- A private garden: trimmed hedges with gold caps and a royal-purple carpet. Status should
	-- look classy, not like a neon box.
	local gold = COLORS.gold
	part({
		Name = "Floor",
		Size = Vector3.new(size, 0.4, size),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.Marble,
		Color = COLORS.cream,
		CastShadow = false,
	}, model)
	part({
		Name = "Carpet",
		Size = Vector3.new(size - 5, 0.1, size - 3),
		CFrame = cf * CFrame.new(0, 0.45, -1.5),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(120, 70, 190),
		CastShadow = false,
		CanCollide = false,
	}, model)
	local wallH = 5
	local function wall(localCF: CFrame, length: number)
		part({
			Name = "Wall",
			Size = Vector3.new(length, wallH, 1.6),
			CFrame = cf * localCF * CFrame.new(0, wallH / 2, 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(58, 132, 56),
		}, model)
		part({
			Name = "WallCap",
			Size = Vector3.new(length + 0.2, 0.3, 1.8),
			CFrame = cf * localCF * CFrame.new(0, wallH + 0.15, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = gold,
			CastShadow = false,
		}, model)
	end
	local h = size / 2
	wall(CFrame.new(0, 0, h), size)
	wall(CFrame.new(-h, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), size)
	wall(CFrame.new(h, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), size)
	local door = 6
	local side = (size - door) / 2
	wall(CFrame.new(-h + side / 2, 0, -h), side)
	wall(CFrame.new(h - side / 2, 0, -h), side)
	part({
		Name = "VIPDoor",
		Size = Vector3.new(door, wallH + 1, 0.4),
		CFrame = cf * CFrame.new(0, (wallH + 1) / 2, -h),
		Material = Enum.Material.Neon,
		Color = gold,
		Transparency = 0.6,
		CastShadow = false,
	}, model)
	-- Benches and a golden trophy carrot
	for _, x in { -4.5, 4.5 } do
		part({
			Name = "Bench",
			Size = Vector3.new(4, 1.2, 1.6),
			CFrame = cf * CFrame.new(x, 0.9, h - 2),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.wood,
		}, model)
	end
	statueCarrot(model, (cf * CFrame.new(0, 7, 2)).Position, 0.6)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Parent and p.Parent.Name == "CarrotStatue" then
			p.Color = gold
			p.Material = Enum.Material.Foil
		end
	end
	-- Name board over the door (a physical sign, not a floating label)
	for _, x in { -door / 2 - 0.4, door / 2 + 0.4 } do
		part({
			Name = "DoorPost",
			Size = Vector3.new(0.8, wallH + 3.6, 0.8),
			CFrame = cf * CFrame.new(x, (wallH + 3.6) / 2, -h),
			Material = Enum.Material.SmoothPlastic,
			Color = gold,
		}, model)
	end
	local vipBoard = part({
		Name = "VipBoard",
		Size = Vector3.new(door + 2.4, 2, 0.4),
		CFrame = cf * CFrame.new(0, wallH + 2.4, -h - 0.1),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(90, 50, 150),
	}, model)
	boardText(vipBoard, Enum.NormalId.Front, Vector2.new(360, 80), {
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "⭐ VIP LOUNGE",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = gold,
		TextStrokeColor3 = Color3.fromRGB(50, 20, 80),
		TextStrokeTransparency = 0,
	})
	model.Parent = parent
end

function WorldBuilder.build(): WorldBuild
	buildLighting()

	local world = folder("World", workspace)
	buildGround(world)
	local marketCFrame = buildMarket(world)
	for _, deg in World.UpgradeStallAngles do
		buildUpgradeStall(world, deg)
	end
	buildDecor(world)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 24)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Color = COLORS.plaza
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	local paths = folder("Paths", world)
	local farmsFolder = folder("Farms", workspace)
	local farms = {}
	for id = 1, World.FarmCount do
		farms[id] = buildFarm(farmsFolder, paths, id)
	end

	-- Anchor for the compact boom timer above the market (client renders it)
	part({
		Name = "PriceBoardAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 34, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, world)

	buildVipLounge(world)

	local boards = folder("Leaderboards", world)
	local leaderboards = {}
	for _, def in LEADERBOARDS do
		table.insert(leaderboards, buildLeaderboard(boards, def))
	end

	assert(#World.PlotCells >= Economy.MaxPlots, "World.PlotCells must cover MaxPlots")
	return { farms = farms, marketCFrame = marketCFrame, leaderboards = leaderboards }
end

return WorldBuilder
