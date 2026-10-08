--!strict
-- Cash, basket and selling. The only place cash changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Economy = {}

-- Phase 1: no market events, value upgrades, prestige or boosts yet.
function Economy.valueContext(_player: Player): CarrotInfo.ValueContext
	return { market = 1, valueUpgrade = 0, prestige = 1, boosts = 1 }
end

function Economy.valueOf(player: Player, carrot: Types.Carrot): number
	return CarrotInfo.value(carrot, Economy.valueContext(player))
end

local function basketTotals(player: Player, data: Data.PlayerData): (number, number)
	local count, value = 0, 0
	for key, n in data.Basket do
		local carrot = CarrotInfo.fromKey(key)
		if carrot then
			count += n
			value += n * Economy.valueOf(player, carrot)
		end
	end
	return count, value
end

function Economy.sync(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local count, value = basketTotals(player, data)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("BasketCount", count)
	player:SetAttribute("BasketValue", value)
	player:SetAttribute("BasketCapacity", EconomyConfig.BasketCapacity)
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

-- Puts a harvested carrot in the basket. If the basket is full it is sold on the spot.
-- Returns (value, autoSold).
function Economy.addCarrot(player: Player, carrot: Types.Carrot): (number, boolean)
	local data = Data.get(player)
	if not data then
		return 0, false
	end
	local value = Economy.valueOf(player, carrot)
	if value > data.Stats.BestValue then
		data.Stats.BestValue = value
	end
	local count = basketTotals(player, data)
	if count >= EconomyConfig.BasketCapacity then
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
	local count, total = basketTotals(player, data)
	if count == 0 then
		return 0, 0
	end
	data.Basket = {}
	data.Stats.Sold += count
	Economy.addCash(player, total, "sell")
	local result: Types.SellResult = { total = total, count = count }
	Remotes.get(Remotes.Names.SellResult):FireClient(player, result)
	return total, count
end

function Economy.start(sellPrompt: ProximityPrompt)
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
end

return Economy
