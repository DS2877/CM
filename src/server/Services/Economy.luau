--!strict
-- Cash, basket and selling. The only place cash changes.
-- Selling happens in one fixed place: walk onto one of the SELL pads around the market and the whole
-- basket sells (no HUD button). Market prices (design doc §5) never go below base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local Events = require(Config.Events)
local World = require(Config.World)
local Upgrades = require(Config.Upgrades)
local Progression = require(Shared.Progression)
local EventSchedule = require(Shared.EventSchedule)
local Market = require(Shared.Market)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local Telemetry = require(script.Parent.Telemetry)
local Perks = require(script.Parent.Perks)
local ProductsConfig = require(Config.Products)

local Economy = {}

local marketPosition = Vector3.zero

local trackById: { [string]: Upgrades.UpgradeDef } = {}
for _, t in Upgrades do
	trackById[t.id] = t
end

local saleCallbacks: { (player: Player, total: number, count: number, atMarket: boolean, boom: boolean) -> () } =
	{}
local bestCallbacks: { (player: Player) -> () } = {}

-- Upgrade effects read straight from data (avoids a require cycle with the Upgrade service).
local function level(player: Player, id: string): number
	local data = Data.get(player)
	return if data then data.Upgrades[id] or 0 else 0
end

function Economy.valueBonus(player: Player): number
	local track = trackById.Value
	return if track then Progression.bonus(track, level(player, "Value")) else 0
end

function Economy.basketCapacity(player: Player): number
	local track = trackById.BasketSize
	local capacity = if track
		then Progression.stepValue(track, level(player, "BasketSize"), EconomyConfig.BasketCapacity)
		else EconomyConfig.BasketCapacity
	if Perks.hasPass(player, "BigBasket") then
		capacity *= ProductsConfig.BigBasketMult
	end
	return capacity
end

function Economy.eventState(): EventSchedule.State
	return Market.state()
end

