--!strict
-- Mobile-first HUD: cash (with count-up), goal bar for the next purchase, big SELL button,
-- UPGRADES button, toasts and server banners. Everything is a large tap target; nothing needs
-- hover or a keyboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Upgrades = require(Config.Upgrades)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local HUD = {}
HUD.foundTypes = {} :: { [string]: boolean }

local COLORS = {
	panel = Color3.fromRGB(30, 30, 40),
	cash = Color3.fromRGB(120, 235, 110),
	sell = Color3.fromRGB(70, 200, 90),
	sellDark = Color3.fromRGB(30, 120, 50),
	upgrade = Color3.fromRGB(255, 170, 50),
	upgradeDark = Color3.fromRGB(170, 90, 20),
	goalFill = Color3.fromRGB(255, 200, 60),
	good = Color3.fromRGB(120, 235, 110),
	bad = Color3.fromRGB(255, 110, 110),
	info = Color3.fromRGB(255, 255, 255),
}

local gui: ScreenGui
local fxGui: ScreenGui
local fxRoot: Frame
local cashLabel: TextLabel
local cashPill: Frame
local goalButton: TextButton
local goalFill: Frame
local goalLabel: TextLabel
local sellButton: TextButton
local sellValue: TextLabel
local sellCount: TextLabel
local upgradesButton: TextButton
local toastList: Frame
local bannerLabel: TextLabel

local shownCash = 0
local targetCash = 0
local openShop: (() -> ())? = nil

