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
	sellPrompt: ProximityPrompt,
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

-- Bright, saturated, child-friendly palette.
local COLORS = {
	grass = Color3.fromRGB(110, 205, 75),
	farmGrass = Color3.fromRGB(140, 222, 95),
	soil = Color3.fromRGB(176, 112, 62),
	soilFurrow = Color3.fromRGB(150, 92, 50),
	soilEdge = Color3.fromRGB(125, 78, 42),
	path = Color3.fromRGB(250, 222, 160),
	plaza = Color3.fromRGB(240, 232, 215),
	wood = Color3.fromRGB(205, 140, 80),
	darkWood = Color3.fromRGB(160, 100, 55),
	fence = Color3.fromRGB(255, 255, 250),
	orange = Color3.fromRGB(255, 140, 30),
	white = Color3.fromRGB(255, 255, 250),
	leaf = Color3.fromRGB(85, 200, 70),
	leafLight = Color3.fromRGB(150, 230, 85),
	trunk = Color3.fromRGB(150, 100, 60),
	rock = Color3.fromRGB(185, 185, 195),
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
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 105, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 165, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	for _, child in Lighting:GetChildren() do
		child:Destroy()
	end

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 2000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 230, 255)
	atmosphere.Decay = Color3.fromRGB(140, 190, 255)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.28
	cc.Contrast = 0.06
	cc.Brightness = 0.04
	cc.TintColor = Color3.fromRGB(255, 252, 245)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
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

	disc("Plaza", Vector3.new(0, 0.25, 0), 64, 0.5, {
		Material = Enum.Material.Cobblestone,
		Color = COLORS.plaza,
		CastShadow = false,
	}, world)
	disc("PlazaRing", Vector3.new(0, 0.2, 0), 68, 0.4, {
		Material = Enum.Material.Brick,
		Color = Color3.fromRGB(170, 120, 90),
		CastShadow = false,
	}, world)
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

local function buildMarket(world: Folder): (ProximityPrompt, CFrame)
	local market = Instance.new("Model")
	market.Name = "Market"

	local size = 16
	local h = size / 2
	-- Corner posts
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			pillar("Post", Vector3.new(sx * (h - 0.6), 0.5, sz * (h - 0.6)), 9.5, 1.2, {
				Color = COLORS.darkWood,
				Material = Enum.Material.Wood,
			}, market)
		end
	end
	-- Counters on all four sides, with crates of carrots on top
	for i = 0, 3 do
		local rot = CFrame.Angles(0, i * math.pi / 2, 0)
		part({
			Name = "Counter",
			Size = Vector3.new(size - 2.4, 3.4, 2.2),
			CFrame = rot * CFrame.new(0, 2.2, h - 1.1),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.wood,
		}, market)
		for c = -1, 1 do
			local crate = part({
				Name = "Crate",
				Size = Vector3.new(2.6, 1, 1.6),
				CFrame = rot * CFrame.new(c * 4, 4.4, h - 1.1),
				Material = Enum.Material.Wood,
				Color = COLORS.darkWood,
			}, market)
			for k = -1, 1 do
				part({
					Name = "CrateCarrot",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.7, 0.7, 0.7),
					CFrame = crate.CFrame * CFrame.new(k * 0.75, 0.55, 0),
					Color = COLORS.orange,
					CastShadow = false,
				}, market)
			end
		end
	end
	-- Roof with orange/white stripes
	part({
		Name = "Roof",
		Size = Vector3.new(size + 3, 0.8, size + 3),
		CFrame = CFrame.new(0, 10.4, 0),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.white,
	}, market)
	local stripes = 9
	local stripeW = (size + 3) / stripes
	for s = 0, stripes - 1 do
		part({
			Name = "Stripe",
			Size = Vector3.new(stripeW, 0.3, size + 3.2),
			CFrame = CFrame.new(-(size + 3) / 2 + stripeW * (s + 0.5), 10.95, 0),
			Material = Enum.Material.Fabric,
			Color = if s % 2 == 0 then COLORS.orange else COLORS.white,
			CastShadow = false,
		}, market)
	end
	statueCarrot(market, Vector3.new(0, 19.5, 0), 1.2)

	-- Sign
	local signPart = part({
		Name = "SignAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 25, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, market)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sign"
	bb.Size = UDim2.fromScale(30, 8)
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = signPart
	label(bb, {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.62),
		Text = "CARROT MARKET",
		TextColor3 = Color3.fromRGB(255, 170, 60),
		TextStrokeColor3 = Color3.fromRGB(70, 30, 0),
		TextStrokeTransparency = 0,
	})
	label(bb, {
		Name = "Slogan",
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.38),
		Text = "Grow carrots. Find rare ones. Get rich.",
	})

	-- One sell prompt reachable from every counter.
	local promptPart = part({
		Name = "SellPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, market)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell All"
	prompt.ObjectText = "Market"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = promptPart

	market.Parent = world
	return prompt, CFrame.new(0, 0, 0)
end

local function buildTree(parent: Instance, pos: Vector3, scale: number, rng: Random)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	local trunkH = 7 * scale
	pillar("Trunk", pos, trunkH, 1.6 * scale, {
		Material = Enum.Material.Wood,
		Color = COLORS.trunk,
	}, tree)
	local leafColor = COLORS.leaf:Lerp(COLORS.leafLight, rng:NextNumber())
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 9 * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH + 2.5 * scale, 0)),
		Material = Enum.Material.SmoothPlastic,
		Color = leafColor,
	}, tree)
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 6 * scale,
		CFrame = CFrame.new(pos + Vector3.new(1.5 * scale, trunkH + 5.5 * scale, -1 * scale)),
		Material = Enum.Material.SmoothPlastic,
		Color = leafColor:Lerp(Color3.new(1, 1, 1), 0.12),
	}, tree)
	tree.Parent = parent