-- Is the player standing at the market (where boom prices are paid)?
function Economy.atMarket(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local offset = (root :: BasePart).Position - marketPosition
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Events.MarketRadius
end

-- Value of one carrot for this player, now. Prestige (phase 6) and boosts (phase 4) are 1.
function Economy.valueOf(player: Player, carrot: Types.Carrot, atMarket: boolean?): number
	local rarity = CarrotInfo.rarityOfType(carrot.type)
	local market = EventSchedule.multiplier(Economy.eventState(), {
		rarity = rarity.id,
		size = carrot.size,
		mutations = carrot.mutations,
	}, atMarket == true)
	return CarrotInfo.value(carrot, {
		market = market,
		valueUpgrade = Economy.valueBonus(player),
		prestige = 1,
		boosts = Perks.valueBoost(player),
	})
end

-- (count, value anywhere, value at the market)
local function basketTotals(player: Player, data: Data.PlayerData): (number, number, number)
	local count, value, marketValue = 0, 0, 0
	for key, n in data.Basket do
		local carrot = CarrotInfo.fromKey(key)
		if carrot then
			count += n
			value += n * Economy.valueOf(player, carrot, false)
			marketValue += n * Economy.valueOf(player, carrot, true)
		end
	end
	return count, value, marketValue
end

function Economy.sync(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local count, value, marketValue = basketTotals(player, data)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("BasketCount", count)
	player:SetAttribute("BasketValue", value)
	player:SetAttribute("BasketMarketValue", marketValue)
	player:SetAttribute("BasketCapacity", Economy.basketCapacity(player))
end

function Economy.addCash(player: Player, amount: number, source: string)
	local data = Data.get(player)
	if not data or amount <= 0 then
		return
	end
	data.Cash += amount
	data.Stats.TotalEarned += amount
	Economy.sync(player)
	Telemetry.source(player, amount, source)
end

-- Returns true if the player could afford it.
function Economy.spend(player: Player, amount: number, sink: string): boolean
	local data = Data.get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	Economy.sync(player)
	Telemetry.sink(player, amount, sink)
	return true
end

function Economy.onSale(callback: (
	player: Player,
	total: number,
	count: number,
	atMarket: boolean,
	boom: boolean
) -> ())
	table.insert(saleCallbacks, callback)
end

function Economy.onNewBest(callback: (player: Player) -> ())
	table.insert(bestCallbacks, callback)
end

function Economy.basketCount(player: Player): number
	local data = Data.get(player)
	if not data then
		return 0
	end
	local n = 0
	for _, c in data.Basket do
		n += c
	end
	return n
end

function Economy.basketFull(player: Player): boolean
	return Economy.basketCount(player) >= Economy.basketCapacity(player)
end

-- Standing on a SELL pad?
function Economy.inSellZone(player: Player, slack: number?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local _, dist = World.nearestSellPad((root :: BasePart).Position - marketPosition)
	return dist <= World.SellPadRadius + (slack or 0)
end

-- Puts a harvested carrot in the basket. Farm checks basketFull() first (a full basket leaves
-- carrots waiting on their plots); offline restores may overfill, which is fine.
-- Returns (value, autoSold) - autoSold is always false now (kept for the result type).
function Economy.addCarrot(player: Player, carrot: Types.Carrot): (number, boolean)
	local data = Data.get(player)
	if not data then
		return 0, false
	end
	local value = Economy.valueOf(player, carrot, false)
	if value > data.Stats.BestValue then
		data.Stats.BestValue = value
	end
	-- Pedestal: best carrot ever, compared at base value so events don't skew it.
	local baseValue = CarrotInfo.value(carrot, { valueUpgrade = Economy.valueBonus(player) })
	if baseValue > data.Best.Value then
		data.Best = {
			Type = carrot.type,
			Size = carrot.size,
			Mutations = table.concat(carrot.mutations, "+"),
			Value = baseValue,
		}
		for _, cb in bestCallbacks do
			task.spawn(cb, player)
		end
	end
	local key = CarrotInfo.key(carrot)
	data.Basket[key] = (data.Basket[key] or 0) + 1
	Economy.sync(player)
	return value, false
end

function Economy.sellAll(player: Player): (number, number)
	local data = Data.get(player)
	if not data then
		return 0, 0
	end
	if not Economy.inSellZone(player, 4) then
		return 0, 0
	end
	local atMarket = true
	local count, baseTotal, marketTotal = basketTotals(player, data)
	if count == 0 then
		return 0, 0
	end
	local total = if atMarket then marketTotal else baseTotal
	data.Basket = {}
	data.Stats.Sold += count
	if total > data.Stats.BiggestSale then
		data.Stats.BiggestSale = total
	end
	Economy.addCash(player, total, if atMarket then "sell_market" else "sell")
	local result: Types.SellResult = {
		total = total,
		count = count,
		bonus = if atMarket and baseTotal > 0 then total / baseTotal else 1,
		boom = Economy.eventState().boomActive,
	}
	Remotes.get(Remotes.Names.SellResult):FireClient(player, result)
	-- The bunny at this stall celebrates for everyone (clients watch these attributes)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("World")
	local market = world and world:FindFirstChild("Market")
	if root and root:IsA("BasePart") and market then
		local index = World.nearestSellPadIndex((root :: BasePart).Position - marketPosition)
		local stall = market:FindFirstChild("Stall_" .. index)
		if stall then
			stall:SetAttribute("SaleCount", count)
			stall:SetAttribute("SaleAt", workspace:GetServerTimeNow())
		end
	end
	for _, cb in saleCallbacks do
		task.spawn(cb, player, total, count, atMarket, atMarket and Economy.eventState().boomActive)
	end
	Telemetry.funnel(player, "FirstSell")
	return total, count
end

function Economy.start(market: Vector3)
	marketPosition = market

	-- The sell circle: standing in it with carrots sells them (checked 5x a second).
	local lastSale: { [Player]: number } = {}
	task.spawn(function()
		while true do
			task.wait(0.2)
			local t = os.clock()
			for _, player in Players:GetPlayers() do
				if
					Economy.inSellZone(player)
					and Economy.basketCount(player) > 0
					and t - (lastSale[player] or 0) > 0.8
				then
					lastSale[player] = t
					Economy.sellAll(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSale[player] = nil
	end)

	-- Basket values change when a boom or day starts/ends: resync everyone then.
	local lastKey = ""
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local s = Economy.eventState()
		local key = string.format("%d:%s:%d", s.cycle, tostring(s.boomActive), s.day)
		if key ~= lastKey then
			lastKey = key
			for _, player in Players:GetPlayers() do
				Economy.sync(player)
			end
		end
	end)
end

return Economy
