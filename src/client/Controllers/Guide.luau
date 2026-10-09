--!strict
-- The way to the fixed places in the world. Selling (the market's green circle) and upgrading
-- (an Upgrade Shop pad) are trips, so when one is the next thing to do, a glowing line runs from
-- your feet to it and a small bouncing marker sits on the spot:
--   * basket full (or a boom while you carry carrots) -> the market
--   * the next upgrade is affordable, or you tapped the goal bar -> the nearest Upgrade Shop
--   * the tutorial can force a target
-- The line hides once you're there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Market = require(Shared.Market)

local UI = require(script.Parent.Parent.Util.UI)
local HUD = require(script.Parent.HUD)
local Shop = require(script.Parent.Shop)

local player = Players.LocalPlayer

local Guide = {}

export type Target = "market" | "shop"

local MARKET_COLOR = Color3.fromRGB(120, 235, 100)
local SHOP_COLOR = Color3.fromRGB(90, 210, 255)

local override: Target? = nil
local requestedUntil = 0
local pads = World.upgradePads()

local anchor: Part
local targetAttachment: Attachment
local beam: Beam
local marker: BillboardGui
local markerText: TextLabel
local footAttachment: Attachment? = nil

function Guide.setOverride(target: Target?)
	override = target
end

-- Show the way to the Upgrade Shop for a while (goal bar tap).
function Guide.showShop()
	requestedUntil = os.clock() + 12
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function attrNumber(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function nearestPad(from: Vector3): Vector3
	local best, bestD = pads[1], math.huge
	for _, p in pads do
		local d = (Vector3.new(from.X, 0, from.Z) - p).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end

local function chooseTarget(): Target?
	if override then
		return override
	end
	if HUD.basketFull() then
		return "market"
	end
	local state = Market.state()
	if state.boomActive and attrNumber("BasketCount") > 0 then
		return "market"
	end
	if HUD.goalAffordable() or os.clock() < requestedUntil then
		return "shop"
	end
	return nil
end

local function build()
	anchor = Instance.new("Part")
	anchor.Name = "GuideTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = workspace.CurrentCamera
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor

	beam = Instance.new("Beam")
	beam.FaceCamera = true
	beam.Width0 = 0.9
	beam.Width1 = 1.6
	beam.LightEmission = 0.6
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.15, 0.3),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	beam.Attachment1 = targetAttachment
	beam.Enabled = false
	beam.Parent = anchor

	-- Small bouncing marker on the spot (glanceable floating info is fine; sized in studs)
	marker = UI.new("BillboardGui", {
		Name = "GuideMarker",
		Adornee = anchor,
		Size = UDim2.new(7, 0, 2.6, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
		LightInfluence = 0,
		AlwaysOnTop = true,
		Enabled = false,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	markerText = UI.bigText({
		Size = UDim2.fromScale(1, 0.55),
		Text = "",
		Parent = marker,
	}, Color3.fromRGB(10, 30, 10), 2.5)
	UI.bigText({
		Name = "Arrow",
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		Text = "⬇",
		Parent = marker,
	}, Color3.fromRGB(10, 30, 10), 2.5)
end

local function attachFoot()
	local root = rootPart()
	if not root then
		footAttachment = nil
		beam.Attachment0 = nil
		return
	end
	local a = root:FindFirstChild("GuideFoot")
	if not a then
		local att = Instance.new("Attachment")
		att.Name = "GuideFoot"
		att.Position = Vector3.new(0, -2.4, 0)
		att.Parent = root
		a = att
	end
	footAttachment = a :: Attachment
	beam.Attachment0 = footAttachment
end

local function update()
	local root = rootPart()
	if not root then
		beam.Enabled = false
		marker.Enabled = false
		return
	end
	if not footAttachment or footAttachment.Parent ~= root then
		attachFoot()
	end
	local target = chooseTarget()
	local pos: Vector3
	local arrived: boolean
	local here = Vector3.new(root.Position.X, 0, root.Position.Z)
	if target == "market" then
		pos = Vector3.zero
		arrived = here.Magnitude <= World.SellRadius + 2
	elseif target == "shop" then
		pos = nearestPad(root.Position)
		arrived = Shop.atShop(1)
	else
		beam.Enabled = false
		marker.Enabled = false
		return
	end
	if arrived then
		beam.Enabled = false
		marker.Enabled = false
		return
	end
	local color = if target == "market" then MARKET_COLOR else SHOP_COLOR
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	markerText.Text = if target == "market" then "SELL HERE 🧺" else "UPGRADES ⬆"
	markerText.TextColor3 = color
	-- Market: aim at the edge of the green circle nearest to you, not the middle of the stall
	if target == "market" and here.Magnitude > 0.1 then
		pos = here.Unit * (World.SellRadius - 2)
	end
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	beam.Enabled = true
	marker.Enabled = true
end

function Guide.start()
	build()
	HUD.setGoalTapHandler(function()
		if Shop.atShop(1) then
			HUD.toast("You're at the Upgrade Shop!", Color3.fromRGB(120, 245, 100))
			return
		end
		Guide.showShop()
		HUD.toast("Follow the line to the Upgrade Shop ⬆", SHOP_COLOR, 4)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			update()
		end
		if marker.Enabled then
			marker.StudsOffsetWorldSpace = Vector3.new(0, 6 + math.sin(os.clock() * 5) * 0.5, 0)
		end
	end)
end

return Guide
