--!strict
-- Robux store (design doc §8): boosts, bundles and game passes, all with KNOWN contents and
-- clear prices. Passes can be gifted to a friend in the server. Also: the one-time Starter
-- Bundle popup (after the first Rare), the boom-time Value Boost offer at the market, and the
-- Carrot Scanner odds panel. Products with ID 0 show "Coming soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Products = require(Config.Products)
local Rarity = require(Config.Rarity)
local Mutations = require(Config.Mutations)
local SeedsConfig = require(Config.Seeds)
local Upgrades = require(Config.Upgrades)
local Events = require(Config.Events)
local EconomyConfig = require(Config.Economy)
local Roller = require(Shared.Roller)
local Progression = require(Shared.Progression)
local EventSchedule = require(Shared.EventSchedule)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Store = {}

local ROBUX_GREEN = Color3.fromRGB(80, 210, 90)
local ROBUX_DARK = Color3.fromRGB(25, 100, 35)
local GRAY = Color3.fromRGB(175, 175, 190)
local GRAY_DARK = Color3.fromRGB(90, 90, 105)
local PINK = Color3.fromRGB(255, 120, 190)
local PINK_DARK = Color3.fromRGB(140, 30, 90)

type Card = { refresh: () -> () }

local panel: Panel.Panel
local giftPanel: Panel.Panel
local oddsPanel: Panel.Panel
local cards: { Card } = {}
local boostLabel: TextLabel
local priceCache: { [string]: number } = {}

local function track(event: string, detail: string)
	Remotes.get(Remotes.Names.Track):FireServer(event, detail)
end

local function owns(passId: string): boolean
	return player:GetAttribute("Pass_" .. passId) == true
end

-- Real Robux price from Roblox when the ID is set, config price otherwise.
local function priceOf(key: string, id: number, infoType: Enum.InfoType, fallback: number): number
	if id == 0 then
		return fallback
	end
	local cached = priceCache[key]
	if cached then
		return cached
	end
	priceCache[key] = fallback
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and typeof(info.PriceInRobux) == "number" then
			priceCache[key] = info.PriceInRobux
			for _, c in cards do
				c.refresh()
			end
		end
	end)
	return fallback
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

function Store.buyProduct(product: Products.ProductDef, placement: string)
	if product.productId == 0 then
		HUD.toast("Coming soon!")
		return
	end
	track("OfferClicked", product.id .. "@" .. placement)
	MarketplaceService:PromptProductPurchase(player, product.productId)
end

local function buyPass(pass: Products.PassDef)
	if pass.passId == 0 then
		HUD.toast("Coming soon!")
		return
	end
	track("OfferClicked", pass.id .. "@store")
	MarketplaceService:PromptGamePassPurchase(player, pass.passId)
end

local function header(text: string, order: number)
	UI.bigText({
		Size = UDim2.new(1, -12, 0, 26),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 140, 190),
		LayoutOrder = order,
		Parent = panel.body,
	}, PINK_DARK, 2.5)
end

-- A row card: emoji badge, name, description, one or two buttons on the right.
local function card(order: number, emoji: string, color: Color3, name: string, description: string): Frame
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.45)
	local row = UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 74),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		LayoutOrder = order,
		Parent = panel.body,
	}, { UI.corner(16), UI.stroke(dark, 3) })
	local badge = UI.new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = color,
		Parent = row,
	}, { UI.corner(14), UI.stroke(dark, 2.5) })
	UI.label({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = badge,
	})
	UI.bigText({
		Position = UDim2.fromOffset(76, 8),
		Size = UDim2.new(1, -330, 0, 24),
		Text = name,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}, dark, 2.5)
	UI.label({
		Position = UDim2.fromOffset(76, 34),
		Size = UDim2.new(1, -330, 0, 34),
		Text = description,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(80, 80, 100),
		Parent = row,
	})
	return row
end

local function productCard(product: Products.ProductDef, order: number)
	local row = card(order, product.emoji, UI.rgb(product.color), product.name, product.description)
	local button, label = Panel.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(130, 56),
		Parent = row,
	}, ROBUX_GREEN, ROBUX_DARK, "")
	local function refresh()
		local bought = product.once and player:GetAttribute("Bought_" .. product.id) == true
		if bought then
			label.Text = "BOUGHT"
			paint(button, label, GRAY, GRAY_DARK)
		elseif product.productId == 0 then
			label.Text = "Soon!"
			paint(button, label, GRAY, GRAY_DARK)
		else
			label.Text = "R$ " .. priceOf(product.id, product.productId, Enum.InfoType.Product, product.price)
			paint(button, label, ROBUX_GREEN, ROBUX_DARK)
		end
	end
	button.Activated:Connect(function()
		if product.once and player:GetAttribute("Bought_" .. product.id) == true then
			return
		end
		Store.buyProduct(product, "store")
	end)
	refresh()
	table.insert(cards, { refresh = refresh })
