--!strict
-- The Bunny Market's public face (design doc §5), all client-side rendering:
--   * BOOM EXCHANGE: the tower in the middle of the plaza has a screen on each side, like a
--     stock-exchange billboard: a scrolling ticker on top, NEXT BOOM IN + a big LED countdown,
--     and what the boom pays. During a boom the screens flash red/orange: "BOOM! BUNNIES PAY
--     MORE!" with the time left. Only true information (no fake prices): when do I sell, and
--     what is worth more.
--   * a compact floating timer above the tower ("BOOM 4:38"), readable from every farm.
--   * the giant bunny buyers: they breathe and look around, do a happy hop (bigger sale =
--     bigger hop) with hearts and "NOM NOM!" whenever anyone sells at their stall, and wear
--     party hats and bounce non-stop during a boom. The SELL mats turn gold in a boom.
--   * the market bell when a boom starts and a small pill that points the way while it's on.
-- All timing comes from the shared schedule (Market.state), so every client agrees.

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

local HOT = Color3.fromRGB(255, 176, 60)
local LED_GREEN = Color3.fromRGB(90, 255, 120)
local SCREEN_BG = Color3.fromRGB(16, 20, 30)
local MAT_GREEN = Color3.fromRGB(110, 200, 95)
local MAT_BOOM = Color3.fromRGB(255, 170, 40)

type Screen = {
	bg: Frame,
	ticker: TextLabel,
	kicker: TextLabel,
	time: TextLabel,
	boom: TextLabel,
}
type Bunny = {
	body: Model,
	head: Model,
	bodyBase: CFrame,
	headBase: CFrame,
	hat: { BasePart },
	mouth: BasePart?,
	hearts: ParticleEmitter?,
	hopStart: number,
	hopHeight: number,
	spin: boolean,
	phase: number,
	stall: Instance,
}

local screens: { Screen } = {}
local bunnies: { Bunny } = {}
local mats: { BasePart } = {}
local matLabels: { TextLabel } = {}
local confetti: ParticleEmitter? = nil
local timerText: TextLabel
local timerFrame: Frame
local arrow: TextLabel
local pointer: Frame
local pointerText: TextLabel
local marketPos = Vector3.new(0, 4, 0)
local boomOn = false
local tickerText = ""

local function now(): number
	return workspace:GetServerTimeNow()
end

