--!strict
-- Seeds panel: every seed with what it does, its odds (Mystery Seeds show exact odds), how many
-- you have, BUY x1 / x10 for cash and USE. Seeds are never sold for Robux.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local SeedsConfig = require(Config.Seeds)
local World = require(Config.World)
local Upgrades = require(Config.Upgrades)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Seeds = {}

type Row = {
	seed: SeedsConfig.SeedDef,
	count: TextLabel,
	buy1: TextButton?,
	buy1Text: TextLabel?,
	buy10: TextButton?,
	buy10Text: TextLabel?,
	use: TextButton,
	useText: TextLabel,
}

local GREEN = Color3.fromRGB(80, 210, 90)
local GREEN_DARK = Color3.fromRGB(25, 100, 35)
local BLUE = Color3.fromRGB(80, 170, 255)
local BLUE_DARK = Color3.fromRGB(20, 70, 150)
local GRAY = Color3.fromRGB(175, 175, 190)
local GRAY_DARK = Color3.fromRGB(90, 90, 105)

local panel: Panel.Panel
local rows: { Row } = {}
local valueTrack: Upgrades.UpgradeDef? = nil
for _, t in Upgrades do
	if t.id == "Value" then
		valueTrack = t
	end
end
local seedName: { [string]: string } = {}
for _, s in SeedsConfig do
	seedName[s.id] = s.name
end

