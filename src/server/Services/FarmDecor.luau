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
	wallTop: number, -- top of the farm's border (fence 3, stone wall 4.5, castle wall 8.4)
	unlockId: string?, -- the unlock currently being built (tags parts for the rise-in show)
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
	if ctx.unlockId then
		p:SetAttribute("Unlock", ctx.unlockId)
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

local function windmill(ctx: Ctx, x: number, z: number, s: number)
	block(ctx, x, 5 * s, z, Vector3.new(4.5, 10, 4.5) * s, C.white, Enum.Material.WoodPlanks)
	block(ctx, x, 10.6 * s, z, Vector3.new(5.2, 1.2, 5.2) * s, ctx.identity)
	if s > 1.5 then
		-- the giant one gets a pointed cap, a door and a balcony
		for k = 0, 2 do
			column(ctx, x, (11.2 + k * 1.4) * s, z, 1.4 * s, (5 - k * 1.5) * s, ctx.identity)
		end
		block(ctx, x - 2.3 * s, 2 * s, z, Vector3.new(0.2, 4, 2.2) * s, C.darkWood, Enum.Material.Wood)
		block(ctx, x, 7 * s, z, Vector3.new(6, 0.4, 6) * s, C.darkWood, Enum.Material.WoodPlanks)
	end
	-- Spinning blades: an anchored hub turned by a tween, blades welded to it
	local hub = part(ctx, {
		Name = "WindmillHub",
		Size = Vector3.new(1.2, 1.2, 1.2) * s,
		CFrame = at(ctx, x, 9 * s, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -2.9 * s),
		Color = C.darkWood,
		CanCollide = false,
	})
	for k = 0, 3 do
		local blade = part(ctx, {
			Size = Vector3.new(1.3, 6, 0.2) * s,
			CFrame = hub.CFrame * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 3.4 * s, 0),
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
		TweenInfo.new(2.5 * s, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ CFrame = hub.CFrame * CFrame.Angles(0, 0, math.pi / 2) }
	):Play()
end

