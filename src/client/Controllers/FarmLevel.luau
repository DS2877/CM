--!strict
-- Farm Level panel: opens when you step on the gold pad by your own farm gate (next to the Farm
-- Level board) and closes when you walk away. Shows what the next level adds (plots + a new
-- piece of farm decor everyone can see) and a big BUY button. The server re-checks everything,
-- including that you're on your own pad; this only previews with the shared config.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Upgrades = require(Config.Upgrades)
local EconomyConfig = require(Config.Economy)
local FarmLevels = require(Config.FarmLevels)
local World = require(Config.World)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local FarmLevel = {}

local ORANGE = Color3.fromRGB(255, 150, 60)
local ORANGE_DARK = Color3.fromRGB(140, 60, 0)
local GREEN = Color3.fromRGB(80, 210, 90)
local GREEN_DARK = Color3.fromRGB(25, 100, 35)
local GRAY = Color3.fromRGB(170, 170, 185)
local GRAY_DARK = Color3.fromRGB(90, 90, 105)

local function findTrack(): Upgrades.UpgradeDef
	for _, t in Upgrades do
		if t.id == "FarmSize" then
			return t
		end
	end
	error("Config/Upgrades needs a FarmSize (Farm Level) track")
end
local track = findTrack()

local panel: Panel.Panel
local levelText: TextLabel
local plotsText: TextLabel
local unlockText: TextLabel
local upcomingText: TextLabel
local buy: TextButton
local buyText: TextLabel

local function attrNumber(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function setButton(color: Color3, dark: Color3)
	buy.BackgroundColor3 = color
	local stroke = buy:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = dark
	end
	local textStroke = buyText:FindFirstChildOfClass("UIStroke")
	if textStroke then
		textStroke.Color = dark
	end
end

local function refresh()
	local t = track
	local trackLevel = attrNumber("Upg_FarmSize")
	local level = trackLevel + 1
	local plots = Progression.plots(t, trackLevel, EconomyConfig.StartingPlots)
	if Progression.isMaxed(t, trackLevel) then
		levelText.Text = string.format("LEVEL %d  👑", level)
		plotsText.Text = string.format("%d plots – the biggest farm there is!", plots)
		unlockText.Text = "Max level reached. More levels are coming!"
		upcomingText.Text = ""
		buyText.Text = "MAX"
		setButton(GRAY, GRAY_DARK)
		return
	end
	local nextPlots = Progression.plots(t, trackLevel + 1, EconomyConfig.StartingPlots)
	levelText.Text = string.format("LEVEL %d  →  %d", level, level + 1)
	plotsText.Text = if nextPlots > plots
		then string.format("🌱 Plots %d → %d", plots, nextPlots)
		else string.format("🌱 %d plots", plots)
	local parts = {}
	for _, u in FarmLevels.at(level + 1) do
		table.insert(parts, u.emoji .. " " .. u.name)
	end
	unlockText.Text = if #parts > 0 then "New on your farm: " .. table.concat(parts, ", ") else ""
	local upcoming = {}
	for l = level + 2, math.min(level + 4, FarmLevels.MaxLevel) do
		for _, u in FarmLevels.at(l) do
			table.insert(upcoming, string.format("Lv %d %s", l, u.emoji))
		end
	end
	upcomingText.Text = if #upcoming > 0 then "Coming up: " .. table.concat(upcoming, "   ") else ""
	local cost = Progression.cost(t, trackLevel)
	buyText.Text = Format.cash(cost)
	if attrNumber("Cash") >= cost then
		setButton(GREEN, GREEN_DARK)
	else
		setButton(GRAY, GRAY_DARK)
	end
end

local function build()
	panel = Panel.new("FarmLevel", "Farm Level", ORANGE, ORANGE_DARK, Vector2.new(500, 300))
	local body = panel.body
	levelText = UI.bigText({
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 40),
		Text = "",
		TextColor3 = ORANGE,
		Parent = body,
	}, ORANGE_DARK, 3)
	plotsText = UI.label({
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "",
		TextColor3 = Color3.fromRGB(60, 110, 40),
		Parent = body,
	})
	unlockText = UI.label({
		Position = UDim2.fromOffset(10, 80),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "",
		TextColor3 = Color3.fromRGB(110, 70, 30),
		Parent = body,
	})
	upcomingText = UI.label({
		Position = UDim2.fromOffset(10, 108),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(140, 120, 100),
		Parent = body,
	})
	buy, buyText = Panel.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 138),
		Size = UDim2.fromOffset(220, 62),
		Parent = body,
	}, GREEN, GREEN_DARK, "")
	buy.Activated:Connect(function()
		local t = track
		local lvl = attrNumber("Upg_FarmSize")
		if Progression.isMaxed(t, lvl) then
			return
		end
		if attrNumber("Cash") >= Progression.cost(t, lvl) then
			Remotes.get(Remotes.Names.BuyUpgrade):FireServer("FarmSize")
			Sound.play("Upgrade")
			UI.bump(buy, 0.15)
		else
			Sound.play("Denied")
			HUD.toast("Not enough cash yet – sell some carrots!")
		end
	end)
	panel.onOpen = refresh
end

-- My farm's Farm Level pad (a part in my farm model).
local function myPad(): BasePart?
	local farmId = player:GetAttribute("FarmId")
	local farms = workspace:FindFirstChild("Farms")
	local farm = farms and farms:FindFirstChild("Farm_" .. tostring(farmId))
	local pad = farm and farm:FindFirstChild("LevelPad")
	return if pad and pad:IsA("BasePart") then pad else nil
end

function FarmLevel.padPosition(): Vector3?
	local pad = myPad()
	return if pad then pad.Position else nil
end

-- Can I afford the next farm level right now?
function FarmLevel.affordable(): boolean
	local lvl = attrNumber("Upg_FarmSize")
	return not Progression.isMaxed(track, lvl) and attrNumber("Cash") >= Progression.cost(track, lvl)
end

function FarmLevel.onPad(extra: number?): boolean
	local pad = myPad()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not pad or not root or not root:IsA("BasePart") then
		return false
	end
	local p, q = (root :: BasePart).Position, pad.Position
	return Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude <= World.FarmLevelPadRadius + (extra or 0)
end

function FarmLevel.start()
	build()
	local inside = false
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		if not inside and FarmLevel.onPad(0) then
			inside = true
			if not panel.isOpen() then
				panel.setOpen(true)
			end
		elseif inside and not FarmLevel.onPad(2) then
			inside = false
			if panel.isOpen() then
				panel.setOpen(false)
			end
		end
	end)
	-- One nudge per level when you can afford the next one (the board and pad show the rest).
	local nudged = -1
	player.AttributeChanged:Connect(function(name)
		if panel.isOpen() and (name == "Cash" or name == "Upg_FarmSize") then
			refresh()
		end
		local t = track
		if name == "Cash" and player:GetAttribute("Tutorial") ~= true then
			local lvl = attrNumber("Upg_FarmSize")
			if
				lvl ~= nudged
				and not Progression.isMaxed(t, lvl)
				and attrNumber("Cash") >= Progression.cost(t, lvl)
			then
				nudged = lvl
				HUD.toast(
					"🏡 You can level up your farm! Gold pad by your farm gate",
					Color3.fromRGB(255, 200, 90),
					4
				)
			end
		end
	end)
end

return FarmLevel
