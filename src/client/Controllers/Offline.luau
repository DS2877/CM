--!strict
-- "While you were away…" reveal (design doc §4): the offline basket is revealed one carrot at a
-- time, faster and faster, with the best ones last (the server sorts them). Tap to skip.
-- The carrots are already in the basket on the server; this is pure presentation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Panel = require(script.Parent.Parent.Util.Panel)
local CarrotIcon = require(script.Parent.Parent.Util.CarrotIcon)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Offline = {}

local function awayText(seconds: number): string
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

local function show(result: Types.OfflineResult)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = "OfflineReveal",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Parent = playerGui,
	})
	UI.autoScale(gui)
	UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 40, 80),
		BackgroundTransparency = 0.35,
		Parent = gui,
	})

	local frame: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(420, 300),
		BackgroundColor3 = Color3.fromRGB(255, 248, 230),
		Parent = gui,
	}, {
		UI.corner(24),
		UI.stroke(Color3.fromRGB(150, 70, 0), 4),
	})
	UI.bigText({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "While you were away…",
		TextColor3 = Color3.fromRGB(255, 170, 50),
	}, Color3.fromRGB(110, 50, 0), 3).Parent =
		frame
	UI.label({
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 18),
		Text = string.format("Your planted carrots kept growing for %s!", awayText(result.seconds)),
		TextColor3 = Color3.fromRGB(110, 80, 50),
		Parent = frame,
	})

	-- Big card
	local card: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(200, 150),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = frame,
	}, { UI.corner(18) })
	local cardStroke = UI.stroke(Color3.fromRGB(150, 150, 160), 4)
	cardStroke.Parent = card
	local icon = CarrotIcon.new(result.carrots[1].type, result.carrots[1].mutations)
	icon.Position = UDim2.fromOffset(10, 4)
	icon.Size = UDim2.new(1, -20, 0, 92)
	icon.Parent = card
	local nameLabel = UI.bigText({
		Position = UDim2.fromOffset(6, 98),
		Size = UDim2.new(1, -12, 0, 22),
		Text = "",
		Parent = card,
	}, Color3.new(0, 0, 0), 2)
	local valueLabel = UI.bigText({
		Position = UDim2.fromOffset(6, 122),
		Size = UDim2.new(1, -12, 0, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(110, 240, 90),
		Parent = card,
	}, Color3.fromRGB(20, 90, 20), 2.5)

	local counter = UI.bigText({
		Position = UDim2.new(0, 14, 1, -74),
		Size = UDim2.fromOffset(120, 24),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 150, 50),
		Parent = frame,
	}, Color3.fromRGB(110, 50, 0), 2)
	local totalLabel = UI.bigText({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 1, -74),
		Size = UDim2.fromOffset(200, 24),
		Text = "$0",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(110, 240, 90),
		Parent = frame,
	}, Color3.fromRGB(20, 90, 20), 2.5)

	local button, buttonText = Panel.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(220, 40),
		Parent = frame,
	}, Color3.fromRGB(80, 170, 255), Color3.fromRGB(20, 70, 150), "SKIP")

	local skipping = false
	local done = false
	button.Activated:Connect(function()
		if done then
			gui:Destroy()
			HUD.bump("sell", 0.3)
		else
			skipping = true
		end
	end)

	task.spawn(function()
		local n = #result.carrots
		local running = 0
		for i, c in result.carrots do
			if skipping then
				break
			end
			local rarity = CarrotInfo.rarity(c.rarity)
			local order = if rarity then rarity.order else 1
			local color = if rarity then CarrotInfo.color(rarity.color) else Color3.new(1, 1, 1)
			CarrotIcon.set(icon, c.type, c.mutations)
			nameLabel.Text = CarrotInfo.displayName({ type = c.type, size = c.size, mutations = c.mutations })
			nameLabel.TextColor3 = color
			cardStroke.Color = color
			card.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.75)
			valueLabel.Text = Format.cash(c.value)
			running += c.value
			counter.Text = string.format("%d/%d", i, n)
			totalLabel.Text = Format.cash(running)
			UI.bump(card, if order >= 4 then 0.35 else 0.12)
			-- Rising ladder as the reveal speeds up: anticipation for the best ones (shown last)
			Sound.play("RevealTick", { speed = 0.85 + math.min(0.6, i / n * 0.6) })
			if c.isNewType then
				HUD.toast("NEW CARROT! " .. (CarrotInfo.type(c.type) or { name = c.type }).name, color, 3)
			end
			-- Faster and faster, but the last few (the best) get a proper moment.
			local left = n - i
			local delay = math.max(0.05, 0.5 * 0.9 ^ i)
			if left < 3 then
				delay = 0.6
			end
			if order >= 5 then
				Sound.play(if order >= 6 then "HarvestMythic" else "HarvestLegendary")
				HUD.banner(string.upper(rarity and rarity.name or "") .. "!", color, 2.5)
				delay = 1.4
			elseif order >= 4 then
				delay = math.max(delay, 0.7)
			end
			task.wait(delay)
		end
		-- Final state
		local last = result.carrots[n]
		CarrotIcon.set(icon, last.type, last.mutations)
		counter.Text = string.format("%d carrots", n)
		totalLabel.Text = Format.cash(result.total)
		done = true
		buttonText.Text = "COLLECT!"
		button.BackgroundColor3 = Color3.fromRGB(80, 210, 90)
		UI.bump(button, 0.3)
		if result.soldTotal > 0 then
			HUD.toast(
				string.format("Basket was full – %s sold automatically", Format.cash(result.soldTotal)),
				Color3.fromRGB(255, 220, 90),
				5
			)
		end
	end)
end

function Offline.start()
	Remotes.get(Remotes.Names.OfflineReveal).OnClientEvent:Connect(function(result: Types.OfflineResult)
		if #result.carrots > 0 then
			show(result)
		end
	end)
end

return Offline
