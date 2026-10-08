--!strict
-- Mobile-first HUD in the style of current top Roblox simulators:
--   * goal bar in the free part of the Roblox top bar (yellow progress bar, tap to buy)
--   * left stack of chunky tiles with red "!" badges (Upgrades)
--   * right SELL tile with a count badge, basket value under it (thumb reach, above jump)
--   * bottom-left currency stack with big stroked numbers
--   * big stroked toasts above the bottom center, big center banners
-- Every tap target is at least ~60 pt on a phone; nothing needs hover or a keyboard.

local GuiService = game:GetService("GuiService")
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
local Events = require(Config.Events)
local EventSchedule = require(Shared.EventSchedule)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local HUD = {}

local C = {
	cash = Color3.fromRGB(110, 240, 90),
	cashDark = Color3.fromRGB(20, 90, 20),
	sell = Color3.fromRGB(80, 215, 90),
	sellDark = Color3.fromRGB(20, 100, 35),
	upgrade = Color3.fromRGB(255, 165, 40),
	upgradeDark = Color3.fromRGB(150, 70, 0),
	goal = Color3.fromRGB(255, 205, 40),
	goalDark = Color3.fromRGB(120, 70, 10),
	carrot = Color3.fromRGB(255, 150, 50),
	badge = Color3.fromRGB(235, 40, 50),
	good = Color3.fromRGB(120, 245, 100),
	bad = Color3.fromRGB(255, 80, 80),
	info = Color3.fromRGB(255, 255, 255),
	outline = Color3.fromRGB(15, 15, 20),
}

local gui: ScreenGui
local topGui: ScreenGui
local fxGui: ScreenGui
local fxRoot: Frame

local cashLabel: TextLabel
local cashRow: Frame
local basketLabel: TextLabel
local goalButton: TextButton
local goalFill: Frame
local goalName: TextLabel
local goalAmount: TextLabel
local sellTile: TextButton
local sellBadge: Frame
local sellBadgeText: TextLabel
local sellValue: TextLabel
local upgradesTile: TextButton
local upgradesBadge: Frame
local tiles: { [string]: TextButton } = {}
local tileHandlers: { [string]: () -> () } = {}
local oddsHandler: (() -> ())? = nil
local tileBadges: { [string]: { frame: Frame, label: TextLabel } } = {}
local pityFill: Frame
local pityLabel: TextLabel
local buffLabel: TextLabel
local boomTag: TextLabel
local toastList: Frame
local bannerLabel: TextLabel

local shownCash = 0
local targetCash = 0

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

local function affordableGoal(): boolean
	local track, cost = HUD.nextGoal()
	return track ~= nil and attrNumber("Cash") >= cost
end

local bigText = UI.bigText

local function badge(parent: GuiObject, color: Color3, text: string): (Frame, TextLabel)
	local b: Frame = UI.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = color,
		ZIndex = 5,
		Parent = parent,
	}, { UI.corner(14), UI.stroke(Color3.new(1, 1, 1), 2.5) })
	local l = bigText({
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		Text = text,
		ZIndex = 6,
		Parent = b,
	}, Color3.fromRGB(60, 0, 0), 1.5)
	return b, l
end

-- Square tile button: gradient fill, dark outline, big icon, label overlapping the bottom edge.
local function tile(
	name: string,
	size: number,
	color: Color3,
	dark: Color3,
	iconName: string,
	emoji: string,
	text: string
): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
	}, {
		UI.corner(14),
		UI.stroke(dark, 3),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
			Rotation = 90,
		}),
	})
	local icon = UI.icon(iconName, emoji)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.42)
	icon.Size = UDim2.fromScale(0.68, 0.68)
	icon.Parent = b
	bigText({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.new(1, 6, 0, 22),
		Text = text,
		ZIndex = 3,
		Parent = b,
	}, dark, 2.5)
	return b
end

local function screenScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(844, 390)
	-- Phones in landscape are ~390 pt tall; scale up on tablets/PC, down on tiny screens.
	return math.clamp(math.min(size.Y / 400, size.X / 760), 0.75, 1.6)
