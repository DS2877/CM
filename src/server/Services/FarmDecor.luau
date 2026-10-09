--!strict
-- Builds what a farm's level unlocks (Config/FarmLevels): flowers, scarecrow, chickens, windmill,
-- pond … up to a giant golden carrot. Everything is primitives built at runtime and placed in
-- the farm's free border (between the plots and the fence) or outside the fence by the barn, so
-- it never covers a plot. `apply` rebuilds from scratch, so level-downs (account reset) and a
-- farm going free (owner left) just work.
--
-- Farm-local coordinates: origin = farm center, -Z = the gate (toward the market), +Z = barn.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmLevels = require(ReplicatedStorage.Shared.Config.FarmLevels)

local FarmDecor = {}

type Ctx = {
	center: CFrame,
	half: number,
	folder: Folder,
	identity: Color3,
	level: number,
	-- the barn for this level (farm-local): center z, half width, depth, wall height, roof top
	barnZ: number,
	barnHalfW: number,
	barnDepth: number,
	barnH: number,
	barnTop: number,
}

local C = {
	wood = Color3.fromRGB(190, 132, 78),
	darkWood = Color3.fromRGB(120, 78, 46),
	white = Color3.fromRGB(255, 252, 245),
	straw = Color3.fromRGB(232, 196, 96),
	leaf = Color3.fromRGB(72, 158, 64),
	leafLight = Color3.fromRGB(122, 196, 78),
	trunk = Color3.fromRGB(128, 86, 54),
	stone = Color3.fromRGB(168, 168, 176),
	water = Color3.fromRGB(90, 170, 235),
	gold = Color3.fromRGB(255, 200, 60),
	red = Color3.fromRGB(214, 74, 64),
	black = Color3.fromRGB(40, 36, 40),
	yellow = Color3.fromRGB(255, 214, 60),
	orange = Color3.fromRGB(255, 136, 36),
	glass = Color3.fromRGB(200, 235, 255),
}
local FLOWERS = {
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(255, 214, 60),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 140, 60),
}
local RAINBOW = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(100, 200, 90),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(150, 100, 230),
}

