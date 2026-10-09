--!strict
-- Renders every plot in the world from the attributes the server sets (all farms, so everyone
-- sees each other's carrots and light pillars), and turns taps on your own plots into
-- PlotAction intents. The client never decides what grows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local World = require(Config.World)
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local CarrotModel = require(script.Parent.Parent.Util.CarrotModel)
local RevealFX = require(script.Parent.RevealFX)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Plot = {}

type View = {
	part: BasePart,
	farmId: number,
	index: number,
	isMine: boolean,
	unlocked: boolean,
	state: string,
	plantedAt: number,
	growTime: number,
	tier: number,
	sprout: Model?,
	sproutScale: number,
	carrot: Model?,
	carrotBase: CFrame?,
	carrotScale: number,
	popStart: number?,
	reveal: RevealFX.Handle,
	dirt: ParticleEmitter?,
	billboard: BillboardGui?,
	inReach: boolean?,
	barFill: Frame?,
	barText: TextLabel?,
	bobPhase: number,
}

local views: { [BasePart]: View } = {}
local actOn: (view: View) -> ()
local fxFolder: Folder
local farmsFolder: Folder

local COLORS = {
	bar = Color3.fromRGB(110, 225, 80),
	ready = Color3.fromRGB(255, 210, 50),
	plant = Color3.fromRGB(80, 205, 255),
	plantPulse = Color3.fromRGB(140, 230, 255),
	outline = Color3.fromRGB(90, 50, 15),
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function myFarmId(): number
	local v = player:GetAttribute("FarmId")
	return if typeof(v) == "number" then v else -1
end

local function num(part: BasePart, name: string): number
	local v = part:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function str(part: BasePart, name: string): string
	local v = part:GetAttribute(name)
	return if typeof(v) == "string" then v else ""
end

local function plotTop(part: BasePart): Vector3
	return part.Position + Vector3.new(0, part.Size.Y / 2, 0)
end

-- Where a ready carrot of this size stands: shoulder above the soil, tip buried.
function Plot.readyCFrame(part: BasePart, length: number, index: number): CFrame
	local yaw = (index * 1.37) % (2 * math.pi)
	local tilt = math.rad(((index * 7) % 9) - 4)
	return CFrame.new(plotTop(part) + Vector3.new(0, length * 0.42, 0))
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(tilt, 0, 0)
end

local function tagModel(model: Model, view: View)
	model:SetAttribute("FarmId", view.farmId)
	model:SetAttribute("PlotIndex", view.index)
end

local function destroySprout(view: View)
	if view.sprout then
		view.sprout:Destroy()
		view.sprout = nil
	end
end

local function destroyCarrot(view: View)
	if view.carrot then
		view.carrot:Destroy()
		view.carrot = nil
		view.carrotBase = nil
	end
	view.popStart = nil
end

local function dirtPuff(view: View, amount: number)
	if not view.dirt then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Dirt"
		e.Rate = 0
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(140, 100, 65))
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Speed = NumberRange.new(4, 8)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Acceleration = Vector3.new(0, -20, 0)
		e.Size = NumberSequence.new(0.8, 0)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = view.part
		view.dirt = e
	end
	(view.dirt :: ParticleEmitter):Emit(amount)
end

local function ensureBillboard(view: View)
	if view.billboard or not view.isMine then
		return
	end
	local bb: BillboardGui = UI.new("BillboardGui", {
		Name = "PlotStatus",
		Adornee = view.part,
		-- Small pill: readable at farm distance without covering the plots next to it.
		Size = UDim2.new(3.2, 0, 0.8, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0),
		AlwaysOnTop = true,
		MaxDistance = 60,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- The label itself is a big tap target too.
	local bg: TextButton = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 250, 235),
		AutoButtonColor = false,
		Text = "",
		Parent = bb,
	}, { UI.corner(12), UI.stroke(COLORS.outline, 3) })
	bg.Activated:Connect(function()
		actOn(view)
	end)
	local fill = UI.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.bar,
		Parent = bg,
	}, { UI.corner(12) })
	local text = UI.bigText({
		Position = UDim2.fromScale(0.04, 0.12),
		Size = UDim2.fromScale(0.92, 0.76),
		Text = "",
		ZIndex = 2,
		Parent = bg,
	}, COLORS.outline, 2.5)
	view.billboard = bb
	view.inReach = nil
	view.barFill = fill
	view.barText = text