end

local function buildDecor(world: Folder)
	local decor = folder("Decor", world)
	local rng = Random.new(World.Seed)
	local angleStep = 2 * math.pi / World.FarmCount

	-- Trees between farms
	for i = 0, World.FarmCount - 1 do
		local a = (i + 0.5) * angleStep
		for _, r in { 88, 118 } do
			local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
			buildTree(decor, pos, 0.9 + rng:NextNumber() * 0.4, rng)
		end
	end

	-- Outer ring of trees
	local placed = 0
	local attempts = 0
	while placed < World.TreeCount and attempts < 1000 do
		attempts += 1
		local a = rng:NextNumber() * 2 * math.pi
		local r = 165 + rng:NextNumber() * 140
		local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if math.abs(pos.X) < 315 and math.abs(pos.Z) < 315 then
			buildTree(decor, pos, 0.9 + rng:NextNumber() * 0.8, rng)
			placed += 1
		end
	end

	-- Flower patches: little colorful dots everywhere (cheap: one ball per flower)
	for _ = 1, 90 do
		local a = rng:NextNumber() * 2 * math.pi
		local r = 36 + rng:NextNumber() * 270
		local angleToFarm = (a % angleStep) / angleStep
		local onFarm = r > 62 and r < 138 and (angleToFarm < 0.32 or angleToFarm > 0.68)
		if not onFarm then
			local center = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
			local color = COLORS.flowers[rng:NextInteger(1, #COLORS.flowers)]
			for _ = 1, 3 do
				local offset = Vector3.new(rng:NextNumber() * 3 - 1.5, 0, rng:NextNumber() * 3 - 1.5)
				part({
					Name = "Flower",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * (0.7 + rng:NextNumber() * 0.4),
					CFrame = CFrame.new(center + offset + Vector3.new(0, 0.35, 0)),
					Color = color,
					CanCollide = false,
					CastShadow = false,
				}, decor)
			end
		end
	end

	-- Rocks
	for _ = 1, 24 do
		local a = rng:NextNumber() * 2 * math.pi
		local r = 40 + rng:NextNumber() * 250
		local pos = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		local angleToFarm = (a % angleStep) / angleStep
		local nearFarm = r > 65 and r < 135 and (angleToFarm < 0.3 or angleToFarm > 0.7)
		if not nearFarm and r > 40 then
			local s = 1.5 + rng:NextNumber() * 2.5
			part({
				Name = "Rock",
				Size = Vector3.new(s * 1.4, s, s * 1.1),
				CFrame = CFrame.new(pos + Vector3.new(0, s * 0.3, 0))
					* CFrame.Angles(rng:NextNumber(), rng:NextNumber() * 6, rng:NextNumber() * 0.5),
				Material = Enum.Material.Slate,
				Color = COLORS.rock,
			}, decor)
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
	local half = 2 * cell - World.PlotGap / 2 + World.FarmPadding

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
		local plot = part({
			Name = "Plot_" .. index,
			Size = Vector3.new(World.PlotSize, 0.8, World.PlotSize),
			CFrame = center * CFrame.new(localPos + Vector3.new(0, 0.4, 0)),
			Material = Enum.Material.SmoothPlastic,
			Color = COLORS.soil,
			CastShadow = false,
		}, plotsFolder)
		-- Three soft furrows on top
		for f = -1, 1 do
			part({
				Name = "Furrow",
				Size = Vector3.new(0.9, 0.2, World.PlotSize - 1.2),
				CFrame = center * CFrame.new(localPos + Vector3.new(f * 2.1, 0.85, 0)),
				Material = Enum.Material.SmoothPlastic,
				Color = COLORS.soilFurrow,
				CastShadow = false,
				CanCollide = false,
			}, plot)
		end
		-- Darker rim so plots read clearly from above on small screens
		part({
			Name = "Rim",
			Size = Vector3.new(World.PlotSize + 0.8, 0.5, World.PlotSize + 0.8),
			CFrame = center * CFrame.new(localPos + Vector3.new(0, 0.25, 0)),
			Material = Enum.Material.WoodPlanks,
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

	-- Sign at the entrance, facing the market
	local signCF = center * CFrame.new(-entrance / 2 - 5, 0, -half - 1.5)
	for _, x in { -2.6, 2.6 } do
		part({
			Name = "SignPost",
			Size = Vector3.new(0.5, 5.5, 0.5),
			CFrame = signCF * CFrame.new(x, 2.75, 0),
			Material = Enum.Material.Wood,
			Color = COLORS.darkWood,
		}, model)
	end
	local board = part({
		Name = "SignBoard",
		Size = Vector3.new(6.6, 2.6, 0.4),
		CFrame = signCF * CFrame.new(0, 4.4, 0),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
	}, model)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(330, 130)
	surface.LightInfluence = 0.3
	surface.Parent = board
	local title = label(surface, {
		Name = "Title",
		Size = UDim2.new(1, -16, 0.62, 0),
		Position = UDim2.fromOffset(8, 6),
		Text = "Free Farm",
		TextColor3 = Color3.fromRGB(255, 245, 220),
		TextStrokeColor3 = Color3.fromRGB(60, 35, 15),
		TextStrokeTransparency = 0,
	})
	local subtitle = label(surface, {
		Name = "Subtitle",
		Size = UDim2.new(1, -16, 0.3, 0),
		Position = UDim2.new(0, 8, 0.64, 0),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 220, 160),
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
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(255, 230, 150),
	}, model)
	local pedestalTop = part({
		Name = "PedestalTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 4.6, 4.6),
		CFrame = pedestalCF * CFrame.new(0, 3.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 205, 60),
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

	-- Path from the plaza to the entrance
	local startPos = centerPos.Unit * 33
	local endPos = (center * CFrame.new(0, 0, -half)).Position
	local length = (endPos - startPos).Magnitude
	part({
		Name = "Path",
		Size = Vector3.new(8, 0.2, length),
		CFrame = CFrame.lookAt((startPos + endPos) / 2, endPos) * CFrame.new(0, 0.1, 0),
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
	local gold = Color3.fromRGB(255, 205, 60)
	part({
		Name = "Floor",
		Size = Vector3.new(size, 0.4, size),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(255, 240, 190),
		CastShadow = false,
	}, model)
	local wallH = 5
	local function wall(localCF: CFrame, length: number)
		part({
			Name = "Wall",
			Size = Vector3.new(length, wallH, 0.6),
			CFrame = cf * localCF * CFrame.new(0, wallH / 2, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = gold,
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
			p.Material = Enum.Material.Neon
		end
	end
	local signPart = part({
		Name = "SignAnchor",
		Size = Vector3.one,
		CFrame = cf * CFrame.new(0, 9, -h),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, model)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(12, 2.5)
	bb.LightInfluence = 0
	bb.MaxDistance = 150
	bb.Parent = signPart
	label(bb, {
		Size = UDim2.fromScale(1, 1),
		Text = "⭐ VIP LOUNGE ⭐",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = gold,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(110, 60, 0),
	})
	model.Parent = parent
end

function WorldBuilder.build(): WorldBuild
	buildLighting()

	local world = folder("World", workspace)
	buildGround(world)
	local sellPrompt, marketCFrame = buildMarket(world)
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

	-- Price board anchor above the market (the client renders the live board on it)
	part({
		Name = "PriceBoardAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 38, 0),
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
	return { farms = farms, sellPrompt = sellPrompt, marketCFrame = marketCFrame, leaderboards = leaderboards }
end

return WorldBuilder
