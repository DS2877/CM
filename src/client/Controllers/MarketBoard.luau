--!strict
-- The market's public face (design doc §5): a big price board above the kiosk with today's
-- prices and the boom countdown, a market bell everyone hears when a boom starts, and an arrow
-- that points the way to the market while a boom is on. All timing comes from the shared
-- EventSchedule, so every client shows the same countdown as every server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Events = require(Config.Events)
local Rarity = require(Config.Rarity)
local EventSchedule = require(Shared.EventSchedule)
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local MarketBoard = {}

local cfg: EventSchedule.EventsConfig = Events :: any

type Row = { rarity: Rarity.RarityDef, price: TextLabel, change: TextLabel }

local statusLabel: TextLabel
local nextLabel: TextLabel
local dailyLabel: TextLabel
local rows: { Row } = {}
local arrow: TextLabel
local marketPos = Vector3.new(0, 4, 0)

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Multiplier for a whole rarity right now at the market (sizes/mutations aside).
local function rarityMult(state: EventSchedule.State, rarityId: string): number
	local m = if rarityId == state.dailyRarity then state.dailyMult else 1
	if state.boomActive then
		local b = state.boom
		if b.kind == "all" or (b.kind == "rarity" and b.targets and table.find(b.targets, rarityId)) then
			m *= b.mult
		end
	end
	return m
end

local function build()
	local anchor = workspace:WaitForChild("World"):WaitForChild("PriceBoardAnchor") :: BasePart
	marketPos = Vector3.new(anchor.Position.X, 4, anchor.Position.Z)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local bb: BillboardGui = UI.new("BillboardGui", {
		Name = "PriceBoard",
		Adornee = anchor,
		Size = UDim2.new(22, 0, 15, 0),
		LightInfluence = 0,
		MaxDistance = 260,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 248, 230),
		Parent = bb,
	}, { UI.corner(18), UI.stroke(Color3.fromRGB(150, 70, 0), 4) })
	local header = UI.new("Frame", {
		Size = UDim2.fromScale(1, 0.17),
		BackgroundColor3 = Color3.fromRGB(255, 160, 40),
		Parent = frame,
	}, { UI.corner(18) })
	UI.bigText({
		Position = UDim2.fromScale(0.03, 0.08),
		Size = UDim2.fromScale(0.94, 0.84),
		Text = "🥕 MARKET PRICES",
		Parent = header,
	}, Color3.fromRGB(110, 50, 0), 3)
	statusLabel = UI.bigText({
		Position = UDim2.fromScale(0.03, 0.18),
		Size = UDim2.fromScale(0.94, 0.11),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 90, 60),
		Parent = frame,
	}, Color3.fromRGB(90, 20, 0), 2.5)
	nextLabel = UI.label({
		Position = UDim2.fromScale(0.03, 0.29),
		Size = UDim2.fromScale(0.94, 0.07),
		Text = "",
		TextColor3 = Color3.fromRGB(110, 80, 50),
		Parent = frame,
	})
	dailyLabel = UI.label({
		Position = UDim2.fromScale(0.03, 0.36),
		Size = UDim2.fromScale(0.94, 0.07),
		Text = "",
		TextColor3 = Color3.fromRGB(60, 140, 60),
		Parent = frame,
	})
	local rowH = 0.52 / #Rarity
	for i, r in Rarity do
		local y = 0.45 + (i - 1) * rowH
		local color = CarrotInfo.color(r.color)
		UI.bigText({
			Position = UDim2.fromScale(0.05, y),
			Size = UDim2.fromScale(0.42, rowH * 0.9),
			Text = r.name,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}, color:Lerp(Color3.new(0, 0, 0), 0.6), 2)
		local price = UI.bigText({
			Position = UDim2.fromScale(0.45, y),
			Size = UDim2.fromScale(0.27, rowH * 0.9),
			Text = Format.cash(r.baseValue),
			TextColor3 = Color3.fromRGB(70, 60, 50),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		}, Color3.fromRGB(255, 255, 255), 1.5)
		local change = UI.bigText({
			Position = UDim2.fromScale(0.74, y),
			Size = UDim2.fromScale(0.22, rowH * 0.9),
			Text = "",
			TextColor3 = Color3.fromRGB(60, 190, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}, Color3.fromRGB(10, 70, 10), 1.5)
		table.insert(rows, { rarity = r, price = price, change = change })
	end

	-- Screen arrow toward the market during a boom (sits under the goal bar)
	local arrowGui: ScreenGui = UI.new("ScreenGui", {
		Name = "MarketArrow",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Parent = playerGui,
	})
	UI.autoScale(arrowGui)
	arrow = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(64, 64),
		Text = "⬆",
		TextColor3 = Color3.fromRGB(255, 210, 40),
		Visible = false,
		Parent = arrowGui,
	}, Color3.fromRGB(120, 60, 0), 3.5)
	UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(170, 20),
		Text = "MARKET BOOM!",
		TextColor3 = Color3.fromRGB(255, 120, 60),
		Parent = arrow,
	}, Color3.fromRGB(90, 20, 0), 2)