end

local function destroyBillboard(view: View)
	if view.billboard then
		view.billboard:Destroy()
		view.billboard = nil
		view.barFill = nil
		view.barText = nil
	end
end

local function setBar(view: View, fraction: number, text: string, color: Color3)
	if view.barFill and view.barText then
		view.barFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		view.barFill.BackgroundColor3 = color
		view.barText.Text = text
	end
end

local function buildReadyCarrot(view: View)
	destroySprout(view)
	destroyCarrot(view)
	local typeId = str(view.part, "Type")
	if typeId == "" then
		return
	end
	local sizeDef = CarrotInfo.size(str(view.part, "Size"))
	local scale = if sizeDef then sizeDef.scale else 1
	local mutString = str(view.part, "Mutations")
	local mutations = if mutString == "" then {} else string.split(mutString, "+")
	-- HD on your own farm, a lighter build on other farms (8 farms x 36 plots on a phone)
	local model = CarrotModel.build(typeId, mutations, scale, if view.isMine then "high" else "low")
	tagModel(model, view)
	local length = CarrotModel.length(model)
	view.carrotBase = Plot.readyCFrame(view.part, length, view.index)
	view.carrotScale = scale
	model:PivotTo(view.carrotBase :: CFrame)
	model.Parent = fxFolder
	view.carrot = model
	view.popStart = os.clock()
	if view.billboard then
		view.billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2 + length * 0.42 + 1.3 * scale, 0)
	end
	RevealFX.colorFor(view.reveal, str(view.part, "Rarity"))
end

local function ensureSprout(view: View)
	if view.sprout then
		return
	end
	local model = CarrotModel.sprout()
	tagModel(model, view)
	model:PivotTo(CFrame.new(plotTop(view.part)) * CFrame.Angles(0, view.index * 1.1, 0))
	model.Parent = fxFolder
	view.sprout = model
	view.sproutScale = 1
end

local function refresh(view: View)
	local part = view.part
	local unlocked = part:GetAttribute("Unlocked") == true
	local state = str(part, "State")
	local prevState = view.state
	view.unlocked = unlocked
	view.state = state
	view.plantedAt = num(part, "PlantedAt")
	view.growTime = math.max(0.1, num(part, "GrowTime"))
	view.tier = num(part, "RevealTier")
	view.isMine = view.farmId == myFarmId()

	if not unlocked then
		destroySprout(view)
		destroyCarrot(view)
		destroyBillboard(view)
		RevealFX.clear(view.reveal)
		return
	end

	if view.isMine then
		ensureBillboard(view)
	else
		destroyBillboard(view)
	end

	if prevState == "Ready" and state ~= "Ready" and view.carrot and not view.isMine then
		-- Someone else harvested: a small pop for spectators.
		dirtPuff(view, 10)
	end

	if state == "Ready" then
		if not view.carrot then
			buildReadyCarrot(view)
		end
		RevealFX.set(view.reveal, view.tier)
		RevealFX.colorFor(view.reveal, str(part, "Rarity"))
	elseif state == "Growing" then
		destroyCarrot(view)
		ensureSprout(view)
		RevealFX.set(view.reveal, 0)
		if view.billboard then
			view.billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
		end
	else
		destroyCarrot(view)
		destroySprout(view)
		RevealFX.clear(view.reveal)
		if view.billboard then
			view.billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
		end
	end
end

local function addPlot(part: BasePart)
	if views[part] then
		return
	end
	local rawFarm = part:GetAttribute("FarmId")
	local rawIndex = part:GetAttribute("PlotIndex")
	if typeof(rawFarm) ~= "number" or typeof(rawIndex) ~= "number" then
		return
	end
	local farmId, index = rawFarm :: number, rawIndex :: number
	local view: View = {
		part = part,
		farmId = farmId,
		index = index,
		isMine = false,
		unlocked = false,
		state = "",
		plantedAt = 0,
		growTime = 1,
		tier = 0,
		sprout = nil,
		sproutScale = 1,
		carrot = nil,
		carrotBase = nil,
		carrotScale = 1,
		popStart = nil,
		reveal = RevealFX.new(part, fxFolder),
		dirt = nil,
		billboard = nil,
		barFill = nil,
		barText = nil,
		bobPhase = index * 0.9 + farmId,
	}
	views[part] = view
	part.AttributeChanged:Connect(function(name)
		if name == "State" or name == "Unlocked" or name == "PlantedAt" or name == "Type" then
			refresh(view)
		end
	end)
	refresh(view)
