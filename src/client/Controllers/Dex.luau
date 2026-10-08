--!strict
-- CarrotDex: layer 1 = every carrot type (found ones in full color, unfound as a silhouette),
-- layer 2 = mutation stamps per type (one dot per mutation). Odds are always shown (design
-- doc §11). Rewards for milestones come from the server (Config/Dex).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local CarrotsConfig = require(Config.Carrots)
local Mutations = require(Config.Mutations)
local DexConfig = require(Config.Dex)
local SeedsConfig = require(Config.Seeds)
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local UI = require(script.Parent.Parent.Util.UI)
local Panel = require(script.Parent.Parent.Util.Panel)
local CarrotIcon = require(script.Parent.Parent.Util.CarrotIcon)
local HUD = require(script.Parent.HUD)

local Dex = {}

type Card = {
	def: CarrotsConfig.CarrotDef,
	icon: ViewportFrame,
	name: TextLabel,
	frame: Frame,
	dots: { [string]: Frame },
}

local panel: Panel.Panel
local cards: { Card } = {}
local milestoneLabel: TextLabel
local state: Types.DexState = { types = {}, stamps = {} }
local seen: { [string]: boolean } = {}
local firstSync = true

local seedName: { [string]: string } = {}
for _, s in SeedsConfig do
	seedName[s.id] = s.name
end

-- Chance of one specific type with base luck.
local function typeChance(def: CarrotsConfig.CarrotDef): number
	local rarity = CarrotInfo.rarityOfType(def.id)
	local total = 0
	for _, c in CarrotsConfig do
		if c.rarity == def.rarity then
			total += c.weight
		end
	end
	return rarity.chance * def.weight / total
end

local function counts(): (number, number)
	local found, stamps = 0, 0
	for id in state.types do
		if CarrotInfo.type(id) then
			found += 1
		end
	end
	for _ in state.stamps do
		stamps += 1
	end
	return found, stamps
end

local function nextMilestoneText(found: number, stamps: number): string
	local parts = {}
	for _, m in DexConfig.TypeMilestones do
		if found < m.count then
			table.insert(
				parts,
				string.format("%d found → %d %s", m.count, m.amount, seedName[m.seed] or m.seed)
			)
			break
		end
	end
	for _, m in DexConfig.StampMilestones do
		if stamps < m.count then
			table.insert(
				parts,
				string.format("%d stamps → %d %s", m.count, m.amount, seedName[m.seed] or m.seed)
			)
			break
		end
	end
	if #parts == 0 then
		return "All rewards collected – you're a Carrot Master!"
	end
	return "Next reward: " .. table.concat(parts, "   ·   ")
end

local function refresh()
	local found, stamps = counts()
	panel.subtitle.Text = string.format("%d/%d found", found, CarrotInfo.TotalTypes)
	milestoneLabel.Text = string.format(
		"Stamps %d/%d   ·   %s",
		stamps,
		CarrotInfo.TotalStamps,
		nextMilestoneText(found, stamps)
	)
	for _, card in cards do
		local isFound = state.types[card.def.id] == true
		local rarity = CarrotInfo.rarityOfType(card.def.id)
		card.icon.ImageColor3 = if isFound then Color3.new(1, 1, 1) else Color3.fromRGB(40, 30, 60)
		card.name.Text = if isFound then card.def.name else "???"
		local color = CarrotInfo.color(rarity.color)
		card.frame.BackgroundColor3 = if isFound
			then color:Lerp(Color3.new(1, 1, 1), 0.65)
			else Color3.fromRGB(225, 225, 235)
		for mutId, dot in card.dots do
			local m = CarrotInfo.mutation(mutId)
			local has = state.stamps[card.def.id .. "|" .. mutId] == true
			dot.BackgroundColor3 = if has and m
				then CarrotInfo.color(m.color)
				else Color3.fromRGB(235, 235, 240)
			dot.BackgroundTransparency = if has then 0 else 0.2
		end
	end
