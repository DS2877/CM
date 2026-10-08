--!strict
-- Builds carrot visuals from primitives (no mesh needed). A model has an anchored, invisible
-- "Root" at the carrot's shoulder (top of the orange body); the body hangs below it and the
-- leaves point up. Everything else is welded to Root, so moving Root moves the whole carrot.
-- If Config/Assets.Meshes.Carrot is set later, this is the place to swap in the mesh.
--
-- HD anatomy (detail "high"): an organic taper over many segments (full shoulder, accelerating
-- taper), shading from a lighter shoulder to a deeper tip, growth rings, a sun-greened shoulder
-- cap, a thin root tail with root hairs, and a neck with arched feathery fronds in two greens.
-- Detail "low" (other players' farms) keeps the silhouette with a fraction of the parts, so
-- eight farms of ready carrots stay smooth on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)

local CarrotModel = {}

local LENGTH = 2.4
local RADIUS = 0.6

export type Detail = "high" | "low"

local DETAIL = {
	high = { segments = 11, rings = 4, hairs = 3, fronds = 5, leaflets = 3 },
	low = { segments = 5, rings = 0, hairs = 0, fronds = 3, leaflets = 1 },
}

-- Radius along the body, t = 0 at the shoulder, 1 at the tip. A rounded shoulder, then a taper
-- that accelerates toward a fine point (a real carrot, not a cone).
local function profile(t: number): number
	local shoulder = if t < 0.08 then 0.9 + (t / 0.08) * 0.1 else 1
	return shoulder * (1 - 0.9 * t ^ 1.35)
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Rainbow parts cycle hue every frame.
local rainbowParts: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local rainbowConn: RBXScriptConnection? = nil

local function ensureRainbowLoop()
	if rainbowConn then
		return
	end
	rainbowConn = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for p, offset in rainbowParts do
			if p.Parent then
				p.Color = Color3.fromHSV((t * 0.25 + offset) % 1, 0.75, 1)
			else
				rainbowParts[p] = nil
			end
		end
	end)
end

