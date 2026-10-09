--!strict
-- Mobile-first HUD. Layout rule: the middle of the screen belongs to the farm, and there are NO
-- sell or upgrade buttons: you sell by walking onto the market's green circle and upgrade at an
-- Upgrade Shop on the plaza (Guide draws the way). The HUD only tells you where you stand:
--   * top center: next-upgrade goal bar in the Roblox top bar (tap = show me the way)
--   * top-left: cash, basket (count/capacity + what it sells for) and the Legendary meter, as
--     dark-glass pills that size to their text (never truncated)
--   * left edge: 2x2 menu tiles (Daily, Seeds, Index, Shop) with badges
--   * top-right: small round buttons (odds, music)
--   * bottom center: toasts; upper third: banners
-- Sizes are authored for a ~520 pt tall screen and scaled by UI.screenScale (phones ~0.75).

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

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Music = require(script.Parent.Music)

local player = Players.LocalPlayer

local HUD = {}

local C = {
	cash = Color3.fromRGB(110, 240, 90),
	cashDark = Color3.fromRGB(20, 90, 20),
	upgrade = Color3.fromRGB(255, 165, 40),
	upgradeDark = Color3.fromRGB(150, 70, 0),
	goal = Color3.fromRGB(255, 205, 40),
	goalDark = Color3.fromRGB(120, 70, 10),
	carrot = Color3.fromRGB(255, 160, 60),
	badge = Color3.fromRGB(235, 40, 50),
	good = Color3.fromRGB(120, 245, 100),
	bad = Color3.fromRGB(255, 80, 80),
	info = Color3.fromRGB(255, 255, 255),
	glass = Color3.fromRGB(22, 26, 40),
	outline = Color3.fromRGB(15, 15, 20),
}

local gui: ScreenGui
local topGui: ScreenGui
local fxGui: ScreenGui
local fxRoot: Frame

local cashLabel: TextLabel
local cashIcon: Frame
local basketPill: Frame
local basketIcon: GuiObject
local basketCount: TextLabel
local basketValue: TextLabel
local basketFill: Frame
local basketStroke: UIStroke
local goalButton: TextButton
local goalFill: Frame
local goalName: TextLabel
local goalAmount: TextLabel
local goalIconHolder: Frame
local goalIconStroke: UIStroke
local goalEmoji: TextLabel
local goalShine: Frame
local goalStroke: UIStroke
local tiles: { [string]: GuiButton } = {}
local tileHandlers: { [string]: () -> () } = {}
local cornerRow: Frame? = nil
local makeRoundButton: ((name: string, emoji: string, color: Color3, dark: Color3) -> (TextButton, TextLabel))? =
	nil
local oddsHandler: (() -> ())? = nil
local goalTapHandler: (() -> ())? = nil
local tileBadges: { [string]: { frame: Frame, label: TextLabel } } = {}
local buffLabel: TextLabel
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

function HUD.goalAffordable(): boolean
	local track, cost = HUD.nextGoal()
	return track ~= nil and attrNumber("Cash") >= cost
end

function HUD.basketFull(): boolean
	local cap = attrNumber("BasketCapacity")
	return cap > 0 and attrNumber("BasketCount") >= cap
end

local bigText = UI.bigText

-- Fixed-size chunky text that grows its box to fit (pills never cut text off).
local function fitText(props: { [string]: any }, size: number, stroke: Color3, thickness: number): TextLabel
	local base: { [string]: any } = {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
		TextScaled = false,
		TextSize = size,
	}
	for k, v in props do
		base[k] = v
	end
	return bigText(base, stroke, thickness)
end

local function badge(parent: GuiObject, color: Color3, text: string): (Frame, TextLabel)
	local b: Frame = UI.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = color,
		ZIndex = 5,
		Parent = parent,
	}, { UI.corner(12), UI.stroke(Color3.new(1, 1, 1), 2) })
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
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	local icon = UI.icon(iconName, emoji)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.4)
	icon.Size = UDim2.fromScale(0.58, 0.58)
	icon.Parent = b
	bigText({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(1, 0, 0, 16),
		Text = text,
		ZIndex = 3,
		Parent = b,
	}, dark, 2)
	return b
end

-- Small round icon button (odds, music) with a 44 pt tap area on phones.
local function roundButton(name: string, emoji: string, color: Color3, dark: Color3): (TextButton, TextLabel)
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
	}, { UI.corner(23), UI.stroke(dark, 2.5) })
	local icon = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.58, 0.58),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	return b, icon
end