local function attrNumber(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

-- Cheapest enabled upgrade the player can work toward right now.
function HUD.nextGoal(): (Upgrades.UpgradeDef?, number, number)
	local best: Upgrades.UpgradeDef? = nil
	local bestCost = math.huge
	local bestLevel = 0
	for _, track in Upgrades do
		if track.enabled then
			local level = attrNumber("Upg_" .. track.id)
			if not Progression.isMaxed(track, level) then
				local cost = Progression.cost(track, level)
				if cost < bestCost then
					best, bestCost, bestLevel = track, cost, level
				end
			end
		end
	end
	return best, bestCost, bestLevel
end

local function refreshGoal()
	local track, cost, level = HUD.nextGoal()
	local cash = attrNumber("Cash")
	if not track then
		goalLabel.Text = "All upgrades maxed!"
		goalFill.Size = UDim2.fromScale(1, 1)
		return
	end
	local progress = math.clamp(cash / cost, 0, 1)
	UI.tween(goalFill, 0.25, { Size = UDim2.fromScale(progress, 1) })
	local name = string.format("%s %d", track.name, level + 1)
	if cash >= cost then
		goalLabel.Text = name .. " – TAP TO BUY!"
		goalFill.BackgroundColor3 = COLORS.good
	else
		local basket = attrNumber("BasketValue")
		if cash + basket >= cost then
			goalLabel.Text = name .. " – sell carrots to afford!"
		else
			goalLabel.Text = string.format("%s – %s left", name, Format.cash(cost - cash))
		end
		goalFill.BackgroundColor3 = COLORS.goalFill
	end
end

local function refreshSell()
	local count = attrNumber("BasketCount")
	local value = attrNumber("BasketValue")
	local cap = attrNumber("BasketCapacity")
	sellValue.Text = Format.cash(value)
	sellCount.Text = if cap > 0 then string.format("%d / %d carrots", count, cap) else tostring(count)
	local empty = count == 0
	sellButton.BackgroundColor3 = if empty then Color3.fromRGB(90, 110, 95) else COLORS.sell
	sellButton.AutoButtonColor = not empty
end

local function onCashChanged()
	targetCash = attrNumber("Cash")
	refreshGoal()
end

local function screenScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(844, 390)
	return math.clamp(math.min(size.X / 900, size.Y / 420), 0.7, 1.35)
end

local function makeButton(props: { [string]: any }, color: Color3, dark: Color3): TextButton
	local base: { [string]: any } = {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
		BorderSizePixel = 0,
	}
	for k, v in props do
		base[k] = v
	end
	local b: TextButton = UI.new("TextButton", base, {
		UI.corner(16),
		UI.stroke(dark, 3),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
			Rotation = 90,
		}),
	})
	return b
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	gui = UI.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local scale: UIScale = UI.new("UIScale", { Parent = gui })
	scale.Scale = screenScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scale.Scale = screenScale()
		end)
	end

	-- Cash pill (top center)
	cashPill = UI.new("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(230, 50),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		UI.corner(25),
		UI.stroke(Color3.fromRGB(15, 15, 20), 2),
	})
	UI.new("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = COLORS.cash,
		Parent = cashPill,
	}, {
		UI.corner(19),
		UI.stroke(Color3.fromRGB(30, 110, 30), 2),
		UI.label({
			Size = UDim2.fromScale(1, 1),
			Text = "$",
			TextColor3 = Color3.fromRGB(20, 80, 20),
		}),
	})
	cashLabel = UI.label({
		Name = "Amount",
		Position = UDim2.fromOffset(50, 6),
		Size = UDim2.new(1, -60, 1, -12),
		Text = "$0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.cash,
		Parent = cashPill,
	})
	UI.textStroke(Color3.fromRGB(10, 40, 10), 2).Parent = cashLabel

	-- Goal bar (next purchase)
	goalButton = UI.new("TextButton", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.15,
		AutoButtonColor = true,
		Text = "",
		Parent = gui,
	}, {
		UI.corner(17),
		UI.stroke(Color3.fromRGB(15, 15, 20), 2),
	})
	local fillClip = UI.new("Frame", {
		Name = "Clip",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = goalButton,
	}, { UI.corner(13) })
	goalFill = UI.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.goalFill,
		BackgroundTransparency = 0.25,
		Parent = fillClip,
	}, { UI.corner(13) })
	goalLabel = UI.label({
		Name = "Text",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		Text = "",
		ZIndex = 2,
		Parent = goalButton,
	})
	UI.textStroke(Color3.fromRGB(20, 20, 20), 1.5).Parent = goalLabel

	-- Toasts under the goal bar
	toastList = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 102),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Server banner
	bannerLabel = UI.label({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(640, 44),
		Text = "",
		TextTransparency = 1,
		Parent = gui,
	})
	local bannerStroke = UI.textStroke(Color3.new(0, 0, 0), 3)
	bannerStroke.Name = "Stroke"
	bannerStroke.Transparency = 1
	bannerStroke.Parent = bannerLabel

	-- SELL button (right side, above the jump button)
	sellButton = makeButton({
		Name = "Sell",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.4, 0),
		Size = UDim2.fromOffset(150, 84),
		Parent = gui,
	}, COLORS.sell, COLORS.sellDark)
	local sellTitle = UI.label({
		Size = UDim2.new(1, -12, 0, 30),
		Position = UDim2.fromOffset(6, 4),
		Text = "SELL",
		Parent = sellButton,
	})
	UI.textStroke(COLORS.sellDark, 2.5).Parent = sellTitle
	sellValue = UI.label({
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 33),
		Text = "$0",
		TextColor3 = Color3.fromRGB(240, 255, 220),
		Parent = sellButton,
	})
	UI.textStroke(COLORS.sellDark, 2).Parent = sellValue
	sellCount = UI.label({
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.fromOffset(6, 61),
		Text = "",
		TextColor3 = Color3.fromRGB(225, 245, 215),
		Parent = sellButton,
	})
	UI.textStroke(COLORS.sellDark, 1.5).Parent = sellCount

	-- UPGRADES button (left side, above the thumbstick)
	upgradesButton = makeButton({
		Name = "Upgrades",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.4, 0),
		Size = UDim2.fromOffset(120, 84),
		Parent = gui,
	}, COLORS.upgrade, COLORS.upgradeDark)
	local upArrow = UI.label({
		Size = UDim2.new(1, -12, 0, 36),
		Position = UDim2.fromOffset(6, 6),
		Text = "▲",
		Parent = upgradesButton,
	})
	UI.textStroke(COLORS.upgradeDark, 2.5).Parent = upArrow
	local upText = UI.label({
		Size = UDim2.new(1, -12, 0, 30),
		Position = UDim2.fromOffset(6, 46),
		Text = "UPGRADES",
		Parent = upgradesButton,
	})
	UI.textStroke(COLORS.upgradeDark, 2).Parent = upText

	-- Effects layer: full viewport, used for flying icons
	fxGui = UI.new("ScreenGui", {
		Name = "HUD_FX",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	fxRoot = UI.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = fxGui,
	})
end

function HUD.toast(text: string, color: Color3?, seconds: number?)
	local holder = UI.new("Frame", {
		Size = UDim2.fromOffset(420, 34),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.2,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastList,
	}, { UI.corner(12) })
	local l = UI.label({
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 1, -10),
		Text = text,
		TextColor3 = color or COLORS.info,
		Parent = holder,
	})
	UI.textStroke(Color3.new(0, 0, 0), 1.5).Parent = l
	UI.bump(holder, 0.12)
	local children = toastList:GetChildren()
	local frames = 0
	for _, c in children do
		if c:IsA("Frame") then
			frames += 1
		end
	end
	if frames > 4 then
		for _, c in children do
			if c:IsA("Frame") and c ~= holder then
				c:Destroy()
				break
			end
		end
	end
	task.delay(seconds or 3, function()
		if holder.Parent then
			UI.tween(holder, 0.3, { BackgroundTransparency = 1 })
			UI.tween(l, 0.3, { TextTransparency = 1 })
			task.wait(0.3)
			holder:Destroy()
		end
	end)