end

local function openGift(pass: Products.PassDef)
	giftPanel.subtitle.Text = pass.emoji .. " " .. pass.name
	for _, child in giftPanel.body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local any = false
	for i, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Pass_" .. pass.id) ~= true then
			any = true
			local b, _ = Panel.button({
				Size = UDim2.new(1, -12, 0, 50),
				LayoutOrder = i,
				Parent = giftPanel.body,
			}, PINK, PINK_DARK, "🎁 " .. other.DisplayName)
			b.Activated:Connect(function()
				Remotes.get(Remotes.Names.SetGiftTarget):FireServer(other.UserId, pass.id)
				giftPanel.setOpen(false)
				track("OfferClicked", pass.id .. "@gift")
				MarketplaceService:PromptProductPurchase(player, pass.giftProductId)
			end)
		end
	end
	if not any then
		UI.label({
			Size = UDim2.new(1, -12, 0, 40),
			Text = "Nobody here to gift to yet – invite a friend!",
			TextColor3 = Color3.fromRGB(110, 80, 50),
			Parent = giftPanel.body,
		})
	end
	giftPanel.setOpen(true)
end

local function passCard(pass: Products.PassDef, order: number)
	local row = card(order, pass.emoji, UI.rgb(pass.color), pass.name, pass.description)
	local button, label = Panel.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(120, 56),
		Parent = row,
	}, ROBUX_GREEN, ROBUX_DARK, "")
	local gift, giftLabel = Panel.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(82, 56),
		Parent = row,
	}, PINK, PINK_DARK, "🎁 Gift")
	local function refresh()
		if owns(pass.id) then
			label.Text = "OWNED"
			paint(button, label, GRAY, GRAY_DARK)
		elseif pass.passId == 0 then
			label.Text = "Soon!"
			paint(button, label, GRAY, GRAY_DARK)
		else
			label.Text = "R$ " .. priceOf(pass.id, pass.passId, Enum.InfoType.GamePass, pass.price)
			paint(button, label, ROBUX_GREEN, ROBUX_DARK)
		end
		if pass.giftProductId == 0 then
			paint(gift, giftLabel, GRAY, GRAY_DARK)
		else
			paint(gift, giftLabel, PINK, PINK_DARK)
		end
	end
	button.Activated:Connect(function()
		if not owns(pass.id) then
			buyPass(pass)
		end
	end)
	gift.Activated:Connect(function()
		if pass.giftProductId == 0 then
			HUD.toast("Gifting is coming soon!")
		else
			openGift(pass)
		end
	end)
	refresh()
	table.insert(cards, { refresh = refresh })
end

local function boostText(): string
	local parts = {}
	for _, b in Products.Boosts do
		local left = player:GetAttribute("Boost_" .. b.id)
		if typeof(left) == "number" and left > 0 then
			table.insert(parts, string.format("%s %s %s", b.emoji, b.name, Format.duration(left)))
		end
	end
	if #parts == 0 then
		return "Boosts only count down while you play ⏸"
	end
	return table.concat(parts, "   ")
end

local function buildStore()
	panel = Panel.new("Store", "Shop", Color3.fromRGB(255, 120, 190), PINK_DARK, Vector2.new(620, 320))
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	UI.new("UIPadding", { PaddingBottom = UDim.new(0, 8), Parent = panel.body })
	boostLabel = UI.label({
		Size = UDim2.new(1, -12, 0, 20),
		Text = "",
		TextColor3 = Color3.fromRGB(60, 140, 60),
		LayoutOrder = 0,
		Parent = panel.body,
	})
	local order = 1
	header("⚡ Boosts", order)
	for _, p in Products.DeveloperProducts do
		if p.kind ~= "bundle" then
			order += 1
			productCard(p, order)
		end
	end
	order += 1
	header("🎁 Bundles", order)
	for _, p in Products.DeveloperProducts do
		if p.kind == "bundle" then
			order += 1
			productCard(p, order)
		end
	end
	order += 1
	header("⭐ Game Passes", order)
	for _, p in Products.GamePasses do
		order += 1
		passCard(p, order)
	end
	panel.onOpen = function()
		boostLabel.Text = boostText()
		for _, c in cards do
			c.refresh()
		end
		track("OpenedStore", "")
	end
	HUD.setTileHandler("Shop", panel.toggle)

	giftPanel = Panel.new("Gift", "Gift to…", PINK, PINK_DARK, Vector2.new(380, 280))
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = giftPanel.body,
	})