-- Next-upgrade bar. Dark glass like the pills; the ring and fill take the upgrade's own color.
-- When affordable it turns green with a sweeping shine: "go to the Upgrade Shop!"
local function buildGoalBar(): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(300, 32),
		BackgroundColor3 = C.glass,
		BackgroundTransparency = 0.2,
		AutoButtonColor = false,
		Text = "",
	}, {
		UI.corner(16),
	})
	goalStroke = UI.stroke(Color3.fromRGB(255, 255, 255), 1.5, 0.6)
	goalStroke.Parent = b
	local clip = UI.new("Frame", {
		Name = "Clip",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = b,
	}, { UI.corner(13) })
	goalFill = UI.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.goal,
		Parent = clip,
	}, {
		UI.corner(13),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185)),
			Rotation = 90,
		}),
	})
	goalShine = UI.new("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(-0.3, 0),
		Size = UDim2.new(0, 46, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Rotation = 18,
		Visible = false,
		ZIndex = 2,
		Parent = clip,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	-- Upgrade icon on a dark disc with a colored ring (the emoji stays readable on any color)
	goalIconHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.glass,
		ZIndex = 4,
		Parent = b,
	}, { UI.corner(20) })
	goalIconStroke = UI.stroke(C.upgrade, 3)
	goalIconStroke.Parent = goalIconHolder
	goalEmoji = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		Text = "⬆️",
		TextScaled = true,
		ZIndex = 5,
		Parent = goalIconHolder,
	})
	goalName = bigText({
		Position = UDim2.fromOffset(32, 6),
		Size = UDim2.new(0.5, -32, 1, -12),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = b,
	}, Color3.fromRGB(10, 10, 20), 2)
	goalAmount = bigText({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 7),
		Size = UDim2.new(0.5, -14, 1, -14),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = b,
	}, Color3.fromRGB(10, 10, 20), 2)
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

