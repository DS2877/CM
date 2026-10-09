--!strict
-- The guided first minute for brand-new players (server sets the "Tutorial" attribute). It reacts
-- to what the player actually does, never to timers, and points at the real thing:
--   1. a bouncing arrow over an empty plot: "Tap to plant!" (Basic Seeds are free and endless)
--   2. "Wait for it to grow…" then an arrow over the ready carrot: "Tap to harvest!"
--   3. the guide line to the market: "Step on a SELL pad to sell!"
--   4. an arrow on the Seeds tile: "Buy Lucky Seeds – more luck!"
--   5. the guide line to the Upgrade Shop: "Buy your first upgrade!"
-- Then a celebration, and the server is told it's done (never shown again). Target: the whole
-- core loop (plant -> grow -> harvest -> sell -> better seeds / upgrades) inside a few minutes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SeedsConfig = require(ReplicatedStorage.Shared.Config.Seeds)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local HUD = require(script.Parent.HUD)
local Guide = require(script.Parent.Guide)

local player = Players.LocalPlayer

local Tutorial = {}

local hint: TextLabel
local hintGui: ScreenGui
local worldArrow: BillboardGui
local screenArrow: TextLabel
local step = 0
local seedsDone = false

local function myPlots(): { BasePart }
	local farmId = player:GetAttribute("FarmId")
	local farms = workspace:FindFirstChild("Farms")
	local farm = farms and farms:FindFirstChild("Farm_" .. tostring(farmId))
	local out = {}
	if farm then
		for _, d in farm:GetDescendants() do
			if
				d:IsA("BasePart")
				and d:GetAttribute("PlotIndex") ~= nil
				and d:GetAttribute("Unlocked") == true
			then
				table.insert(out, d)
			end
		end
		table.sort(out, function(a, b)
			return (a:GetAttribute("PlotIndex") :: number) < (b:GetAttribute("PlotIndex") :: number)
		end)
	end
	return out
end

local function firstWithState(state: string): BasePart?
	for _, p in myPlots() do
		if p:GetAttribute("State") == state then
			return p
		end
	end
	return nil
end

local function say(text: string)
	if hint.Text ~= text then
		hint.Text = text
		UI.bump(hint, 0.15)
	end
end

local function pointAtPlot(part: BasePart?, label: string)
	if part then
		worldArrow.Adornee = part
		worldArrow.Enabled = true
		local l = worldArrow:FindFirstChild("Label") :: TextLabel
		l.Text = label
	else
		worldArrow.Enabled = false
	end
end

local function pointAtHud(name: string?)
	local target = name and HUD.element(name)
	if target then
		screenArrow.Parent = target
		screenArrow.Visible = true
	else
		screenArrow.Visible = false
	end
end

local soldOnce = false

-- The first seed above Basic (the cheapest step up the luck ladder)
local firstSeed: SeedsConfig.SeedDef? = nil
for _, s in SeedsConfig do
	if s.buyable and not s.mystery and (firstSeed == nil or s.basePrice < firstSeed.basePrice) then
		firstSeed = s
	end
end

local function boughtSeed(): boolean
	for name, v in player:GetAttributes() do
		if string.sub(name, 1, 5) == "Seed_" and typeof(v) == "number" and v > 0 then
			return true
		end
	end
	local selected = player:GetAttribute("SelectedSeed")
	return selected ~= nil and selected ~= "Basic"
end

local function cash(): number
	local c = player:GetAttribute("Cash")
	return if typeof(c) == "number" then c else 0
end

local function finish()
	step = 99
	Guide.setOverride(nil)
	worldArrow:Destroy()
	screenArrow:Destroy()
	say("You're a farmer now! Luckier seeds = rarer carrots! 🥕✨")
	Sound.play("Discover")
	HUD.banner("FARMER UNLOCKED!", Color3.fromRGB(120, 245, 100), 3)
	Remotes.get(Remotes.Names.TutorialDone):FireServer()
	task.delay(5, function()
		hintGui:Destroy()
	end)
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	hintGui = UI.new("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = playerGui,
	})
	UI.autoScale(hintGui)
	-- A dark-glass pill at the bottom center (free on phones: thumbstick left, jump right), so the
	-- hint never sits on top of signs or the farm.
	local pill = UI.new("Frame", {
		Name = "HintPill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(400, 40),
		BackgroundColor3 = Color3.fromRGB(25, 30, 45),
		BackgroundTransparency = 0.2,
		Parent = hintGui,
	}, { UI.corner(20), UI.stroke(Color3.fromRGB(255, 220, 90), 2) })
	hint = UI.bigText({
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.new(1, -28, 1, -14),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 120),
		Parent = pill,
	}, Color3.fromRGB(40, 25, 0), 2)

	-- Bouncing arrow in the world, over the plot to tap
	worldArrow = UI.new("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.new(4, 0, 4.4, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	UI.bigText({
		Name = "Label",
		Size = UDim2.fromScale(1, 0.3),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 120),
		Parent = worldArrow,
	}, Color3.fromRGB(40, 25, 0), 2.5)
	UI.bigText({
		Name = "Arrow",
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.fromScale(1, 0.7),
		Text = "⬇",
		TextColor3 = Color3.fromRGB(255, 220, 60),
		Parent = worldArrow,
	}, Color3.fromRGB(90, 50, 0), 3)

	-- Arrow that sits on a HUD element (parented to it)
	screenArrow = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(40, 40),
		Text = "⬇",
		TextColor3 = Color3.fromRGB(255, 220, 60),
		Visible = false,
		ZIndex = 20,
	}, Color3.fromRGB(90, 50, 0), 3)
