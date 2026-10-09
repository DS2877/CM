--!strict
-- The plaza: a farmers' market where giant bunnies buy your carrots.
--   * BOOM EXCHANGE in the middle: a tall billboard tower with a screen on all four sides (the
--     client draws the live boom countdown on them) and big bunny ears on top - the landmark you
--     see from every farm.
--   * Four stalls around it, one per side, each with a giant bunny buyer behind the counter,
--     a striped awning and crates of carrots. Step on the round SELL mat in front of a stall
--     and the bunny buys your whole basket (server: Economy.sellAll). The stall model gets
--     SaleAt/SaleCount attributes so every client can make that bunny celebrate.
--   * Little market tables with umbrellas between the paths.
-- Everything is primitives. Named parts are what the client animates (BigBunny/Head/Body,
-- PartyHat, Screen_*).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local BunnyMarket = {}

local C = {
	wood = Color3.fromRGB(190, 132, 78),
	darkWood = Color3.fromRGB(120, 78, 46),
	white = Color3.fromRGB(255, 252, 245),
	cream = Color3.fromRGB(255, 244, 222),
	orange = Color3.fromRGB(255, 136, 36),
	leaf = Color3.fromRGB(72, 158, 64),
	gold = Color3.fromRGB(255, 200, 60),
	pink = Color3.fromRGB(255, 160, 185),
	black = Color3.fromRGB(35, 30, 35),
	screen = Color3.fromRGB(20, 24, 34),
	mat = Color3.fromRGB(110, 200, 95),
}
-- Per stall: awning color and bunny fur
local STALLS = {
	{ awning = Color3.fromRGB(235, 80, 90), fur = Color3.fromRGB(250, 250, 250) },
	{ awning = Color3.fromRGB(80, 170, 255), fur = Color3.fromRGB(215, 180, 140) },
	{ awning = Color3.fromRGB(120, 210, 100), fur = Color3.fromRGB(190, 190, 200) },
	{ awning = Color3.fromRGB(175, 120, 255), fur = Color3.fromRGB(150, 110, 80) },
}
local CANDY = {
	Color3.fromRGB(255, 105, 150),
	Color3.fromRGB(255, 205, 50),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(120, 220, 110),
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

local function sphere(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, { Name = name, Size = size, CFrame = cf, Color = color, CanCollide = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Upright cylinder centered at `cf` (height along Y).
local function cyl(parent: Instance, name: string, height: number, d: number, cf: CFrame, color: Color3): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, d, d),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	})
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = C.white
	l.TextStrokeTransparency = 0
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function surface(p: BasePart, face: Enum.NormalId, canvas: Vector2): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.CanvasSize = canvas
	g.LightInfluence = 0.15
	g.MaxDistance = 250
	g.Parent = p
	return g
end