end

-- Carrot Scanner ---------------------------------------------------------

local trackById: { [string]: Upgrades.UpgradeDef } = {}
for _, t in Upgrades do
	trackById[t.id] = t
end
local seedById: { [string]: SeedsConfig.SeedDef } = {}
for _, s in SeedsConfig do
	seedById[s.id] = s
end

local function attrNumber(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- Same luck the server uses when you plant next (upgrades, seed, friends, boosts, server luck).
local function currentLuck(): (number, SeedsConfig.SeedDef)
	local luck = Progression.multiplier(trackById.Luck, attrNumber(player, "Upg_Luck", 0))
	luck *= 1 + attrNumber(player, "FriendBoost", 0)
	luck *= attrNumber(player, "LuckBoost", 1)
	if attrNumber(workspace, "ServerLuckEnds", 0) > workspace:GetServerTimeNow() then
		luck *= attrNumber(workspace, "ServerLuck", 1)
	end
	local selected = player:GetAttribute("SelectedSeed")
	local seed = seedById[if typeof(selected) == "string" then selected else "Basic"] or seedById.Basic
	return luck * seed.luck, seed
end

local oddsRows: { { label: TextLabel, rarity: Rarity.RarityDef } } = {}
local mutationLabel: TextLabel

local function refreshOdds()
	local luck, seed = currentLuck()
	local ctx: Roller.RollContext = { luck = luck }
	if seed.minRarity then
		for _, r in Rarity do
			if r.id == seed.minRarity then
				ctx.minRarityOrder = r.order
			end
		end
	end
	local weights = Roller.rarityWeights(Rarity :: any, ctx)
	local total = 0
	for _, w in weights do
		total += w
	end
	for i, row in oddsRows do
		local p = if total > 0 then weights[i] / total else 0
		row.label.Text = if p > 0
			then string.format("%s   (%s)", Format.percent(p), Format.oneIn(p))
			else "–"
	end
	local mutTotal = 0
	for _, m in Mutations.List do
		mutTotal += m.chance
	end
	local mutationLuck = Progression.mutationLuck(luck / seed.luck, Mutations.LuckFactor) * seed.mutationLuck
	local mutChance = if seed.forceMutation
		then 1
		else math.min(Mutations.MaxTotalChance, mutTotal * mutationLuck)
	mutationLabel.Text = string.format(
		"Mutation chance: %s   ·   Luck x%s   ·   Seed: %s",
		Format.percent(mutChance),
		tostring(math.floor(luck * 100 + 0.5) / 100),
		seed.name
	)
	oddsPanel.subtitle.Text = if owns("Scanner") then "🔍 Scanner" else ""
end

local function buildOdds()
	oddsPanel = Panel.new(
		"Odds",
		"My Odds",
		Color3.fromRGB(90, 220, 200),
		Color3.fromRGB(10, 100, 90),
		Vector2.new(460, 320)
	)
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = oddsPanel.body,
	})
	mutationLabel = UI.label({
		Size = UDim2.new(1, -12, 0, 20),
		Text = "",
		TextColor3 = Color3.fromRGB(10, 100, 90),
		LayoutOrder = 0,
		Parent = oddsPanel.body,
	})
	for i, r in Rarity do
		local color = UI.rgb(r.color)
		local row = UI.new("Frame", {
			Size = UDim2.new(1, -12, 0, 30),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.7),
			LayoutOrder = i,
			Parent = oddsPanel.body,
		}, { UI.corner(10) })
		UI.bigText({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.4, -10, 1, -8),
			Text = r.name,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, color:Lerp(Color3.new(0, 0, 0), 0.6), 2)
		local l = UI.bigText({
			Position = UDim2.new(0.4, 0, 0, 4),
			Size = UDim2.new(0.6, -10, 1, -8),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(60, 60, 80),
			Parent = row,
		}, Color3.new(1, 1, 1), 1.5)
		table.insert(oddsRows, { label = l, rarity = r })
	end
	oddsPanel.onOpen = refreshOdds
end

-- Opening the odds: the Scanner pass shows them; without it, the store explains the pass.
function Store.openOdds()
	if owns("Scanner") then
		oddsPanel.setOpen(true)
	else
		HUD.toast("The 🔍 Carrot Scanner pass shows your exact odds!", Color3.fromRGB(90, 220, 200), 4)
		panel.setOpen(true)
	end
