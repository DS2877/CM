--!strict
-- The market's public face (design doc §5). Two pieces, each answering one question:
--   * the big chalkboard next to the market: BOOM NOW / NEXT BOOM IN, a huge timer, what the
--     boom does and today's hot rarity. No price table: a player's question is "when do I sell?",
--     not "what is the base price of an Epic?". During a boom the board glows orange, the SELL
--     pads turn gold ("🔥 SELL!") and confetti pops over the roof.
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
local boardBg: Frame
local sellPads: { BasePart } = {}
local padLabels: { TextLabel } = {}
local confetti: ParticleEmitter? = nil
local PAD_GREEN = Color3.fromRGB(110, 200, 95)
local PAD_BOOM = Color3.fromRGB(255, 160, 40)
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

	-- Chalkboard next to the market (Market.PriceBoard, text on its back face = facing the plaza).
	-- Few, big lines: what's happening, how long, what it means for you.
	local market = world:WaitForChild("Market")
	local board = market:WaitForChild("PriceBoard") :: BasePart
	local sg: SurfaceGui = UI.new("SurfaceGui", {
		Name = "PriceBoard",
		Adornee = board,
		Face = Enum.NormalId.Back,
		CanvasSize = Vector2.new(480, 312),
		LightInfluence = 0.1,
		MaxDistance = 150,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	boardBg = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 66, 54),
		BorderSizePixel = 0,
		Parent = sg,
	})
	local pad = UI.new("Frame", {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -36, 1, -20),
		BackgroundTransparency = 1,
		Parent = sg,
	})
	kickerLabel = chalk({
		Size = UDim2.new(1, 0, 0, 52),
		Text = "NEXT BOOM IN",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = CHALK,
		Parent = pad,
	})
	timeLabel = chalk({
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 100),
		Text = "",
		Font = Enum.Font.LuckiestGuy,
		Parent = pad,
	})
	boomLabel = chalk({
		Position = UDim2.fromOffset(0, 162),
		Size = UDim2.new(1, 0, 0, 46),
		Text = "",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = HOT,
		Parent = pad,
	})
	hintLabel = chalk({
		Position = UDim2.fromOffset(0, 214),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextColor3 = CHALK,
		Parent = pad,
	})
	dailyLabel = chalk({
		Position = UDim2.fromOffset(0, 254),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 225, 120),
		Parent = pad,
	})

	-- SELL pads and their painted labels: they light up during a boom (local only)
	for _, d in market:GetChildren() do
		if d:IsA("BasePart") and d.Name == "SellPad" then
			table.insert(sellPads, d)
		elseif d:IsA("BasePart") and d.Name == "SellPlate" then
			local label = d:FindFirstChildWhichIsA("SurfaceGui")
			local text = label and label:FindFirstChildWhichIsA("TextLabel")
			if text then
				table.insert(padLabels, text)
			end
		end
	end
	-- Confetti over the market while a boom is on
	local roof = market:FindFirstChild("RoofTier")
	if roof and roof:IsA("BasePart") then
		confetti = Instance.new("ParticleEmitter")
		confetti.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 100)),
		})
		confetti.Size = NumberSequence.new(0.45)
		confetti.Lifetime = NumberRange.new(2, 3)
		confetti.Rate = 0
		confetti.Speed = NumberRange.new(10, 16)
		confetti.SpreadAngle = Vector2.new(70, 70)
		confetti.Acceleration = Vector3.new(0, -12, 0)
		confetti.Rotation = NumberRange.new(0, 360)
		confetti.RotSpeed = NumberRange.new(-200, 200)
		confetti.EmissionDirection = Enum.NormalId.Top
		confetti.LightEmission = 0.3
		confetti.Parent = roof
	end

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
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 5)
	if state.boomActive then
		local left = Format.duration(state.boomEnd - t)
		kickerLabel.Text = "🔥 BOOM! SELL NOW! 🔥"
		kickerLabel.TextColor3 = HOT
		timeLabel.Text = left
		timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		boomLabel.Text = state.boom.description
		boomLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
		hintLabel.Text = "Stand on a 💰 SELL pad – boom prices!"
		boardBg.BackgroundColor3 = Color3.fromRGB(150, 60, 20):Lerp(Color3.fromRGB(190, 85, 25), pulse)
		timerText.Text = "BOOM! " .. left
		timerText.TextColor3 = HOT
		timerFrame.BackgroundColor3 = Color3.fromRGB(150, 60, 10)
		for _, p in sellPads do
			p.Color = PAD_BOOM:Lerp(Color3.fromRGB(255, 220, 90), pulse)
		end
		for _, l in padLabels do
			l.Text = "🔥 SELL!"
		end
		if confetti then
			confetti.Rate = 25
		end
	else
		local left = Format.duration(state.boomStart - t)
		kickerLabel.Text = "NEXT BOOM IN"
		kickerLabel.TextColor3 = CHALK_DIM
		timeLabel.Text = left
		timeLabel.TextColor3 = CHALK
		boomLabel.Text = "Next: " .. state.boom.description
		boomLabel.TextColor3 = HOT
		hintLabel.Text = "Save your carrots and sell in the boom!"
		boardBg.BackgroundColor3 = Color3.fromRGB(40, 66, 54)
		timerText.Text = "BOOM " .. left
		timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		timerFrame.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
		for _, p in sellPads do
			p.Color = PAD_GREEN
		end
		for _, l in padLabels do
			l.Text = "💰 SELL"
		end
		if confetti then
			confetti.Rate = 0
		end
	end
	dailyLabel.Text = string.format("⭐ Today: %s carrots x%s", state.dailyRarity, tostring(state.dailyMult))
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