-- A giant bunny standing behind a counter. `base` = feet on the stall floor, looking along -Z.
local function bigBunny(parent: Instance, base: CFrame, fur: Color3): Model
	local model = Instance.new("Model")
	model.Name = "BigBunny"
	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = model
	sphere(body, "Belly", Vector3.new(5.2, 5.8, 4.6), base * CFrame.new(0, 3.2, 0), fur)
	sphere(body, "Tummy", Vector3.new(3.4, 4, 1), base * CFrame.new(0, 3.1, -2), C.cream)
	sphere(body, "Tail", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 2, 2.3), C.white)
	for _, s in { -1, 1 } do
		sphere(body, "Foot", Vector3.new(1.6, 1, 2.6), base * CFrame.new(s * 1.4, 0.5, -1), fur)
		-- paws resting on the counter
		sphere(body, "Paw", Vector3.new(1.3, 1.1, 1.5), base * CFrame.new(s * 1.6, 3.8, -2.6), fur)
	end

	local head = Instance.new("Model")
	head.Name = "Head"
	head.Parent = model
	local h = base * CFrame.new(0, 7.3, -0.6)
	sphere(head, "Skull", Vector3.new(4.4, 3.9, 3.9), h, fur)
	for _, s in { -1, 1 } do
		sphere(head, "Eye", Vector3.new(0.7, 0.9, 0.4), h * CFrame.new(s * 0.95, 0.4, -1.75), C.black)
		sphere(head, "Shine", Vector3.new(0.25, 0.25, 0.15), h * CFrame.new(s * 0.85, 0.6, -1.95), C.white)
		sphere(head, "Cheek", Vector3.new(0.8, 0.5, 0.3), h * CFrame.new(s * 1.45, -0.4, -1.65), C.pink)
		-- Ears: outer fur, inner pink
		local ear = h * CFrame.new(s * 0.9, 3.3, 0.1) * CFrame.Angles(0, 0, math.rad(-s * 10))
		sphere(head, if s < 0 then "EarL" else "EarR", Vector3.new(1.1, 4.4, 0.7), ear, fur)
		sphere(head, "EarInner", Vector3.new(0.6, 3.4, 0.2), ear * CFrame.new(0, 0, -0.3), C.pink)
	end
	sphere(head, "Nose", Vector3.new(0.6, 0.45, 0.4), h * CFrame.new(0, -0.15, -1.95), C.pink)
	part(head, {
		Name = "Teeth",
		Size = Vector3.new(0.7, 0.55, 0.15),
		CFrame = h * CFrame.new(0, -0.75, -1.85),
		Color = C.white,
		CanCollide = false,
	})
	-- Party hat (hidden; the client shows it during a boom)
	local hat = Instance.new("Model")
	hat.Name = "PartyHat"
	hat.Parent = head
	for i = 0, 3 do
		local d = 1.9 - i * 0.45
		local p = cyl(hat, "Hat", 0.55, d, h * CFrame.new(-0.9, 2.1 + i * 0.5, -0.2), CANDY[(i % #CANDY) + 1])
		p.CanCollide = false
		p.Transparency = 1
	end
	local pom = sphere(hat, "Pom", Vector3.new(0.6, 0.6, 0.6), h * CFrame.new(-0.9, 4.2, -0.2), C.gold)
	pom.Transparency = 1

	-- Hearts / crumbs come out here when someone sells (client)
	local mouth = part(head, {
		Name = "Mouth",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = h * CFrame.new(0, -0.6, -2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	mouth:SetAttribute("Fx", true)
	model.Parent = parent
	return model
end

local function buildStall(parent: Instance, index: number, deg: number)
	local a = math.rad(deg)
	local dir = Vector3.new(math.sin(a), 0, math.cos(a))
	local center = dir * World.BunnyStallDistance
	-- -Z (LookVector) points out toward the mat and the arriving players
	local cf = CFrame.lookAt(center, center + dir)
	local style = STALLS[(index - 1) % #STALLS + 1]
	local name = World.BunnyNames[index] or "Bunny"
	local model = Instance.new("Model")
	model.Name = "Stall_" .. index
	model:SetAttribute("StallIndex", index)
	model:SetAttribute("SaleAt", 0)
	model:SetAttribute("SaleCount", 0)
	local W, D = 11, 6.5

	part(model, {
		Name = "Floor",
		Size = Vector3.new(W + 1, 0.5, D + 1),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.WoodPlanks,
		Color = C.wood,
	})
	-- Candy-striped posts
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for k = 0, 6 do
				cyl(
					model,
					"Post",
					1.8,
					0.7,
					cf * CFrame.new(sx * (W / 2 - 0.3), 1.6 + k * 1.8, sz * (D / 2 - 0.3)),
					if k % 2 == 0 then C.white else style.awning
				)
			end
		end
	end
	-- Counter at the front, with crates of carrots
	part(model, {
		Name = "Counter",
		Size = Vector3.new(W - 1, 3, 1.4),
		CFrame = cf * CFrame.new(0, 2.25, -D / 2 + 0.9),
		Material = Enum.Material.WoodPlanks,
		Color = C.wood,
	})
	part(model, {
		Name = "CounterTop",
		Size = Vector3.new(W - 0.6, 0.3, 1.8),
		CFrame = cf * CFrame.new(0, 3.9, -D / 2 + 0.9),
		Material = Enum.Material.Wood,
		Color = C.darkWood,
	})
	for _, x in { -3.6, 3.6 } do
		local crate = part(model, {
			Name = "Crate",
			Size = Vector3.new(2.6, 1, 1.4),
			CFrame = cf * CFrame.new(x, 4.55, -D / 2 + 0.9),
			Material = Enum.Material.WoodPlanks,
			Color = C.wood,
		})
		for k = -1, 1 do
			part(model, {
				Name = "CrateCarrot",
				Size = Vector3.new(0.55, 1.1, 0.55),
				CFrame = crate.CFrame * CFrame.new(k * 0.8, 0.7, 0) * CFrame.Angles(0, 0, math.rad(k * 12)),
				Color = C.orange,
				CanCollide = false,
			})
			part(model, {
				Name = "CrateLeaf",
				Size = Vector3.new(0.3, 0.6, 0.3),
				CFrame = crate.CFrame * CFrame.new(k * 0.8 + k * 0.12, 1.45, 0),
				Color = C.leaf,
				CanCollide = false,
			})
		end
	end
	-- Striped awning sloping toward the front
	local stripes = 6
	for i = 0, stripes - 1 do
		local x = -W / 2 - 0.5 + (W + 1) * (i + 0.5) / stripes
		part(model, {
			Name = "Awning",
			Size = Vector3.new((W + 1) / stripes, 0.35, D + 2.2),
			CFrame = cf * CFrame.new(x, 13.9, -0.4) * CFrame.Angles(math.rad(14), 0, 0),
			Material = Enum.Material.Fabric,
			Color = if i % 2 == 0 then style.awning else C.white,
			CastShadow = false,
		})
	end
	-- Name sign on the awning front: who buys here
	local sign = part(model, {
		Name = "StallSign",
		Size = Vector3.new(W, 2.6, 0.3),
		CFrame = cf * CFrame.new(0, 14.4, -D / 2 - 1.6),
		Color = style.awning,
	})
	local g = surface(sign, Enum.NormalId.Front, Vector2.new(440, 104))
	label(g, {
		Size = UDim2.new(1, -16, 0.62, 0),
		Position = UDim2.fromOffset(8, 4),
		Text = "🐰 " .. string.upper(name),
		TextStrokeColor3 = style.awning:Lerp(Color3.new(0, 0, 0), 0.6),
	})
	label(g, {
		Size = UDim2.new(1, -16, 0.32, 0),
		Position = UDim2.new(0, 8, 0.64, 0),
		Text = "BUYS CARROTS!",
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 240, 160),
		TextStrokeColor3 = style.awning:Lerp(Color3.new(0, 0, 0), 0.6),
	})

	bigBunny(model, cf * CFrame.new(0, 0.75, 0.9), style.fur)

	-- The SELL mat in front of the stall: a round woven rug with SELL painted on it
	local pad = World.sellPads()[index]
	local mat = part(model, {
		Name = "SellMat",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, World.SellPadRadius * 2 + 1, World.SellPadRadius * 2 + 1),
		CFrame = CFrame.new(pad + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.gold,
		CanCollide = false,
		CastShadow = false,
	})
	mat.Material = Enum.Material.Fabric
	local inner = part(model, {
		Name = "SellPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.32, World.SellPadRadius * 2, World.SellPadRadius * 2),
		CFrame = CFrame.new(pad + Vector3.new(0, 0.47, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.mat,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
	inner:SetAttribute("StallIndex", index)
	local plate = part(model, {
		Name = "SellPlate",
		Size = Vector3.new(World.SellPadRadius * 1.5, 0.05, World.SellPadRadius * 0.9),
		CFrame = CFrame.lookAt(pad + Vector3.new(0, 0.66, 0), pad + Vector3.new(0, 0.66, 0) - dir),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local pg = surface(plate, Enum.NormalId.Top, Vector2.new(260, 150))
	label(pg, {
		Size = UDim2.fromScale(1, 1),
		Text = "🥕 SELL",
		TextStrokeColor3 = Color3.fromRGB(20, 80, 30),
	})

	model.Parent = parent
end

-- BOOM EXCHANGE: tower with four screens and bunny ears on top.
local function buildTower(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "BoomTower"
	cyl(model, "Step", 0.8, 13, CFrame.new(0, 0.7, 0), Color3.fromRGB(205, 120, 80)).Material =
		Enum.Material.Brick
	cyl(model, "Step", 0.8, 10, CFrame.new(0, 1.5, 0), Color3.fromRGB(238, 222, 190)).Material =
		Enum.Material.Slate
	part(model, {
		Name = "Pillar",
		Size = Vector3.new(3.4, 14, 3.4),
		CFrame = CFrame.new(0, 8.8, 0),
		Color = Color3.fromRGB(60, 64, 80),
		Material = Enum.Material.Metal,
	})
	for _, y in { 4, 9, 14 } do
		part(model, {
			Name = "Ring",
			Size = Vector3.new(4, 0.5, 4),
			CFrame = CFrame.new(0, y, 0),
			Color = C.gold,
			Material = Enum.Material.Metal,
		})
	end
	-- The screen box (15 x 9 x 15) with a gold frame
	local boxY = 20.5
	part(model, {
		Name = "ScreenBox",
		Size = Vector3.new(15, 9, 15),
		CFrame = CFrame.new(0, boxY, 0),
		Color = C.screen,
	})
	for _, y in { boxY - 4.75, boxY + 4.75 } do
		part(model, {
			Name = "Frame",
			Size = Vector3.new(15.8, 0.6, 15.8),
			CFrame = CFrame.new(0, y, 0),
			Color = C.gold,
			Material = Enum.Material.Metal,
		})
	end
	-- One screen part per side, slightly in front of the box, so each gets its own SurfaceGui
	for i = 0, 3 do
		local rot = CFrame.Angles(0, i * math.pi / 2, 0)
		local screen = part(model, {
			Name = "Screen_" .. (i + 1),
			Size = Vector3.new(14.2, 8.2, 0.1),
			CFrame = rot * CFrame.new(0, boxY, -7.56),
			Color = C.screen,
			CanCollide = false,
		})
		screen:SetAttribute("Screen", true)
	end
	-- Bunny ears on top: the plaza's silhouette
	for _, s in { -1, 1 } do
		local ear = CFrame.new(s * 2.6, boxY + 10.5, 0) * CFrame.Angles(0, 0, math.rad(-s * 12))
		sphere(model, "TowerEar", Vector3.new(3.2, 13, 2), ear, C.white).CanCollide = true
		sphere(model, "TowerEarInner", Vector3.new(1.8, 10, 0.6), ear * CFrame.new(0, 0, -0.85), C.pink)
		sphere(model, "TowerEarInner", Vector3.new(1.8, 10, 0.6), ear * CFrame.new(0, 0, 0.85), C.pink)
	end
	sphere(model, "TowerHead", Vector3.new(9, 4, 9), CFrame.new(0, boxY + 5.6, 0), C.white)
	model.Parent = parent
end

-- A little market table under a striped umbrella, with a basket of veggies.
local function buildTable(parent: Instance, pos: Vector3, color: Color3)
	cyl(parent, "TableLeg", 2.6, 0.5, CFrame.new(pos + Vector3.new(0, 1.3, 0)), C.darkWood)
	cyl(parent, "TableTop", 0.3, 4, CFrame.new(pos + Vector3.new(0, 2.7, 0)), C.wood).Material =
		Enum.Material.WoodPlanks
	cyl(parent, "UmbrellaPole", 6.5, 0.25, CFrame.new(pos + Vector3.new(0, 4.6, 0)), C.white)
	for i = 0, 3 do
		local d = 7.4 - i * 1.6
		cyl(
			parent,
			"Umbrella",
			0.35,
			d,
			CFrame.new(pos + Vector3.new(0, 7.7 + i * 0.3, 0)),
			if i % 2 == 0 then color else C.white
		).CanCollide =
			false
	end
	for k = 0, 4 do
		local a = k * 1.3
		sphere(
			parent,
			"Veggie",
			Vector3.one * 0.8,
			CFrame.new(pos + Vector3.new(math.cos(a) * 0.9, 3.2, math.sin(a) * 0.9)),
			CANDY[(k % #CANDY) + 1]
		)
	end
end

-- Builds the market into `world` and returns the Market model.
function BunnyMarket.build(world: Instance): Model
	local market = Instance.new("Model")
	market.Name = "Market"
	buildTower(market)
	for i, deg in World.SellPadAngles do
		buildStall(market, i, deg)
	end
	local tables = Instance.new("Folder")
	tables.Name = "Tables"
	tables.Parent = market
	for k, deg in { 22.5, 67.5, 157.5, 202.5, 247.5, 337.5 } do
		local a = math.rad(deg)
		buildTable(tables, Vector3.new(math.sin(a), 0, math.cos(a)) * 26, CANDY[(k % #CANDY) + 1])
	end
	-- Anchor for the market's ambience sound (client Music controller)
	part(market, {
		Name = "SellPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	market.Parent = world
	return market
end

-- The stall model for a SELL pad index (for sale reactions).
function BunnyMarket.stall(world: Instance, index: number): Model?
	local market = world:FindFirstChild("Market")
	local stall = market and market:FindFirstChild("Stall_" .. index)
	return if stall and stall:IsA("Model") then stall else nil
end

return BunnyMarket
