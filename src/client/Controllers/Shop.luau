--!strict
-- Upgrades panel. Shows every enabled track with level, effect and a big BUY button.
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

local panel: Frame
local rows: { Row } = {}

local function attrNumber(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function effectText(track: Upgrades.UpgradeDef, level: number): string
	if track.id == "GrowthSpeed" then
		local now =
			Progression.growTime(EconomyConfig.BaseGrowTime, EconomyConfig.MinGrowTime, track, level, 1)
		local nxt =
			Progression.growTime(EconomyConfig.BaseGrowTime, EconomyConfig.MinGrowTime, track, level + 1, 1)
		return string.format("Grow time %s → %s", Format.duration(now), Format.duration(nxt))
	end
	return track.description
end

local function refresh()
	local cash = attrNumber("Cash")
	for _, row in rows do
		local level = attrNumber("Upg_" .. row.track.id)
		row.level.Text = "Level " .. level
		if Progression.isMaxed(row.track, level) then
			row.effect.Text = "Maxed!"
			row.buyText.Text = "MAX"
			row.buy.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
		else
			local cost = Progression.cost(row.track, level)
			row.effect.Text = effectText(row.track, level)
			row.buyText.Text = Format.cash(cost)
			row.buy.BackgroundColor3 = if cash >= cost
				then Color3.fromRGB(70, 200, 90)
				else Color3.fromRGB(120, 120, 130)
		end
	end
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = UI.new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Enabled = false,
		Parent = playerGui,
	})
	local camera = workspace.CurrentCamera
	local scale: UIScale = UI.new("UIScale", { Parent = gui })
	local function rescale()
		scale.Scale = HUD.scale()
	end
	rescale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- Tap outside to close
	local backdrop: TextButton = UI.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})

	local enabled = {}
	for _, t in Upgrades do
		if t.enabled then
			table.insert(enabled, t)
		end
	end

	local rowH = 76
	panel = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(460, 70 + #enabled * (rowH + 8) + 8),
		BackgroundColor3 = Color3.fromRGB(255, 200, 120),
		Parent = gui,
	}, {
		UI.corner(20),
		UI.stroke(Color3.fromRGB(110, 50, 0), 4),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 225, 160), Color3.fromRGB(255, 160, 60)),
			Rotation = 90,
		}),
	})
	UI.bigText({
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -100, 0, 44),
		Text = "Upgrades",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	}, Color3.fromRGB(110, 50, 0), 3.5)

	local close: TextButton = UI.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Color3.fromRGB(235, 60, 60),
		Text = "",
		Parent = panel,
	}, { UI.corner(14), UI.stroke(Color3.fromRGB(110, 20, 20), 3) })
	UI.bigText({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		Text = "X",
		Parent = close,
	}, Color3.fromRGB(110, 20, 20), 2.5)

	for i, track in enabled do
		local y = 64 + (i - 1) * (rowH + 8)
		local row = UI.new("Frame", {
			Position = UDim2.fromOffset(12, y),
			Size = UDim2.new(1, -24, 0, rowH),
			BackgroundColor3 = Color3.fromRGB(70, 50, 40),
			Parent = panel,
		}, { UI.corner(14), UI.stroke(Color3.fromRGB(110, 50, 0), 3) })
		UI.bigText({
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -170, 0, 28),
			Text = track.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local level = UI.label({
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.new(1, -170, 0, 18),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 200, 120),
			Parent = row,
		})
		local effect = UI.label({
			Position = UDim2.fromOffset(14, 53),
			Size = UDim2.new(1, -170, 0, 17),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(210, 210, 225),
			Parent = row,
		})
		local buy: TextButton = UI.new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(140, rowH - 14),
			BackgroundColor3 = Color3.fromRGB(70, 200, 90),
			Text = "",
			Parent = row,
		}, {
			UI.corner(14),
			UI.stroke(Color3.fromRGB(20, 60, 20), 3),
			UI.new("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
				Rotation = 90,
			}),
		})
		local buyText = UI.bigText({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			Text = "",
			Parent = buy,
		}, Color3.fromRGB(20, 60, 20), 2.5)
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

	local function setOpen(open: boolean)
		gui.Enabled = open
		if open then
			refresh()
			UI.bump(panel, 0.08)
		end
	end
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	HUD.setShopOpener(function()
		setOpen(not gui.Enabled)
	end)
end

function Shop.start()
	build()
	player.AttributeChanged:Connect(function(name)
		if name == "Cash" or string.sub(name, 1, 4) == "Upg_" then
			refresh()
		end
	end)
	refresh()
end

return Shop
