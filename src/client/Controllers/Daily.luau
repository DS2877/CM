--!strict
-- Daily panel (📅 tile): the 7-day reward calendar and today's three quests. The server owns the
-- state (DailySync); this only renders it and sends claims. Opens itself on join when today's
-- reward is waiting: the moment that brings players back tomorrow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DailyConfig = require(Shared.Config.Daily)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Daily = {}

type QuestView = { text: string, target: number, progress: number, done: boolean, claimed: boolean }
type DailyState = {
	canClaim: boolean,
	slot: number,
	claims: number,
	quests: { QuestView },
	allBonusClaimed: boolean,
	secondsToReset: number,
}

local GOLD = Color3.fromRGB(255, 205, 60)
local GOLD_DARK = Color3.fromRGB(140, 85, 0)
local GREEN = Color3.fromRGB(90, 200, 100)
local GREEN_DARK = Color3.fromRGB(25, 100, 40)
local GREY = Color3.fromRGB(190, 190, 200)

local panel: Panel.Panel
local dayCells: { { frame: Frame, stroke: UIStroke, check: TextLabel } } = {}
local claimButton: TextButton
local claimLabel: TextLabel
local questRows: { { text: TextLabel, fill: Frame, count: TextLabel, button: TextButton, label: TextLabel } } =
	{}
local resetLabel: TextLabel
local state: DailyState? = nil
local openedToday = false

local function build()
	panel = Panel.new("Daily", "Daily", GOLD, GOLD_DARK, Vector2.new(600, 330))
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	UI.new("UIPadding", { PaddingBottom = UDim.new(0, 8), Parent = panel.body })

	-- Calendar strip
	local strip = UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 92),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel.body,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, r in DailyConfig.Calendar do
		local big = i == #DailyConfig.Calendar
		local cell: Frame = UI.new("Frame", {
			Size = UDim2.fromOffset(if big then 104 else 66, 92),
			BackgroundColor3 = if big then Color3.fromRGB(255, 240, 200) else Color3.fromRGB(255, 255, 255),
			LayoutOrder = i,
			Parent = strip,
		}, { UI.corner(12) })
		local stroke = UI.stroke(GREY, 2.5)
		stroke.Parent = cell
		UI.bigText({
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 16),
			Text = "DAY " .. i,
			TextColor3 = GOLD,
			Parent = cell,
		}, GOLD_DARK, 1.5)
		UI.label({
			Position = UDim2.fromOffset(4, 22),
			Size = UDim2.new(1, -8, 0, 32),
			Text = r.emoji,
			Parent = cell,
		})
		UI.label({
			Position = UDim2.fromOffset(4, 56),
			Size = UDim2.new(1, -8, 0, 30),
			Text = r.label,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(80, 70, 60),
			Parent = cell,
		})
		local check = UI.bigText({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 2, 0, -4),
			Size = UDim2.fromOffset(24, 24),
			Text = "✓",
			TextColor3 = GREEN,
			Visible = false,
			ZIndex = 3,
			Parent = cell,
		}, GREEN_DARK, 2)
		table.insert(dayCells, { frame = cell, stroke = stroke, check = check })
	end

	-- Claim button + reset timer
	local claimRow = UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 46),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel.body,
	})
	claimButton, claimLabel = Panel.button({
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(240, 42),
		Parent = claimRow,
	}, GREEN, GREEN_DARK, "CLAIM!")
	claimButton.Activated:Connect(function()
		if state and state.canClaim then
			Sound.play("Purchase")
			UI.bump(claimButton, 0.2)
			Remotes.get(Remotes.Names.ClaimDaily):FireServer()
		end
	end)
	resetLabel = UI.label({
		Position = UDim2.fromOffset(252, 6),
		Size = UDim2.new(1, -256, 1, -12),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(110, 90, 70),
		Parent = claimRow,
	})

	-- Quests
	UI.bigText({
		Size = UDim2.new(1, -12, 0, 24),
		Text = "📋 Today's quests",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		LayoutOrder = 3,
		Parent = panel.body,
	}, GOLD_DARK, 2)
	for i = 1, DailyConfig.QuestsPerDay do
		local row = UI.new("Frame", {
			Size = UDim2.new(1, -12, 0, 54),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			LayoutOrder = 3 + i,
			Parent = panel.body,
		}, { UI.corner(12), UI.stroke(GREY, 2) })
		local text = UI.label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 20),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(60, 50, 40),
			Parent = row,
		})
		local bar = UI.new("Frame", {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -150, 0, 16),
			BackgroundColor3 = Color3.fromRGB(235, 228, 210),
			Parent = row,
		}, { UI.corner(8) })
		local fill = UI.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = GOLD,
			Parent = bar,
		}, { UI.corner(8) })
		local count = UI.bigText({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 2,
			Parent = bar,
		}, GOLD_DARK, 1.5)
		local button, label = Panel.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(120, 38),
			Parent = row,
		}, GREY, Color3.fromRGB(110, 110, 120), "…")
		local index = i
		button.Activated:Connect(function()
			local s = state
			local q = s and s.quests[index]
			if q and q.done and not q.claimed then
				Sound.play("Purchase")
				UI.bump(button, 0.2)
				Remotes.get(Remotes.Names.ClaimQuest):FireServer(index)
			end
		end)
		table.insert(questRows, { text = text, fill = fill, count = count, button = button, label = label })
	end

	panel.onOpen = function()
		Daily.render()
	end
	HUD.setTileHandler("Daily", panel.toggle)
