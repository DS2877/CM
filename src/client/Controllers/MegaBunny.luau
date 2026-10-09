--!strict
-- MEGA BUNNY: a giant fluffy bunny that hops in a big circle around the plaza, between the
-- market and the farms. Its position comes from the server clock, so every player sees it in the
-- same place without any network traffic (client-only model). Land on its back and it launches
-- you sky-high - BOING! During a boom it wears a golden crown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage.Shared.Config.World)
local Market = require(ReplicatedStorage.Shared.Market)
local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local MegaBunny = {}

type Piece = { part: Part, offset: CFrame }

local pieces: { Piece } = {}
local crown: { BasePart } = {}
local back: BasePart
local model: Model
local HOP = 1.8 -- seconds per hop

local function add(size: Vector3, offset: CFrame, color: Color3, sphere: boolean?, collide: boolean?): Part
	local s = World.MegaBunnyScale
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size * s
	p.Color = color
	if sphere ~= false then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	local o = offset.Position * s
	table.insert(pieces, { part = p, offset = CFrame.new(o) * offset.Rotation })
	return p
end

local function build()
	model = Instance.new("Model")
	model.Name = "MegaBunny"
	local fur = Color3.fromRGB(250, 248, 245)
	local pink = Color3.fromRGB(255, 165, 190)
	local black = Color3.fromRGB(35, 30, 35)
	-- body faces -Z (direction of travel)
	add(Vector3.new(1.3, 1.15, 1.6), CFrame.new(0, 0.6, 0.1), fur)
	-- the back you can land on (flat-ish collider on top of the body)
	back = add(Vector3.new(0.9, 0.12, 1.1), CFrame.new(0, 1.17, 0.15), fur, false, true)
	back.Transparency = 1
	back.Name = "MegaBack"
	add(Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, 0.55, 0.95), Color3.fromRGB(255, 255, 255)) -- tail
	add(Vector3.new(0.9, 0.85, 0.9), CFrame.new(0, 1.25, -0.75), fur) -- head
	for _, sx in { -1, 1 } do
		add(Vector3.new(0.12, 0.16, 0.08), CFrame.new(sx * 0.22, 1.35, -1.18), black) -- eyes
		add(Vector3.new(0.18, 0.12, 0.06), CFrame.new(sx * 0.32, 1.12, -1.15), pink) -- cheeks
		local ear = CFrame.new(sx * 0.2, 2.05, -0.65) * CFrame.Angles(0.15, 0, -sx * 0.12)
		add(Vector3.new(0.26, 1.0, 0.16), ear, fur)
		add(Vector3.new(0.14, 0.8, 0.05), ear * CFrame.new(0, 0, -0.07), pink)
		add(Vector3.new(0.35, 0.25, 0.6), CFrame.new(sx * 0.4, 0.12, -0.35), fur) -- front paws
		add(Vector3.new(0.4, 0.3, 0.75), CFrame.new(sx * 0.5, 0.15, 0.5), fur) -- feet
	end
	add(Vector3.new(0.14, 0.1, 0.08), CFrame.new(0, 1.2, -1.2), pink) -- nose
	-- Crown for booms (hidden otherwise)
	local gold = Color3.fromRGB(255, 200, 60)
	local base = add(Vector3.new(0.6, 0.18, 0.6), CFrame.new(0, 1.75, -0.75), gold, false)
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.18, 0.6, 0.6) * World.MegaBunnyScale
	table.insert(crown, base)
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		local spike = add(
			Vector3.new(0.1, 0.22, 0.1),
			CFrame.new(math.cos(a) * 0.25, 1.92, -0.75 + math.sin(a) * 0.25),
			gold,
			false
		)
		table.insert(crown, spike)
	end
	-- the cylinder crown base needs a rotation to stand up
	for _, p in pieces do
		if p.part == base then
			p.offset = p.offset * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	model.Parent = workspace
end

-- Where the bunny is at server time t: (feet CFrame facing travel direction, lift, squash).
local function poseAt(t: number): (CFrame, number)
	local r = World.MegaBunnyRadius
	local lap = World.MegaBunnyLapSeconds
	-- progress only while in the air: hop forward, sit a moment, hop again
	local hopIndex = math.floor(t / HOP)
	local k = (t % HOP) / HOP
	local air = math.clamp(k / 0.6, 0, 1)
	local step = (2 * math.pi) * HOP / lap
	local angle = (hopIndex + (1 - math.cos(air * math.pi)) / 2) * step
	local pos = Vector3.new(math.sin(angle) * r, 0, math.cos(angle) * r)
	local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
	local lift = if k < 0.6 then math.sin(air * math.pi) * 9 else 0
	return CFrame.lookAt(pos, pos + tangent), lift
end

local lastBounce = 0
local lastHop = -1

local function launch(rootPart: BasePart, up: number, push: Vector3)
	lastBounce = os.clock()
	local v = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(v.X + push.X, up, v.Z + push.Z)
	Sound.play("Boing")
end

function MegaBunny.start()
	build()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { back }
	RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow()
		local feet, lift = poseAt(t)
		local cf = feet + Vector3.new(0, lift, 0)
		for _, p in pieces do
			p.part.CFrame = cf * p.offset
		end
		local boom = Market.state().boomActive
		for _, p in crown do
			p.Transparency = if boom then 0 else 1
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and os.clock() - lastBounce > 0.4 then
			local rootPart = root :: BasePart
			-- Standing on its back: BOING, sky-high
			if rootPart.AssemblyLinearVelocity.Y <= 2 then
				local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -4, 0), params)
				if hit then
					launch(rootPart, World.MegaBunnyBounce, Vector3.zero)
				end
			end
			-- It just landed right next to you: the ground shakes and you go flying
			local hopIndex = math.floor(t / HOP)
			local landed = (t % HOP) / HOP >= 0.6
			if landed and hopIndex ~= lastHop then
				lastHop = hopIndex
				local away = rootPart.Position - feet.Position
				local flatAway = Vector3.new(away.X, 0, away.Z)
				if flatAway.Magnitude < World.MegaBunnyScale * 1.4 and away.Y < 8 then
					local push = if flatAway.Magnitude > 0.1
						then flatAway.Unit * 40
						else Vector3.new(40, 0, 0)
					launch(rootPart, World.MegaBunnyBounce * 0.6, push)
				end
			end
		end
	end)
end

return MegaBunny