local function buildScreen(part: BasePart, playerGui: PlayerGui): Screen
	local sg: SurfaceGui = UI.new("SurfaceGui", {
		Name = "BoomScreen",
		Adornee = part,
		Face = Enum.NormalId.Front,
		CanvasSize = Vector2.new(568, 328),
		LightInfluence = 0,
		Brightness = 1.4,
		MaxDistance = 400,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local bg = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = SCREEN_BG,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = sg,
	})
	-- Ticker strip
	local strip = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(255, 200, 50),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = bg,
	})
	local ticker = UI.new("TextLabel", {
		Size = UDim2.new(4, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(40, 25, 5),
		Text = "",
		Parent = strip,
	})
	local kicker = UI.new("TextLabel", {
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "NEXT BOOM IN",
		Parent = bg,
	})
	local time = UI.new("TextLabel", {
		Position = UDim2.fromOffset(16, 104),
		Size = UDim2.new(1, -32, 0, 140),
		BackgroundTransparency = 1,
		Font = Enum.Font.Arcade,
		TextScaled = true,
		TextColor3 = LED_GREEN,
		Text = "",
		Parent = bg,
	})
	local boom = UI.new("TextLabel", {
		Position = UDim2.fromOffset(16, 254),
		Size = UDim2.new(1, -32, 0, 60),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = HOT,
		Text = "",
		Parent = bg,
	})
	return { bg = bg, ticker = ticker, kicker = kicker, time = time, boom = boom }
end

local function addBunny(stall: Instance)
	local model = stall:FindFirstChild("BigBunny")
	local body = model and model:FindFirstChild("Body")
	local head = model and model:FindFirstChild("Head")
	if not body or not head or not body:IsA("Model") or not head:IsA("Model") then
		return
	end
	local bodyModel = body :: Model
	local headModel = head :: Model
	local hat: { BasePart } = {}
	local hatModel = headModel:FindFirstChild("PartyHat")
	if hatModel then
		for _, p in hatModel:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(hat, p)
			end
		end
	end
	local mouth = headModel:FindFirstChild("Mouth")
	local hearts: ParticleEmitter? = nil
	if mouth and mouth:IsA("BasePart") then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 220, 90))
		e.LightEmission = 0.5
		e.Size = NumberSequence.new(1.2, 0.2)
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(6, 10)
		e.SpreadAngle = Vector2.new(50, 50)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = mouth
		hearts = e
	end
	local bunny: Bunny = {
		body = bodyModel,
		head = headModel,
		bodyBase = bodyModel:GetPivot(),
		headBase = headModel:GetPivot(),
		hat = hat,
		mouth = if mouth and mouth:IsA("BasePart") then mouth else nil,
		hearts = hearts,
		hopStart = -10,
		hopHeight = 0,
		spin = false,
		phase = math.random() * 6,
		stall = stall,
	}
	table.insert(bunnies, bunny)
	-- Someone sold here: happy hop, hearts, NOM NOM
	stall:GetAttributeChangedSignal("SaleAt"):Connect(function()
		local count = stall:GetAttribute("SaleCount")
		local n = if typeof(count) == "number" then count else 1
		bunny.hopStart = os.clock()
		bunny.hopHeight = 1.5 + math.min(4, n / 10)
		bunny.spin = n >= 30
		if bunny.hearts then
			bunny.hearts:Emit(math.clamp(n, 8, 40))
		end
		local m = bunny.mouth
		if m then
			local bb = Instance.new("BillboardGui")
			bb.Adornee = m
			bb.Size = UDim2.new(5, 0, 1.2, 0)
			bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
			bb.AlwaysOnTop = false
			bb.LightInfluence = 0
			bb.MaxDistance = 60
			local l = UI.bigText({
				Size = UDim2.fromScale(1, 1),
				Text = if n >= 30 then "NOM NOM NOM! 😋" else "NOM NOM! 😋",
				TextColor3 = Color3.fromRGB(255, 230, 120),
				Parent = bb,
			}, Color3.fromRGB(90, 40, 0), 1.5)
			bb.Parent = player:WaitForChild("PlayerGui")
			UI.tween(bb, 1.4, { StudsOffsetWorldSpace = Vector3.new(0, 10, 0) })
			UI.tween(l, 1.4, { TextTransparency = 1 })
			task.delay(1.5, function()
				bb:Destroy()
			end)
		end
	end)
end