end

-- Offers -----------------------------------------------------------------

local function starterPopup(product: Products.ProductDef)
	local popup = Panel.new(
		"StarterOffer",
		"Special Offer!",
		Color3.fromRGB(255, 120, 160),
		PINK_DARK,
		Vector2.new(420, 250)
	)
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = popup.body,
	})
	UI.bigText({
		Size = UDim2.new(1, -12, 0, 30),
		Text = "🎉 Your first Rare! 🎉",
		TextColor3 = Color3.fromRGB(80, 170, 255),
		LayoutOrder = 1,
		Parent = popup.body,
	}, Color3.fromRGB(20, 70, 150), 2.5)
	UI.label({
		Size = UDim2.new(1, -12, 0, 44),
		Text = product.emoji .. " " .. product.name .. ": " .. product.description,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(80, 60, 50),
		LayoutOrder = 2,
		Parent = popup.body,
	})
	local buy, buyLabel = Panel.button({
		Size = UDim2.fromOffset(220, 52),
		LayoutOrder = 3,
		Parent = popup.body,
	}, ROBUX_GREEN, ROBUX_DARK, "")
	buyLabel.Text = "R$ " .. priceOf(product.id, product.productId, Enum.InfoType.Product, product.price)
	local no = UI.new("TextButton", {
		Size = UDim2.fromOffset(160, 26),
		BackgroundTransparency = 1,
		Text = "No thanks",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(140, 120, 110),
		LayoutOrder = 4,
		Parent = popup.body,
	})
	buy.Activated:Connect(function()
		popup.setOpen(false)
		Store.buyProduct(product, "starter_popup")
	end)
	no.Activated:Connect(function()
		popup.setOpen(false)
	end)
	popup.setOpen(true)
end

-- Boom-time Value Boost button by the SELL tile, only at the market and never when the pity
-- meter is nearly full (the player is about to be rewarded anyway).
local function buildBoomOffer()
	local product: Products.ProductDef? = nil
	for _, p in Products.DeveloperProducts do
		if p.id == "ValueBoost" then
			product = p
		end
	end
	if not product or product.productId == 0 then
		return
	end
	local valueBoost: Products.ProductDef = product
	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = "BoomOffer",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
	})
	UI.autoScale(gui)
	local button, label = Panel.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0.46, 82),
		Size = UDim2.fromOffset(140, 40),
		Visible = false,
		Parent = gui,
	}, Color3.fromRGB(255, 205, 50), Color3.fromRGB(130, 80, 0), "💰 x2 Value")
	button.Activated:Connect(function()
		Store.buyProduct(valueBoost, "boom_market")
	end)
	local shownCycle = -1
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local state = EventSchedule.at(workspace:GetServerTimeNow(), Events :: any)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = false
		if root and root:IsA("BasePart") then
			local p = (root :: BasePart).Position
			near = Vector2.new(p.X, p.Z).Magnitude <= Events.MarketRadius
		end
		local pity = attrNumber(player, "Pity", 0)
			/ math.max(1, attrNumber(player, "PityMax", EconomyConfig.PityLegendary))
		local show = state.boomActive
			and near
			and pity < Products.OfferPityHide
			and attrNumber(player, "Boost_Value2", 0) <= 0
		button.Visible = show
		label.Text = "💰 x2 Value · R$ "
			.. priceOf(valueBoost.id, valueBoost.productId, Enum.InfoType.Product, valueBoost.price)
		if show and shownCycle ~= state.cycle then
			shownCycle = state.cycle
			track("OfferShown", "ValueBoost@boom_market")
		end
	end)
end

function Store.start()
	buildStore()
	buildOdds()
	buildBoomOffer()
	HUD.setOddsHandler(Store.openOdds)

	Remotes.get(Remotes.Names.Offer).OnClientEvent:Connect(function(id: string)
		for _, p in Products.DeveloperProducts do
			if p.id == id then
				task.delay(1.5, starterPopup, p) -- let the Rare moment play first
			end
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Pass_" or string.sub(name, 1, 7) == "Bought_" then
			for _, c in cards do
				c.refresh()
			end
		end
		if panel.isOpen() and string.sub(name, 1, 6) == "Boost_" then
			boostLabel.Text = boostText()
		end
		if oddsPanel.isOpen() then
			refreshOdds()
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_userId, _productId, purchased)
		if purchased then
			Sound.play("Purchase")
		end
	end)
end

return Store
