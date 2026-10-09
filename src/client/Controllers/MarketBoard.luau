--!strict
-- The market's public face (design doc §5). Two pieces, each answering one question:
--   * the chalkboard on the market's easel (read up close): what's on now, when the next boom
--     comes, and today's hot rarity. No price table: a player's question is "when do I sell?",
--     not "what is the base price of an Epic?".
--   * a compact floating timer above the market statue (read from every farm): "BOOM 4:38", or
--     "BOOM! 2:31" in orange while it runs.
-- Plus the market bell when a boom starts and a small pill that points the way while it's on.
-- All timing comes from the shared EventSchedule, so every client and server agree.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Events = require(Config.Events)
local EventSchedule = require(Shared.EventSchedule)
local Market = require(Shared.Market)
local Format = require(Shared.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local MarketBoard = {}

local CHALK = Color3.fromRGB(245, 242, 230)
local CHALK_DIM = Color3.fromRGB(190, 205, 195)
local HOT = Color3.fromRGB(255, 176, 60)

local kickerLabel: TextLabel -- "NEXT BOOM IN" / "BOOM ON NOW!"
local timeLabel: TextLabel -- "4:38"
local boomLabel: TextLabel -- "Carrot Craze · ALL carrots x2"
local dailyLabel: TextLabel
local hintLabel: TextLabel
local timerText: TextLabel
local timerFrame: Frame
local arrow: TextLabel
local pointer: Frame
local pointerText: TextLabel
local marketPos = Vector3.new(0, 4, 0)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function chalk(props: { [string]: any }): TextLabel
	local l: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = CHALK,
	})
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function build()
	local world = workspace:WaitForChild("World")
	local anchor = world:WaitForChild("PriceBoardAnchor") :: BasePart
	marketPos = Vector3.new(anchor.Position.X, 4, anchor.Position.Z)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Chalkboard on the easel (Market.PriceBoard, text on its back face = the spawn side)
	local market = world:WaitForChild("Market")
	local board = market:WaitForChild("PriceBoard") :: BasePart
	local sg: SurfaceGui = UI.new("SurfaceGui", {
		Name = "PriceBoard",
		Adornee = board,
		Face = Enum.NormalId.Back,
		CanvasSize = Vector2.new(440, 290),
		LightInfluence = 0.15,
		MaxDistance = 120,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local pad = UI.new("Frame", {
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -44, 1, -28),
		BackgroundTransparency = 1,
		Parent = sg,
	})
	chalk({
		Size = UDim2.new(1, 0, 0, 34),
		Text = "🥕 CARROT MARKET",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = HOT,
		Parent = pad,
	})
	UI.new("Frame", {
		Position = UDim2.fromOffset(40, 42),
		Size = UDim2.new(1, -80, 0, 2),
		BackgroundColor3 = CHALK_DIM,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = pad,
	})
	kickerLabel = chalk({
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "NEXT BOOM IN",
		TextColor3 = CHALK_DIM,
		Parent = pad,
	})
	timeLabel = chalk({
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 70),
		Text = "",
		Font = Enum.Font.LuckiestGuy,
		Parent = pad,
	})
	boomLabel = chalk({
		Position = UDim2.fromOffset(0, 152),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextColor3 = HOT,
		Parent = pad,
	})
	dailyLabel = chalk({
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = CHALK_DIM,
		Parent = pad,
	})
	hintLabel = chalk({
		Position = UDim2.fromOffset(0, 230),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextColor3 = CHALK_DIM,
		Parent = pad,
	})

	-- Compact boom timer above the market statue, readable from every farm
	local bb: BillboardGui = UI.new("BillboardGui", {
		Name = "BoomTimer",
		Adornee = anchor,
		Size = UDim2.new(7, 0, 1.9, 0),
		LightInfluence = 0,
		MaxDistance = 320,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	timerFrame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 34, 48),
		BackgroundTransparency = 0.15,
		Parent = bb,
	}, { UI.corner(16), UI.stroke(Color3.fromRGB(255, 255, 255), 2, 0.6) })
	timerText = UI.bigText({
		Position = UDim2.fromScale(0.06, 0.12),
		Size = UDim2.fromScale(0.88, 0.76),
		Text = "",
		Parent = timerFrame,
	}, Color3.fromRGB(10, 10, 20), 2)

	-- Screen pill toward the market during a boom (sits under the goal bar)
	local arrowGui: ScreenGui = UI.new("ScreenGui", {
		Name = "MarketArrow",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Parent = playerGui,
	})
	UI.autoScale(arrowGui)
	-- Compact pill just under the top bar: [rotating arrow] MARKET BOOM! 45m
	-- Only the small arrow rotates; the text always stays upright.
	pointer = UI.new("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(200, 34),
		BackgroundColor3 = Color3.fromRGB(255, 160, 40),
		Visible = false,
		Parent = arrowGui,
	}, {
		UI.corner(17),
		UI.stroke(Color3.fromRGB(130, 55, 0), 2.5),
	})
	local circle = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = pointer,
	}, { UI.corner(13), UI.stroke(Color3.fromRGB(130, 55, 0), 2) })
	arrow = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Text = "▲",
		TextColor3 = Color3.fromRGB(255, 140, 30),
		Parent = circle,
	}, Color3.fromRGB(130, 55, 0), 1.5)
	pointerText = UI.bigText({
		Position = UDim2.fromOffset(36, 6),
		Size = UDim2.new(1, -44, 1, -12),
		Text = "MARKET BOOM!",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pointer,
	}, Color3.fromRGB(130, 55, 0), 2)