local function build()
	local world = workspace:WaitForChild("World")
	local anchor = world:WaitForChild("PriceBoardAnchor") :: BasePart
	marketPos = Vector3.new(anchor.Position.X, 4, anchor.Position.Z)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local market = world:WaitForChild("Market")
	local tower = market:WaitForChild("BoomTower")

	for i = 1, 4 do
		local part = tower:WaitForChild("Screen_" .. i) :: BasePart
		table.insert(screens, buildScreen(part, playerGui))
	end
	for i = 1, 4 do
		local stall = market:WaitForChild("Stall_" .. i, 10)
		if stall then
			addBunny(stall)
			for _, d in stall:GetChildren() do
				if d:IsA("BasePart") and d.Name == "SellPad" then
					table.insert(mats, d)
				elseif d:IsA("BasePart") and d.Name == "SellPlate" then
					local g = d:FindFirstChildWhichIsA("SurfaceGui")
					local l = g and g:FindFirstChildWhichIsA("TextLabel")
					if l then
						table.insert(matLabels, l)
					end
				end
			end
		end
	end

	-- Confetti from the tower top during a boom
	local top = tower:FindFirstChild("TowerHead")
	if top and top:IsA("BasePart") then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 100)),
		})
		e.Size = NumberSequence.new(0.5)
		e.Lifetime = NumberRange.new(2.5, 3.5)
		e.Rate = 0
		e.Speed = NumberRange.new(14, 22)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -12, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.EmissionDirection = Enum.NormalId.Top
		e.LightEmission = 0.3
		e.Parent = top
		confetti = e
	end

	-- Compact boom timer above the tower, readable from every farm
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
	-- Bunnies party in a boom, or when an admin starts a bunny dance
	local dance = workspace:GetAttribute("BunnyPartyUntil")
	boomOn = state.boomActive or (typeof(dance) == "number" and dance > t)
	local daily = string.format("TODAY: %s x%s", string.upper(state.dailyRarity), tostring(state.dailyMult))
	if state.boomActive then
		local left = Format.duration(state.boomEnd - t)
		tickerText = string.format(
			"🔥 BOOM!  ▲  %s  ▲  SELL ON A 🥕 MAT NOW  ▲  %s  ▲  ",
			string.upper(state.boom.description),
			daily
		)
		for _, s in screens do
			s.bg.BackgroundColor3 = Color3.fromRGB(140, 30, 20):Lerp(Color3.fromRGB(200, 90, 20), pulse)
			s.kicker.Text = "🔥 BOOM! BUNNIES PAY MORE! 🔥"
			s.kicker.TextColor3 = Color3.fromRGB(255, 240, 150)
			s.time.Text = left
			s.time.TextColor3 = Color3.fromRGB(255, 255, 255)
			s.boom.Text = state.boom.description .. " – SELL NOW!"
			s.boom.TextColor3 = Color3.fromRGB(255, 230, 90)
		end
		timerText.Text = "BOOM! " .. left
		timerText.TextColor3 = HOT
		timerFrame.BackgroundColor3 = Color3.fromRGB(150, 60, 10)
		for _, p in mats do
			p.Color = MAT_BOOM:Lerp(Color3.fromRGB(255, 225, 100), pulse)
		end
		for _, l in matLabels do
			l.Text = "🔥 SELL!"
		end
		if confetti then
			confetti.Rate = 30
		end
	else
		local left = Format.duration(state.boomStart - t)
		tickerText = string.format(
			"🐰 BUNNY EXCHANGE  ▲  NEXT BOOM: %s  ▲  %s  ▲  SAVE YOUR CARROTS FOR THE BOOM  ▲  ",
			string.upper(state.boom.description),
			daily
		)
		for _, s in screens do
			s.bg.BackgroundColor3 = SCREEN_BG
			s.kicker.Text = "NEXT BOOM IN"
			s.kicker.TextColor3 = Color3.fromRGB(255, 255, 255)
			s.time.Text = left
			s.time.TextColor3 = LED_GREEN
			s.boom.Text = "Next: " .. state.boom.description
			s.boom.TextColor3 = HOT
		end
		timerText.Text = "BOOM " .. left
		timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		timerFrame.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
		for _, p in mats do
			p.Color = MAT_GREEN
		end
		for _, l in matLabels do
			l.Text = "🥕 SELL"
		end
		if confetti then
			confetti.Rate = 0
		end
	end
	for _, s in screens do
		if s.ticker.Text ~= tickerText .. tickerText then
			s.ticker.Text = tickerText .. tickerText
		end
	end
	for _, b in bunnies do
		for _, p in b.hat do
			p.Transparency = if boomOn then 0 else 1
		end
	end
end

-- Every frame: ticker scroll and bunny animation (only when the plaza is near the camera).
local function animate()
	local clock = os.clock()
	for _, s in screens do
		local width = s.ticker.TextBounds.X / 2
		if width > 0 then
			local x = -((clock * 90) % width)
			s.ticker.Position = UDim2.fromOffset(x, 0)
		end
	end
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - marketPos).Magnitude > 220 then
		return
	end
	for _, b in bunnies do
		local lift, spin = 0, 0
		local k = (clock - b.hopStart) / 0.7
		if k >= 0 and k <= 1 then
			lift = math.sin(k * math.pi) * b.hopHeight
			if b.spin then
				spin = k * math.pi * 2
			end
		elseif boomOn then
			-- party mode: bouncing to the beat
			lift = math.abs(math.sin(clock * 5 + b.phase)) * 1.4
		end
		local breathe = math.sin(clock * 1.6 + b.phase) * 0.08
		local look = math.sin(clock * 0.5 + b.phase) * 0.25
		local tilt = math.sin(clock * 0.9 + b.phase) * 0.08
		local up = Vector3.new(0, lift, 0)
		local bodyCF = b.bodyBase + up
		b.body:PivotTo(bodyCF * CFrame.Angles(0, spin, 0) * CFrame.new(0, breathe, 0))
		-- head follows the body (rotate around the body center when spinning)
		local rel = b.bodyBase:ToObjectSpace(b.headBase)
		b.head:PivotTo(
			bodyCF * CFrame.Angles(0, spin, 0) * rel * CFrame.Angles(0, look, tilt)
				+ Vector3.new(0, breathe, 0)
		)
	end
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
	RunService.RenderStepped:Connect(animate)
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
				"The bunnies are hungry! Sell on a 🥕 mat for the boom price!",
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