end

local function update(state: EventSchedule.State)
	local t = now()
	if state.boomActive then
		statusLabel.Text = string.format(
			"🔔 %s! %s · %s left",
			state.boom.name,
			state.boom.description,
			Format.duration(state.boomEnd - t)
		)
		nextLabel.Text = "Sell HERE for the boom price!"
	else
		statusLabel.Text = string.format("Next boom in %s", Format.duration(state.boomStart - t))
		nextLabel.Text = string.format("Coming up: %s – %s", state.boom.name, state.boom.description)
	end
	dailyLabel.Text = string.format(
		"Today's market: %s carrots x%s everywhere",
		state.dailyRarity,
		tostring(state.dailyMult)
	)
	for _, row in rows do
		local m = rarityMult(state, row.rarity.id)
		row.price.Text = Format.cash(math.floor(row.rarity.baseValue * m + 0.5))
		row.change.Text = if m > 1 then "▲ x" .. tostring(math.floor(m * 100 + 0.5) / 100) else "●"
		row.change.TextColor3 = if m > 1 then Color3.fromRGB(60, 200, 60) else Color3.fromRGB(170, 160, 150)
	end
end

local function updateArrow(state: EventSchedule.State)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state.boomActive or not camera or not root or not root:IsA("BasePart") then
		arrow.Visible = false
		return
	end
	local offset = marketPos - (root :: BasePart).Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Events.MarketRadius then
		arrow.Visible = false
		return
	end
	-- Direction to the market relative to where the camera looks (0 = straight ahead = up).
	local rel = camera.CFrame:VectorToObjectSpace(offset)
	local angle = math.deg(math.atan2(rel.X, -rel.Z))
	arrow.Rotation = angle
	arrow.Visible = true
end

function MarketBoard.start()
	build()
	local lastBoomActive: boolean? = nil
	local lastCycle = -1
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		local state = EventSchedule.at(now(), cfg)
		updateArrow(state)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		update(state)
		-- Market bell when a boom starts (not on join mid-boom: lastBoomActive starts nil)
		if lastBoomActive == false and state.boomActive and state.cycle ~= lastCycle then
			Sound.play("Bell", { volume = 0.9 })
			HUD.banner(
				string.format("🔔 MARKET BOOM! %s", state.boom.description),
				Color3.fromRGB(255, 170, 40),
				5
			)
			HUD.toast(
				"Run to the market and sell your basket for the boom price!",
				Color3.fromRGB(255, 220, 90),
				5
			)
		end
		if lastBoomActive == true and not state.boomActive then
			HUD.toast("The boom is over – next one in " .. Format.duration(state.boomStart - now()), nil, 4)
		end
		lastBoomActive = state.boomActive
		lastCycle = state.cycle
	end)
end

return MarketBoard