end

local function update(state: EventSchedule.State)
	local t = now()
	if state.boomActive then
		local left = Format.duration(state.boomEnd - t)
		kickerLabel.Text = "BOOM ON NOW! ENDS IN"
		kickerLabel.TextColor3 = HOT
		timeLabel.Text = left
		timeLabel.TextColor3 = HOT
		boomLabel.Text = string.format("%s · %s", state.boom.name, state.boom.description)
		hintLabel.Text = "Step on the green circle: boom prices now!"
		timerText.Text = "BOOM! " .. left
		timerText.TextColor3 = HOT
		timerFrame.BackgroundColor3 = Color3.fromRGB(150, 60, 10)
	else
		local left = Format.duration(state.boomStart - t)
		kickerLabel.Text = "NEXT BOOM IN"
		kickerLabel.TextColor3 = CHALK_DIM
		timeLabel.Text = left
		timeLabel.TextColor3 = CHALK
		boomLabel.Text = string.format("%s · %s", state.boom.name, state.boom.description)
		hintLabel.Text = "Step on the green circle to sell everything"
		timerText.Text = "BOOM " .. left
		timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		timerFrame.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
	end
	dailyLabel.Text =
		string.format("TODAY: %s carrots x%s everywhere", state.dailyRarity, tostring(state.dailyMult))
end

local function updateArrow(state: EventSchedule.State)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state.boomActive or not camera or not root or not root:IsA("BasePart") then
		pointer.Visible = false
		return
	end
	local offset = marketPos - (root :: BasePart).Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = flat.Magnitude
	if distance <= Events.MarketRadius then
		pointer.Visible = false
		return
	end
	-- Direction to the market relative to where the camera looks (0 = straight ahead = up).
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local dir = flat.Unit
	arrow.Rotation = math.deg(math.atan2(dir:Dot(right), dir:Dot(forward)))
	pointerText.Text = string.format("MARKET BOOM! %dm", math.floor(distance - Events.MarketRadius + 0.5))
	pointer.Visible = true
end

function MarketBoard.start()
	build()
	local lastBoomActive: boolean? = nil
	local lastCycle = -1
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		local state = Market.state()
		updateArrow(state)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		update(state)
		-- Market bell when a boom starts (not on join mid-boom: lastBoomActive starts nil)
		if lastBoomActive == false and state.boomActive and state.cycle ~= lastCycle then
			Sound.play("Bell")
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
			Sound.play("BoomEnd")
		end
		lastBoomActive = state.boomActive
		lastCycle = state.cycle
	end)
end

return MarketBoard