local function attrNumber(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function price(seed: SeedsConfig.SeedDef): number
	local bonus = if valueTrack then Progression.bonus(valueTrack, attrNumber("Upg_Value")) else 0
	return Progression.seedPrice(seed.basePrice, bonus)
end

local function selected(): string
	local v = player:GetAttribute("SelectedSeed")
	return if typeof(v) == "string" then v else "Basic"
end

local function paint(button: TextButton, label: TextLabel, color: Color3, dark: Color3)
	button.BackgroundColor3 = color
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = dark
	end
	local textStroke = label:FindFirstChildOfClass("UIStroke")
	if textStroke then
		textStroke.Color = dark
	end
end

local function refresh()
	local cash = attrNumber("Cash")
	local sel = selected()
	for _, row in rows do
		local id = row.seed.id
		local count = attrNumber("Seed_" .. id)
		row.count.Text = if id == "Basic" then "∞" else "x" .. Format.number(count)
		if row.buy1 and row.buy1Text and row.buy10 and row.buy10Text then
			local p = price(row.seed)
			row.buy1Text.Text = "1 · " .. Format.cash(p)
			row.buy10Text.Text = "10 · " .. Format.cash(p * 10)
			if cash >= p then
				paint(row.buy1, row.buy1Text, GREEN, GREEN_DARK)
			else
				paint(row.buy1, row.buy1Text, GRAY, GRAY_DARK)
			end
			if cash >= p * 10 then
				paint(row.buy10, row.buy10Text, GREEN, GREEN_DARK)
			else
				paint(row.buy10, row.buy10Text, GRAY, GRAY_DARK)
			end
		end
		if sel == id then
			row.useText.Text = "IN USE"
			paint(row.use, row.useText, Color3.fromRGB(255, 205, 50), Color3.fromRGB(130, 80, 0))
		elseif id == "Basic" or count > 0 then
			row.useText.Text = "USE"
			paint(row.use, row.useText, BLUE, BLUE_DARK)
		else
			row.useText.Text = "USE"
			paint(row.use, row.useText, GRAY, GRAY_DARK)
		end
	end
end

local function oddsText(seed: SeedsConfig.SeedDef): string
	local mystery = seed.mystery
	if not mystery then
		if seed.growMult > 1 then
			return string.format("%s · ⏱ %sx grow time", seed.description, tostring(seed.growMult))
		end
		return seed.description
	end
	local total = 0
	for _, o in mystery do
		total += o.weight
	end
	local parts = {}
	for _, o in mystery do
		local name = string.gsub(seedName[o.seed] or o.seed, " Seed", "")
		table.insert(parts, string.format("%s %s", name, Format.percent(o.weight / total)))
	end
	return table.concat(parts, " · ")
end

local function build()
	panel = Panel.new(
		"Seeds",
		"Seeds",
		Color3.fromRGB(120, 215, 90),
		Color3.fromRGB(40, 110, 30),
		Vector2.new(600, 310)
	)
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
	panel.subtitle.Text = "Cash only!"

	for i, seed in SeedsConfig do
		local color = UI.rgb(seed.color)
		local dark = color:Lerp(Color3.new(0, 0, 0), 0.45)
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			LayoutOrder = i,
			Parent = panel.body,
		}, { UI.corner(16), UI.stroke(dark, 3) })
		local badge = UI.new("Frame", {
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = color,
			Parent = row,
		}, { UI.corner(14), UI.stroke(dark, 2.5) })
		UI.label({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			Text = seed.emoji,
			Font = Enum.Font.GothamBold,
			Parent = badge,
		})
		local count = UI.bigText({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.fromOffset(44, 20),
			Text = "",
			ZIndex = 3,
			Parent = badge,
		}, dark, 2)
		UI.bigText({
			Position = UDim2.fromOffset(76, 8),
			Size = UDim2.new(1, -340, 0, 26),
			Text = seed.name,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, dark, 2.5)
		UI.label({
			Position = UDim2.fromOffset(76, 38),
			Size = UDim2.new(1, -340, 0, 30),
			Text = if seed.buyable or seed.id == "Basic"
				then oddsText(seed)
				else oddsText(seed) .. "\nFrom CarrotDex rewards",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(80, 80, 100),
			Parent = row,
		})

		local buy1, buy1Text, buy10, buy10Text = nil, nil, nil, nil
		if seed.buyable then
			buy1, buy1Text = Panel.button({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -102, 0, 8),
				Size = UDim2.fromOffset(150, 30),
				Parent = row,
			}, GREEN, GREEN_DARK, "")
			buy10, buy10Text = Panel.button({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -102, 0, 42),
				Size = UDim2.fromOffset(150, 30),
				Parent = row,
			}, GREEN, GREEN_DARK, "")
			local function buy(amount: number, button: TextButton)
				if attrNumber("Cash") >= price(seed) * amount then
					Remotes.get(Remotes.Names.BuySeed):FireServer(seed.id, amount)
					Sound.play("Purchase")
					UI.bump(button, 0.15)
				else
					Sound.play("Denied")
					HUD.toast("Not enough cash yet – sell some carrots!")
				end
			end
			assert(buy1 and buy10, "seed buttons")
			local b1, b10 = buy1, buy10
			b1.Activated:Connect(function()
				buy(1, b1)
			end)
			b10.Activated:Connect(function()
				buy(10, b10)
			end)
		end
		local use, useText = Panel.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(88, 64),
			Parent = row,
		}, BLUE, BLUE_DARK, "USE")
		use.Activated:Connect(function()
			if seed.id ~= "Basic" and attrNumber("Seed_" .. seed.id) <= 0 then
				HUD.toast(if seed.buyable then "Buy some first!" else "Earn these from CarrotDex rewards!")
				return
			end
			Remotes.get(Remotes.Names.SelectSeed):FireServer(seed.id)
			Sound.play("Click")
			UI.bump(use, 0.15)
		end)
		table.insert(rows, {
			seed = seed,
			count = count,
			buy1 = buy1,
			buy1Text = buy1Text,
			buy10 = buy10,
			buy10Text = buy10Text,
			use = use,
			useText = useText,
		})
	end

	panel.onOpen = refresh
	HUD.setTileHandler("Seeds", panel.toggle)
end

function Seeds.start()
	build()
	-- The Seed Store on the square: standing on its pad opens this panel too (the HUD button
	-- stays the main way for now).
	local seedPad = World.seedPad()
	local inside = false
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local p = (root :: BasePart).Position
		local d = Vector3.new(p.X - seedPad.X, 0, p.Z - seedPad.Z).Magnitude
		if not inside and d <= World.SeedPadRadius then
			inside = true
			if not panel.isOpen() then
				panel.setOpen(true)
			end
		elseif inside and d > World.SeedPadRadius + 2.5 then
			inside = false
			if panel.isOpen() then
				panel.setOpen(false)
			end
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if
			panel.isOpen()
			and (
				name == "Cash"
				or name == "SelectedSeed"
				or name == "Upg_Value"
				or string.sub(name, 1, 5) == "Seed_"
			)
		then
			refresh()
		end
	end)
end

return Seeds