end

function Daily.render()
	local s = state
	if not s then
		return
	end
	-- Calendar: claimed days get a check; the next one glows
	local claimedInLoop = s.claims % #DailyConfig.Calendar
	for i, cell in dayCells do
		local isNext = i == s.slot
		cell.check.Visible = i <= claimedInLoop and not (isNext and s.canClaim)
		cell.stroke.Color = if isNext then (if s.canClaim then GREEN else GOLD) else GREY
		cell.stroke.Thickness = if isNext then 4 else 2.5
	end
	if s.canClaim then
		claimLabel.Text = string.format("CLAIM DAY %d!", s.slot)
		claimButton.BackgroundColor3 = GREEN
		resetLabel.Text = "Come back every day – your streak never resets!"
	else
		claimLabel.Text = "CLAIMED ✓"
		claimButton.BackgroundColor3 = GREY
		resetLabel.Text = "Next reward in " .. Format.duration(s.secondsToReset)
	end
	for i, row in questRows do
		local q = s.quests[i]
		if q then
			row.text.Text = q.text
			row.fill.Size = UDim2.fromScale(q.progress / q.target, 1)
			row.fill.BackgroundColor3 = if q.done then GREEN else GOLD
			row.count.Text = string.format("%d/%d", q.progress, q.target)
			if q.claimed then
				row.label.Text = "DONE ✓"
				row.button.BackgroundColor3 = GREY
			elseif q.done then
				row.label.Text = "CLAIM!"
				row.button.BackgroundColor3 = GREEN
			else
				row.label.Text = "IN PROGRESS"
				row.button.BackgroundColor3 = GREY
			end
		end
	end
end

function Daily.start()
	build()
	Remotes.get(Remotes.Names.DailySync).OnClientEvent:Connect(function(s: DailyState)
		state = s
		if panel.isOpen() then
			Daily.render()
		end
		-- Open by itself once per session when today's reward is waiting (not during the
		-- tutorial: brand-new players learn the farm first)
		if s.canClaim and not openedToday and player:GetAttribute("Tutorial") ~= true then
			openedToday = true
			task.delay(2.5, function()
				if not panel.isOpen() then
					panel.setOpen(true)
				end
			end)
		end
	end)
	local function refreshBadge()
		HUD.setTileBadge("Daily", if player:GetAttribute("DailyReady") == true then "!" else nil)
	end
	refreshBadge()
	player:GetAttributeChangedSignal("DailyReady"):Connect(refreshBadge)
end

return Daily