local function part(ctx: Ctx, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = ctx.folder
	return p
end

-- Local position -> world CFrame (upright, facing the farm's front).
local function at(ctx: Ctx, x: number, y: number, z: number): CFrame
	return ctx.center * CFrame.new(x, y, z)
end

local function block(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?
): Part
	return part(ctx, {
		Size = size,
		CFrame = at(ctx, x, y, z),
		Color = color,
		Material = mat or Enum.Material.SmoothPlastic,
	})
end

local function ball(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	d: number,
	color: Color3,
	mat: Enum.Material?
): Part
	return part(ctx, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(d, d, d),
		CFrame = at(ctx, x, y, z),
		Color = color,
		Material = mat or Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
end

-- Upright cylinder with its bottom at y.
local function column(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	h: number,
	d: number,
	color: Color3,
	mat: Enum.Material?
): Part
	return part(ctx, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, d, d),
		CFrame = at(ctx, x, y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = mat or Enum.Material.SmoothPlastic,
	})
end

local function tree(ctx: Ctx, x: number, z: number, scale: number, fruit: Color3?)
	column(ctx, x, 0, z, 5 * scale, 1.2 * scale, C.trunk, Enum.Material.Wood)
	ball(ctx, x, 6.5 * scale, z, 6 * scale, C.leaf, Enum.Material.Grass)
	ball(ctx, x + 1.6 * scale, 5.6 * scale, z - 1 * scale, 3.8 * scale, C.leafLight, Enum.Material.Grass)
	if fruit then
		for i = 0, 5 do
			local a = i * math.pi / 3
			ball(
				ctx,
				x + math.cos(a) * 2.7 * scale,
				6 * scale + (i % 2) * 1.2,
				z + math.sin(a) * 2.7 * scale,
				0.7,
				fruit
			)
		end
	end
end

local builders: { [string]: (ctx: Ctx) -> () } = {}

builders.Flowers = function(ctx)
	-- Two flower boxes inside the front fence, either side of the gate
	local z = -ctx.half + 1.6
	for _, side in { -1, 1 } do
		local x0, x1 = 9, ctx.half - 3
		block(
			ctx,
			side * (x0 + x1) / 2,
			0.4,
			z,
			Vector3.new(x1 - x0, 0.8, 1.4),
			C.wood,
			Enum.Material.WoodPlanks
		)
		local i = 0
		for x = x0 + 0.8, x1 - 0.8, 1.6 do
			i += 1
			ball(ctx, side * x, 1.25, z, 0.9, FLOWERS[(i % #FLOWERS) + 1])
		end
	end
end

builders.Scarecrow = function(ctx)
	local x, z = -ctx.half + 4, 2
	column(ctx, x, 0, z, 6.5, 0.4, C.darkWood, Enum.Material.Wood)
	block(ctx, x, 4.6, z, Vector3.new(0.35, 0.35, 4.6), C.darkWood, Enum.Material.Wood)
	block(ctx, x, 4, z, Vector3.new(1.3, 2.2, 1.8), C.red, Enum.Material.Fabric)
	ball(ctx, x, 6.2, z, 1.6, C.straw, Enum.Material.Fabric)
	column(ctx, x, 6.8, z, 0.15, 2.4, C.straw, Enum.Material.Fabric)
	column(ctx, x, 6.9, z, 0.9, 1.3, C.darkWood, Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		ball(ctx, x, 4.6, z + s * 2.4, 0.6, C.straw, Enum.Material.Fabric)
	end
end

builders.Lanterns = function(ctx)
	-- Lanterns hanging on the gate posts and a mailbox in the farm color
	for _, s in { -1, 1 } do
		local lamp = block(
			ctx,
			s * 6.7,
			7.6,
			-ctx.half - 0.9,
			Vector3.new(0.9, 1.2, 0.9),
			C.yellow,
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 220, 150)
		light.Parent = lamp
		block(ctx, s * 6.7, 8.35, -ctx.half - 0.9, Vector3.new(1.2, 0.3, 1.2), C.black)
	end
	local mx, mz = 8.8, -ctx.half - 3
	column(ctx, mx, 0, mz, 3, 0.35, C.darkWood, Enum.Material.Wood)
	block(ctx, mx, 3.3, mz, Vector3.new(1.1, 0.9, 1.6), ctx.identity)
	block(ctx, mx + 0.6, 3.6, mz + 0.4, Vector3.new(0.1, 0.7, 0.2), C.red)
end

builders.HayBales = function(ctx)
	local x, z = -ctx.half + 4, ctx.half - 4.5
	for i, p in { { 0, 0 }, { 2.6, 0.4 }, { 1.2, 2.4 } } do
		local bale = part(ctx, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2, 2.4, 2.4),
			CFrame = at(ctx, x + p[1], 1.2, z - p[2]) * CFrame.Angles(0, i * 0.7, 0),
			Color = C.straw,
			Material = Enum.Material.Fabric,
		})
		bale.Name = "HayBale"
	end
	part(ctx, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 2.4, 2.4),
		CFrame = at(ctx, x + 1.3, 3.4, z - 0.2) * CFrame.Angles(0, 0.3, 0),
		Color = C.straw,
		Material = Enum.Material.Fabric,
	})
end

builders.Chickens = function(ctx)
	local spots =
		{ { ctx.half - 4, ctx.half - 4 }, { ctx.half - 6.5, ctx.half - 3 }, { ctx.half - 3.5, ctx.half - 8 } }
	for _, p in spots do
		local x, z = p[1], p[2]
		ball(ctx, x, 0.8, z, 1.6, C.white).Name = "Chicken"
		ball(ctx, x, 1.8, z - 0.6, 0.9, C.white)
		ball(ctx, x, 2.3, z - 0.6, 0.35, C.red)
		block(ctx, x, 1.75, z - 1.1, Vector3.new(0.25, 0.2, 0.4), C.orange)
	end
end

builders.Well = function(ctx)
	local x, z = ctx.half - 4.5, -18
	column(ctx, x, 0, z, 2.2, 4, C.stone, Enum.Material.Cobblestone)
	column(ctx, x, 1.6, z, 0.7, 3, C.water, Enum.Material.Glass)
	for _, s in { -1, 1 } do
		block(ctx, x, 2.8, z + s * 1.7, Vector3.new(0.4, 3.6, 0.4), C.darkWood, Enum.Material.Wood)
	end
	block(ctx, x, 4.8, z, Vector3.new(3.4, 0.4, 4.6), C.red, Enum.Material.WoodPlanks)
	block(ctx, x, 3.4, z, Vector3.new(0.7, 0.8, 0.7), C.wood, Enum.Material.Wood)
end

builders.AppleTrees = function(ctx)
	tree(ctx, -ctx.half + 4, ctx.half + 6, 1.1, C.red)
	tree(ctx, ctx.half - 4, ctx.half + 6, 1.1, C.red)
end

builders.Windmill = function(ctx)
	local x, z = -ctx.half - 8, ctx.half - 12
	block(ctx, x, 5, z, Vector3.new(4.5, 10, 4.5), C.white, Enum.Material.WoodPlanks)
	block(ctx, x, 10.6, z, Vector3.new(5.2, 1.2, 5.2), ctx.identity)
	-- Spinning blades: an anchored hub turned by a tween, blades welded to it
	local hub = part(ctx, {
		Name = "WindmillHub",
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = at(ctx, x, 9, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -2.9),
		Color = C.darkWood,
		CanCollide = false,
	})
	for k = 0, 3 do
		local blade = part(ctx, {
			Size = Vector3.new(1.3, 6, 0.2),
			CFrame = hub.CFrame * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 3.4, 0),
			Color = C.wood,
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
			Anchored = false,
			Massless = true,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hub
		weld.Part1 = blade
		weld.Parent = blade
	end
	-- 4 blades: a quarter turn looks identical, so a repeating quarter turn spins forever
	TweenService:Create(
		hub,
		TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ CFrame = hub.CFrame * CFrame.Angles(0, 0, math.pi / 2) }
	):Play()
end

builders.Silo = function(ctx)
	local x, z = ctx.barnHalfW + 7.5, ctx.barnZ
	column(ctx, x, 0, z, 13, 6, Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
	ball(ctx, x, 13, z, 6, ctx.identity)
	for y = 3, 11, 4 do
		column(ctx, x, y, z, 0.3, 6.2, Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	end
end

builders.Pond = function(ctx)
	local x, z = ctx.half + 9, ctx.half - 16
	part(ctx, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 11, 11),
		CFrame = at(ctx, x, 0.12, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.stone,
		Material = Enum.Material.Pebble,
	})
	part(ctx, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 9.6, 9.6),
		CFrame = at(ctx, x, 0.2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.water,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	for _, p in { { -1.5, 1 }, { 1.8, -1.2 } } do
		ball(ctx, x + p[1], 0.75, z + p[2], 1.1, C.yellow)
		ball(ctx, x + p[1], 1.35, z + p[2] - 0.45, 0.7, C.yellow)
		block(ctx, x + p[1], 1.3, z + p[2] - 0.9, Vector3.new(0.3, 0.15, 0.35), C.orange)
	end
end

builders.Cow = function(ctx)
	local x, z = ctx.half + 7, ctx.half + 4
	block(ctx, x, 2.4, z, Vector3.new(2.4, 2, 4), C.white)
	block(ctx, x + 0.5, 2.9, z + 0.6, Vector3.new(1.45, 1, 1.6), C.black)
	block(ctx, x - 0.5, 2.2, z - 1, Vector3.new(1.45, 1, 1), C.black)
	block(ctx, x, 3.1, z - 2.5, Vector3.new(1.6, 1.6, 1.4), C.white)
	block(ctx, x, 2.7, z - 3.25, Vector3.new(1.2, 0.7, 0.3), Color3.fromRGB(255, 180, 190))
	for _, l in { { -0.8, -1.4 }, { 0.8, -1.4 }, { -0.8, 1.4 }, { 0.8, 1.4 } } do
		block(ctx, x + l[1], 0.7, z + l[2], Vector3.new(0.5, 1.4, 0.5), C.white)
	end
end

builders.Greenhouse = function(ctx)
	local x, z = -(ctx.barnHalfW + 12), ctx.barnZ
	block(ctx, x, 0.2, z, Vector3.new(9, 0.4, 7), C.stone, Enum.Material.Concrete)
	local glass = part(ctx, {
		Size = Vector3.new(8.6, 4.4, 6.6),
		CFrame = at(ctx, x, 2.6, z),
		Color = C.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	glass.Name = "Greenhouse"
	for _, s in { -1, 1 } do
		part(ctx, {
			Size = Vector3.new(8.8, 0.3, 4),
			CFrame = at(ctx, x, 5.6, z + s * 1.55) * CFrame.Angles(math.rad(s * 30), 0, 0),
			Color = C.glass,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
	end
	for i = -1, 1 do
		ball(ctx, x + i * 2.6, 1.4, z, 1.8, C.leafLight, Enum.Material.Grass)
	end
end

builders.Banners = function(ctx)
	local h = ctx.half
	for _, p in { { -h, -h }, { h, -h }, { -h, h }, { h, h } } do
		column(ctx, p[1], 0, p[2], 9, 0.35, C.white, Enum.Material.Metal)
		local flag =
			block(ctx, p[1] + 1.2, 8, p[2], Vector3.new(2.4, 1.6, 0.1), ctx.identity, Enum.Material.Fabric)
		TweenService:Create(
			flag,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = flag.CFrame * CFrame.Angles(0, math.rad(12), 0) }
		):Play()
	end
end

builders.Tractor = function(ctx)
	local x, z = -(ctx.barnHalfW + 3.5), ctx.half + 4
	block(ctx, x, 2, z, Vector3.new(2.6, 1.6, 4.4), C.red)
	block(ctx, x, 3.4, z + 0.8, Vector3.new(2.4, 1.6, 1.8), C.glass, Enum.Material.Glass)
	column(ctx, x - 0.4, 2.8, z - 1.6, 1.4, 0.3, C.black, Enum.Material.Metal)
	for _, w in { { -1.5, 1.2, 2.4 }, { 1.5, 1.2, 2.4 }, { -1.5, -1.5, 1.4 }, { 1.5, -1.5, 1.4 } } do
		part(ctx, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, w[3], w[3]),
			CFrame = at(ctx, x + w[1], w[3] / 2, z + w[2]),
			Color = C.black,
		})
	end
end

builders.Fountain = function(ctx)
	local x, z = -ctx.half + 4.5, -26
	column(ctx, x, 0, z, 1.2, 6, C.stone, Enum.Material.Marble)
	column(ctx, x, 1, z, 0.3, 5.2, C.water, Enum.Material.Glass)
	column(ctx, x, 1, z, 2.6, 0.8, C.stone, Enum.Material.Marble)
	local top = ball(ctx, x, 3.8, z, 1.4, C.water, Enum.Material.Glass)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 30
	spray.Speed = NumberRange.new(5, 7)
	spray.SpreadAngle = Vector2.new(20, 20)
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = top
end

builders.GoldTrim = function(ctx)
	-- Lamp posts along the walk from the gate, warm light at dusk
	for _, s in { -1, 1 } do
		for _, z in { -ctx.half + 3, -ctx.half + 7 } do
			column(ctx, s * 5, 0, z, 4.2, 0.35, C.gold, Enum.Material.Metal)
			local lamp = ball(ctx, s * 5, 4.5, z, 0.9, Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 10
			light.Brightness = 1
			light.Color = Color3.fromRGB(255, 220, 150)
			light.Parent = lamp
		end
	end
end

builders.Rainbow = function(ctx)
	-- An arch of colored bands over the barn
	local cx, cz, baseR = 0, ctx.barnZ + ctx.barnDepth / 2 + 1, ctx.barnTop + 6
	for band, color in RAINBOW do
		local r = baseR - (band - 1) * 0.9
		local segments = 14
		for k = 0, segments - 1 do
			local a0 = math.pi * k / segments
			local a1 = math.pi * (k + 1) / segments
			local p0 = Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local mid = (p0 + p1) / 2
			local len = (p1 - p0).Magnitude + 0.1
			part(ctx, {
				Size = Vector3.new(len, 0.9, 0.6),
				CFrame = at(ctx, cx + mid.X, mid.Y, cz)
					* CFrame.Angles(0, 0, math.atan2(p1.Y - p0.Y, p1.X - p0.X)),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
	end
end

builders.GoldenCarrot = function(ctx)
	-- A giant golden carrot on the barn roof, sparkling: the max-level landmark
	local x, z = 0, ctx.barnZ
	local y0 = ctx.barnTop + 3
	local root = part(ctx, {
		Name = "GoldenCarrot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2.2, 2.2),
		CFrame = at(ctx, x, y0, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.gold,
		Material = Enum.Material.Foil,
		CanCollide = false,
	})
	ball(ctx, x, y0 + 2.9, z, 2.4, C.gold, Enum.Material.Foil)
	for k = -1, 1 do
		part(ctx, {
			Size = Vector3.new(0.5, 2.6, 0.5),
			CFrame = at(ctx, x + k * 0.6, y0 + 4.9, z) * CFrame.Angles(0, 0, math.rad(k * 20)),
			Color = C.leafLight,
			CanCollide = false,
		})
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Rate = 14
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = root
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Parent = root
end

-- The barn ---------------------------------------------------------------------
-- Grows and changes with the level (Config/FarmLevels.BarnTiers): bare wood shed -> painted
-- barn -> big barn with white trim and windows -> farmhouse with a gold roof -> golden manor
-- with towers. The first thing you see when you look at someone's farm.
local function buildBarn(ctx: Ctx, tier: FarmLevels.BarnTier)
	local k = tier.scale
	local w, h, d = 12 * k, 7 * k, 8 * k
	local z = ctx.barnZ
	local style = tier.style
	local wall = if style == "plain" then Color3.fromRGB(176, 124, 76) else ctx.identity
	if style == "golden" then
		wall = ctx.identity:Lerp(C.white, 0.15)
	end
	local roofColor = if style == "gold" or style == "golden"
		then C.gold
		elseif style == "trim" then ctx.identity:Lerp(Color3.new(0, 0, 0), 0.35)
		else C.darkWood
	local roofMat = if style == "gold" or style == "golden"
		then Enum.Material.Foil
		else Enum.Material.WoodPlanks
	local trim = if style == "golden" then C.gold else C.white

	block(ctx, 0, h / 2, z, Vector3.new(w, h, d), wall, Enum.Material.WoodPlanks).Name = "Barn"
	-- Roof: two slopes + a gable
	for _, sx in { -1, 1 } do
		part(ctx, {
			Name = "BarnRoof",
			Size = Vector3.new(w * 0.62, 0.6 * k, d + 1),
			CFrame = at(ctx, sx * w * 0.26, h + 1.6 * k, z) * CFrame.Angles(0, 0, math.rad(-sx * 38)),
			Color = roofColor,
			Material = roofMat,
		})
	end
	block(ctx, 0, h + 1.1 * k, z, Vector3.new(w * 0.42, 2.2 * k, d - 0.2), wall, Enum.Material.WoodPlanks)
	-- Door on the farm side (-Z face)
	local front = z - d / 2
	block(ctx, 0, 2.5 * k, front - 0.05, Vector3.new(4.6 * k, 5 * k, 0.2), C.white, Enum.Material.Wood)
	if style ~= "plain" then
		for _, dd in { 1, -1 } do
			part(ctx, {
				Size = Vector3.new(0.4 * k, 6.4 * k, 0.25),
				CFrame = at(ctx, 0, 2.5 * k, front - 0.2) * CFrame.Angles(0, 0, math.rad(dd * 42)),
				Color = wall:Lerp(Color3.new(0, 0, 0), 0.25),
				Material = Enum.Material.Wood,
				CanCollide = false,
			})
		end
	end
	if style == "trim" or style == "gold" or style == "golden" then
		-- White (or gold) corner trim and a trimmed roof edge
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				block(ctx, sx * (w / 2), h / 2, z + sz * (d / 2), Vector3.new(0.6 * k, h, 0.6 * k), trim)
			end
		end
		block(ctx, 0, h, front - 0.1, Vector3.new(w + 0.4, 0.5 * k, 0.4), trim)
		-- Windows either side of the door; they glow warm from the farmhouse tier up
		for _, sx in { -1, 1 } do
			local glow = style ~= "trim"
			local win = block(
				ctx,
				sx * w * 0.32,
				h * 0.6,
				front - 0.12,
				Vector3.new(2 * k, 1.8 * k, 0.2),
				if glow then Color3.fromRGB(255, 225, 140) else Color3.fromRGB(150, 210, 255),
				if glow then Enum.Material.Neon else Enum.Material.Glass
			)
			win.Name = "BarnWindow"
			block(ctx, sx * w * 0.32, h * 0.6, front - 0.16, Vector3.new(2.4 * k, 0.25 * k, 0.15), trim)
			block(ctx, sx * w * 0.32, h * 0.6, front - 0.16, Vector3.new(0.25 * k, 2.2 * k, 0.15), trim)
		end
		-- Hay-loft door in the gable
		block(ctx, 0, h + 1.1 * k, front - 0.12, Vector3.new(1.8 * k, 1.6 * k, 0.2), trim)
	end
	if style == "gold" or style == "golden" then
		-- Weathervane on the ridge
		column(ctx, 0, h + 3.2 * k, z, 2.5 * k, 0.25, C.gold, Enum.Material.Metal)
		block(ctx, 0, h + 5.3 * k, z, Vector3.new(2.2 * k, 0.6 * k, 0.15), C.gold, Enum.Material.Foil)
	end
	if style == "golden" then
		-- Two round towers with pointed tops and flags: a manor, not a barn
		for _, sx in { -1, 1 } do
			local tx = sx * (w / 2 + 2.2)
			column(ctx, tx, 0, z, h * 1.35, 4.2, C.white, Enum.Material.Marble)
			column(ctx, tx, h * 1.35, z, 0.6, 4.8, C.gold, Enum.Material.Foil)
			part(ctx, {
				Size = Vector3.new(4, 4.5, 4),
				CFrame = at(ctx, tx, h * 1.35 + 2.85, z) * CFrame.Angles(0, math.rad(45), 0),
				Color = ctx.identity,
				Material = Enum.Material.SmoothPlastic,
			}).Shape =
				Enum.PartType.Ball
			column(ctx, tx, h * 1.35 + 4.5, z, 3.5, 0.2, C.white, Enum.Material.Metal)
			block(ctx, tx + 0.9, h * 1.35 + 7.4, z, Vector3.new(1.8, 1.1, 0.1), C.gold, Enum.Material.Fabric)
		end
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 140))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.6, 0)
		sparkle.Lifetime = NumberRange.new(1, 2)
		sparkle.Rate = 18
		sparkle.Speed = NumberRange.new(0.5, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		local emitterPart = block(ctx, 0, h / 2, z, Vector3.new(w, h, d), wall)
		emitterPart.Transparency = 1
		emitterPart.CanCollide = false
		emitterPart.CanQuery = false
		sparkle.Parent = emitterPart
	end
	-- Level badge on the barn front: big, readable from the path and the plaza
	if ctx.level >= 2 then
		local badge = block(ctx, 0, h + 1.1 * k, front - 0.3, Vector3.new(w * 0.4, 1.8 * k, 0.1), wall)
		badge.Transparency = 1
		badge.CanCollide = false
		badge.CanQuery = false
		if style == "trim" or style == "gold" or style == "golden" then
			-- the loft door sits there; put the badge above the door instead
			badge.CFrame = at(ctx, 0, 5.7 * k, front - 0.3)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(260, 90)
		gui.LightInfluence = 0
		gui.MaxDistance = 400
		gui.Parent = badge
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = "LV " .. ctx.level
		l.TextColor3 = if ctx.level >= 15 then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(255, 255, 255)
		l.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
		l.TextStrokeTransparency = 0
		l.Parent = gui
	end
end

-- Glow & spectacle ---------------------------------------------------------------

builders.StringLights = function(ctx)
	-- Colored bulbs along the top fence rail all the way around
	local h = ctx.half
	local colors = {
		Color3.fromRGB(255, 90, 110),
		Color3.fromRGB(255, 210, 80),
		Color3.fromRGB(110, 220, 120),
		Color3.fromRGB(100, 180, 255),
	}
	local i = 0
	for _, side in { { -h, -h, h, -h }, { h, -h, h, h }, { h, h, -h, h }, { -h, h, -h, -h } } do
		local x0, z0, x1, z1 = side[1], side[2], side[3], side[4]
		local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
		for t = 0, len, 3 do
			local f = t / len
			local x, z = x0 + (x1 - x0) * f, z0 + (z1 - z0) * f
			-- leave the gate opening clear
			if not (z0 == -h and z1 == -h and math.abs(x) < 7) then
				i += 1
				ball(ctx, x, 3.15, z, 0.55, colors[(i % #colors) + 1], Enum.Material.Neon)
			end
		end
	end
end

builders.GlowBorder = function(ctx)
	-- A glowing strip in the farm color just inside the fence
	local h = ctx.half - 0.8
	local color = ctx.identity:Lerp(C.white, 0.35)
	for _, side in
		{ { 0, -h, h * 2, 0.6 }, { 0, h, h * 2, 0.6 }, { -h, 0, 0.6, h * 2 }, { h, 0, 0.6, h * 2 } }
	do
		local strip =
			block(ctx, side[1], 0.25, side[2], Vector3.new(side[3], 0.12, side[4]), color, Enum.Material.Neon)
		strip.CanCollide = false
		strip.CanQuery = false
	end
end

builders.SkyBeams = function(ctx)
	-- Two sweeping searchlight beams from beside the barn, visible from anywhere on the map
	for _, sx in { -1, 1 } do
		local baseX = sx * (ctx.barnHalfW + 1.5)
		local baseZ = ctx.barnZ
		block(ctx, baseX, 0.6, baseZ, Vector3.new(2, 1.2, 2), C.black, Enum.Material.Metal)
		local pivot = part(ctx, {
			Name = "BeamPivot",
			Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = at(ctx, baseX, 1.3, baseZ) * CFrame.Angles(0, 0, math.rad(sx * 14)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local beam = part(ctx, {
			Name = "SkyBeam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(160, 2.4, 2.4),
			CFrame = pivot.CFrame * CFrame.new(0, 80, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = ctx.identity:Lerp(C.white, 0.5),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanQuery = false,
			Anchored = false,
			Massless = true,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = pivot
		weld.Part1 = beam
		weld.Parent = beam
		TweenService:Create(
			pivot,
			TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = pivot.CFrame * CFrame.Angles(0, 0, math.rad(-sx * 28)) }
		):Play()
	end
end

builders.Fireworks = function(ctx)
	-- Bursts of colored sparks over the barn, all the time
	for _, sx in { -1, 1 } do
		local p = part(ctx, {
			Name = "Fireworks",
			Size = Vector3.new(1, 1, 1),
			CFrame = at(ctx, sx * 8, ctx.barnTop + 22, ctx.barnZ),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
		})
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Speed = NumberRange.new(16, 22)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 2.5
		e.Acceleration = Vector3.new(0, -6, 0)
		e.Rate = 0
		e.Parent = p
		-- a burst every couple of seconds (server loop, stops when the decor is rebuilt)
		task.spawn(function()
			while p.Parent and p:IsDescendantOf(game) do
				e:Emit(70)
				task.wait(2.2 + sx * 0.4)
			end
		end)
	end
end

-- Looks that change rather than add (applied every time, so a level-down restores them)
local FENCE_PLAIN = Color3.fromRGB(176, 124, 76)
local FENCE_WHITE = Color3.fromRGB(246, 238, 222)

local function has(level: number, id: string): boolean
	for _, u in FarmLevels.unlocked(level) do
		if u.id == id then
			return true
		end
	end
	return false
end

-- A burst of confetti and sparkles over the farm when it levels up.
function FarmDecor.celebrate(center: CFrame)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = center * CFrame.new(0, 14, 0)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 100)),
	})
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.8, 0.2)
	e.Lifetime = NumberRange.new(2, 3)
	e.Speed = NumberRange.new(25, 40)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -20, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	e:Emit(250)
	Debris:AddItem(p, 4)
end

-- Rebuild the farm's decor for `level` (0 or 1 = a plain fresh farm).
function FarmDecor.apply(model: Model, center: CFrame, half: number, level: number)
	local old = model:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	local barn = model:FindFirstChild("BarnBody")
	local tier = FarmLevels.barnTier(level)
	local k = tier.scale
	local depth = 8 * k
	local ctx: Ctx = {
		center = center,
		half = half,
		folder = folder,
		identity = if barn and barn:IsA("BasePart") then barn.Color else C.red,
		level = math.max(1, level),
		barnZ = half + 4 + depth / 2,
		barnHalfW = 6 * k,
		barnDepth = depth,
		barnH = 7 * k,
		barnTop = 7 * k + 3.4 * k,
	}
	-- The built-in barn from WorldBuilder is replaced by the level barn
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 4) == "Barn" then
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
		end
	end
	buildBarn(ctx, tier)
	for _, u in FarmLevels.unlocked(level) do
		local build = builders[u.id]
		if build then
			build(ctx)
		end
	end
	folder.Parent = model

	local fence = if has(level, "WhiteFence") then FENCE_WHITE else FENCE_PLAIN
	local gold = has(level, "GoldTrim")
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "FenceRail" or child.Name == "FencePost" then
				child.Color = fence
			elseif child.Name == "GatePostCap" then
				child.Color = if gold then C.gold else ctx.identity
				child.Material = if gold then Enum.Material.Foil else Enum.Material.Wood
			end
		end
	end
	model:SetAttribute("FarmLevel", math.max(1, level))
end

return FarmDecor
