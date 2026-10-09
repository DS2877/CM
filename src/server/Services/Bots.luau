--!strict
-- Plaza bots: a handful of blocky Roblox-style farmers (straw hats, bright clothes) who stroll
-- around the market, visit the bunny stalls, wander out along the farm paths and come back. They
-- make an empty server feel alive. Purely visual: they never buy, sell or touch the economy.
-- Built at runtime from a HumanoidDescription (no uploaded assets), walked with
-- PathfindingService, animated with Roblox's built-in R15 animations (Config/Assets.Animations).

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local World = require(Config.World)
local Assets = require(Config.Assets)

local Bots = {}

local NAMES = {
	"Farmer Mo",
	"Lily Sprout",
	"Carrot Kid",
	"Benny Beans",
	"Hoppy Sam",
	"Mia Muncher",
	"Tom Turnip",
	"Ella Acorn",
	"Pip Potato",
	"Rosie Radish",
}
local SKIN = {
	Color3.fromRGB(255, 220, 180),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(196, 140, 100),
	Color3.fromRGB(140, 95, 65),
	Color3.fromRGB(255, 204, 0), -- classic noob yellow
}
local CLOTHES = {
	Color3.fromRGB(235, 80, 90),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(120, 210, 100),
	Color3.fromRGB(175, 120, 255),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(255, 120, 180),
	Color3.fromRGB(60, 190, 190),
}

