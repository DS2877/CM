--!strict
-- Cash, basket and selling. The only place cash changes.
-- Market prices (design doc §5): the daily modifier applies everywhere; a boom only pays when
-- the player sells AT the market. Prices never go below base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local Events = require(Config.Events)
local Upgrades = require(Config.Upgrades)
local Progression = require(Shared.Progression)
local EventSchedule = require(Shared.EventSchedule)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Economy = {}

local eventsCfg: EventSchedule.EventsConfig = Events :: any
local marketPosition = Vector3.zero

local trackById: { [string]: Upgrades.UpgradeDef } = {}
for _, t in Upgrades do
	trackById[t.id] = t
end

local saleCallbacks: { (player: Player, total: number, count: number) -> () } = {}
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
	if not track then
		return EconomyConfig.BasketCapacity
	end
	return Progression.stepValue(track, level(player, "BasketSize"), EconomyConfig.BasketCapacity)
end

function Economy.eventState(): EventSchedule.State
	return EventSchedule.at(os.time(), eventsCfg)
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
		boosts = 1,
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

function Economy.addCash(player: Player, amount: number, _source: string)
	local data = Data.get(player)
	if not data or amount <= 0 then
		return
	end
	data.Cash += amount
	data.Stats.TotalEarned += amount
	Economy.sync(player)
end

-- Returns true if the player could afford it.
function Economy.spend(player: Player, amount: number, _sink: string): boolean
	local data = Data.get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	Economy.sync(player)
	return true
end

function Economy.onSale(callback: (player: Player, total: number, count: number) -> ())
	table.insert(saleCallbacks, callback)
end

function Economy.onNewBest(callback: (player: Player) -> ())
	table.insert(bestCallbacks, callback)
end

-- Puts a harvested carrot in the basket. If the basket is full it is sold on the spot (base
-- price). Returns (value, autoSold).
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
	local count = basketTotals(player, data)
	if count >= Economy.basketCapacity(player) then
		data.Stats.Sold += 1
		Economy.addCash(player, value, "harvest_autosell")
		return value, true
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
	local atMarket = Economy.atMarket(player)
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
	}
	Remotes.get(Remotes.Names.SellResult):FireClient(player, result)
	for _, cb in saleCallbacks do
		task.spawn(cb, player, total, count)
	end
	return total, count
end

function Economy.start(sellPrompt: ProximityPrompt, market: Vector3)
	marketPosition = market
	local limit = EconomyConfig.RateLimits.SellAll
	local allow = RateLimit.new(limit.rate, limit.burst)
	Remotes.get(Remotes.Names.SellAll).OnServerEvent:Connect(function(player)
		if allow(player) then
			Economy.sellAll(player)
		end
	end)
	sellPrompt.Triggered:Connect(function(player)
		if allow(player) then
			Economy.sellAll(player)
		end
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
