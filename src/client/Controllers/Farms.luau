--!strict
-- Social layer on every farm (design doc §6): the owner's best carrot floats on the pedestal (with a plaque),
-- big and glowing, for everyone walking past; other players' farms show "Tap to water!" when
-- you're close; and watering makes a splash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local SocialConfig = require(Shared.Config.Social)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local CarrotModel = require(script.Parent.Parent.Util.CarrotModel)

local player = Players.LocalPlayer

local Farms = {}

type FarmView = {
	model: Model,
	id: number,
	pedestal: BasePart?,
	carrot: Model?,
	carrotKey: string,
	label: Instance?,
	waterHint: BillboardGui?,
	center: Vector3,
}

local views: { FarmView } = {}
local fxFolder: Folder

local PEDESTAL_SCALE = 1.7 -- the trophy carrot is shown bigger than in the field
local MAX_TROPHY_SCALE = 4

local function str(inst: Instance, name: string): string
	local v = inst:GetAttribute(name)
	return if typeof(v) == "string" then v else ""
end

local function num(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function refreshPedestal(view: FarmView)
	local typeId = str(view.model, "BestType")
	local sizeId = str(view.model, "BestSize")
	local mutString = str(view.model, "BestMutations")
	local key = typeId .. "|" .. sizeId .. "|" .. mutString
	if key == view.carrotKey then
		return
	end
	view.carrotKey = key
	if view.carrot then
		view.carrot:Destroy()
		view.carrot = nil
	end
	if view.label then
		view.label:Destroy()
		view.label = nil
	end
	local pedestal = view.pedestal
	if typeId == "" or not pedestal then
		return
	end
	local mutations = if mutString == "" then {} else string.split(mutString, "+")
	local size = CarrotInfo.size(sizeId)
	local scale = math.min(MAX_TROPHY_SCALE, (if size then size.scale else 1) * PEDESTAL_SCALE)
	local model = CarrotModel.build(typeId, mutations, scale)
	model.Parent = fxFolder
	view.carrot = model

	local rarity = CarrotInfo.rarityOfType(typeId)
	local name = CarrotInfo.displayName({ type = typeId, size = sizeId, mutations = mutations })
	-- A tilted plaque in front of the pedestal, facing the plaza (a physical sign, not a label
	-- floating in the sky).
	local base = Vector3.new(pedestal.Position.X, 0, pedestal.Position.Z)
	local toMarket = if base.Magnitude > 0.1 then -base.Unit else Vector3.new(0, 0, -1)
	local plaquePos = base + toMarket * 5.2 + Vector3.new(0, 1.7, 0)
	local plaque = Instance.new("Part")
	plaque.Name = "TrophyPlaque"
	plaque.Anchored = true
	plaque.CanCollide = false
	plaque.CanQuery = false
	plaque.Size = Vector3.new(6.4, 2.4, 0.3)
	plaque.Material = Enum.Material.Wood
	plaque.Color = Color3.fromRGB(120, 78, 46)
	plaque.CFrame = CFrame.lookAt(plaquePos, plaquePos + toMarket) * CFrame.Angles(math.rad(28), 0, 0)
	plaque.Parent = fxFolder
	local leg = Instance.new("Part")
	leg.Name = "PlaqueLeg"
	leg.Anchored = true
	leg.CanCollide = false
	leg.CanQuery = false
	leg.Size = Vector3.new(0.4, 1.4, 0.4)
	leg.Material = Enum.Material.Wood
	leg.Color = Color3.fromRGB(120, 78, 46)
	leg.CFrame = CFrame.new(plaquePos - Vector3.new(0, 1.1, 0) - toMarket * 0.3)
	leg.Parent = plaque
	local surface: SurfaceGui = UI.new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		CanvasSize = Vector2.new(320, 120),
		LightInfluence = 0.2,
		MaxDistance = 120,
		Parent = plaque,
	})
	UI.new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundColor3 = Color3.fromRGB(255, 244, 222),
		Parent = surface,
	}, { UI.corner(10) })
	UI.bigText({
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 40),
		Text = string.format("%s's best", str(view.model, "OwnerName")),
		TextColor3 = Color3.fromRGB(120, 78, 46),
		Parent = surface,
	}, Color3.fromRGB(255, 255, 255), 0)
	UI.bigText({
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 46),
		Text = string.format("%s · %s", name, Format.cash(num(view.model, "BestValue"))),
		TextColor3 = CarrotInfo.rarityColor(rarity, os.clock()),
		Parent = surface,
	}, Color3.fromRGB(30, 20, 10), 2)
	local bb = plaque
	view.label = bb