local function newPart(model: Model, root: BasePart, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = root.CFrame
	p.Parent = model
	return p
end

-- Weld every part to Root. Must run after all parts are positioned.
local function weldAll(model: Model, root: BasePart)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
end

local function newModel(name: string): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

-- Vertical cylinder centered at local `y` (relative to root).
local function segment(
	model: Model,
	root: BasePart,
	y: number,
	x: number,
	length: number,
	diameter: number,
	props: { [string]: any }
): Part
	local p = newPart(model, root, props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = root.CFrame * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

-- Carrot greens: a short neck, then arched stems with feathery leaflets in two greens.
local function leaves(
	model: Model,
	root: BasePart,
	color: Color3,
	count: number,
	size: number,
	material: Enum.Material,
	leaflets: number?
)
	local per = leaflets or 2
	local light = color:Lerp(Color3.fromRGB(190, 240, 120), 0.3)
	local neck = newPart(model, root, {
		Name = "Leaf",
		Shape = Enum.PartType.Cylinder,
		Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = material,
		Size = Vector3.new(0.35 * size, 0.32 * size, 0.32 * size),
	})
	neck.CFrame = root.CFrame * CFrame.new(0, 0.12 * size, 0) * CFrame.Angles(0, 0, math.rad(90))
	for i = 0, count - 1 do
		local a = i * (2 * math.pi / count) + 0.4
		local tilt = math.rad(16 + (i % 2) * 14)
		local stemLen = (1.1 + (i % 3) * 0.18) * size
		local base = root.CFrame
			* CFrame.new(0, 0.25 * size, 0)
			* CFrame.Angles(0, a, 0)
			* CFrame.Angles(tilt, 0, 0)
		local stem = newPart(model, root, {
			Name = "Leaf",
			Color = color,
			Material = material,
			Size = Vector3.new(0.07, stemLen, 0.07) * Vector3.new(size, 1, size),
		})
		stem.CFrame = base * CFrame.new(0, stemLen / 2, 0)
		-- Leaflets fan out along the upper stem, alternating sides, arching outward
		for k = 1, per do
			local f = 0.45 + 0.55 * (k / per)
			local side = if k % 2 == 0 then -1 else 1
			local leaflet = newPart(model, root, {
				Name = "Leaf",
				Color = if k % 2 == 0 then light else color,
				Material = material,
				Size = Vector3.new(0.05, 0.62, 0.3) * size,
			})
			leaflet.CFrame = base
				* CFrame.new(0, stemLen * f, 0)
				* CFrame.Angles(0, 0, math.rad(side * 38))
				* CFrame.Angles(math.rad(10), 0, 0)
				* CFrame.new(0, 0.26 * size, 0)
		end
	end
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Full carrot for a ready/harvested carrot. `scale` is the size's visual scale.
function CarrotModel.build(typeId: string, mutations: { string }, scale: number, detail: Detail?): Model
	local d = DETAIL[detail or "high"]
	local def = CarrotInfo.type(typeId)
	local model, root = newModel("Carrot")
	local shape = if def and def.shapeScale then def.shapeScale else 1
	local length = LENGTH * shape
	local radius = RADIUS * shape * (if def and def.fatness then def.fatness else 1)

	local bodyColor = if def then CarrotInfo.color(def.bodyColor) else Color3.fromRGB(245, 130, 30)
	local leafColor = if def then CarrotInfo.color(def.leafColor) else Color3.fromRGB(70, 170, 60)
	local material = Enum.Material.SmoothPlastic
	if def then
		local ok, m = pcall(function()
			return (Enum.Material :: any)[def.material]
		end)
		if ok and m then
			material = m
		end
	end
	local leafMaterial = Enum.Material.SmoothPlastic
	local reflectance = 0
	local transparency = if def and def.transparency then def.transparency else 0
	local stripeColor = if def and def.stripeColor then CarrotInfo.color(def.stripeColor) else nil

	local mutation = mutations[1]
	if mutation == "Golden" then
		bodyColor = Color3.fromRGB(255, 200, 45)
		material = Enum.Material.SmoothPlastic
		reflectance = 0.35
		stripeColor = if stripeColor then Color3.fromRGB(255, 240, 160) else nil
	elseif mutation == "Frozen" then
		bodyColor = Color3.fromRGB(175, 225, 255)
		leafColor = Color3.fromRGB(200, 240, 255)
		material = Enum.Material.Ice
		leafMaterial = Enum.Material.Ice
		transparency = math.max(transparency, 0.1)
		stripeColor = nil
	end

	local body: { BasePart } = {}
	local segments = d.segments
	local segLen = length / segments
	local twist = def ~= nil and def.twisted == true
	local function xAt(i: number): number
		return if twist then math.sin(i * 1.7 * 5 / segments) * radius * 0.35 else 0
	end
	-- Shading: lighter at the sun-facing shoulder, deeper toward the tip
	local shoulderTone = bodyColor:Lerp(Color3.new(1, 1, 1), 0.1)
	local tipTone = bodyColor:Lerp(Color3.new(0, 0, 0), 0.18)
	for i = 0, segments - 1 do
		local t = (i + 0.5) / segments
		local diameter = radius * 2 * profile(t)
		local tone = shoulderTone:Lerp(tipTone, t)
		local striped = stripeColor and (math.floor(i * 5 / segments) % 2 == 1)
		local p = segment(model, root, -(i + 0.5) * segLen, xAt(i), segLen + 0.04, diameter, {
			Name = "Body",
			Color = if striped and stripeColor then stripeColor else tone,
			Material = material,
			Reflectance = reflectance,
			Transparency = transparency,
		})
		table.insert(body, p)
	end
	-- Rounded shoulder cap, slightly sun-greened on a normal carrot
	local cap = segment(model, root, -0.02, xAt(0), 0.1, radius * 2 * 0.86, {
		Name = "Body",
		Color = if mutation == nil and not stripeColor
			then bodyColor:Lerp(Color3.fromRGB(150, 170, 60), 0.35)
			else shoulderTone,
		Material = material,
		Reflectance = reflectance,
		Transparency = transparency,
	})
	table.insert(body, cap)
	-- Growth rings: thin, slightly darker bands proud of the surface
	for r = 1, d.rings do
		local t = r / (d.rings + 1.4)
		local i = math.floor(t * segments)
		segment(model, root, -t * length, xAt(i), 0.05, radius * 2 * profile(t) + 0.05, {
			Name = "Ring",
			Color = bodyColor:Lerp(Color3.new(0, 0, 0), 0.28),
			Material = material,
			Reflectance = reflectance,
			Transparency = transparency,
		})
	end
	-- Thin root tail
	local tailD = math.max(0.06, radius * 2 * profile(1) * 0.9)
	local tail = segment(model, root, -length - 0.15, xAt(segments - 1), 0.36, tailD, {
		Name = "Body",
		Color = tipTone,
		Material = material,
		Reflectance = reflectance,
		Transparency = transparency,
	})
	table.insert(body, tail)
	-- Root hairs on the lower half
	for h = 1, d.hairs do
		local t = 0.45 + h * 0.13
		local hair = newPart(model, root, {
			Name = "Hair",
			Color = tipTone:Lerp(Color3.new(1, 1, 1), 0.25),
			Material = material,
			Size = Vector3.new(0.035, 0.035, 0.32),
			Transparency = transparency,
		})
		hair.CFrame = root.CFrame
			* CFrame.new(xAt(math.floor(t * segments)), -t * length, 0)
			* CFrame.Angles(0, h * 2.1, 0)
			* CFrame.new(0, 0, radius * profile(t) + 0.12)
			* CFrame.Angles(math.rad(-25), 0, 0)
	end

	leaves(model, root, leafColor, d.fronds, shape, leafMaterial, d.leaflets)

	if def and def.crown then
		for i = 0, 4 do
			local a = i * (2 * math.pi / 5)
			local spike = newPart(model, root, {
				Name = "Crown",
				Color = Color3.fromRGB(255, 215, 60),
				Material = Enum.Material.Neon,
				Size = Vector3.new(0.22, 0.5, 0.22),
			})
			spike.CFrame = root.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.22, radius * 0.8)
		end
	end
	if def and def.spikes then
		-- Little dragon spikes down both sides
		for i = 0, 3 do
			for _, side in { -1, 1 } do
				local spike = newPart(model, root, {
					Name = "Spike",
					Color = Color3.fromRGB(255, 200, 60),
					Size = Vector3.new(0.18, 0.35, 0.5),
				})
				local t = (i + 0.5) / 5
				spike.CFrame = root.CFrame
					* CFrame.new(side * radius * profile(t), -t * length, 0)
					* CFrame.Angles(0, 0, side * math.rad(-60))
			end
		end
	end
	if def and def.fire then
		local fire = emitter(body[1], {
			Name = "Fire",
			Rate = 18,
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 60, 30)),
		})
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	end
	if def and def.glow then
		local light = Instance.new("PointLight")
		light.Color = bodyColor
		light.Range = 10
		light.Brightness = 2
		light.Parent = body[1]
	end
	if def and def.stars then
		emitter(body[2], {
			Rate = 14,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.25, 0),
			Color = ColorSequence.new(Color3.fromRGB(150, 255, 255), Color3.fromRGB(200, 140, 255)),
		})
	end

	if mutation == "Golden" then
		emitter(body[2], {
			Rate = 8,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.3, 0),
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 120)),
		})
	elseif mutation == "Frozen" then
		emitter(body[3], {
			Rate = 10,
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(0.3, 0.8),
			Acceleration = Vector3.new(0, 0.6, 0),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.2, 0),
			Color = ColorSequence.new(Color3.fromRGB(230, 250, 255)),
		})
	elseif mutation == "Rainbow" then
		for i, p in body do
			rainbowParts[p] = i * 0.08
		end
		ensureRainbowLoop()
		emitter(body[2], {
			Rate = 12,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(0.5, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.3, 0),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 100, 255)),
			}),
		})
	end

	-- Rarity aura: every carrot sparkles a little, better ones a lot (Config/Rarity aura).
	local rarity = CarrotInfo.rarityOfType(typeId)
	local aura = rarity.aura
	local auraColor = CarrotInfo.rarityColor(rarity)
	local auraSeq = CarrotInfo.raritySequence(rarity)
	-- Divine carrots (and Prism) shimmer through every color
	if (def and def.rainbow) or rarity.style == "rainbow" then
		for i, p in body do
			rainbowParts[p] = i * 0.06
		end
		ensureRainbowLoop()
	end
	if aura.rate > 0 then
		emitter(body[2], {
			Name = "Aura",
			Rate = aura.rate,
			Lifetime = NumberRange.new(0.6, 1.3),
			Speed = NumberRange.new(aura.speed * 0.5, aura.speed),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.25, aura.size),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Color = auraSeq,
		})
	end
	if aura.rising > 0 then
		emitter(body[1], {
			Name = "Rising",
			Rate = aura.rising,
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(2, 4),
			Acceleration = Vector3.new(0, 2, 0),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, aura.size * 0.8),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = auraSeq,
		})
	end
	if aura.light > 0 then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = auraColor
		light.Range = aura.light
		light.Brightness = 1.6
		light.Parent = body[2]
	end

	weldAll(model, root)
	model:SetAttribute("Length", length)
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

-- Generic sprout shown while growing. Reveals nothing about the roll.
-- `showShoulder` adds the orange top peeking out of the soil (phases 3–4).
function CarrotModel.sprout(): Model
	local model, root = newModel("Sprout")
	leaves(model, root, Color3.fromRGB(80, 175, 65), 3, 1, Enum.Material.SmoothPlastic, 1)
	local shoulder = segment(model, root, -0.12, 0, 0.3, RADIUS * 1.8, {
		Name = "Shoulder",
		Color = Color3.fromRGB(235, 125, 35),
		Transparency = 1,
	})
	shoulder:SetAttribute("Shoulder", true)
	weldAll(model, root)
	return model
end

function CarrotModel.setShoulderVisible(model: Model, visible: boolean)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Shoulder") then
			p.Transparency = if visible then 0 else 1
		end
	end
end

-- Length in studs of a built carrot at its current scale.
function CarrotModel.length(model: Model): number
	local base = model:GetAttribute("Length")
	return (if typeof(base) == "number" then base else LENGTH) * model:GetScale()
end

return CarrotModel