end

local function myRootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- You walk to a plot to plant or harvest it (the server checks the same distance).
local function reachable(view: View, rootPos: Vector3?): boolean
	if not rootPos then
		return false
	end
	local q = view.part.Position
	return Vector3.new(rootPos.X - q.X, 0, rootPos.Z - q.Z).Magnitude <= World.PlotReach
end

-- Plots in reach get a big, bright button; the rest a small, dimmer status pill.
local function styleReach(view: View, inReach: boolean)
	local bb = view.billboard
	if not bb or view.inReach == inReach then
		return
	end
	view.inReach = inReach
	bb.Size = if inReach then UDim2.new(4.2, 0, 1.15, 0) else UDim2.new(3.4, 0, 0.9, 0)
	local button = bb:FindFirstChildOfClass("TextButton")
	if button then
		button.BackgroundTransparency = if inReach then 0 else 0.35
	end
end

local function backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function update()
	local t = now()
	local clock = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local rootPos = myRootPosition()

	for _, view in views do
		if not view.unlocked then
			continue
		end
		if view.billboard then
			styleReach(view, reachable(view, rootPos))
		end
		local near = (view.part.Position - camPos).Magnitude < 220

		if view.state == "Growing" then
			local progress = math.clamp((t - view.plantedAt) / view.growTime, 0, 1)
			-- Reveal escalates with growth, up to what the roll actually is.
			local level = 0
			for i, threshold in RevealFX.Thresholds do
				if progress >= threshold and view.tier >= i then
					level = i
				end
			end
			RevealFX.set(view.reveal, level)

			local sprout = view.sprout
			if sprout and near then
				-- Four visible phases; quantized so we don't rescale every frame.
				local target = math.floor((0.35 + 0.65 * progress) * 16 + 0.5) / 16
				if target ~= view.sproutScale then
					sprout:ScaleTo(target)
					sprout:PivotTo(CFrame.new(plotTop(view.part)) * CFrame.Angles(0, view.index * 1.1, 0))
					view.sproutScale = target
				end
				CarrotModel.setShoulderVisible(sprout, progress >= 0.5)
			end
			if view.billboard then
				local left = math.max(0, view.plantedAt + view.growTime - t)
				if progress >= 1 then
					setBar(view, 1, "READY!", COLORS.ready)
				else
					setBar(view, progress, Format.duration(left), COLORS.bar)
				end
			end
		elseif view.state == "Ready" then
			local carrot = view.carrot
			local base = view.carrotBase
			if carrot and base and near then
				if view.popStart then
					local k = math.clamp((clock - view.popStart) / 0.4, 0, 1)
					local s = view.carrotScale * math.max(0.05, 0.3 + 0.7 * backOut(k))
					carrot:ScaleTo(s)
					local rise = (1 - k) * -CarrotModel.length(carrot) * 0.4
					carrot:PivotTo(base * CFrame.new(0, rise, 0))
					if k >= 1 then
						view.popStart = nil
					end
				else
					local bob = math.sin(clock * 3 + view.bobPhase) * 0.12
					carrot:PivotTo(
						base
							* CFrame.new(0, bob, 0)
							* CFrame.Angles(0, math.sin(clock * 1.3 + view.bobPhase) * 0.12, 0)
					)
				end
			end
			RevealFX.animate(view.reveal, clock)
			if view.billboard then
				local pulse = 0.5 + 0.5 * math.sin(clock * 6)
				local rarity = CarrotInfo.rarity(str(view.part, "Rarity"))
				local color = COLORS.ready
				local text = "HARVEST!"
				if rarity and rarity.order >= 2 then
					color = CarrotInfo.rarityColor(rarity, clock, true)
					text = string.upper(rarity.name) .. "!"
				end
				setBar(view, 1, text, color:Lerp(Color3.new(1, 1, 1), pulse * 0.35))
			end
		else
			if view.billboard then
				local pulse = 0.5 + 0.5 * math.sin(clock * 4 + view.index)
				setBar(view, 1, "PLANT", COLORS.plant:Lerp(COLORS.plantPulse, pulse))
			end
		end
	end
