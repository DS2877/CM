--!strict
-- Life in the valley (client only, capped, never collide, cost ~nothing). A still world reads as
-- cheap; small motion everywhere reads as alive:
--   * butterflies flutter near the camera
--   * bunnies hop around on the grass near you
--   * birds circle high above, puffy clouds drift across the sky
--   * the plaza balloons bob on their strings
--   * bouncy mushrooms: land on a cap (World/Fun/Mushrooms) and you get launched up – BOING!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage.Shared.Config.World)
local Sound = require(script.Parent.Parent.Util.Sound)
local DayCycle = require(script.Parent.DayCycle)

local Ambience = {}

local COUNT = 18
local RANGE = 60 -- studs around the camera where butterflies live
local COLORS = {
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 140, 200),
	Color3.fromRGB(150, 200, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 70),
}

type Fly = {
	model: Model,
	left: BasePart,
	right: BasePart,
	pos: Vector3,
	target: Vector3,
	speed: number,
	phase: number,
	color: Color3,
}

local flies: { Fly } = {}
local folder: Folder

local function wing(color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(0.05, 0.45, 0.35)
	return p
end

local function randomSpot(around: Vector3): Vector3
	local a = math.random() * math.pi * 2
	local r = 8 + math.random() * RANGE
	return Vector3.new(around.X + math.cos(a) * r, 1.5 + math.random() * 3.5, around.Z + math.sin(a) * r)
end

local function spawnFly(around: Vector3): Fly
	local color = COLORS[math.random(1, #COLORS)]
	local model = Instance.new("Model")
	model.Name = "Butterfly"
	local left, right = wing(color), wing(color)
	left.Parent = model
	right.Parent = model
	model.Parent = folder
	local pos = randomSpot(around)
	return {
		model = model,
		left = left,
		right = right,
		pos = pos,
		target = randomSpot(around),
		speed = 3 + math.random() * 2.5,
		phase = math.random() * 10,
		color = color,
	}
end

local function prop(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function sphereMesh(p: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

-- Bunnies --------------------------------------------------------------------

type Bunny = {
	parts: { { part: Part, offset: CFrame } },
	pos: Vector3,
	heading: number,
	hopStart: number,
	nextHop: number,
}

local bunnies: { Bunny } = {}
local BUNNY_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(215, 185, 150),
	Color3.fromRGB(180, 180, 190),
}

local function groundY(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else 0
end

local function spawnBunny(around: Vector3): Bunny
	local color = BUNNY_COLORS[math.random(1, #BUNNY_COLORS)]
	local list: { { part: Part, offset: CFrame } } = {}
	local function add(size: Vector3, offset: CFrame, c: Color3?)
		local p = prop({ Size = size, Color = c or color })
		sphereMesh(p)
		table.insert(list, { part = p, offset = offset })
	end
	add(Vector3.new(1.1, 1, 1.5), CFrame.new(0, 0.5, 0)) -- body
	add(Vector3.new(0.85, 0.8, 0.85), CFrame.new(0, 1.05, -0.65)) -- head
	add(Vector3.new(0.25, 0.9, 0.18), CFrame.new(-0.18, 1.7, -0.6) * CFrame.Angles(0.2, 0, -0.15)) -- ears
	add(Vector3.new(0.25, 0.9, 0.18), CFrame.new(0.18, 1.7, -0.6) * CFrame.Angles(0.2, 0, 0.15))
	add(Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0.6, 0.78), Color3.fromRGB(255, 255, 255)) -- tail
	add(Vector3.new(0.15, 0.15, 0.1), CFrame.new(0, 1.05, -1.07), Color3.fromRGB(255, 150, 170)) -- nose
	local a = math.random() * math.pi * 2
	local r = 15 + math.random() * 40
	local pos = Vector3.new(around.X + math.cos(a) * r, 0, around.Z + math.sin(a) * r)
	pos = Vector3.new(pos.X, groundY(pos), pos.Z)
	return {
		parts = list,
		pos = pos,
		heading = math.random() * 6.28,
		hopStart = -10,
		nextHop = os.clock() + math.random() * 2,
	}
end

local function updateBunny(b: Bunny, center: Vector3, t: number)
	local away = Vector3.new(b.pos.X - center.X, 0, b.pos.Z - center.Z).Magnitude
	if away > 90 then
		-- left behind: pop up somewhere near the camera again
		local fresh = spawnBunny(center)
		for _, p in b.parts do
			p.part:Destroy()
		end
		b.parts, b.pos = fresh.parts, fresh.pos
	end
	if t >= b.nextHop then
		b.hopStart = t
		b.nextHop = t + 0.45 + math.random() * (if math.random() < 0.3 then 3 else 0.6)
		b.heading += (math.random() - 0.5) * 1.6
		local step = Vector3.new(math.sin(b.heading), 0, math.cos(b.heading)) * 2.2
		local nextPos = b.pos + step
		local y = groundY(nextPos)
		if y - b.pos.Y > 1.5 then
			-- something in the way (fence, building): turn around instead
			b.heading += math.pi
		else
			b.pos = Vector3.new(nextPos.X, y, nextPos.Z)
		end
	end
	local k = math.clamp((t - b.hopStart) / 0.35, 0, 1)
	local lift = math.sin(k * math.pi) * 1.1
	local base = CFrame.new(b.pos + Vector3.new(0, lift, 0)) * CFrame.Angles(0, b.heading + math.pi, 0)
	for _, p in b.parts do
		p.part.CFrame = base * p.offset
	end
end

-- Birds & clouds ---------------------------------------------------------------

type Bird = {
	left: BasePart,
	right: BasePart,
	body: BasePart,
	center: Vector3,
	radius: number,
	speed: number,
	phase: number,
	height: number,
}
local birds: { Bird } = {}
type Cloud = { parts: { { part: Part, offset: Vector3 } }, pos: Vector3, speed: number }
local clouds: { Cloud } = {}
local MAP = 330

local function spawnBird(): Bird
	local body = prop({ Size = Vector3.new(0.6, 0.5, 1.2), Color = Color3.fromRGB(70, 80, 110) })
	sphereMesh(body)
	local left = prop({ Size = Vector3.new(1.6, 0.08, 0.7), Color = Color3.fromRGB(70, 80, 110) })
	local right = prop({ Size = Vector3.new(1.6, 0.08, 0.7), Color = Color3.fromRGB(70, 80, 110) })
	return {
		body = body,
		left = left,
		right = right,
		center = Vector3.new((math.random() - 0.5) * 300, 0, (math.random() - 0.5) * 300),
		radius = 25 + math.random() * 40,
		speed = 0.25 + math.random() * 0.2,
		phase = math.random() * 6.28,
		height = 45 + math.random() * 25,
	}
end

local function updateBird(b: Bird, t: number)
	local a = b.phase + t * b.speed
	local pos = b.center
		+ Vector3.new(
			math.cos(a) * b.radius,
			b.height + math.sin(t * 0.7 + b.phase) * 2,
			math.sin(a) * b.radius
		)
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
	local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, 0.25)
	local flap = math.sin(t * 9 + b.phase) * 0.6
	b.body.CFrame = cf
	b.left.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.85, 0, 0)
	b.right.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.85, 0, 0)
end

local function spawnCloud(x: number?): Cloud
	local list: { { part: Part, offset: Vector3 } } = {}
	local puffs = math.random(4, 6)
	for k = 1, puffs do
		local size = 14 + math.random() * 12
		local p = prop({
			Size = Vector3.new(size * 1.4, size * 0.75, size),
			Color = Color3.fromRGB(255, 255, 255),
			Transparency = 0.08,
		})
		sphereMesh(p)
		table.insert(list, {
			part = p,
			offset = Vector3.new((k - puffs / 2) * 11, math.random() * 5, (math.random() - 0.5) * 12),
		})
	end
	return {
		parts = list,
		pos = Vector3.new(
			x or (math.random() - 0.5) * 2 * MAP,
			110 + math.random() * 40,
			(math.random() - 0.5) * 2 * MAP
		),
		speed = 2 + math.random() * 2.5,
	}
end

-- Bouncy mushrooms -------------------------------------------------------------

local lastBounce = 0
local function bounceCheck(params: RaycastParams)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local rootPart = root :: BasePart
	-- Only while falling/landing, not every frame you stand still on it
	if rootPart.AssemblyLinearVelocity.Y > 2 or os.clock() - lastBounce < 0.35 then
		return
	end
	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -3.6, 0), params)
	local cap = hit and hit.Instance
	if cap and cap.Name == "BounceCap" then
		local power = cap:GetAttribute("Bounce")
		if typeof(power) == "number" then
			lastBounce = os.clock()
			local v = rootPart.AssemblyLinearVelocity
			rootPart.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
			Sound.play("Boing")
			-- a little squash of the cap (local only)
			local mesh = cap:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh.Scale = Vector3.new(1.12, 0.75, 1.12)
				task.delay(0.12, function()
					mesh.Scale = Vector3.one
				end)
			end
		end
	end
end

function Ambience.start()
	folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = workspace

	for _ = 1, World.Birds do
		table.insert(birds, spawnBird())
	end

	-- Pollen and dandelion seeds drifting with the wind all around you (a box of particles that
	-- follows the camera; the terrain grass sways in the same wind)
	local motes = prop({ Name = "Motes", Size = Vector3.new(110, 14, 110), Transparency = 1 })
	local pollen = Instance.new("ParticleEmitter")
	pollen.Shape = Enum.ParticleEmitterShape.Box
	pollen.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pollen.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 255, 255))
	pollen.LightEmission = 0.6
	pollen.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(0.8, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	pollen.Lifetime = NumberRange.new(6, 9)
	pollen.Rate = 30
	pollen.Speed = NumberRange.new(0.2, 0.8)
	pollen.SpreadAngle = Vector2.new(180, 180)
	pollen.Drag = 1.5
	pollen.WindAffectsDrag = true
	pollen.Parent = motes
	local seeds = Instance.new("ParticleEmitter")
	seeds.Shape = Enum.ParticleEmitterShape.Box
	seeds.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	seeds.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	seeds.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	seeds.LightEmission = 0.3
	seeds.Size = NumberSequence.new(0.35)
	seeds.Lifetime = NumberRange.new(8, 12)
	seeds.Rate = 6
	seeds.Speed = NumberRange.new(0.5, 1)
	seeds.Rotation = NumberRange.new(0, 360)
	seeds.RotSpeed = NumberRange.new(-30, 30)
	seeds.Drag = 1
	seeds.WindAffectsDrag = true
	seeds.Parent = motes
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			motes.CFrame = CFrame.new(camera.Focus.Position + Vector3.new(0, 5, 0))
		end
	end)
	for _ = 1, World.Clouds do
		table.insert(clouds, spawnCloud())
	end

	local world = workspace:WaitForChild("World", 10)
	local fun = world and world:WaitForChild("Fun", 10)
	local balloonFolder = fun and fun:FindFirstChild("Balloons")
	local mushrooms = fun and fun:FindFirstChild("Mushrooms")
	-- Balloons: remember where each one rests, then bob around that
	type Bob = { part: BasePart, base: CFrame, phase: number }
	local bobs: { Bob } = {}
	if balloonFolder then
		for _, p in balloonFolder:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Balloon" then
				table.insert(bobs, { part = p, base = p.CFrame, phase = math.random() * 6.28 })
			end
		end
	end
	local bounceParams = RaycastParams.new()
	bounceParams.FilterType = Enum.RaycastFilterType.Include
	bounceParams.FilterDescendantsInstances = if mushrooms then { mushrooms } else {}

	-- The waterfall's Super Slide: standing on a "Slide" part shoots you down it
	local wilds = world and world:WaitForChild("Wilds", 10)
	local waterfall = wilds and wilds:WaitForChild("Waterfall", 10)
	local slides = waterfall and waterfall:FindFirstChild("Slides")
	local slideParams = RaycastParams.new()
	slideParams.FilterType = Enum.RaycastFilterType.Include
	slideParams.FilterDescendantsInstances = if slides then { slides } else {}
	local wasSliding = false

	RunService.Heartbeat:Connect(function()
		if mushrooms then
			bounceCheck(bounceParams)
		end
		if slides then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local rootPart = root :: BasePart
				local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -4, 0), slideParams)
				local dir = hit and hit.Instance:GetAttribute("SlideDir")
				if hit and hit.Instance.Name == "Slide" and typeof(dir) == "Vector3" then
					if not wasSliding then
						Sound.play("Boing")
					end
					wasSliding = true
					rootPart.AssemblyLinearVelocity = dir * World.SlideSpeed
				else
					wasSliding = false
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t0 = os.clock()
		local center0 = camera.Focus.Position
		while #bunnies < World.Bunnies do
			table.insert(bunnies, spawnBunny(center0))
		end
		for _, b in bunnies do
			updateBunny(b, center0, t0)
		end
		for _, b in birds do
			updateBird(b, t0)
		end
		for _, c in clouds do
			c.pos += Vector3.new(c.speed * dt, 0, c.speed * dt * 0.3)
			if c.pos.X > MAP then
				c.pos = Vector3.new(-MAP, c.pos.Y, (math.random() - 0.5) * 2 * MAP)
			end
			for _, p in c.parts do
				p.part.CFrame = CFrame.new(c.pos + p.offset)
			end
		end
		for _, b in bobs do
			b.part.CFrame = b.base
				* CFrame.new(0, math.sin(t0 * 1.6 + b.phase) * 0.35, 0)
				* CFrame.Angles(0, 0, math.sin(t0 * 1.1 + b.phase) * 0.08)
		end

		local center = center0
		while #flies < COUNT do
			table.insert(flies, spawnFly(center))
		end
		local t = t0
		-- At night the butterflies become glowing fireflies
		local night = DayCycle.darkness() > 0.5
		local glow = Color3.fromRGB(255, 240, 140)
		for _, f in flies do
			local offset = f.target - f.pos
			if
				offset.Magnitude < 1
				or (Vector3.new(f.pos.X - center.X, 0, f.pos.Z - center.Z)).Magnitude > RANGE * 1.6
			then
				-- New wander target; butterflies left behind hop back near the camera
				if (Vector3.new(f.pos.X - center.X, 0, f.pos.Z - center.Z)).Magnitude > RANGE * 1.6 then
					f.pos = randomSpot(center)
				end
				f.target = randomSpot(center)
				offset = f.target - f.pos
			end
			local dir = offset.Unit
			f.pos += dir * f.speed * dt + Vector3.new(0, math.sin(t * 3 + f.phase) * 0.02, 0)
			local flap = math.sin(t * 22 + f.phase) * 0.9
			local base = CFrame.lookAt(f.pos, f.pos + Vector3.new(dir.X, 0, dir.Z) + Vector3.new(0, 0, 1e-3))
			local wingColor = if night then glow else f.color
			if f.left.Color ~= wingColor then
				local mat = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
				f.left.Color, f.right.Color = wingColor, wingColor
				f.left.Material, f.right.Material = mat, mat
			end
			f.left.CFrame = base * CFrame.Angles(0, 0, flap) * CFrame.new(-0.2, 0, 0)
			f.right.CFrame = base * CFrame.Angles(0, 0, -flap) * CFrame.new(0.2, 0, 0)
		end
	end)
end

return Ambience