end

local function buildGoalBar(): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(340, 38),
		BackgroundColor3 = Color3.fromRGB(255, 244, 220),
		AutoButtonColor = false,
		Text = "",
	}, {
		UI.corner(12),
		UI.stroke(C.goalDark, 3),
	})
	local clip = UI.new("Frame", {
		Name = "Clip",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = b,
	}, { UI.corner(8) })
	goalFill = UI.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.goal,
		Parent = clip,
	}, {
		UI.corner(8),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 190, 150)),
			Rotation = 90,
		}),
	})
	-- Icon overlapping the left edge, like a level badge
	local iconHolder: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.upgrade,
		ZIndex = 3,
		Parent = b,
	}, { UI.corner(22), UI.stroke(C.upgradeDark, 3) })
	local icon = UI.icon("Upgrade", "⬆️")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.ZIndex = 4
	icon.Parent = iconHolder
	goalName = bigText({
		Position = UDim2.fromOffset(32, 6),
		Size = UDim2.new(0.58, -32, 1, -12),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = b,
	}, C.goalDark, 2.5)
	goalAmount = bigText({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.new(0.42, -10, 1, -12),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = b,
	}, C.goalDark, 2.5)
	return b
end

-- Put the goal bar centered in the Roblox top bar row, keeping well clear of the Roblox
-- buttons on the left (TopbarInset can lag behind the chat/voice buttons, so add a margin).
-- If there isn't room, it goes just below the top bar instead.
local TOPBAR_SAFETY = 90
local function placeGoalBar()
	local inset = GuiService.TopbarInset
	local screenW = topGui.AbsoluteSize.X
	local center = screenW / 2
	local half = math.min(center - (inset.Min.X + TOPBAR_SAFETY), inset.Max.X - 12 - center)
	local w = math.min(300, half * 2)
	if w >= 220 and inset.Height > 20 then
		goalButton.Parent = topGui
		goalButton.Size = UDim2.fromOffset(w, math.min(32, inset.Height - 12))
		goalButton.Position = UDim2.fromOffset(center, inset.Min.Y + inset.Height / 2)
	else
		goalButton.Parent = gui
		goalButton.Size = UDim2.fromOffset(280, 32)
		goalButton.Position = UDim2.new(0.5, 0, 0, 24)
	end
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

	-- Top bar layer (positions come from GuiService.TopbarInset, in raw screen points)
	topGui = UI.new("ScreenGui", {
		Name = "HUD_Top",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	goalButton = buildGoalBar()
	placeGoalBar()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeGoalBar)
	topGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeGoalBar)

	-- Tile row under the currency stack (the thumbstick owns the bottom-left corner)
	local left = UI.new("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 148),
		Size = UDim2.fromOffset(284, 66),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(62, 62),
			CellPadding = UDim2.fromOffset(9, 9),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	type TileDef = { name: string, color: Color3, dark: Color3, icon: string, emoji: string }
	local tileDefs: { TileDef } = {
		{ name = "Upgrades", color = C.upgrade, dark = C.upgradeDark, icon = "Upgrade", emoji = "⬆️" },
		{
			name = "Seeds",
			color = Color3.fromRGB(120, 215, 90),
			dark = Color3.fromRGB(40, 110, 30),
			icon = "Seeds",
			emoji = "🌱",
		},
		{
			name = "Index",
			color = Color3.fromRGB(80, 170, 255),
			dark = Color3.fromRGB(20, 70, 150),
			icon = "Index",
			emoji = "📖",
		},
		{
			name = "Shop",
			color = Color3.fromRGB(255, 120, 190),
			dark = Color3.fromRGB(140, 30, 90),
			icon = "Shop",
			emoji = "🛒",
		},
	}
	for i, d in tileDefs do
		local name = d.name
		local t = tile(name, 68, d.color, d.dark, d.icon, d.emoji, name)
		t.LayoutOrder = i
		t.Parent = left
		tiles[name] = t
		local f, l = badge(t, C.badge, "!")
		f.Visible = false
		tileBadges[name] = { frame = f, label = l }
		t.Activated:Connect(function()
			local handler = tileHandlers[name]
			if handler then
				handler()
			end
		end)
	end
	upgradesTile = tiles.Upgrades
	upgradesBadge = tileBadges.Upgrades.frame

	-- Right SELL tile with count badge and value underneath
	local right = UI.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.46, 0),
		Size = UDim2.fromOffset(120, 128),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	sellTile = tile("Sell", 92, C.sell, C.sellDark, "Basket", "🧺", "SELL")
	sellTile.AnchorPoint = Vector2.new(0.5, 0)
	sellTile.Position = UDim2.new(0.5, 0, 0, 0)
	sellTile.Parent = right
	sellBadge, sellBadgeText = badge(sellTile, C.sell, "0")
	sellBadge.Size = UDim2.fromOffset(34, 28)
	sellValue = bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.new(1, 20, 0, 26),
		Text = "$0",
		TextColor3 = C.cash,
		Parent = right,
	}, C.cashDark, 2.5)
	-- Boom tag above the SELL tile
	boomTag = bigText({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(170, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 150, 40),
		Visible = false,
		Parent = right,
	}, Color3.fromRGB(100, 30, 0), 2.5)

	-- Currency stack, top-left under the Roblox buttons (the thumbstick owns the bottom-left)
	local currencies = UI.new("Frame", {
		Name = "Currencies",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.fromOffset(260, 136),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 2),
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local basketRow = UI.new("Frame", {
		Name = "Basket",
		Size = UDim2.fromOffset(260, 30),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = currencies,
	})
	local carrotIcon = UI.icon("Carrot", "🥕")
	carrotIcon.Size = UDim2.fromOffset(30, 30)
	carrotIcon.Parent = basketRow
	basketLabel = bigText({
		Position = UDim2.fromOffset(38, 2),
		Size = UDim2.new(1, -38, 1, -4),
		Text = "0",
		TextColor3 = C.carrot,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = basketRow,
	}, Color3.fromRGB(90, 35, 0), 2.5)
	cashRow = UI.new("Frame", {
		Name = "Cash",
		Size = UDim2.fromOffset(260, 46),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = currencies,
	})
	local cashIcon = UI.icon("Cash", "💵")
	cashIcon.Size = UDim2.fromOffset(44, 44)
	cashIcon.Parent = cashRow
	cashLabel = bigText({
		Position = UDim2.fromOffset(50, 2),
		Size = UDim2.new(1, -50, 1, -4),
		Text = "$0",
		TextColor3 = C.cash,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cashRow,
	}, C.cashDark, 3)

	-- Pity meter: Legendary guaranteed within N plantings
	local pityRow = UI.new("Frame", {
		Name = "Pity",
		Size = UDim2.fromOffset(260, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = currencies,
	})
	local crown = UI.icon("Crown", "👑")
	crown.Size = UDim2.fromOffset(28, 28)
	crown.Parent = pityRow
	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(36, 4),
		Size = UDim2.fromOffset(170, 20),
		BackgroundColor3 = Color3.fromRGB(255, 248, 225),
		Parent = pityRow,
	}, { UI.corner(10), UI.stroke(C.goalDark, 2.5) })
	local clip = UI.new("Frame", {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = bar,
	}, { UI.corner(8) })
	pityFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 200, 40),
		Parent = clip,
	}, { UI.corner(8) })
	pityLabel = bigText({
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -12, 1, -4),
		Text = "",
		ZIndex = 2,
		Parent = bar,
	}, C.goalDark, 2)
	-- 🔍 My odds (Carrot Scanner)
	local oddsButton: TextButton = UI.new("TextButton", {
		Position = UDim2.fromOffset(212, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(90, 220, 200),
		Text = "",
		Parent = pityRow,
	}, { UI.corner(14), UI.stroke(Color3.fromRGB(10, 100, 90), 2.5) })
	local oddsIcon = UI.icon("Scanner", "🔍")
	oddsIcon.Position = UDim2.fromOffset(4, 4)
	oddsIcon.Size = UDim2.new(1, -8, 1, -8)
	oddsIcon.Parent = oddsButton
	oddsButton.Activated:Connect(function()
		if oddsHandler then
			oddsHandler()
		end
	end)

	-- Active buffs: friend bonus, watered
	buffLabel = bigText({
		Size = UDim2.fromOffset(260, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(120, 210, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 4,
		Parent = currencies,
	}, Color3.fromRGB(10, 50, 110), 2)

	-- Toasts: big stroked text at the bottom center, between thumbstick and jump button
	toastList = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(430, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Big center banner
	bannerLabel = bigText({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.27),
		Size = UDim2.fromOffset(480, 36),
		Text = "",
		TextTransparency = 1,
		Parent = gui,
	}, Color3.new(0, 0, 0), 3.5)
	local bannerStroke = bannerLabel:FindFirstChildOfClass("UIStroke") :: UIStroke
	bannerStroke.Name = "Stroke"
	bannerStroke.Transparency = 1

	-- Effects layer: full viewport, used for flying icons and gain popups
	fxGui = UI.new("ScreenGui", {
		Name = "HUD_FX",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
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

local function refreshGoal()
	local track, cost, level = HUD.nextGoal()
	local cash = attrNumber("Cash")
	if not track then
		goalName.Text = "All maxed!"
		goalAmount.Text = ""
		goalFill.Size = UDim2.fromScale(1, 1)
		upgradesBadge.Visible = false
		return
	end
	local progress = math.clamp(cash / cost, 0, 1)
	UI.tween(goalFill, 0.25, { Size = UDim2.fromScale(progress, 1) })
	goalName.Text = string.format("%s %d", track.name, level + 1)
	if cash >= cost then
		goalAmount.Text = "TAP TO BUY!"
		goalFill.BackgroundColor3 = C.good
	else
		goalAmount.Text = string.format("%s/%s", Format.cash(cash), Format.cash(cost))
		goalFill.BackgroundColor3 = C.goal
	end
	upgradesBadge.Visible = cash >= cost
end

local function refreshPity()
	local pity = attrNumber("Pity")
	local max = attrNumber("PityMax")
	if max <= 0 then
		pityLabel.Text = ""
		return
	end
	local left = math.max(1, max - pity)
	pityLabel.Text = string.format("Legendary in %d", left)
	UI.tween(pityFill, 0.2, { Size = UDim2.fromScale(math.clamp(pity / max, 0, 1), 1) })
end

local function refreshSeedTile()
	local selected = player:GetAttribute("SelectedSeed")
	local id = if typeof(selected) == "string" then selected else "Basic"
	local b = tileBadges.Seeds
	if id ~= "Basic" then
		b.frame.Visible = true
		b.frame.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
		b.label.Text = Format.number(attrNumber("Seed_" .. id))
	else
		b.frame.Visible = false
	end
end

local eventsCfg: EventSchedule.EventsConfig = Events :: any

local function atMarket(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local p = (root :: BasePart).Position
	return Vector2.new(p.X, p.Z).Magnitude <= Events.MarketRadius
end

-- Boom tag + which price the SELL tile shows (the server decides the real price).
local function refreshBoom()
	local state = EventSchedule.at(workspace:GetServerTimeNow(), eventsCfg)
	local value = attrNumber("BasketValue")
	local marketValue = attrNumber("BasketMarketValue")
	local boosted = state.boomActive and marketValue > value
	if boosted and atMarket() then
		sellValue.Text = Format.cash(marketValue)
		sellValue.TextColor3 = Color3.fromRGB(255, 170, 40)
		boomTag.Text = "BOOM PRICE!"
		boomTag.Visible = true
	elseif boosted then
		sellValue.Text = Format.cash(value)
		sellValue.TextColor3 = C.cash
		boomTag.Text = Format.cash(marketValue) .. " at market!"
		boomTag.Visible = true
	else
		sellValue.Text = Format.cash(value)
		sellValue.TextColor3 = C.cash
		boomTag.Visible = false
	end
end

local function refreshBuffs()
	local parts = {}
	local friends = attrNumber("FriendCount")
	if friends > 0 then
		table.insert(
			parts,
			string.format("👥 +%d%% luck", math.floor(attrNumber("FriendBoost") * 100 + 0.5))
		)
	end
	local nowT = workspace:GetServerTimeNow()
	local watered = attrNumber("Buff_Watered") - nowT
	if watered > 0 then
		table.insert(parts, "💧 " .. Format.duration(watered))
	end
	local luck = attrNumber("LuckBoost")
	if luck > 1 then
		local left = math.max(attrNumber("Boost_Luck2"), attrNumber("Boost_Luck4"), attrNumber("Boost_Luck8"))
		table.insert(parts, string.format("🍀x%d %s", luck, Format.duration(left)))
	end
	if attrNumber("Boost_Value2") > 0 then
		table.insert(parts, "💰x2 " .. Format.duration(attrNumber("Boost_Value2")))
	end
	local serverEnds = workspace:GetAttribute("ServerLuckEnds")
	if typeof(serverEnds) == "number" and serverEnds > nowT then
		table.insert(parts, "🌍x2 " .. Format.duration(serverEnds - nowT))
	end
	buffLabel.Text = table.concat(parts, "   ")
end

local basketWasFull = false

local function refreshBasket()
	local count = attrNumber("BasketCount")
	local cap = attrNumber("BasketCapacity")
	-- Tell the player once each time the basket fills up: from now on harvests sell instantly at
	-- base price, so selling (ideally at a boom) or a bigger basket is the next move.
	local full = cap > 0 and count >= cap
	if full and not basketWasFull and toastList then
		HUD.toast("Basket full! Sell now or upgrade Basket Size", C.bad, 5)
	end
	basketWasFull = full
	refreshBoom()
	sellBadgeText.Text = Format.number(count)
	sellBadge.Visible = count > 0
	basketLabel.Text = if cap > 0
		then string.format("%s/%s", Format.number(count), Format.number(cap))
		else tostring(count)
	-- Full basket: harvests now sell at base price, so nudge the player to sell or upgrade.
	basketLabel.TextColor3 = if cap > 0 and count >= cap then C.bad else C.carrot
end

function HUD.toast(text: string, color: Color3?, seconds: number?)
	local l = bigText({
		Size = UDim2.fromOffset(430, 26),
		Text = text,
		TextColor3 = color or C.info,
		LayoutOrder = math.floor(os.clock() * 1000),
		Parent = toastList,
	}, Color3.new(0, 0, 0), 2.5)
	UI.bump(l, 0.2)
	local labels = {}
	for _, c in toastList:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels > 4 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
	task.delay(seconds or 3, function()
		if l.Parent then
			UI.tween(l, 0.35, { TextTransparency = 1 })
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				UI.tween(stroke, 0.35, { Transparency = 1 })
			end
			task.wait(0.4)
			l:Destroy()
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
	UI.bump(bannerLabel, 0.35)
	task.delay(seconds or 4, function()
		if token == bannerToken then
			UI.tween(bannerLabel, 0.5, { TextTransparency = 1 })
			UI.tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
end

function HUD.notice(n: Types.Notice)
	local color = if n.kind == "good" then C.good elseif n.kind == "bad" then C.bad else C.info
	HUD.toast(n.text, color)
end

function HUD.fxRoot(): Frame
	return fxRoot
end

local function target(name: string): GuiObject
	if name == "cash" then
		return cashRow
	elseif name == "sell" then
		return sellTile
	end
	return upgradesTile
end

-- Center of a HUD element in fxRoot coordinates.
function HUD.centerOf(name: string): Vector2
	local g = target(name)
	if name == "cash" then
		-- Aim at the cash icon, not the middle of the row
		local s = g.AbsoluteSize.Y / 46
		return g.AbsolutePosition + Vector2.new(22, 22) * s - fxRoot.AbsolutePosition
	end
	return g.AbsolutePosition + g.AbsoluteSize / 2 - fxRoot.AbsolutePosition
end

function HUD.bump(name: string, amount: number?)
	UI.bump(target(name), amount)
end

-- HUD scale factor, so effects can match the HUD size.
function HUD.scale(): number
	return screenScale()
end

-- What a left tile does when tapped ("Upgrades", "Seeds", "Index").
function HUD.setTileHandler(name: string, fn: () -> ())
	tileHandlers[name] = fn
end

function HUD.setOddsHandler(fn: () -> ())
	oddsHandler = fn
end

-- Show a badge on a tile (nil hides it).
function HUD.setTileBadge(name: string, text: string?)
	local b = tileBadges[name]
	if b then
		b.frame.Visible = text ~= nil
		b.frame.BackgroundColor3 = C.badge
		b.label.Text = text or ""
	end
end

function HUD.start()
	build()

	sellTile.Activated:Connect(function()
		if attrNumber("BasketCount") > 0 then
			Remotes.get(Remotes.Names.SellAll):FireServer()
		else
			HUD.toast("Your basket is empty – harvest some carrots first!")
		end
	end)

	goalButton.Activated:Connect(function()
		local track, cost = HUD.nextGoal()
		if track and attrNumber("Cash") >= cost then
			Remotes.get(Remotes.Names.BuyUpgrade):FireServer(track.id)
			Sound.play("Purchase")
			UI.bump(goalButton, 0.1)
		else
			local handler = tileHandlers.Upgrades
			if handler then
				handler()
			end
		end
	end)

	player.AttributeChanged:Connect(function(name)
		if name == "Cash" then
			targetCash = attrNumber("Cash")
			refreshGoal()
		elseif
			name == "BasketCount"
			or name == "BasketValue"
			or name == "BasketCapacity"
			or name == "BasketMarketValue"
		then
			refreshBasket()
		elseif string.sub(name, 1, 4) == "Upg_" then
			refreshGoal()
		elseif name == "Pity" or name == "PityMax" then
			refreshPity()
		elseif name == "SelectedSeed" or string.sub(name, 1, 5) == "Seed_" then
			refreshSeedTile()
		end
	end)
	Remotes.get(Remotes.Names.Notice).OnClientEvent:Connect(HUD.notice)

	shownCash = attrNumber("Cash")
	targetCash = shownCash
	cashLabel.Text = Format.cash(shownCash)
	refreshBasket()
	refreshGoal()
	refreshPity()
	refreshSeedTile()

	-- Cash count-up and attention pulses
	local t = 0
	local slowAcc = 0
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
		t += dt
		slowAcc += dt
		if slowAcc >= 0.25 then
			slowAcc = 0
			refreshBoom()
			refreshBuffs()
		end
		boomTag.Rotation = math.sin(t * 5) * 4
		local pulse = 0.5 + 0.5 * math.sin(t * 6)
		local goalStroke = goalButton:FindFirstChildOfClass("UIStroke")
		if goalStroke then
			goalStroke.Color = if affordableGoal() then C.outline:Lerp(C.good, pulse) else C.outline
		end
		if upgradesBadge.Visible then
			upgradesBadge.Rotation = math.sin(t * 8) * 12
		end
		local sellStroke = sellTile:FindFirstChildOfClass("UIStroke")
		if sellStroke then
			sellStroke.Color = if attrNumber("BasketCount") > 0
				then C.sellDark:Lerp(Color3.fromRGB(230, 255, 200), pulse * 0.8)
				else C.sellDark
		end
	end)

	-- First-time hint
	task.delay(2, function()
		if attrNumber("FoundCount") == 0 then
			HUD.toast("Tap a dirt plot on your farm to plant a carrot!", C.good, 6)
		end
	end)
end

return HUD