end

-- Find which of my plots a tap refers to. Taps slightly outside a plot still count.
local lastWater = 0

local function resolveTap(screenPos: Vector2): View?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { farmsFolder, fxFolder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not result then
		return nil
	end
	local mine = myFarmId()

	-- Direct hit on a plot or a carrot standing on it
	local inst: Instance? = result.Instance
	while inst and inst ~= workspace do
		local farmId = inst:GetAttribute("FarmId")
		local index = inst:GetAttribute("PlotIndex")
		if typeof(farmId) == "number" and typeof(index) == "number" then
			if farmId ~= mine then
				-- Someone else's plot: water their farm (the server checks range and cooldown).
				local farm = farmsFolder:FindFirstChild("Farm_" .. farmId)
				local owner = farm and farm:GetAttribute("OwnerUserId")
				if typeof(owner) == "number" and owner ~= 0 and os.clock() - lastWater > 1 then
					lastWater = os.clock()
					Remotes.get(Remotes.Names.WaterFarm):FireServer(farmId)
				end
				return nil
			end
			for _, view in views do
				if view.farmId == farmId and view.index == index and view.unlocked then
					return view
				end
			end
			return nil
		end
		inst = inst.Parent
	end

	-- Near miss: nearest of my plots within a small margin
	local best: View? = nil
	local bestDist = World.PlotSize / 2 + 2
	for _, view in views do
		if view.isMine and view.unlocked then
			local offset = result.Position - view.part.Position
			local d = math.max(math.abs(offset.X), math.abs(offset.Z))
			if d < bestDist then
				best, bestDist = view, d
			end
		end
	end
	return best
end

local lastTap = 0
function actOn(view: View)
	-- Ignore accidental double-fire from touch + mouse emulation
	local clock = os.clock()
	if clock - lastTap < 0.05 then
		return
	end
	lastTap = clock
	if not reachable(view, myRootPosition()) then
		Sound.play("Denied")
		pcall(HUD.toast, "Walk over to that plot first! 🚶", nil, 1.5)
		return
	end
	if view.state == "Empty" then
		Sound.play("Plant")
		dirtPuff(view, 8)
	end
	if view.billboard then
		local button = view.billboard:FindFirstChildOfClass("TextButton")
		if button then
			UI.bump(button, 0.12)
		end
	end
	Remotes.get(Remotes.Names.PlotAction):FireServer(view.index)
end

local function onTap(screenPos: Vector2)
	local view = resolveTap(screenPos)
	if view then
		actOn(view)
	end
end

-- My plot part for an index (for effects).
function Plot.myPlot(index: number): BasePart?
	local mine = myFarmId()
	for part, view in views do
		if view.farmId == mine and view.index == index then
			return part
		end
	end
	return nil
end

-- Called by HarvestFX so the harvested carrot vanishes instantly (it plays its own flourish).
function Plot.hideCarrot(index: number)
	local part = Plot.myPlot(index)
	local view = part and views[part]
	if view then
		destroyCarrot(view)
		dirtPuff(view, 14)
	end
end

function Plot.fxFolder(): Folder
	return fxFolder
end

function Plot.start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = workspace

	farmsFolder = workspace:WaitForChild("Farms") :: Folder
	for _, d in farmsFolder:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PlotIndex") ~= nil then
			addPlot(d)
		end
	end
	farmsFolder.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d:GetAttribute("PlotIndex") ~= nil then
			addPlot(d)
		end
	end)

	player:GetAttributeChangedSignal("FarmId"):Connect(function()
		for _, view in views do
			refresh(view)
		end
	end)

	RunService.Heartbeat:Connect(update)

	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			onTap(position)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onTap(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
end

return Plot