-- Dark-glass pill that grows with its contents: [icon] text text, optional thin meter at the
-- bottom. Returns (pill, row) - put content in `row`.
local function pill(parent: Instance, name: string, height: number, order: number): (Frame, Frame)
	local p: Frame = UI.new("Frame", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		BackgroundColor3 = C.glass,
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
		Parent = parent,
	}, { UI.corner(height // 2) })
	local row: Frame = UI.new("Frame", {
		Name = "Row",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		BackgroundTransparency = 1,
		Parent = p,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.new("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 14),
		}),
	})
	return p, row
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
	scale.Scale = UI.screenScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scale.Scale = UI.screenScale()
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

	-- Status pills, top-left under the Roblox buttons
	local stack = UI.new("Frame", {
		Name = "Status",
		Position = UDim2.fromOffset(14, 6),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Cash: a drawn coin (crisp at any size, unlike the bill emoji) and the amount
	local _, cashRow = pill(stack, "Cash", 40, 1)
	cashIcon = UI.new("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Color3.fromRGB(80, 205, 70),
		LayoutOrder = 1,
		Parent = cashRow,
	}, {
		UI.corner(16),
		UI.stroke(Color3.fromRGB(220, 255, 200), 2),
		UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
	})
	bigText({
		Size = UDim2.fromScale(1, 1),
		Text = "$",
		Parent = cashIcon,
	}, C.cashDark, 2)
	cashLabel = fitText({
		Text = "$0",
		TextColor3 = C.cash,
		LayoutOrder = 2,
		Parent = cashRow,
	}, 28, C.cashDark, 2.5)
	UI.new("UISizeConstraint", {
		MinSize = Vector2.new(70, 0),
		Parent = cashLabel,
	})

	-- Basket: what you carry, how much room is left, and what it sells for at the market
	-- Compact fixed-size card (an auto-sized pill with a full-width bar inside kept growing):
	-- icon + count + value on top, a chunky fill bar underneath.
	basketPill = UI.new("Frame", {
		Name = "Basket",
		Size = UDim2.fromOffset(196, 50),
		BackgroundColor3 = C.glass,
		BackgroundTransparency = 0.25,
		LayoutOrder = 2,
		Parent = stack,
	}, { UI.corner(16) })
	local basketRow: Frame = UI.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = basketPill,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
	})
	basketStroke = UI.stroke(Color3.fromRGB(255, 255, 255), 1.5, 0.8)
	basketStroke.Parent = basketPill
	basketIcon = UI.icon("Basket", "🧺")
	basketIcon.Size = UDim2.fromOffset(28, 28)
	basketIcon.LayoutOrder = 1
	basketIcon.Parent = basketRow
	basketCount = fitText({
		Text = "0/0",
		TextColor3 = C.carrot,
		LayoutOrder = 2,
		Parent = basketRow,
	}, 20, Color3.fromRGB(90, 35, 0), 2)
	basketValue = fitText({
		Text = "",
		TextColor3 = C.cash,
		LayoutOrder = 3,
		Parent = basketRow,
	}, 20, C.cashDark, 2)
	local basketTrack = UI.new("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -20, 0, 9),
		BackgroundColor3 = Color3.fromRGB(30, 25, 20),
		BackgroundTransparency = 0.2,
		Parent = basketPill,
	}, { UI.corner(5) })
	basketFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.carrot,
		Parent = basketTrack,
	}, { UI.corner(5) })

	-- (The Legendary meter lives on a wooden board at each farm's gate, not on screen.)

	-- Active buffs: friend bonus, watered, boosts
	buffLabel = fitText({
		Text = "",
		TextColor3 = Color3.fromRGB(120, 210, 255),
		LayoutOrder = 4,
		Parent = stack,
	}, 15, Color3.fromRGB(10, 50, 110), 2)

	-- Menu tiles: 2x2 on the left edge, under the pills and clear of the farm
	local left = UI.new("Frame", {
		Name = "Left",
		-- right under the status pills, well above the thumbstick's corner
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(14, 138),
		Size = UDim2.fromOffset(134, 134),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(62, 62),
			CellPadding = UDim2.fromOffset(10, 10),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	type TileDef = { name: string, color: Color3, dark: Color3, icon: string, emoji: string }
	local tileDefs: { TileDef } = {
		{
			name = "Daily",
			color = Color3.fromRGB(255, 205, 60),
			dark = Color3.fromRGB(140, 85, 0),
			icon = "Daily",
			emoji = "🎁",
		},
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
		local t = tile(name, 62, d.color, d.dark, d.icon, d.emoji, name)
		t.LayoutOrder = i
		t.Parent = left
		tiles[name] = t
		local f, l = badge(t, C.badge, "!")
		f.Visible = false
		tileBadges[name] = { frame = f, label = l }
		t.Activated:Connect(function()
			local handler = tileHandlers[name]
			if handler then
				Sound.play("Click")
				handler()
			end
		end)
	end

	-- Small round buttons, top-right: my odds (Carrot Scanner) and music on/off
	local corner = UI.new("Frame", {
		Name = "Corner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.fromOffset(104, 46),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local oddsButton = roundButton("Odds", "🔍", Color3.fromRGB(90, 220, 200), Color3.fromRGB(10, 100, 90))
	oddsButton.LayoutOrder = 1
	oddsButton.Parent = corner
	oddsButton.Activated:Connect(function()
		if oddsHandler then
			Sound.play("Click")
			oddsHandler()
		end
	end)
	local musicButton, musicIcon =
		roundButton("Music", "🎵", Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 60, 80))
	musicButton.LayoutOrder = 2
	musicButton.Parent = corner
	local function refreshMusicIcon()
		musicIcon.Text = if player:GetAttribute("MusicOff") == true then "🔇" else "🎵"
	end
	refreshMusicIcon()
	player:GetAttributeChangedSignal("MusicOff"):Connect(refreshMusicIcon)
	musicButton.Activated:Connect(function()
		Sound.play("Click")
		Music.toggle()
	end)
	cornerRow = corner
	makeRoundButton = roundButton

	-- Toasts: big stroked text at the bottom center, between thumbstick and jump button
	toastList = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 130),
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

local goalWasReady = true -- no chime for what you could already afford when you joined

local function refreshGoal()
	local track, cost, level = HUD.nextGoal()
	local cash = attrNumber("Cash")
	if not track then
		goalName.Text = "All maxed!"
		goalAmount.Text = ""
		goalFill.Size = UDim2.fromScale(1, 1)
		return
	end
	local progress = math.clamp(cash / cost, 0, 1)
	local trackColor = UI.rgb(track.color)
	UI.tween(goalFill, 0.25, { Size = UDim2.fromScale(if cash >= cost then 1 else progress, 1) })
	goalName.Text = string.format("%s %d", track.name, level + 1)
	goalEmoji.Text = track.emoji
	goalIconStroke.Color = trackColor
	if cash >= cost then
		goalAmount.Text = "GO UPGRADE! ⬆"
		goalAmount.TextColor3 = Color3.new(1, 1, 1)
		goalFill.BackgroundColor3 = C.good
	else
		goalAmount.Text = string.format("%s/%s", Format.cash(cash), Format.cash(cost))
		goalAmount.TextColor3 = Color3.fromRGB(255, 236, 170)
		goalFill.BackgroundColor3 = trackColor
	end
	goalShine.Visible = cash >= cost
	-- A small chime the moment the next upgrade becomes affordable
	if cash >= cost and not goalWasReady then
		Sound.play("GoalReady")
		HUD.toast("You can afford " .. track.name .. "! Follow the line to the Upgrade Shop", C.good, 4)
	end
	goalWasReady = cash >= cost
end

local function refreshPity() end

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
	buffLabel.Visible = #parts > 0
end

local basketWasFull = false

local function refreshBasket()
	local count = attrNumber("BasketCount")
	local cap = attrNumber("BasketCapacity")
	local full = cap > 0 and count >= cap
	if full and not basketWasFull and toastList then
		HUD.toast("Basket full! Walk to the market to sell 🧺", C.bad, 5)
	end
	basketWasFull = full
	basketCount.Text = if cap > 0
		then string.format("%s/%s", Format.number(count), Format.number(cap))
		else Format.number(count)
	basketCount.TextColor3 = if full then C.bad else C.carrot
	-- What it sells for at the market (the only place you sell)
	local value = math.max(attrNumber("BasketMarketValue"), attrNumber("BasketValue"))
	basketValue.Text = if count > 0 then Format.cash(value) else ""
	basketValue.Visible = count > 0
	UI.tween(
		basketFill,
		0.2,
		{ Size = UDim2.fromScale(if cap > 0 then math.clamp(count / cap, 0, 1) else 0, 1) }
	)
	basketFill.BackgroundColor3 = if full then C.bad else C.carrot
end

function HUD.toast(text: string, color: Color3?, seconds: number?)
	local l = bigText({
		Size = UDim2.fromOffset(420, 22),
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
		return cashIcon
	elseif name == "sell" or name == "basket" then
		return basketIcon
	end
	return goalButton
end

-- Center of a HUD element in fxRoot coordinates ("cash", "sell"/"basket", anything else = goal).
function HUD.centerOf(name: string): Vector2
	local g = target(name)
	return g.AbsolutePosition + g.AbsoluteSize / 2 - fxRoot.AbsolutePosition
end

-- A HUD element by name, for things that attach to it (tutorial arrows): "basket", "goal",
-- "cash", or a tile name ("Daily", "Seeds", "Index", "Shop").
function HUD.element(name: string): GuiObject?
	if name == "goal" then
		return goalButton
	elseif name == "sell" or name == "basket" then
		return basketPill
	elseif name == "cash" then
		return cashIcon
	end
	return tiles[name]
end

function HUD.bump(name: string, amount: number?)
	local g = if name == "sell" or name == "basket" then basketPill else target(name)
	UI.bump(g, amount)
end

-- HUD scale factor, so effects can match the HUD size.
function HUD.scale(): number
	return UI.screenScale()
end

-- What a tile does when tapped ("Daily", "Seeds", "Index", "Shop").
-- Extra small round button in the top-right corner (e.g. the admin dashboard).
function HUD.addCornerButton(name: string, emoji: string, color: Color3, dark: Color3, fn: () -> ())
	local row, make = cornerRow, makeRoundButton
	if not row or not make or row:FindFirstChild(name) then
		return
	end
	local button = make(name, emoji, color, dark)
	button.Name = name
	button.LayoutOrder = 0
	button.Parent = row
	row.Size = UDim2.fromOffset(row.Size.X.Offset + 56, row.Size.Y.Offset)
	button.Activated:Connect(function()
		Sound.play("Click")
		fn()
	end)
end

function HUD.setTileHandler(name: string, fn: () -> ())
	tileHandlers[name] = fn
end

function HUD.setOddsHandler(fn: () -> ())
	oddsHandler = fn
end

-- What tapping the goal bar does (Guide: show the way to the Upgrade Shop).
function HUD.setGoalTapHandler(fn: () -> ())
	goalTapHandler = fn
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

	goalButton.Activated:Connect(function()
		Sound.play("Click")
		UI.bump(goalButton, 0.12)
		if goalTapHandler then
			goalTapHandler()
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
	refreshBuffs()

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
		if slowAcc >= 0.5 then
			slowAcc = 0
			refreshBuffs()
		end
		local pulse = 0.5 + 0.5 * math.sin(t * 6)
		-- Affordable upgrade: shine sweep every ~1.8 s, icon bob, glowing rim
		if HUD.goalAffordable() then
			local sweep = (t % 1.8) / 1.8
			goalShine.Position = UDim2.fromScale(-0.3 + sweep * 1.6, 0)
			goalIconHolder.Rotation = math.sin(t * 7) * 8
			goalStroke.Color = Color3.fromRGB(255, 255, 255):Lerp(C.good, pulse)
			goalStroke.Transparency = 0.1
			goalStroke.Thickness = 2
		else
			goalIconHolder.Rotation = 0
			goalStroke.Color = Color3.fromRGB(255, 255, 255)
			goalStroke.Transparency = 0.6
			goalStroke.Thickness = 1.5
		end
		-- Full basket: the pill's rim pulses red until you sell
		if HUD.basketFull() then
			basketStroke.Color = Color3.fromRGB(255, 255, 255):Lerp(C.bad, pulse)
			basketStroke.Transparency = 0
			basketStroke.Thickness = 2.5
		else
			basketStroke.Color = Color3.fromRGB(255, 255, 255)
			basketStroke.Transparency = 0.8
			basketStroke.Thickness = 1.5
		end
	end)
end

return HUD
