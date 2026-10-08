--!strict
-- Seeds: bought with in-game cash only (never Robux), selected by the player, used one per
-- planting. Mystery Seeds resolve to another seed when planted (odds shown in the Seeds panel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local SeedsConfig = require(Config.Seeds)
local EconomyConfig = require(Config.Economy)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Roll = require(script.Parent.Roll)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Seeds = {}

local seedById: { [string]: SeedsConfig.SeedDef } = {}
for _, s in SeedsConfig do
	seedById[s.id] = s
end
local BASIC = seedById.Basic
assert(BASIC, "Config/Seeds needs a Basic seed")

local MAX_BUY = 100

function Seeds.def(id: string): SeedsConfig.SeedDef?
	return seedById[id]
end

function Seeds.price(player: Player, id: string): number
	local def = seedById[id]
	if not def or not def.buyable then
		return math.huge
	end
	return Progression.seedPrice(def.basePrice, Economy.valueBonus(player))
end

function Seeds.count(player: Player, id: string): number
	local data = Data.get(player)
	return if data then data.Seeds[id] or 0 else 0
end

function Seeds.sync(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	for _, s in SeedsConfig do
		if s.id ~= "Basic" then
			player:SetAttribute("Seed_" .. s.id, data.Seeds[s.id] or 0)
		end
	end
	player:SetAttribute("SelectedSeed", data.SelectedSeed)
end

function Seeds.grant(player: Player, id: string, amount: number, reason: string?)
	local data = Data.get(player)
	local def = seedById[id]
	if not data or not def or id == "Basic" or amount <= 0 then
		return
	end
	data.Seeds[id] = (data.Seeds[id] or 0) + amount
	Seeds.sync(player)
	if reason then
		Remotes.get(Remotes.Names.Notice):FireClient(player, {
			text = string.format("%s: +%d %s!", reason, amount, def.name),
			kind = "good",
		})
	end
end

function Seeds.buy(player: Player, id: string, amount: number): boolean
	local def = seedById[id]
	if not def or not def.buyable then
		return false
	end
	amount = math.clamp(math.floor(amount), 1, MAX_BUY)
	local cost = Seeds.price(player, id) * amount
	if not Economy.spend(player, cost, "seed_" .. id) then
		return false
	end
	Seeds.grant(player, id, amount)
	-- Buying a seed you don't have selected yet selects it: one tap from shop to planting.
	Seeds.select(player, id)
	return true
end

function Seeds.select(player: Player, id: string): boolean
	local data = Data.get(player)
	if not data or not seedById[id] then
		return false
	end
	if id ~= "Basic" and (data.Seeds[id] or 0) <= 0 then
		return false
	end
	data.SelectedSeed = id
	Seeds.sync(player)
	return true
end

-- Takes one of the selected seed (or Basic). Returns the seed whose effect applies (a Mystery
-- Seed is resolved here) and the id that was used up.
function Seeds.consume(player: Player): (SeedsConfig.SeedDef, string)
	local data = Data.get(player)
	if not data then
		return BASIC, "Basic"
	end
	local id = data.SelectedSeed
	local def = seedById[id]
	if not def or id == "Basic" or (data.Seeds[id] or 0) <= 0 then
		return BASIC, "Basic"
	end
	data.Seeds[id] -= 1
	if data.Seeds[id] <= 0 then
		data.Seeds[id] = nil
		data.SelectedSeed = "Basic"
		Remotes.get(Remotes.Names.Notice):FireClient(player, {
			text = string.format("Out of %ss – back to Basic Seeds", def.name),
		})
	end
	Seeds.sync(player)

	local mystery = def.mystery
	if mystery then
		local total = 0
		for _, o in mystery do
			total += o.weight
		end
		local r = Roll.number() * total
		for _, o in mystery do
			if r < o.weight then
				return seedById[o.seed] or BASIC, id
			end
			r -= o.weight
		end
		return seedById[mystery[#mystery].seed] or BASIC, id
	end
	return def, id
end

function Seeds.start()
	local buyLimit = EconomyConfig.RateLimits.BuySeed
	local allowBuy = RateLimit.new(buyLimit.rate, buyLimit.burst)
	Remotes.get(Remotes.Names.BuySeed).OnServerEvent
		:Connect(function(player, rawId: unknown, rawAmount: unknown)
			if not allowBuy(player) or typeof(rawId) ~= "string" or typeof(rawAmount) ~= "number" then
				return
			end
			local amount = rawAmount :: number
			if amount ~= amount then
				return
			end
			Seeds.buy(player, rawId :: string, amount)
		end)
	local selLimit = EconomyConfig.RateLimits.SelectSeed
	local allowSelect = RateLimit.new(selLimit.rate, selLimit.burst)
	Remotes.get(Remotes.Names.SelectSeed).OnServerEvent:Connect(function(player, rawId: unknown)
		if allowSelect(player) and typeof(rawId) == "string" then
			Seeds.select(player, rawId :: string)
		end
	end)
end

return Seeds