builders.Windmill = function(ctx)
	if ctx.level >= 22 then
		return -- replaced by the giant windmill
	end
	windmill(ctx, -ctx.half - 8, ctx.half - 12, 1)
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
	if ctx.level >= 26 then
		return -- the castle towers carry the flags now
	end
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
				ball(ctx, x, ctx.wallTop + 0.15, z, 0.55, colors[(i % #colors) + 1], Enum.Material.Neon)
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
		local baseX = sx * math.max(4, ctx.barnHalfW - 2)
		local baseZ = ctx.barnZ - ctx.barnDepth / 2 - 3
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

-- LEVELS 21-40 -------------------------------------------------------------------------

local STONE = Color3.fromRGB(196, 190, 180)
local STONE_DARK = Color3.fromRGB(150, 144, 136)
local NEON_CYAN = Color3.fromRGB(90, 230, 255)
local NEON_PINK = Color3.fromRGB(255, 110, 210)
local COSMIC = Color3.fromRGB(70, 45, 130)

-- A cone roof made of stacked cylinders (bottom at y).
local function cone(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	d: number,
	h: number,
	color: Color3,
	mat: Enum.Material?
)
	local steps = 5
	for k = 0, steps - 1 do
		column(ctx, x, y + k * h / steps, z, h / steps + 0.05, d * (1 - k / steps) + 0.2, color, mat)
	end
	ball(ctx, x, y + h + 0.3, z, d * 0.15 + 0.4, C.gold, Enum.Material.Foil)
end

-- A round tower with an optional cone roof and flag.
local function tower(
	ctx: Ctx,
	x: number,
	z: number,
	d: number,
	h: number,
	wall: Color3,
	roof: Color3?,
	mat: Enum.Material?
)
	column(ctx, x, 0, z, h, d, wall, mat or Enum.Material.Cobblestone)
	-- battlement ring
	for k = 0, 7 do
		local a = k * math.pi / 4
		block(
			ctx,
			x + math.cos(a) * (d / 2 - 0.4),
			h + 0.6,
			z + math.sin(a) * (d / 2 - 0.4),
			Vector3.new(1, 1.2, 1),
			wall,
			mat or Enum.Material.Cobblestone
		)
	end
	if roof then
		cone(ctx, x, h, z, d + 0.6, d * 1.1, roof)
		column(ctx, x, h + d * 1.1 + 0.6, z, 4, 0.2, C.white, Enum.Material.Metal)
		block(
			ctx,
			x + 0.9,
			h + d * 1.1 + 3.8,
			z,
			Vector3.new(1.8, 1.1, 0.1),
			ctx.identity,
			Enum.Material.Fabric
		)
	end
end

-- The big buildings for levels 25+: Estate Manor, Carrot Castle, Sky Palace, Cosmic Palace.
local function buildPalace(ctx: Ctx, tier: FarmLevels.BarnTier)
	local k = tier.scale
	local w, h, d = 12 * k, 7 * k, 8 * k
	local z = ctx.barnZ
	local front = z - d / 2
	local style = tier.style
	local wall: Color3, wallMat: Enum.Material, roof: Color3, trim: Color3, roofMat: Enum.Material, windowColor: Color3
	if style == "estate" then
		wall, wallMat = Color3.fromRGB(235, 225, 205), Enum.Material.Brick
		roof, roofMat, trim, windowColor =
			Color3.fromRGB(70, 80, 110), Enum.Material.Slate, C.gold, Color3.fromRGB(255, 225, 140)
	elseif style == "castle" then
		wall, wallMat = STONE, Enum.Material.Cobblestone
		roof, roofMat, trim, windowColor =
			ctx.identity, Enum.Material.SmoothPlastic, C.gold, Color3.fromRGB(255, 200, 110)
	elseif style == "sky" then
		wall, wallMat = Color3.fromRGB(250, 248, 255), Enum.Material.Marble
		roof, roofMat, trim, windowColor = C.gold, Enum.Material.Foil, C.gold, Color3.fromRGB(180, 230, 255)
	else -- cosmic
		wall, wallMat = COSMIC, Enum.Material.SmoothPlastic
		roof, roofMat, trim, windowColor = NEON_PINK, Enum.Material.Neon, NEON_CYAN, NEON_CYAN
	end
	-- main hall
	block(ctx, 0, h / 2, z, Vector3.new(w, h, d), wall, wallMat).Name = "Barn"
	block(
		ctx,
		0,
		h + 0.3,
		z,
		Vector3.new(w + 0.8, 0.6, d + 0.8),
		trim,
		if trim == NEON_CYAN then Enum.Material.Neon else Enum.Material.Metal
	)
	-- side wings
	for _, sx in { -1, 1 } do
		block(
			ctx,
			sx * (w / 2 + w * 0.18),
			h * 0.35,
			z + d * 0.1,
			Vector3.new(w * 0.36, h * 0.7, d * 0.8),
			wall,
			wallMat
		)
	end
	-- roof: a big central dome/cone (castle: battlements instead)
	if style == "castle" then
		for i = -5, 5 do
			block(ctx, i * w / 11, h + 1.4, front + 0.5, Vector3.new(w / 22, 2, 1), wall, wallMat)
			block(ctx, i * w / 11, h + 1.4, front + d - 0.5, Vector3.new(w / 22, 2, 1), wall, wallMat)
		end
		tower(ctx, 0, z + d * 0.2, w * 0.3, h * 1.7, wall, roof)
	else
		column(ctx, 0, h, z, h * 0.35, w * 0.45, wall, wallMat)
		ball(ctx, 0, h * 1.35, z, w * 0.48, roof, roofMat)
		column(ctx, 0, h * 1.6, z, h * 0.5, 0.5, trim, Enum.Material.Metal)
		ball(
			ctx,
			0,
			h * 2.15,
			z,
			1.6,
			trim,
			if trim == NEON_CYAN then Enum.Material.Neon else Enum.Material.Foil
		)
	end
	-- corner towers
	for _, sx in { -1, 1 } do
		local tx = sx * (w / 2 + w * 0.36 + 1.5)
		if style == "castle" then
			tower(ctx, tx, z, 6, h * 1.5, wall, roof)
		else
			column(ctx, tx, 0, z, h * 1.3, 5, wall, wallMat)
			ball(ctx, tx, h * 1.3 + 1.6, z, 5.6, roof, roofMat)
			column(ctx, tx, h * 1.3 + 4.3, z, 3, 0.25, trim, Enum.Material.Metal)
		end
	end
	-- grand door and glowing windows
	block(
		ctx,
		0,
		3 * k,
		front - 0.1,
		Vector3.new(5 * k, 6 * k, 0.3),
		trim,
		if trim == NEON_CYAN then Enum.Material.Neon else Enum.Material.Metal
	)
	block(
		ctx,
		0,
		3 * k,
		front - 0.2,
		Vector3.new(4.2 * k, 5.4 * k, 0.3),
		Color3.fromRGB(110, 70, 40),
		Enum.Material.Wood
	)
	for _, sx in { -1, 1 } do
		for row = 0, 1 do
			block(
				ctx,
				sx * w * 0.3,
				h * (0.35 + row * 0.35),
				front - 0.15,
				Vector3.new(2.2, 2.6, 0.2) * k * 0.7,
				windowColor,
				Enum.Material.Neon
			)
		end
	end
	-- front steps
	for i = 0, 2 do
		block(
			ctx,
			0,
			0.3 + i * 0.6,
			front - 1.5 - (2 - i) * 1.2,
			Vector3.new(8 * k - i * 1.5, 0.6, 1.2),
			STONE_DARK,
			Enum.Material.Concrete
		)
	end
	if style == "sky" then
		-- clouds hugging the base
		for i = 0, 9 do
			local a = i * math.pi / 5
			ball(
				ctx,
				math.cos(a) * w * 0.7,
				1.5,
				z + math.sin(a) * d * 0.7,
				5 + (i % 3),
				Color3.fromRGB(255, 255, 255)
			)
		end
	end
	if style == "cosmic" then
		local emitter = block(ctx, 0, h, z, Vector3.new(w, 1, d), wall)
		emitter.Transparency = 1
		emitter.CanCollide = false
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(NEON_CYAN, NEON_PINK)
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.6, 0)
		e.Lifetime = NumberRange.new(2, 3)
		e.Rate = 25
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = emitter
	end
	-- level badge over the door
	local badge = block(ctx, 0, 7 * k, front - 0.35, Vector3.new(w * 0.4, 1.8 * k, 0.1), wall)
	badge.Transparency = 1
	badge.CanCollide = false
	badge.CanQuery = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(260, 90)
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	gui.Parent = badge
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = "LV " .. ctx.level
	l.TextColor3 = if style == "cosmic" then NEON_CYAN else Color3.fromRGB(255, 215, 80)
	l.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
	l.TextStrokeTransparency = 0
	l.Parent = gui
end

-- A wall along the farm border (gap at the gate), height hgt, with optional battlements.
local function borderWall(
	ctx: Ctx,
	hgt: number,
	thick: number,
	color: Color3,
	mat: Enum.Material,
	merlons: boolean,
	gateGap: number
)
	local h = ctx.half
	local function segment(x0: number, z0: number, x1: number, z1: number)
		local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
		if len < 0.5 then
			return
		end
		local horizontal = math.abs(x1 - x0) > math.abs(z1 - z0)
		local size = if horizontal then Vector3.new(len, hgt, thick) else Vector3.new(thick, hgt, len)
		block(ctx, (x0 + x1) / 2, hgt / 2, (z0 + z1) / 2, size, color, mat)
		local capSize = if horizontal
			then Vector3.new(len + 0.4, 0.5, thick + 0.4)
			else Vector3.new(thick + 0.4, 0.5, len + 0.4)
		block(ctx, (x0 + x1) / 2, hgt + 0.25, (z0 + z1) / 2, capSize, STONE_DARK, mat)
		if merlons then
			local n = math.floor(len / 3)
			for i = 0, n - 1 do
				local f = (i + 0.5) / n
				local mx, mz = x0 + (x1 - x0) * f, z0 + (z1 - z0) * f
				block(ctx, mx, hgt + 1.2, mz, Vector3.new(1.4, 1.4, 1.4), color, mat)
			end
		end
	end
	segment(-h, h, h, h)
	segment(-h, -h, -h, h)
	segment(h, -h, h, h)
	segment(-h, -h, -gateGap, -h)
	segment(gateGap, -h, h, -h)
	-- corner pillars
	for _, p in { { -h, -h }, { h, -h }, { -h, h }, { h, h } } do
		block(ctx, p[1], (hgt + 1) / 2, p[2], Vector3.new(thick + 1.2, hgt + 1, thick + 1.2), STONE_DARK, mat)
	end
end

builders.StoneWall = function(ctx)
	if ctx.level >= 26 then
		return -- the castle walls replace it
	end
	borderWall(ctx, 4, 1.6, STONE, Enum.Material.Cobblestone, false, 6)
end

builders.GiantWindmill = function(ctx)
	windmill(ctx, -ctx.half - 14, ctx.half - 8, 2)
end

builders.Orchard = function(ctx)
	local fruits = {
		Color3.fromRGB(255, 160, 120),
		Color3.fromRGB(255, 140, 40),
		Color3.fromRGB(220, 40, 70),
		Color3.fromRGB(255, 220, 70),
	}
	local i = 0
	for _, sx in { -1, 1 } do
		for _, off in { 11, 19 } do
			for _, z in { -30, -15, 0, 15 } do
				i += 1
				tree(ctx, sx * (ctx.half + off), z, 1.15, fruits[(i % #fruits) + 1])
			end
		end
	end
end

-- a blocky horse
local function horse(ctx: Ctx, x: number, z: number, color: Color3, yaw: number)
	local base = at(ctx, x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function piece(size: Vector3, offset: Vector3, c: Color3)
		part(ctx, { Size = size, CFrame = base * CFrame.new(offset), Color = c })
	end
	piece(Vector3.new(1.8, 1.8, 4), Vector3.new(0, 3, 0), color)
	piece(Vector3.new(1, 2.2, 1.2), Vector3.new(0, 4.3, -1.8), color)
	piece(Vector3.new(1, 1, 2), Vector3.new(0, 5, -2.6), color)
	piece(Vector3.new(0.3, 2.2, 1), Vector3.new(0, 4.6, -1.4), C.darkWood) -- mane
	for _, l in { { -0.6, -1.5 }, { 0.6, -1.5 }, { -0.6, 1.5 }, { 0.6, 1.5 } } do
		piece(Vector3.new(0.5, 2.2, 0.5), Vector3.new(l[1], 1.1, l[2]), color)
	end
	piece(Vector3.new(0.3, 1.8, 0.3), Vector3.new(0, 2.8, 2.1), C.darkWood) -- tail
end

builders.Stable = function(ctx)
	local x, z = ctx.half + 20, ctx.half + 12
	block(ctx, x, 3.5, z + 2, Vector3.new(14, 7, 6), C.wood, Enum.Material.WoodPlanks)
	for _, sz in { -1, 1 } do
		part(ctx, {
			Size = Vector3.new(15, 0.5, 4.6),
			CFrame = at(ctx, x, 7.6, z + 2 + sz * 1.6) * CFrame.Angles(math.rad(sz * 28), 0, 0),
			Color = ctx.identity,
		})
	end
	for k = -1, 1 do
		block(ctx, x + k * 4.5, 2.5, z - 1.1, Vector3.new(3.6, 4, 0.3), C.darkWood, Enum.Material.Wood)
	end
	-- paddock fence and two horses
	local px, pz = x, z - 10
	for _, side in { { 0, -6, 16, 0.3 }, { -8, 0, 0.3, 12 }, { 8, 0, 0.3, 12 } } do
		block(ctx, px + side[1], 1.4, pz + side[2], Vector3.new(side[3], 0.4, side[4]), C.white)
		block(ctx, px + side[1], 0.7, pz + side[2], Vector3.new(side[3], 0.4, side[4]), C.white)
	end
	horse(ctx, px - 3, pz, Color3.fromRGB(150, 95, 55), 0.4)
	horse(ctx, px + 3, pz + 1, Color3.fromRGB(245, 240, 230), -0.6)
end

builders.EstateArch = function(ctx)
	local z = -ctx.half - 8
	for _, sx in { -1, 1 } do
		block(ctx, sx * 8.5, 8, z, Vector3.new(2.6, 16, 2.6), STONE, Enum.Material.Marble)
		block(ctx, sx * 8.5, 16.4, z, Vector3.new(3.4, 0.8, 3.4), C.gold, Enum.Material.Foil)
		-- a stone bunny on each pillar
		ball(ctx, sx * 8.5, 18, z, 2.4, STONE, Enum.Material.Marble)
		ball(ctx, sx * 8.5, 19.6, z - 0.3, 1.8, STONE, Enum.Material.Marble)
		for _, ex in { -0.35, 0.35 } do
			part(ctx, {
				Size = Vector3.new(0.4, 1.8, 0.3),
				CFrame = at(ctx, sx * 8.5 + ex, 21, z - 0.3),
				Color = STONE,
				Material = Enum.Material.Marble,
			})
		end
	end
	block(ctx, 0, 15, z, Vector3.new(20, 2, 2), STONE, Enum.Material.Marble)
	block(ctx, 0, 16.4, z, Vector3.new(21, 0.6, 2.4), C.gold, Enum.Material.Foil)
	ball(ctx, 0, 17.6, z, 2.6, C.orange) -- a carrot emblem
	block(ctx, 0, 19.2, z, Vector3.new(0.5, 1.6, 0.5), C.leaf)
end

builders.CastleWalls = function(ctx)
	borderWall(ctx, 7, 2.2, STONE, Enum.Material.Cobblestone, true, 9.5)
	local h = ctx.half
	for _, p in { { -h, -h }, { h, -h }, { -h, h }, { h, h } } do
		tower(ctx, p[1], p[2], 8, 16, STONE, ctx.identity)
	end
	-- gatehouse towers flanking the entrance
	for _, sx in { -1, 1 } do
		tower(ctx, sx * 7.3, -h, 4.4, 12, STONE, ctx.identity)
	end
end

builders.Moat = function(ctx)
	local h = ctx.half
	local wcol = Color3.fromRGB(70, 150, 220)
	local function water(x: number, z: number, sx: number, sz: number)
		block(ctx, x, 0.12, z, Vector3.new(sx + 1, 0.2, sz + 1), STONE_DARK, Enum.Material.Slate).CanCollide =
			false
		local p = block(ctx, x, 0.2, z, Vector3.new(sx, 0.2, sz), wcol, Enum.Material.Glass)
		p.Transparency = 0.15
		p.CanCollide = false
	end
	local r = h + 5
	water(0, r, 2 * r + 5, 5) -- back
	water(-r, 2.5, 5, 2 * r) -- sides
	water(r, 2.5, 5, 2 * r)
	-- front, leaving the gate area (boards, pad, launcher) dry
	local fx = (r + 22) / 2
	water(-fx, -r, r - 22 + 5, 5)
	water(fx, -r, r - 22 + 5, 5)
end

builders.Knights = function(ctx)
	local h = ctx.half
	for _, sx in { -1, 1 } do
		local x, z = sx * 4.4, -h + 2.6
		block(ctx, x, 1.5, z, Vector3.new(1.6, 3, 1.2), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		block(ctx, x, 3.6, z, Vector3.new(2.2, 1.6, 1.4), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		ball(ctx, x, 5, z, 1.6, Color3.fromRGB(210, 215, 225), Enum.Material.Metal)
		block(ctx, x, 5, z - 0.75, Vector3.new(1, 0.2, 0.1), C.black)
		block(ctx, x, 6.2, z, Vector3.new(0.3, 1.2, 1.2), C.red, Enum.Material.Fabric) -- plume
		block(ctx, x + sx * 1.3, 4.5, z - 0.2, Vector3.new(0.25, 9, 0.25), C.darkWood, Enum.Material.Wood) -- spear
		block(
			ctx,
			x + sx * 1.3,
			9.2,
			z - 0.2,
			Vector3.new(0.6, 0.9, 0.2),
			Color3.fromRGB(200, 205, 215),
			Enum.Material.Metal
		)
		block(ctx, x - sx * 1.2, 3.4, z - 0.4, Vector3.new(0.3, 2.4, 1.8), ctx.identity) -- shield
	end
	-- royal banners hanging on the front wall
	for _, x in { -36, -20, 20, 36 } do
		block(ctx, x, 4, -h - 1.2, Vector3.new(3.4, 6, 0.15), ctx.identity, Enum.Material.Fabric)
		block(ctx, x, 4.4, -h - 1.3, Vector3.new(1.4, 1.4, 0.1), C.gold, Enum.Material.Foil)
	end
end

builders.Topiary = function(ctx)
	local z = -ctx.half - 13
	for _, x in { -40, -28, 28, 40 } do
		column(ctx, x, 0, z, 1.4, 4.5, Color3.fromRGB(205, 120, 80), Enum.Material.Brick)
		ball(ctx, x, 3.4, z, 4, C.leaf, Enum.Material.Grass)
		ball(ctx, x, 6.2, z - 0.5, 2.8, C.leaf, Enum.Material.Grass)
		for _, ex in { -0.6, 0.6 } do
			part(ctx, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 3.4, 0.7),
				CFrame = at(ctx, x + ex, 8.6, z - 0.5),
				Color = C.leafLight,
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end
end

builders.FloatingCrown = function(ctx)
	local y = ctx.barnTop + 20
	local hub = part(ctx, {
		Name = "CrownHub",
		Size = Vector3.new(1, 1, 1),
		CFrame = at(ctx, 0, y, ctx.barnZ),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local function weld(p: BasePart)
		p.Anchored = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = p
		w.Parent = p
	end
	for k = 0, 15 do
		local a = k * math.pi / 8
		local seg = part(ctx, {
			Size = Vector3.new(2.6, 2.4, 0.8),
			CFrame = hub.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 6),
			Color = C.gold,
			Material = Enum.Material.Foil,
			CanCollide = false,
		})
		weld(seg)
		if k % 2 == 0 then
			local spike = part(ctx, {
				Size = Vector3.new(1, 3, 0.6),
				CFrame = hub.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.6, 6),
				Color = C.gold,
				Material = Enum.Material.Foil,
				CanCollide = false,
			})
			weld(spike)
			local jewel = part(ctx, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.1,
				CFrame = hub.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 4.4, 6),
				Color = if k % 4 == 0 then C.red else Color3.fromRGB(80, 160, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			weld(jewel)
		end
	end
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 215, 120)
	light.Parent = hub
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.8, 0)
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 20
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = hub
	-- 16 segments: an eighth of a turn repeats seamlessly
	TweenService:Create(hub, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		CFrame = hub.CFrame * CFrame.Angles(0, math.pi / 4, 0),
	}):Play()
end

-- A floating island: grass top, rocky cone underneath, a couple of trees.
local function skyIsland(ctx: Ctx, x: number, y: number, z: number, d: number)
	column(ctx, x, y, z, 2, d, Color3.fromRGB(110, 190, 75), Enum.Material.Grass)
	for k = 1, 5 do
		local dd = d * (1 - k * 0.18)
		column(
			ctx,
			x,
			y - k * 2.2,
			z,
			2.3,
			dd,
			if k % 2 == 0 then STONE_DARK else Color3.fromRGB(150, 110, 75),
			Enum.Material.Slate
		)
	end
	tree(ctx, x - d * 0.2, z + d * 0.1, 0.9, nil)
	tree(ctx, x + d * 0.22, z - d * 0.15, 0.7, C.red)
	-- the trees were built at ground level: lift them onto the island
	for _, p in ctx.folder:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Unlock") == ctx.unlockId and p.Position.Y < y - 12 then
			local localPos = ctx.center:PointToObjectSpace(p.Position)
			if math.abs(localPos.X - x) < d and math.abs(localPos.Z - z) < d then
				p.CFrame = p.CFrame + Vector3.new(0, y + 2, 0)
			end
		end
	end
end

builders.SkyIslands = function(ctx)
	local h = ctx.half
	skyIsland(ctx, -(h + 22), 48, -5, 18)
	skyIsland(ctx, h + 24, 56, 10, 14)
end

builders.SkyWaterfall = function(ctx)
	local h = ctx.half
	local x, z = -(h + 22) - 7, -5
	local fall =
		block(ctx, x, 25, z, Vector3.new(0.6, 46, 5), Color3.fromRGB(110, 190, 245), Enum.Material.Glass)
	fall.Transparency = 0.3
	fall.CanCollide = false
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	e.Transparency = NumberSequence.new(0.3, 0.9)
	e.Size = NumberSequence.new(1.4, 2.4)
	e.Lifetime = NumberRange.new(2, 3)
	e.Rate = 30
	e.Speed = NumberRange.new(18, 22)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Parent = fall
	local pool = column(ctx, x, 0.05, z, 0.3, 12, Color3.fromRGB(90, 175, 235), Enum.Material.Glass)
	pool.Transparency = 0.2
	pool.CanCollide = false
	local mist = block(ctx, x, 1, z, Vector3.new(6, 1, 6), C.white)
	mist.Transparency = 1
	mist.CanCollide = false
	local m = Instance.new("ParticleEmitter")
	m.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	m.Transparency = NumberSequence.new(0.4, 1)
	m.Size = NumberSequence.new(2, 5)
	m.Lifetime = NumberRange.new(1.5, 2.5)
	m.Rate = 12
	m.Speed = NumberRange.new(2, 4)
	m.SpreadAngle = Vector2.new(60, 60)
	m.EmissionDirection = Enum.NormalId.Top
	m.Parent = mist
end

local function balloon(ctx: Ctx, x: number, y: number, z: number, colors: { Color3 })
	local hub = part(ctx, {
		Name = "BalloonHub",
		Size = Vector3.one,
		CFrame = at(ctx, x, y, z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local pieces = {}
	-- envelope: three stacked balls in stripes
	table.insert(
		pieces,
		part(ctx, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 11,
			CFrame = hub.CFrame,
			Color = colors[1],
			CanCollide = false,
		})
	)
	table.insert(
		pieces,
		part(ctx, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 10.6,
			CFrame = hub.CFrame * CFrame.new(0, -0.6, 0),
			Color = colors[2],
			CanCollide = false,
		})
	)
	table.insert(
		pieces,
		part(ctx, {
			Size = Vector3.new(2.6, 2, 2.6),
			CFrame = hub.CFrame * CFrame.new(0, -9.5, 0),
			Color = C.wood,
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
		})
	)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		table.insert(
			pieces,
			part(ctx, {
				Size = Vector3.new(0.12, 5, 0.12),
				CFrame = hub.CFrame * CFrame.new(c[1] * 1.2, -6.5, c[2] * 1.2),
				Color = C.darkWood,
				CanCollide = false,
			})
		)
	end
	for _, p in pieces do
		p.Anchored = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = p
		w.Parent = p
	end
	TweenService:Create(
		hub,
		TweenInfo.new(3 + math.random(), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			CFrame = hub.CFrame + Vector3.new(0, 3, 0),
		}
	):Play()
end

builders.Balloons = function(ctx)
	local h = ctx.half
	balloon(ctx, -(h + 8), 40, h - 10, { Color3.fromRGB(235, 80, 90), Color3.fromRGB(255, 220, 60) })
	balloon(ctx, h + 10, 46, -h + 6, { Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 255, 255) })
	balloon(ctx, 0, 52, -h - 30, { Color3.fromRGB(175, 120, 255), Color3.fromRGB(120, 220, 110) })
end

builders.RainbowBridge = function(ctx)
	-- an arc of rainbow bands from the ground up onto the big sky island
	local h = ctx.half
	local from = Vector3.new(-(h + 8), 0, -30)
	local to = Vector3.new(-(h + 22), 49, -5)
	local segments = 16
	local sideDir = Vector3.new(-(to.Z - from.Z), 0, to.X - from.X).Unit
	for band, color in RAINBOW do
		local off = sideDir * (band - 3.5) * 0.9
		for k = 0, segments - 1 do
			local function point(t: number): Vector3
				local p = from:Lerp(to, t)
				return p + Vector3.new(0, math.sin(t * math.pi) * 14, 0) + off
			end
			local a, b = point(k / segments), point((k + 1) / segments)
			local mid = (a + b) / 2
			part(ctx, {
				Size = Vector3.new(0.9, 0.4, (b - a).Magnitude + 0.1),
				CFrame = ctx.center * CFrame.lookAt(mid, b),
				Color = color,
				CanCollide = band == 3 or band == 4, -- you can walk up the middle!
			})
		end
	end
end

builders.CloudCastle = function(ctx)
	local cx, cy, cz = 0, 88, ctx.barnZ + 30
	for i = 0, 13 do
		local a = i * math.pi / 7
		local r = 10 + (i % 3) * 3
		ball(
			ctx,
			cx + math.cos(a) * r,
			cy - 2 + (i % 2),
			cz + math.sin(a) * r * 0.7,
			10 + (i % 4) * 2,
			Color3.fromRGB(255, 255, 255)
		)
	end
	ball(ctx, cx, cy, cz, 22, Color3.fromRGB(250, 252, 255))
	-- the castle
	block(ctx, cx, cy + 10, cz, Vector3.new(16, 10, 10), Color3.fromRGB(250, 248, 255), Enum.Material.Marble)
	ball(ctx, cx, cy + 17, cz, 9, C.gold, Enum.Material.Foil)
	for _, sx in { -1, 1 } do
		column(ctx, cx + sx * 9, cy + 5, cz, 16, 4, Color3.fromRGB(250, 248, 255), Enum.Material.Marble)
		ball(ctx, cx + sx * 9, cy + 22, cz, 5, C.gold, Enum.Material.Foil)
	end
	local glow = block(
		ctx,
		cx,
		cy + 10,
		cz - 5.1,
		Vector3.new(4, 5, 0.2),
		Color3.fromRGB(255, 235, 170),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Parent = glow
end

builders.Crystals = function(ctx)
	local h = ctx.half
	local colors = { NEON_CYAN, NEON_PINK, Color3.fromRGB(180, 120, 255) }
	for i, x in { -42, -30, -18, 18, 30, 42 } do
		local z = -h - 22
		local color = colors[(i % #colors) + 1]
		for k = 0, 3 do
			local hgt = 3 + (k * 7 + i * 3) % 5
			part(ctx, {
				Size = Vector3.new(1.2, hgt, 1.2),
				CFrame = at(ctx, x + (k - 1.5) * 1.1, hgt / 2, z + (k % 2) * 0.9)
					* CFrame.Angles(0.2 * (k - 1.5), 0, 0.25 * (k - 1.5)),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
			})
		end
		local glow = block(ctx, x, 1, z, Vector3.one, color)
		glow.Transparency = 1
		local l = Instance.new("PointLight")
		l.Range = 14
		l.Brightness = 1.6
		l.Color = color
		l.Parent = glow
	end
end

builders.Aurora = function(ctx)
	local colors = { Color3.fromRGB(90, 255, 170), NEON_CYAN, NEON_PINK }
	for band = 1, 3 do
		for k = 0, 17 do
			local x = -68 + k * 8
			local y = 70 + band * 9 + math.sin(k * 0.6 + band) * 4
			local z = -20 + band * 18 + math.sin(k * 0.4) * 8
			local p = part(ctx, {
				Size = Vector3.new(8.4, 10, 0.4),
				CFrame = at(ctx, x, y, z) * CFrame.Angles(0, 0, math.sin(k * 0.7) * 0.25),
				Color = colors[band],
				Material = Enum.Material.Neon,
				Transparency = 0.7,
				CanCollide = false,
				CanQuery = false,
			})
			TweenService:Create(
				p,
				TweenInfo.new(2.5 + band * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{
					CFrame = p.CFrame * CFrame.new(0, 2.5, 0),
					Transparency = 0.82,
				}
			):Play()
		end
	end
end

builders.GoldenBunny = function(ctx)
	local x, z = -(ctx.barnHalfW + 30), ctx.barnZ + 4
	local gold = C.gold
	block(ctx, x, 1.5, z, Vector3.new(14, 3, 14), STONE, Enum.Material.Marble)
	ball(ctx, x, 11, z, 15, gold, Enum.Material.Foil)
	ball(ctx, x, 24, z - 1.5, 11, gold, Enum.Material.Foil)
	for _, sx in { -1, 1 } do
		part(ctx, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 15, 2.2),
			CFrame = at(ctx, x + sx * 2.6, 35, z - 1) * CFrame.Angles(0, 0, -sx * 0.12),
			Color = gold,
			Material = Enum.Material.Foil,
			CanCollide = false,
		})
		ball(ctx, x + sx * 2.3, 25, z - 6.6, 1.6, C.black)
		ball(ctx, x + sx * 3.5, 4, z - 4.5, 4, gold, Enum.Material.Foil) -- feet
	end
	ball(ctx, x, 23, z - 7, 1.4, Color3.fromRGB(255, 150, 170))
	local glow = block(ctx, x, 20, z, Vector3.one, gold)
	glow.Transparency = 1
	glow.CanCollide = false
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(1, 0)
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 20
	sparkle.Speed = NumberRange.new(3, 6)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = glow
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 215, 120)
	light.Parent = glow
end

builders.Planets = function(ctx)
	local cx, cy, cz = 0, 115, 0
	local defs = {
		{ r = 30, d = 8, color = Color3.fromRGB(255, 140, 80), speed = 0.25, ring = false },
		{ r = 46, d = 12, color = Color3.fromRGB(120, 170, 255), speed = 0.15, ring = true },
		{ r = 62, d = 6, color = Color3.fromRGB(190, 120, 255), speed = 0.35, ring = false },
	}
	local sun = ball(ctx, cx, cy, cz, 10, Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Parent = sun
	local planets: { { body: Part, ring: Part?, r: number, speed: number, phase: number } } = {}
	for i, def in defs do
		local body = ball(ctx, cx + def.r, cy, cz, def.d, def.color)
		local ring: Part? = nil
		if def.ring then
			ring = part(ctx, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, def.d * 2, def.d * 2),
				CFrame = body.CFrame,
				Color = Color3.fromRGB(230, 210, 160),
				Transparency = 0.2,
				CanCollide = false,
				CanQuery = false,
			})
		end
		table.insert(planets, { body = body, ring = ring, r = def.r, speed = def.speed, phase = i * 2.1 })
	end
	-- orbit (server loop at 10 Hz; stops when the decor is rebuilt)
	local center = at(ctx, cx, cy, cz)
	task.spawn(function()
		local t = 0
		while sun.Parent and sun:IsDescendantOf(game) do
			t += 0.1
			for _, p in planets do
				local a = p.phase + t * p.speed
				local cf = center * CFrame.new(math.cos(a) * p.r, math.sin(a * 2) * 3, math.sin(a) * p.r)
				p.body.CFrame = cf
				if p.ring then
					p.ring.CFrame = cf * CFrame.Angles(0.3, 0, math.rad(90))
				end
			end
			task.wait(0.1)
		end
	end)
end

builders.Cosmos = function(ctx)
	-- stars twinkling in the farm's grass border
	local h = ctx.half
	for i = 0, 79 do
		local side = i % 4
		local t = ((i * 37) % 80) / 80 * 2 - 1
		local inset = 1.5 + (i % 7)
		local x, z
		if side == 0 then
			x, z = t * (h - 2), -h + inset
		elseif side == 1 then
			x, z = t * (h - 2), h - inset
		elseif side == 2 then
			x, z = -h + inset, t * (h - 2)
		else
			x, z = h - inset, t * (h - 2)
		end
		ball(
			ctx,
			x,
			0.4,
			z,
			0.35 + (i % 3) * 0.15,
			if i % 3 == 0 then NEON_PINK else Color3.fromRGB(255, 255, 230),
			Enum.Material.Neon
		)
	end
	-- the cosmic beam, visible from anywhere on the map
	local beam = part(ctx, {
		Name = "CosmicBeam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(500, 7, 7),
		CFrame = at(ctx, 0, ctx.barnTop + 250, ctx.barnZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(170, 120, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
	})
	TweenService
		:Create(beam, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Color = NEON_CYAN,
			Transparency = 0.6,
		})
		:Play()
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

local PALACE_STYLES = { estate = true, castle = true, sky = true, cosmic = true }

-- The "arrival show": everything the new level added rises out of the ground (or drops in from
-- the sky for things that float), with a little stagger.
local function riseIn(folder: Folder, ids: { [string]: boolean })
	local list = {}
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") and p.Anchored then
			local id = p:GetAttribute("Unlock")
			if typeof(id) == "string" and ids[id] then
				table.insert(list, p)
			end
		end
	end
	for _, p in list do
		local final = p.CFrame
		local floating = final.Position.Y > 30
		local offset = if floating then Vector3.new(0, 60, 0) else Vector3.new(0, -30, 0)
		p.CFrame = final + offset
		local delay = math.clamp((final.Position.Y + 30) / 120, 0, 0.8)
		task.delay(delay, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					CFrame = final,
				}):Play()
			end
		end)
	end
end

-- Rebuild the farm's decor for `level` (0 or 1 = a plain fresh farm). `showLevel`: play the
-- arrival show for what that level added (after a level-up).
function FarmDecor.apply(model: Model, center: CFrame, half: number, level: number, showLevel: number?)
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
		barnTop = if PALACE_STYLES[tier.style] then 7 * k * 2.2 else 7 * k + 3.4 * k,
		wallTop = if level >= 26 then 8.4 elseif level >= 21 then 4.5 else 3,
		unlockId = nil,
	}
	-- The built-in barn from WorldBuilder is replaced by the level barn
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 4) == "Barn" then
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
		end
	end
	ctx.unlockId = "Barn"
	if PALACE_STYLES[tier.style] then
		buildPalace(ctx, tier)
	else
		buildBarn(ctx, tier)
	end
	for _, u in FarmLevels.unlocked(level) do
		local build = builders[u.id]
		if build then
			ctx.unlockId = u.id
			build(ctx)
		end
	end
	ctx.unlockId = nil
	folder.Parent = model
	if showLevel then
		local ids: { [string]: boolean } = {}
		for _, u in FarmLevels.at(showLevel) do
			ids[u.id] = true
		end
		riseIn(folder, ids)
	end

	local fence = if has(level, "WhiteFence") then FENCE_WHITE else FENCE_PLAIN
	local gold = has(level, "GoldTrim")
	local walled = has(level, "StoneWall") or has(level, "CastleWalls")
	local cosmos = has(level, "Cosmos")
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "FenceRail" or child.Name == "FencePost" then
				child.Color = fence
				-- the stone / castle walls replace the fence
				child.Transparency = if walled then 1 else 0
				child.CanCollide = not walled
				child.CanQuery = not walled
			elseif child.Name == "FarmGround" or child.Name == "MowStripe" then
				-- level 40: the farm's ground becomes a starry night sky
				if child:GetAttribute("BaseColor") == nil then
					child:SetAttribute("BaseColor", child.Color)
				end
				local base = child:GetAttribute("BaseColor")
				local cosmicGround = if child.Name == "FarmGround"
					then Color3.fromRGB(35, 25, 75)
					else Color3.fromRGB(50, 35, 100)
				child.Color = if cosmos
					then cosmicGround
					elseif typeof(base) == "Color3" then base
					else child.Color
			elseif child.Name == "GatePostCap" then
				child.Color = if gold then C.gold else ctx.identity
				child.Material = if gold then Enum.Material.Foil else Enum.Material.Wood
			end
		end
	end
	model:SetAttribute("FarmLevel", math.max(1, level))
end

return FarmDecor