end

local function ensureWaterHint(view: FarmView)
	if view.waterHint then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(view.center + Vector3.new(0, 11, 0))
	anchor.Parent = fxFolder
	local bb: BillboardGui = UI.new("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.new(12, 0, 2.2, 0),
		MaxDistance = SocialConfig.WaterRange,
		LightInfluence = 0,
		Enabled = false,
		Parent = anchor,
	})
	UI.bigText({
		Size = UDim2.fromScale(1, 1),
		Text = "💧 Tap plots to water! +10% growth for you both",
		TextColor3 = Color3.fromRGB(110, 210, 255),
	}, Color3.fromRGB(10, 60, 120), 2.5).Parent =
		bb
	view.waterHint = bb
end

local function splash(view: FarmView)
	for _, plot in view.model:GetDescendants() do
		if plot:IsA("BasePart") and plot:GetAttribute("PlotIndex") and plot:GetAttribute("Unlocked") then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = 0
			e.Color = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(220, 245, 255))
			e.LightEmission = 0.6
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Speed = NumberRange.new(5, 9)
			e.SpreadAngle = Vector2.new(40, 40)
			e.Acceleration = Vector3.new(0, -25, 0)
			e.Size = NumberSequence.new(0.5, 0)
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = plot
			e:Emit(14)
			task.delay(1.5, function()
				e:Destroy()
			end)
		end
	end
end

function Farms.start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "FarmFX"
	fxFolder.Parent = workspace

	local farmsFolder = workspace:WaitForChild("Farms")
	for _, model in farmsFolder:GetChildren() do
		if model:IsA("Model") then
			local id = model:GetAttribute("FarmId")
			local pedestal = model:FindFirstChild("PedestalTop", true)
			local view: FarmView = {
				model = model,
				id = if typeof(id) == "number" then id else 0,
				pedestal = if pedestal and pedestal:IsA("BasePart") then pedestal else nil,
				carrot = nil,
				carrotKey = "",
				label = nil,
				waterHint = nil,
				center = model:GetPivot().Position,
			}
			local ground = model:FindFirstChild("FarmGround")
			if ground and ground:IsA("BasePart") then
				view.center = ground.Position
			end
			table.insert(views, view)
			model.AttributeChanged:Connect(function(name)
				if string.sub(name, 1, 4) == "Best" or name == "OwnerName" then
					view.carrotKey = "" -- force rebuild (owner name in the label)
					refreshPedestal(view)
				end
			end)
			refreshPedestal(view)
			ensureWaterHint(view)
		end
	end

	Remotes.get(Remotes.Names.Watered).OnClientEvent:Connect(function(farmId: number, _byName: string)
		for _, view in views do
			if view.id == farmId then
				splash(view)
				Sound.play("Water", { parent = view.pedestal :: Instance? })
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local myFarm = player:GetAttribute("FarmId")
		for _, view in views do
			local pedestal = view.pedestal
			local carrot = view.carrot
			if carrot and pedestal then
				local length = CarrotModel.length(carrot)
				local base = pedestal.Position
					+ Vector3.new(0, 0.3 + length * 0.75 + math.sin(t * 1.6 + view.id) * 0.3, 0)
				carrot:PivotTo(CFrame.new(base) * CFrame.Angles(0, t * 0.8 + view.id, 0))
			end
			local hint = view.waterHint
			if hint then
				hint.Enabled = view.id ~= myFarm and num(view.model, "OwnerUserId") ~= 0
			end
		end
	end)
end

return Farms