end

local bannerToken = 0
function HUD.banner(text: string, color: Color3, seconds: number?)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color
	bannerLabel.TextTransparency = 0
	local stroke = bannerLabel:FindFirstChild("Stroke") :: UIStroke
	stroke.Transparency = 0
	UI.bump(bannerLabel, 0.3)
	task.delay(seconds or 4, function()
		if token == bannerToken then
			UI.tween(bannerLabel, 0.5, { TextTransparency = 1 })
			UI.tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
end

function HUD.notice(n: Types.Notice)
	local color = if n.kind == "good" then COLORS.good elseif n.kind == "bad" then COLORS.bad else COLORS.info
	HUD.toast(n.text, color)
end

function HUD.fxRoot(): Frame
	return fxRoot
end

-- Center of a HUD element in fxRoot coordinates.
function HUD.centerOf(target: string): Vector2
	local g: GuiObject = if target == "cash"
		then cashPill
		elseif target == "sell" then sellButton
		else upgradesButton
	return g.AbsolutePosition + g.AbsoluteSize / 2 - fxRoot.AbsolutePosition
end

function HUD.bump(target: string, amount: number?)
	local g: GuiObject = if target == "cash"
		then cashPill
		elseif target == "sell" then sellButton
		else upgradesButton
	UI.bump(g, amount)
end

function HUD.setShopOpener(fn: () -> ())
	openShop = fn
end

function HUD.start()
	build()

	sellButton.Activated:Connect(function()
		if attrNumber("BasketCount") > 0 then
			Remotes.get(Remotes.Names.SellAll):FireServer()
		else
			HUD.toast("Your basket is empty – harvest some carrots first!")
		end
	end)
	upgradesButton.Activated:Connect(function()
		Sound.play("Click")
		if openShop then
			openShop()
		end
	end)
	goalButton.Activated:Connect(function()
		local track, cost = HUD.nextGoal()
		if track and attrNumber("Cash") >= cost then
			Remotes.get(Remotes.Names.BuyUpgrade):FireServer(track.id)
			Sound.play("Purchase")
		elseif openShop then
			openShop()
		end
	end)

	player:GetAttributeChangedSignal("Cash"):Connect(onCashChanged)
	player.AttributeChanged:Connect(function(name)
		if name == "BasketCount" or name == "BasketValue" or name == "BasketCapacity" then
			refreshSell()
			refreshGoal()
		elseif string.sub(name, 1, 4) == "Upg_" then
			refreshGoal()
		end
	end)
	Remotes.get(Remotes.Names.Notice).OnClientEvent:Connect(HUD.notice)
	-- CarrotDex screen arrives in phase 2; keep the latest set so nothing queues up.
	Remotes.get(Remotes.Names.FoundTypes).OnClientEvent:Connect(function(found: { [string]: boolean })
		HUD.foundTypes = found
	end)

	shownCash = attrNumber("Cash")
	targetCash = shownCash
	cashLabel.Text = Format.cash(shownCash)
	refreshSell()
	refreshGoal()

	-- Cash count-up, pulsing hints
	local pulseT = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if shownCash ~= targetCash then
			local diff = targetCash - shownCash
			local step = diff * math.min(1, dt * 8)
			if math.abs(diff) < 1 or math.abs(step) < 0.5 then
				shownCash = targetCash
			else
				shownCash += step
			end
			cashLabel.Text = Format.cash(math.floor(shownCash + 0.5))
		end
		pulseT += dt
		local pulse = 0.5 + 0.5 * math.sin(pulseT * 6)
		local track, cost = HUD.nextGoal()
		local affordable = track ~= nil and attrNumber("Cash") >= cost
		local goalStroke = goalButton:FindFirstChildOfClass("UIStroke")
		if goalStroke then
			goalStroke.Color = if affordable
				then Color3.fromRGB(15, 15, 20):Lerp(COLORS.good, pulse)
				else Color3.fromRGB(15, 15, 20)
		end
		local sellStroke = sellButton:FindFirstChildOfClass("UIStroke")
		if sellStroke then
			sellStroke.Color = if attrNumber("BasketCount") > 0
				then COLORS.sellDark:Lerp(Color3.fromRGB(230, 255, 200), pulse * 0.8)
				else COLORS.sellDark
		end
	end)

	-- First-time hint
	task.delay(2, function()
		if attrNumber("FoundCount") == 0 then
			HUD.toast("Tap a dirt plot on your farm to plant a carrot!", COLORS.good, 6)
		end
	end)
end

return HUD
