--!strict
-- Upgrades panel: every enabled track with level, what the next level does and a big BUY button.
-- It opens when you step onto an Upgrade Shop's pad on the plaza and closes when you walk away
-- (upgrades are bought in the world, not from a HUD button). The server re-checks everything,
-- including that you're at the shop; this only previews with the shared Progression math.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Upgrades = require(Config.Upgrades)
local EconomyConfig = require(Config.Economy)
local World = require(Config.World)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Shop = {}

type Row = {
	track: Upgrades.UpgradeDef,
	level: TextLabel,
	effect: TextLabel,
	buy: TextButton,
	buyText: TextLabel,
}

local GREEN = Color3.fromRGB(80, 210, 90)
local GREEN_DARK = Color3.fromRGB(25, 100, 35)
local GRAY = Color3.fromRGB(170, 170, 185)
local GRAY_DARK = Color3.fromRGB(90, 90, 105)

local panel: Panel.Panel
local rows: { Row } = {}

local function attrNumber(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function x(n: number): string
	local s = string.format("%.2f", n)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return "x" .. s
end

-- "now → next" for each track.
local function effectText(track: Upgrades.UpgradeDef, level: number): string
	local id = track.id
	if id == "GrowthSpeed" then
		local now =
			Progression.growTime(EconomyConfig.BaseGrowTime, EconomyConfig.MinGrowTime, track, level, 1)
		local nxt =
			Progression.growTime(EconomyConfig.BaseGrowTime, EconomyConfig.MinGrowTime, track, level + 1, 1)
		return string.format("Grow time %s → %s", Format.duration(now), Format.duration(nxt))
	elseif id == "Luck" then
		return string.format(
			"Luck %s → %s",
			x(Progression.multiplier(track, level)),
			x(Progression.multiplier(track, level + 1))
		)
	elseif id == "Value" then
		return string.format(
			"Sell price +%d%% → +%d%%",
			math.floor(Progression.bonus(track, level) * 100 + 0.5),
			math.floor(Progression.bonus(track, level + 1) * 100 + 0.5)
		)
	elseif id == "FarmSize" then
		return string.format(
			"Plots %d → %d",
			Progression.plots(track, level, EconomyConfig.StartingPlots),
			Progression.plots(track, level + 1, EconomyConfig.StartingPlots)
		)
	elseif id == "BasketSize" then
		return string.format(
			"Basket %d → %d carrots",
			Progression.stepValue(track, level, EconomyConfig.BasketCapacity),
			Progression.stepValue(track, level + 1, EconomyConfig.BasketCapacity)
		)
	elseif id == "HarvestPower" then
		return string.format(
			"Big carrots %s → %s",
			x(Progression.multiplier(track, level)),
			x(Progression.multiplier(track, level + 1))
		)
	end
	return track.description
end

local function setButton(row: Row, color: Color3, dark: Color3)
	row.buy.BackgroundColor3 = color
	local stroke = row.buy:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = dark
	end
	local textStroke = row.buyText:FindFirstChildOfClass("UIStroke")
	if textStroke then
		textStroke.Color = dark
	end
end

local function refresh()
	local cash = attrNumber("Cash")
	for _, row in rows do
		local level = attrNumber("Upg_" .. row.track.id)
		local max = Progression.maxLevel(row.track)
		row.level.Text = string.format("Level %d/%d", level, max)
		if Progression.isMaxed(row.track, level) then
			row.effect.Text = "MAXED!"
			row.buyText.Text = "MAX"
			setButton(row, GRAY, GRAY_DARK)
		else
			local cost = Progression.cost(row.track, level)
			row.effect.Text = effectText(row.track, level)
			row.buyText.Text = Format.cash(cost)
			if cash >= cost then
				setButton(row, GREEN, GREEN_DARK)
			else
				setButton(row, GRAY, GRAY_DARK)
			end
		end
	end
end

local function build()
	-- Five upgrade cards side by side: you see at a glance that there are five, no scrolling.
	panel = Panel.new(
		"Upgrades",
		"Upgrades",
		Color3.fromRGB(255, 170, 50),
		Color3.fromRGB(150, 70, 0),
		Vector2.new(640, 320)
	)
	panel.body.ScrollingDirection = Enum.ScrollingDirection.X
	panel.body.AutomaticCanvasSize = Enum.AutomaticSize.X
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 6),
		Parent = panel.body,
	})

	local count = 0
	for _, track in Upgrades do
		if track.enabled and track.soldAt == nil then
			count += 1
		end
	end
	panel.subtitle.Text = string.format("%d upgrades", count)

	for i, track in Upgrades do
		-- Farm Level is bought at your farm's sign, not here
		if not track.enabled or track.soldAt ~= nil then
			continue
		end
		local color = UI.rgb(track.color)
		local darkColor = color:Lerp(Color3.new(0, 0, 0), 0.45)
		local card = UI.new("Frame", {
			Size = UDim2.new(0, 114, 1, -4),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			LayoutOrder = i,
			Parent = panel.body,
		}, { UI.corner(16), UI.stroke(darkColor, 3) })
		-- Colored top with the big emoji
		local top = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = color,
			Parent = card,
		}, { UI.corner(16) })
		UI.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(48, 48),
			Text = track.emoji,
			Font = Enum.Font.GothamBold,
			Parent = top,
		})
		UI.bigText({
			Position = UDim2.fromOffset(6, 68),
			Size = UDim2.new(1, -12, 0, 22),
			Text = track.name,
			TextColor3 = color,
			Parent = card,
		}, darkColor, 2)
		local level = UI.label({
			Position = UDim2.fromOffset(6, 92),
			Size = UDim2.new(1, -12, 0, 16),
			Text = "",
			TextColor3 = Color3.fromRGB(120, 90, 60),
			Parent = card,
		})
		local effect = UI.label({
			Position = UDim2.fromOffset(6, 110),
			Size = UDim2.new(1, -12, 0, 34),
			Text = "",
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(70, 70, 90),
			Parent = card,
		})
		local buy, buyText = Panel.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 46),
			Parent = card,
		}, GREEN, GREEN_DARK, "")
		buy.Activated:Connect(function()
			local lvl = attrNumber("Upg_" .. track.id)
			if Progression.isMaxed(track, lvl) then
				return
			end
			if attrNumber("Cash") >= Progression.cost(track, lvl) then
				Remotes.get(Remotes.Names.BuyUpgrade):FireServer(track.id)
				Sound.play("Upgrade")
				UI.bump(buy, 0.15)
			else
				Sound.play("Denied")
				HUD.toast("Not enough cash yet – sell some carrots!")
			end
		end)
		table.insert(rows, { track = track, level = level, effect = effect, buy = buy, buyText = buyText })
	end

	panel.onOpen = refresh
end

-- Is the local player standing on an Upgrade Shop pad? (extra = hysteresis when leaving)
local pads = World.upgradePads()
function Shop.atShop(extra: number?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local p = (root :: BasePart).Position
	for _, pad in pads do
		if Vector3.new(p.X - pad.X, 0, p.Z - pad.Z).Magnitude <= World.UpgradePadRadius + (extra or 0) then
			return true
		end
	end
	return false
end

function Shop.start()
	build()
	-- Open on the pad, close when walking away. Closing it by hand on the pad keeps it closed
	-- until you step off and on again.
	local inside = false
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		if not inside and Shop.atShop(0) then
			inside = true
			if not panel.isOpen() then
				panel.setOpen(true)
			end
		elseif inside and not Shop.atShop(2.5) then
			inside = false
			if panel.isOpen() then
				panel.setOpen(false)
			end
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if panel.isOpen() and (name == "Cash" or string.sub(name, 1, 4) == "Upg_") then
			refresh()
		end
	end)
end

return Shop
