--!strict
-- Upgrades panel: every enabled track with level, what the next level does and a big BUY button.
-- The server re-checks everything; this only previews with the shared Progression math.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Upgrades = require(Config.Upgrades)
local EconomyConfig = require(Config.Economy)
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
	panel = Panel.new("Upgrades", "Upgrades", Color3.fromRGB(255, 170, 50), Color3.fromRGB(150, 70, 0))
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 12),
		Parent = panel.body,
	})

	for i, track in Upgrades do
		if not track.enabled then
			continue
		end
		local color = UI.rgb(track.color)
		local darkColor = color:Lerp(Color3.new(0, 0, 0), 0.45)
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			LayoutOrder = i,
			Parent = panel.body,
		}, { UI.corner(16), UI.stroke(darkColor, 3) })
		-- Emoji badge
		local badge = UI.new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = color,
			Parent = row,
		}, { UI.corner(14), UI.stroke(darkColor, 2.5) })
		UI.label({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			Text = track.emoji,
			Font = Enum.Font.GothamBold,
			Parent = badge,
		})
		UI.bigText({
			Position = UDim2.fromOffset(76, 6),
			Size = UDim2.new(1, -240, 0, 26),
			Text = track.name,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, darkColor, 2.5)
		local level = UI.label({
			Position = UDim2.fromOffset(76, 33),
			Size = UDim2.new(1, -240, 0, 17),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(120, 90, 60),
			Parent = row,
		})
		local effect = UI.label({
			Position = UDim2.fromOffset(76, 51),
			Size = UDim2.new(1, -240, 0, 17),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(70, 70, 90),
			Parent = row,
		})
		local buy, buyText = Panel.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(150, 58),
			Parent = row,
		}, GREEN, GREEN_DARK, "")
		buy.Activated:Connect(function()
			local lvl = attrNumber("Upg_" .. track.id)
			if Progression.isMaxed(track, lvl) then
				return
			end
			if attrNumber("Cash") >= Progression.cost(track, lvl) then
				Remotes.get(Remotes.Names.BuyUpgrade):FireServer(track.id)
				Sound.play("Purchase")
				UI.bump(buy, 0.15)
			else
				HUD.toast("Not enough cash yet – sell some carrots!")
			end
		end)
		table.insert(rows, { track = track, level = level, effect = effect, buy = buy, buyText = buyText })
	end

	panel.onOpen = refresh
	HUD.setTileHandler("Upgrades", panel.toggle)
end

function Shop.start()
	build()
	player.AttributeChanged:Connect(function(name)
		if panel.isOpen() and (name == "Cash" or string.sub(name, 1, 4) == "Upg_") then
			refresh()
		end
	end)
end

return Shop