end

local function build()
	panel = Panel.new(
		"Index",
		"CarrotDex",
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(20, 70, 150),
		Vector2.new(640, 320)
	)

	milestoneLabel = UI.label({
		Size = UDim2.new(1, -12, 0, 20),
		Text = "",
		TextColor3 = Color3.fromRGB(40, 70, 140),
		LayoutOrder = 0,
		Parent = panel.body,
	})
	local grid = UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel.body,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(110, 138),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
		Parent = panel.body,
	})

	local configIndex: { [string]: number } = {}
	for i, def in CarrotsConfig do
		configIndex[def.id] = i
	end
	local ordered = table.clone(CarrotsConfig)
	table.sort(ordered, function(a, b)
		local ra, rb = CarrotInfo.rarityOrder(a.rarity), CarrotInfo.rarityOrder(b.rarity)
		if ra ~= rb then
			return ra < rb
		end
		return configIndex[a.id] < configIndex[b.id]
	end)

	for i, def in ordered do
		local rarity = CarrotInfo.rarityOfType(def.id)
		local color = CarrotInfo.color(rarity.color)
		local dark = color:Lerp(Color3.new(0, 0, 0), 0.5)
		local frame: Frame = UI.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(225, 225, 235),
			LayoutOrder = i,
			Parent = grid,
		}, { UI.corner(14), UI.stroke(dark, 3) })
		local icon = CarrotIcon.new(def.id, {}, true)
		icon.Position = UDim2.fromOffset(10, 4)
		icon.Size = UDim2.new(1, -20, 0, 62)
		icon.Parent = frame
		local name = UI.label({
			Position = UDim2.fromOffset(4, 66),
			Size = UDim2.new(1, -8, 0, 18),
			Text = "???",
			TextColor3 = Color3.fromRGB(50, 50, 70),
			Parent = frame,
		})
		UI.bigText({
			Position = UDim2.fromOffset(4, 85),
			Size = UDim2.new(1, -8, 0, 16),
			Text = rarity.name,
			TextColor3 = color,
			Parent = frame,
		}, dark, 1.5)
		UI.label({
			Position = UDim2.fromOffset(4, 101),
			Size = UDim2.new(1, -8, 0, 14),
			Text = Format.oneIn(typeChance(def)),
			TextColor3 = Color3.fromRGB(90, 90, 110),
			Parent = frame,
		})
		-- Mutation stamps
		local dotsRow = UI.new("Frame", {
			Position = UDim2.new(0, 0, 1, -20),
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Parent = frame,
		}, {
			UI.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
		})
		local dots: { [string]: Frame } = {}
		for _, m in Mutations.List do
			dots[m.id] = UI.new("Frame", {
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = Color3.fromRGB(235, 235, 240),
				Parent = dotsRow,
			}, { UI.corner(7), UI.stroke(Color3.fromRGB(120, 120, 140), 1.5) })
		end
		table.insert(cards, { def = def, icon = icon, name = name, frame = frame, dots = dots })
	end

	panel.onOpen = function()
		refresh()
		Remotes.get(Remotes.Names.Track):FireServer("OpenedDex", "")
		for id in state.types do
			seen[id] = true
		end
		HUD.setTileBadge("Index", nil)
	end
	HUD.setTileHandler("Index", panel.toggle)
end

function Dex.start()
	build()
	Remotes.get(Remotes.Names.DexSync).OnClientEvent:Connect(function(s: Types.DexState)
		state = s
		if firstSync then
			-- Everything known at join counts as seen.
			firstSync = false
			for id in s.types do
				seen[id] = true
			end
		else
			local unseen = 0
			for id in s.types do
				if not seen[id] then
					unseen += 1
				end
			end
			if unseen > 0 and not panel.isOpen() then
				HUD.setTileBadge("Index", "!")
			end
		end
		if panel.isOpen() then
			refresh()
		end
	end)
end

return Dex
