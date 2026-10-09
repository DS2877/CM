--!strict
-- Monetization (design doc §8, rules in §11): game passes, developer products, bundles, gifts,
-- timed boosts that only tick during play, and contextual offers.
--
-- ProcessReceipt is idempotent: each PurchaseId is recorded in the buyer's profile and the
-- profile is saved BEFORE Roblox is told the purchase was granted. If the save can't be
-- confirmed we return NotProcessedYet and Roblox retries later; the receipt log stops any
-- double grant on the retry.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Products = require(Config.Products)
local EconomyConfig = require(Config.Economy)
local Remotes = require(Shared.Remotes)
local Data = require(script.Parent.Data)
local Seeds = require(script.Parent.Seeds)
local Farm = require(script.Parent.Farm)
local Economy = require(script.Parent.Economy)
local Telemetry = require(script.Parent.Telemetry)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Product = {}

local MAX_RECEIPTS = 200
local TRACK_EVENTS = { OfferShown = true, OfferClicked = true, OpenedDex = true, OpenedStore = true }

local passById: { [string]: Products.PassDef } = {}
local passByRobloxId: { [number]: Products.PassDef } = {}
local passByGiftProduct: { [number]: Products.PassDef } = {}
local productById: { [string]: Products.ProductDef } = {}
local productByRobloxId: { [number]: Products.ProductDef } = {}
local boostById: { [string]: Products.BoostDef } = {}

for _, p in Products.GamePasses do
	passById[p.id] = p
	if p.passId ~= 0 then
		passByRobloxId[p.passId] = p
	end
	if p.giftProductId ~= 0 then
		passByGiftProduct[p.giftProductId] = p
	end
end
for _, p in Products.DeveloperProducts do
	productById[p.id] = p
	if p.productId ~= 0 then
		productByRobloxId[p.productId] = p
	end
end
for _, b in Products.Boosts do
	boostById[b.id] = b
end

-- Who a buyer wants to gift a pass to: set right before the gift prompt.
local pendingGifts: { [Player]: { target: number, pass: string } } = {}

local function notice(player: Player, text: string, kind: string?)
	Remotes.get(Remotes.Names.Notice):FireClient(player, { text = text, kind = kind or "good" })
end

-- Passes ------------------------------------------------------------------

local function today(): number
	return math.floor(os.time() / 86400)
end

-- (The ⭐ VIP tag over the head is drawn by the client Titles controller from Pass_MarketVIP.)

local function vipDaily(player: Player)
	local data = Data.get(player)
	if not data or player:GetAttribute("Pass_MarketVIP") ~= true or data.VipDailyDay == today() then
		return
	end
	data.VipDailyDay = today()
	Seeds.grant(player, Products.VipDaily.seed, Products.VipDaily.amount, "VIP daily bonus")
end

local function setPass(player: Player, passId: string)
	if player:GetAttribute("Pass_" .. passId) == true then
		return
	end
	player:SetAttribute("Pass_" .. passId, true)
	Economy.sync(player) -- Big Basket changes capacity
	if passId == "MarketVIP" then
		vipDaily(player)
	end
end

local function refreshPasses(player: Player)
	local data = Data.get(player)
	for _, pass in Products.GamePasses do
		local owned = data ~= nil and data.GiftedPasses[pass.id] == true
		if not owned and pass.passId ~= 0 and not RunService:IsStudio() then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.passId)
			end)
			owned = ok and result == true
		end
		if owned then
			setPass(player, pass.id)
		end
	end
	-- Offline growth waits for this: Big Basket and 2x Growth change what grew while away.
	player:SetAttribute("PassesLoaded", true)
end

-- Boosts ------------------------------------------------------------------

local function syncBoosts(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local luck, value = 1, 1
	local mega = false
	for id, seconds in data.Boosts do
		local b = boostById[id]
		if b and seconds > 0 then
			if b.stat == "Luck" then
				luck = math.max(luck, b.mult)
			elseif b.stat == "Value" then
				value *= b.mult
			end
			mega = mega or b.aura == true
		end
		player:SetAttribute("Boost_" .. id, if seconds > 0 then seconds else nil)
	end
	local valueChanged = player:GetAttribute("ValueBoost") ~= value
	player:SetAttribute("LuckBoost", luck)
	player:SetAttribute("ValueBoost", value)
	if valueChanged then
		Economy.sync(player) -- basket value includes value boosts
	end

	-- Mega Luck aura, visible to everyone
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local aura = root:FindFirstChild("MegaAura")
		if mega and not aura then
			local e = Instance.new("ParticleEmitter")
			e.Name = "MegaAura"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = 30
			e.Lifetime = NumberRange.new(0.6, 1.2)
			e.Speed = NumberRange.new(1, 3)
			e.SpreadAngle = Vector2.new(180, 180)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.5, 0)
			e.Color = ColorSequence.new(Color3.fromRGB(255, 150, 220), Color3.fromRGB(255, 240, 120))
			e.Parent = root
		elseif not mega and aura then
			aura:Destroy()
		end
	end