local rng = Random.new()

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function flat(deg: number, r: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(math.sin(a) * r, 3, math.cos(a) * r)
end

-- Somewhere nice to walk to (spread over the world, not just the plaza).
local function randomTarget(): Vector3
	local roll = rng:NextNumber()
	if roll < 0.2 then
		-- in front of a bunny stall (watch the bunny)
		local i = rng:NextInteger(1, #World.SellPadAngles)
		return flat(World.SellPadAngles[i] + rng:NextNumber(-12, 12), World.SellPadDistance + 3)
	elseif roll < 0.35 then
		-- around the plaza
		return flat(rng:NextNumber(0, 360), rng:NextNumber(12, 30))
	elseif roll < 0.6 then
		-- out along a farm path
		local k = rng:NextInteger(0, World.FarmCount - 1)
		return flat(k * (360 / World.FarmCount) + rng:NextNumber(-1.5, 1.5), rng:NextNumber(40, 100))
	elseif roll < 0.75 then
		-- visit the campfire
		return flat(World.CampAngle + rng:NextNumber(-8, 8), World.CampRadius - 9)
	elseif roll < 0.88 then
		-- look at the lake
		return flat(World.LakeAngle + rng:NextNumber(-10, 10), World.LakeRadius - World.LakeSize / 2 - 4)
	else
		-- near a bouncy mushroom
		local deg = pick(World.MushroomAngles)
		return flat(deg + rng:NextNumber(-8, 8), World.MushroomRadius + rng:NextNumber(-10, 10))
	end
end

local function weldTo(part: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function addHat(model: Model)
	local headInst = model:FindFirstChild("Head")
	if not headInst or not headInst:IsA("BasePart") then
		return
	end
	local head = headInst :: BasePart
	local straw = Color3.fromRGB(232, 196, 96)
	local band = pick(CLOTHES)
	local function piece(size: Vector3, offset: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = head.CFrame * offset * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = model
		weldTo(p, head)
	end
	piece(Vector3.new(0.15, 2.6, 2.6), CFrame.new(0, 0.62, 0), straw)
	piece(Vector3.new(0.75, 1.35, 1.35), CFrame.new(0, 0.98, 0), straw)
	piece(Vector3.new(0.22, 1.38, 1.38), CFrame.new(0, 0.75, 0), band)
end

local function addCarrot(model: Model)
	local handInst = model:FindFirstChild("RightHand")
	if not handInst or not handInst:IsA("BasePart") then
		return
	end
	local hand = handInst :: BasePart
	local c = Instance.new("Part")
	c.Size = Vector3.new(0.45, 1.5, 0.45)
	c.Color = Color3.fromRGB(255, 136, 36)
	c.CanCollide = false
	c.CanQuery = false
	c.Massless = true
	c.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.3) * CFrame.Angles(math.rad(70), 0, 0)
	c.Parent = model
	weldTo(c, hand)
end

local function loadAnim(animator: Animator, id: string): AnimationTrack?
	if id == "" then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	return if ok then track else nil
end

local function makeBot(index: number, folder: Folder): Model?
	local desc = Instance.new("HumanoidDescription")
	local skin = pick(SKIN)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	local shirt = pick(CLOTHES)
	local pants = pick(CLOTHES)
	desc.TorsoColor = shirt
	desc.LeftLegColor = pants
	desc.RightLegColor = pants
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not result then
		warn("Bots: could not build a bot", result)
		return nil
	end
	local model = result :: Model
	model.Name = "Bot_" .. index
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		return nil
	end
	humanoid.DisplayName = NAMES[(index - 1) % #NAMES + 1]
	humanoid.WalkSpeed = World.BotWalkSpeed
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	addHat(model)
	if rng:NextNumber() < 0.5 then
		addCarrot(model)
	end
	model:PivotTo(CFrame.new(flat(rng:NextNumber(0, 360), rng:NextNumber(12, 28))))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil) -- the server walks them, not a nearby player
		end)
	end
	return model
end

local function walkTo(humanoid: Humanoid, root: BasePart, target: Vector3)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)
	local points = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else nil
	if not points then
		humanoid:MoveTo(target)
		humanoid.MoveToFinished:Wait()
		return
	end
	for _, wp in points do
		if wp.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(wp.Position)
		local reached = false
		local conn = humanoid.MoveToFinished:Connect(function(r)
			reached = r
		end)
		local waited = 0
		while not reached and waited < 3 do
			waited += task.wait(0.1)
		end
		conn:Disconnect()
		if not reached then
			return -- stuck: pick a new target
		end
	end
end

local function run(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local found = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator = if found then found else Instance.new("Animator")
	animator.Parent = humanoid
	local anims = Assets.Animations
	local walk = loadAnim(animator, anims.BotWalk)
	local idle = loadAnim(animator, anims.BotIdle)
	local jump = loadAnim(animator, anims.BotJump)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not walk then
			return
		end
		if speed > 0.5 and not walk.IsPlaying then
			walk.Looped = true
			walk:Play(0.2)
		elseif speed <= 0.5 and walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)
	humanoid.Jumping:Connect(function(active)
		if active and jump then
			jump:Play(0.1)
		end
	end)
	while model.Parent do
		if root.Position.Y < -20 then
			model:PivotTo(CFrame.new(flat(rng:NextNumber(0, 360), 20)))
		end
		walkTo(humanoid, root, randomTarget())
		-- pause: look around, sometimes a happy jump
		task.wait(rng:NextNumber(1.5, 5))
		if rng:NextNumber() < 0.25 then
			humanoid.Jump = true
			task.wait(0.6)
		end
	end
end

-- Hold a bot in place (anchored root, a looping pose) for the campfire and the dock.
local function settle(model: Model, at: CFrame, animId: string): (Humanoid?, BasePart?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local rootPart = root :: BasePart
	rootPart.Anchored = true
	model:PivotTo(at)
	local found = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator = if found then found else Instance.new("Animator")
	animator.Parent = humanoid
	local track = loadAnim(animator, animId)
	if track then
		track.Looped = true
		track:Play()
	end
	return humanoid, rootPart
end

-- Roasting marshmallows: sit on a log, stick toward the fire, marshmallow slowly toasts (and
-- now and then catches fire - whoops - and gets a fresh one).
local function camper(model: Model, seat: BasePart)
	local _, root = settle(model, seat.CFrame, Assets.Animations.BotSit)
	if not root then
		return
	end
	local fireDir = seat.CFrame.LookVector
	local hand = root.Position + fireDir * 0.8 + Vector3.new(0, 0.2, 0)
	local tip = root.Position + fireDir * 3.6 + Vector3.new(0, -0.4, 0)
	local stick = Instance.new("Part")
	stick.Name = "Stick"
	stick.Anchored = true
	stick.CanCollide = false
	stick.CanQuery = false
	stick.Size = Vector3.new(0.1, 0.1, (tip - hand).Magnitude)
	stick.CFrame = CFrame.lookAt((hand + tip) / 2, tip)
	stick.Color = Color3.fromRGB(120, 78, 46)
	stick.Parent = model
	local mallow = Instance.new("Part")
	mallow.Name = "Marshmallow"
	mallow.Shape = Enum.PartType.Cylinder
	mallow.Anchored = true
	mallow.CanCollide = false
	mallow.CanQuery = false
	mallow.Size = Vector3.new(0.6, 0.55, 0.55)
	mallow.CFrame = CFrame.lookAt(tip, tip + fireDir) * CFrame.Angles(0, math.rad(90), 0)
	mallow.Material = Enum.Material.SmoothPlastic
	mallow.Parent = model
	local raw = Color3.fromRGB(255, 252, 245)
	local toasted = Color3.fromRGB(205, 140, 70)
	while model.Parent do
		mallow.Color = raw
		for k = 1, 10 do
			task.wait(rng:NextNumber(1, 2))
			mallow.Color = raw:Lerp(toasted, k / 10)
		end
		if rng:NextNumber() < 0.35 then
			local oops = Instance.new("Fire")
			oops.Size = 1.5
			oops.Heat = 4
			oops.Parent = mallow
			mallow.Color = Color3.fromRGB(40, 30, 25)
			task.wait(2.5)
			oops:Destroy()
		end
		task.wait(rng:NextNumber(1, 3))
	end
end

-- Fishing on the dock: the bobber bobs, every now and then it dips, a fish jumps out, splash.
local function fisher(model: Model, spot: BasePart, bobber: BasePart)
	local _, root = settle(model, spot.CFrame, Assets.Animations.BotIdle)
	if not root then
		return
	end
	local rest = bobber:GetAttribute("Rest")
	local restPos = if typeof(rest) == "Vector3" then rest else bobber.Position
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
	splash.Size = NumberSequence.new(0.4, 0.1)
	splash.Lifetime = NumberRange.new(0.5, 0.9)
	splash.Speed = NumberRange.new(6, 10)
	splash.SpreadAngle = Vector2.new(40, 40)
	splash.Acceleration = Vector3.new(0, -25, 0)
	splash.Rate = 0
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Parent = bobber
	local fishColors =
		{ Color3.fromRGB(255, 150, 60), Color3.fromRGB(120, 190, 255), Color3.fromRGB(255, 210, 80) }
	while model.Parent do
		-- gentle bobbing while waiting
		local waitFor = rng:NextNumber(12, 25)
		local t0 = os.clock()
		while os.clock() - t0 < waitFor do
			bobber.CFrame = CFrame.new(restPos + Vector3.new(0, math.sin(os.clock() * 2) * 0.08, 0))
			task.wait(0.1)
		end
		-- a bite! dip, splash, and a fish flips out of the water onto the dock
		bobber.CFrame = CFrame.new(restPos - Vector3.new(0, 0.35, 0))
		splash:Emit(25)
		local fish = Instance.new("Part")
		fish.Name = "Fish"
		fish.Anchored = true
		fish.CanCollide = false
		fish.CanQuery = false
		fish.Size = Vector3.new(0.5, 0.8, 1.6)
		fish.Color = pick(fishColors)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = fish
		fish.Parent = model
		local from = restPos
		local to = root.Position + spot.CFrame.LookVector * 1.2 + Vector3.new(0, 0.5, 0)
		for k = 0, 20 do
			local f = k / 20
			local p = from:Lerp(to, f) + Vector3.new(0, math.sin(f * math.pi) * 5, 0)
			fish.CFrame = CFrame.lookAt(p, to) * CFrame.Angles(f * 12, 0, 0)
			task.wait(0.03)
		end
		task.wait(1.2)
		fish:Destroy()
		bobber.CFrame = CFrame.new(restPos)
	end
end

function Bots.start()
	local folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
	local world = workspace:WaitForChild("World")
	local fun = world:WaitForChild("Fun")
	local camp = fun:WaitForChild("Campsite")
	local lake = fun:WaitForChild("Lake")
	local seats: { BasePart } = {}
	for _, d in camp:GetChildren() do
		if d:IsA("BasePart") and d.Name == "CampSeat" then
			table.insert(seats, d)
		end
	end
	local spot = lake:FindFirstChild("FishSpot")
	local bobber = lake:FindFirstChild("Bobber")
	for i = 1, World.Bots do
		task.spawn(function()
			task.wait(i * 0.5) -- don't build them all in the same frame
			local bot = makeBot(i, folder)
			if not bot then
				return
			end
			local seat = seats[i]
			if seat then
				camper(bot, seat)
			elseif
				i == #seats + 1
				and spot
				and spot:IsA("BasePart")
				and bobber
				and bobber:IsA("BasePart")
			then
				fisher(bot, spot, bobber)
			else
				run(bot)
			end
		end)
	end
end

return Bots