end

local function update()
	local t = os.clock()
	if worldArrow and worldArrow.Parent then
		worldArrow.StudsOffsetWorldSpace = Vector3.new(0, 6 + math.sin(t * 5) * 0.6, 0)
	end
	if screenArrow and screenArrow.Parent then
		-- The goal bar is at the top of the screen: point up at it from below instead
		local under = screenArrow.Parent == HUD.element("goal")
		screenArrow.Text = if under then "⬆" else "⬇"
		screenArrow.AnchorPoint = if under then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
		local bob = math.sin(t * 6) * 5
		screenArrow.Position = if under then UDim2.new(0.5, 0, 1, 2 + bob) else UDim2.new(0.5, 0, 0, -2 - bob)
	end
	if step >= 99 then
		return
	end

	local empty = firstWithState("Empty")
	local ready = firstWithState("Ready")
	local basket = player:GetAttribute("BasketCount")
	local hasBasket = typeof(basket) == "number" and basket > 0
	local upgraded = false
	for name, v in player:GetAttributes() do
		if string.sub(name, 1, 4) == "Upg_" and typeof(v) == "number" and v >= 1 then
			upgraded = true
		end
	end

	if upgraded then
		finish()
	elseif soldOnce and (seedsDone or boughtSeed()) then
		-- 5. Upgrade: walk to the shop once it's affordable
		seedsDone = true
		step = 5
		pointAtHud(nil)
		if HUD.goalAffordable() then
			Guide.setOverride("shop")
			say("Follow the line to the Upgrade Shop and buy an upgrade! ⬆")
			pointAtPlot(nil, "")
		else
			Guide.setOverride(nil)
			say("Plant, harvest and sell more for your first upgrade!")
			pointAtPlot(ready or empty, if ready then "HARVEST!" else "PLANT")
		end
	elseif soldOnce then
		-- 4. Better seeds: more money spent = more luck (Basic stays free)
		step = 4
		Guide.setOverride(nil)
		local seed = firstSeed
		if seed and cash() >= seed.basePrice then
			say(string.format("Tap SEEDS and buy %ss – %dx luck!", seed.name, seed.luck))
			pointAtPlot(nil, "")
			pointAtHud("Seeds")
		else
			say("Sell a bit more – then try luckier seeds! Basic Seeds are free.")
			pointAtPlot(ready or empty, if ready then "HARVEST!" else "PLANT")
			pointAtHud(nil)
		end
	elseif hasBasket and (step == 3 or (not ready and not empty)) then
		-- 3. Sell: everything planted, carrots in the basket -> to the market
		step = 3
		Guide.setOverride("market")
		say("Follow the line to the market and step on a SELL pad to sell!")
		pointAtPlot(nil, "")
		pointAtHud(nil)
	elseif ready then
		step = 2
		say("It's ready! Walk to it and tap to harvest!")
		pointAtPlot(ready, "HARVEST!")
		pointAtHud(nil)
	elseif empty then
		step = 1
		say("Walk to a dirt plot and tap it to plant – seeds are free!")
		pointAtPlot(empty, "TAP!")
		pointAtHud(nil)
	else
		step = math.max(step, 1)
		say("Growing… a shimmer means something rare! ✨")
		pointAtPlot(nil, "")
		pointAtHud(nil)
	end
end

function Tutorial.start()
	if player:GetAttribute("Tutorial") ~= true then
		return
	end
	build()
	local lastBasket = 0
	player:GetAttributeChangedSignal("BasketCount"):Connect(function()
		local n = player:GetAttribute("BasketCount")
		local count = if typeof(n) == "number" then n else 0
		if lastBasket > 0 and count == 0 then
			soldOnce = true
		end
		lastBasket = count
	end)
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		if step >= 99 and not (hintGui and hintGui.Parent) then
			if conn then
				conn:Disconnect()
			end
			return
		end
		update()
	end)
end

return Tutorial