end

function Product.addBoost(player: Player, boostId: string, seconds: number)
	local data = Data.get(player)
	if not data or not boostById[boostId] then
		return
	end
	-- Buying the same boost again adds time; it never resets what you have.
	data.Boosts[boostId] = (data.Boosts[boostId] or 0) + seconds
	syncBoosts(player)
end

-- Server Luck for everyone in this server (from a purchase, or the admin dashboard).
function Product.serverLuck(byName: string, mult: number?, seconds: number?)
	local nowT = workspace:GetServerTimeNow()
	local ends = workspace:GetAttribute("ServerLuckEnds")
	local base = if typeof(ends) == "number" and ends > nowT then ends else nowT
	local m = mult or Products.ServerLuckMult
	workspace:SetAttribute("ServerLuck", m)
	workspace:SetAttribute("ServerLuckEnds", base + (seconds or Products.ServerLuckSeconds))
	workspace:SetAttribute("ServerLuckBy", byName)
	for _, p in Players:GetPlayers() do
		notice(p, string.format("🌍 %s started SERVER LUCK! Everyone gets x%s luck!", byName, tostring(m)))
	end
end

local function startServerLuck(buyer: Player)
	Product.serverLuck(buyer.DisplayName)
end

-- Admin: give or take a pass (as a gift flag; a real Roblox purchase can't be taken back).
function Product.setPassOwned(player: Player, passId: string, owned: boolean)
	local data = Data.get(player)
	if not data or not passById[passId] then
		return
	end
	if owned then
		data.GiftedPasses[passId] = true
		setPass(player, passId)
	else
		data.GiftedPasses[passId] = nil
		player:SetAttribute("Pass_" .. passId, nil)
		Economy.sync(player)
	end
end

function Product.syncBoosts(player: Player)
	syncBoosts(player)
end

-- Grants ------------------------------------------------------------------

local function grantProduct(player: Player, data: Data.PlayerData, product: Products.ProductDef)
	if product.kind == "serverBoost" then
		startServerLuck(player)
	elseif product.kind == "instantGrow" then
		Farm.instantGrow(player)
		notice(player, "⚡ All your carrots are ready!")
	end
	if product.boosts then
		for _, b in product.boosts do
			Product.addBoost(player, b.boost, b.seconds)
		end
	end
	if product.seeds then
		for _, s in product.seeds do
			Seeds.grant(player, s.seed, s.amount)
		end
	end
	if product.once then
		data.Bought[product.id] = true
		player:SetAttribute("Bought_" .. product.id, true)
	end
	if product.kind ~= "serverBoost" and product.kind ~= "instantGrow" then
		notice(player, string.format("Thanks! %s %s is yours!", product.emoji, product.name))
	end
end

local function grantGift(buyer: Player, buyerData: Data.PlayerData, pass: Products.PassDef)
	local pending = pendingGifts[buyer]
	pendingGifts[buyer] = nil
	local target = if pending and pending.pass == pass.id
		then Players:GetPlayerByUserId(pending.target)
		else nil
	local targetData = target and Data.get(target)
	if target and targetData then
		targetData.GiftedPasses[pass.id] = true
		setPass(target, pass.id)
		for _, p in Players:GetPlayers() do
			notice(p, string.format("🎁 %s gave %s %s!", buyer.DisplayName, target.DisplayName, pass.name))
		end
		return
	end
	if
		pending and Data.message(pending.target, { kind = "gift", pass = pass.id, from = buyer.DisplayName })
	then
		notice(buyer, string.format("🎁 Your %s gift will be waiting for your friend!", pass.name))
		return
	end
	-- No valid friend: the buyer gets the pass, or Golden Seeds if they already have it.
	if buyer:GetAttribute("Pass_" .. pass.id) ~= true then
		buyerData.GiftedPasses[pass.id] = true
		setPass(buyer, pass.id)
		notice(buyer, string.format("Your friend left, so %s is yours!", pass.name))
	else
		Seeds.grant(buyer, "Golden", 20, "Gift couldn't be delivered")
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Data.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receipt.ProductId
	local product = productByRobloxId[productId]
	local giftPass = passByGiftProduct[productId]
	if product then
		grantProduct(player, data, product)
		Telemetry.event(player, "ProductBought", receipt.CurrencySpent, { product.id })
	elseif giftPass then
		grantGift(player, data, giftPass)
		Telemetry.event(player, "GiftBought", receipt.CurrencySpent, { giftPass.id })
	else
		warn("Unknown developer product", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	if not Data.saveAndWait(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Offers ------------------------------------------------------------------

-- Starter Bundle: shown once, right after the player's first Rare (a happy moment), never at
-- login and never after a bad roll.
function Product.onRareHarvest(player: Player)
	local data = Data.get(player)
	local bundle = productById.StarterBundle
	if not data or not bundle or bundle.productId == 0 then
		return
	end
	if data.StarterOffered or data.Bought.StarterBundle then
		return
	end
	data.StarterOffered = true
	Remotes.get(Remotes.Names.Offer):FireClient(player, bundle.id)
	Telemetry.event(player, "OfferShown", 1, { bundle.id, "after_first_rare" })
end

-- Lifecycle ---------------------------------------------------------------

function Product.onPlayerReady(player: Player)
	local data = Data.get(player)
	if data then
		for id in data.Bought do
			player:SetAttribute("Bought_" .. id, true)
		end
	end
	task.spawn(refreshPasses, player)
	syncBoosts(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		syncBoosts(player)
	end)
end

function Product.start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passByRobloxId[passId]
		if purchased and pass then
			setPass(player, pass.id)
			notice(player, string.format("Thanks! %s %s is yours!", pass.emoji, pass.name))
			Telemetry.event(player, "PassBought", 1, { pass.id })
		end
	end)

	-- Gift messages delivered to this profile while the player was elsewhere.
	Data.onMessage(function(player, data, message)
		if typeof(message) == "table" and message.kind == "gift" and typeof(message.pass) == "string" then
			local pass = passById[message.pass]
			if pass then
				data.GiftedPasses[pass.id] = true
				setPass(player, pass.id)
				notice(player, string.format("🎁 %s gave you %s!", tostring(message.from), pass.name))
			end
			return true
		end
		return false
	end)

	local giftLimit = EconomyConfig.RateLimits.SetGiftTarget
	local allowGift = RateLimit.new(giftLimit.rate, giftLimit.burst)
	Remotes.get(Remotes.Names.SetGiftTarget).OnServerEvent
		:Connect(function(player, rawTarget: unknown, rawPass: unknown)
			if not allowGift(player) or typeof(rawTarget) ~= "number" or typeof(rawPass) ~= "string" then
				return
			end
			local target = Players:GetPlayerByUserId(rawTarget :: number)
			if not target or target == player or not passById[rawPass :: string] then
				return
			end
			pendingGifts[player] = { target = target.UserId, pass = rawPass :: string }
		end)

	local trackLimit = EconomyConfig.RateLimits.Track
	local allowTrack = RateLimit.new(trackLimit.rate, trackLimit.burst)
	Remotes.get(Remotes.Names.Track).OnServerEvent
		:Connect(function(player, rawEvent: unknown, rawDetail: unknown)
			if
				not allowTrack(player)
				or typeof(rawEvent) ~= "string"
				or not TRACK_EVENTS[rawEvent :: string]
			then
				return
			end
			local detail = if typeof(rawDetail) == "string"
				then string.sub(rawDetail :: string, 1, 40)
				else ""
			if rawEvent == "OpenedDex" then
				Telemetry.funnel(player, "OpenedDex")
			end
			Telemetry.event(player, rawEvent :: string, 1, { detail })
		end)

	Players.PlayerRemoving:Connect(function(player)
		pendingGifts[player] = nil
	end)

	-- Boosts count PLAY time: tick down once a second for players in the server.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					local changed = false
					for id, seconds in data.Boosts do
						if seconds > 0 then
							data.Boosts[id] = seconds - 1
							changed = true
						else
							data.Boosts[id] = nil
							player:SetAttribute("Boost_" .. id, nil)
						end
					end
					if changed then
						syncBoosts(player)
					end
					vipDaily(player)
				end
			end
		end
	end)
end

return Product
