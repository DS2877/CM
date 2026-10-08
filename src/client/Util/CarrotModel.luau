--!strict
-- Builds carrot visuals from primitives (no mesh needed). A model has an anchored, invisible
-- "Root" at the carrot's shoulder (top of the orange body); the body hangs below it and the
-- leaves point up. Everything else is welded to Root, so moving Root moves the whole carrot.
-- If Config/Assets.Meshes.Carrot is set later, this is the place to swap in the mesh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)

local CarrotModel = {}

local LENGTH = 2.4
local RADIUS = 0.6
local SEGMENTS = 5

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

local function leaves(
	model: Model,
	root: BasePart,
	color: Color3,
	count: number,
	size: number,
	material: Enum.Material
)
	for i = 0, count - 1 do
		local a = i * (2 * math.pi / count) + 0.4
		local leaf = newPart(model, root, {
			Name = "Leaf",
			Color = color,
			Material = material,
			Size = Vector3.new(0.14, 1.35, 0.42) * size,
		})
		leaf.CFrame = root.CFrame
			* CFrame.Angles(0, a, 0)
			* CFrame.Angles(math.rad(20), 0, 0)
			* CFrame.new(0, 0.7 * size + 0.1, 0)
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
function CarrotModel.build(typeId: string, mutations: { string }, scale: number): Model
	local def = CarrotInfo.type(typeId)
	local model, root = newModel("Carrot")
	local shape = if def and def.shapeScale then def.shapeScale else 1
	local length = LENGTH * shape
	local radius = RADIUS * shape

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
	local transparency = 0

	local mutation = mutations[1]
	if mutation == "Golden" then
		bodyColor = Color3.fromRGB(255, 200, 45)
		material = Enum.Material.SmoothPlastic
		reflectance = 0.35
	elseif mutation == "Frozen" then
		bodyColor = Color3.fromRGB(175, 225, 255)
		leafColor = Color3.fromRGB(200, 240, 255)
		material = Enum.Material.Ice
		leafMaterial = Enum.Material.Ice
		transparency = 0.1
	end

	local body: { BasePart } = {}
	local segLen = length / SEGMENTS
	for i = 0, SEGMENTS - 1 do
		local d = radius * 2 * (1 - i * 0.16)
		local x = if def and def.twisted then math.sin(i * 1.7) * radius * 0.35 else 0
		local p = segment(model, root, -(i + 0.5) * segLen, x, segLen + 0.04, d, {
			Name = "Body",
			Color = bodyColor,
			Material = material,
			Reflectance = reflectance,
			Transparency = transparency,
		})
		table.insert(body, p)
	end
	local tipD = radius * 2 * (1 - SEGMENTS * 0.16) * 0.9
	local tip = newPart(model, root, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * math.max(0.15, tipD),
		Color = bodyColor,
		Material = material,
		Reflectance = reflectance,
		Transparency = transparency,
	})
	tip.CFrame = root.CFrame * CFrame.new(0, -length, 0)
	table.insert(body, tip)

	leaves(model, root, leafColor, 4, shape, leafMaterial)

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
	if def and def.glow then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 150)
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
	leaves(model, root, Color3.fromRGB(80, 175, 65), 3, 1, Enum.Material.SmoothPlastic)
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
