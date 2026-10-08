--!strict
-- Offline growth (design doc §4, the strongest D1 hook).
--
-- What is in the ground when you leave is saved (Farm.snapshot): each plot's already-rolled carrot
-- and the time it still needed. Empty plots save nothing and produce nothing. On return
-- (OfflinePlan does the math):
--   * short break: plots come back as they were, finished ones ready to tap;
--   * longer: the saved carrots finish exactly as rolled, then each of those plots keeps going on
--     Basic seeds at a reduced rate, into a capped basket revealed one carrot at a time (best
--     last). Bought seeds are never used offline.
-- All rolls happen here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local SeedsConfig = require(Config.Seeds)
local CarrotInfo = require(Shared.CarrotInfo)
local OfflinePlan = require(Shared.OfflinePlan)
local Remotes = require(Shared.Remotes)
local Roller = require(Shared.Roller)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Dex = require(script.Parent.Dex)
local Farm = require(script.Parent.Farm)
local Leaderboards = require(script.Parent.Leaderboards)
local Perks = require(script.Parent.Perks)
local ProductsConfig = require(Config.Products)

local Offline = {}

local basic: SeedsConfig.SeedDef = SeedsConfig[1]
for _, s in SeedsConfig do
	if s.id == "Basic" then
		basic = s
	end
end

local SAVE_INTERVAL = 30

-- Players whose saved plots have been put back. Until then the farm in the server is not theirs
-- yet, so saving it would wipe what they left in the ground.
local restored: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Saves what is in the ground and when. Safe to call any time; does nothing until the player's
-- saved plots have been restored (or if they have no farm in this server).
function Offline.touch(player: Player)
	local data = Data.get(player)
	if not data or not restored[player] then
		return
	end
	local saved = Farm.snapshot(player)
	if saved then
		data.Growing = saved
		data.LastOnline = os.time()
	end
end

-- Call once the farm is assigned (grow times depend on plots and upgrades). Puts the saved plots
-- back, harvests what finished while away and sends the reveal.
function Offline.restore(player: Player)
	local data = Data.get(player)
	if not data or restored[player] then
		return
	end
	if player:GetAttribute("FarmId") == nil then
		-- No farm in this server (all taken): keep the saved plots for next time.
		return
	end

	local away = if data.LastOnline > 0 then os.time() - data.LastOnline else 0
	local saved = data.Growing
	data.Growing = {}

	local inputs: { OfflinePlan.SavedInput } = {}
	local rolls: { [number]: Roller.RollResult } = {}
	local savedBy: { [number]: Data.SavedPlot } = {}
	for key, s in saved do
		local index = tonumber(key)
		local roll = Farm.rollFromKey(s.Key)
		if index and roll and index >= 1 and index <= Farm.unlockedPlots(player) then
			rolls[index] = roll
			savedBy[index] = s
			table.insert(inputs, {
				index = index,
				remaining = s.Remaining,
				growTime = Farm.growTimeFor(player, index),
			})
		end
	end

	-- Big Basket pass: a longer offline window and a bigger offline basket.
	local bigBasket = Perks.hasPass(player, "BigBasket")
	local plan = OfflinePlan.make(inputs, away, {
		minSeconds = EconomyConfig.OfflineMinSeconds,
		capSeconds = if bigBasket
			then ProductsConfig.BigBasketOfflineSeconds
			else EconomyConfig.OfflineCapSeconds,
		maxCarrots = if bigBasket
			then ProductsConfig.BigBasketOfflineCarrots
			else EconomyConfig.OfflineMaxCarrots,
		rate = EconomyConfig.OfflineRate,
		minCycle = EconomyConfig.OfflineMinCycle,
		perHour = EconomyConfig.OfflinePerHour,
	})

	local carrots: { Types.RevealedCarrot } = {}
	local total, soldTotal, best = 0, 0, 0
	local function collect(roll: Roller.RollResult)
		local carrot: Types.Carrot = { type = roll.type, size = roll.size, mutations = roll.mutations }
		local value, autoSold = Economy.addCarrot(player, carrot)
		local isNew = Dex.record(player, carrot, true)
		total += value
		best = math.max(best, value)
		if autoSold then
			soldTotal += value
		end
		table.insert(carrots, {
			type = roll.type,
			size = roll.size,
			mutations = roll.mutations,
			rarity = roll.rarity,
			value = value,
			isNewType = isNew,
		})
	end

	for _, p in plan.plots do
		local s = savedBy[p.index]
		local roll = rolls[p.index]
		local remaining = p.restoreRemaining
		if not s or not roll then
			continue
		end
		if remaining then
			if not Farm.restorePlot(player, p.index, roll, remaining, s.GrowTime, s.Seed) then
				-- Plot already replanted by the player: the saved carrot goes straight to the basket.
				local carrot: Types.Carrot =
					{ type = roll.type, size = roll.size, mutations = roll.mutations }
				Economy.addCarrot(player, carrot)
				Dex.record(player, carrot)
			end
		else
			if p.finishSaved then
				collect(roll)
			end
			for _ = 1, p.extra do
				local r = Farm.rollFor(player, basic)
				if r then
					collect(r)
				end
			end
			if p.replant then
				Farm.replant(player, p.index)
			end
		end
	end

	restored[player] = true
	Offline.touch(player)

	if #carrots == 0 then
		-- Came back after a real break to an empty farm: teach the mechanic at the moment it matters.
		if #inputs == 0 and away >= EconomyConfig.OfflineMinSeconds and data.Stats.Plantings > 0 then
			Remotes.get(Remotes.Names.Notice):FireClient(player, {
				text = "Tip: carrots you leave planted keep growing while you're away!",
				kind = "good",
			})
		end
		return
	end
	data.Stats.Harvests += #carrots
	Dex.sync(player)
	Leaderboards.report(player, "WeeklyBest", best)
	table.sort(carrots, function(a, b)
		if a.value ~= b.value then
			return a.value < b.value
		end
		return CarrotInfo.rarityOrder(a.rarity) < CarrotInfo.rarityOrder(b.rarity)
	end)
	local result: Types.OfflineResult = {
		seconds = plan.seconds,
		carrots = carrots,
		total = total,
		soldTotal = soldTotal,
	}
	Remotes.get(Remotes.Names.OfflineReveal):FireClient(player, result)
end

-- Last save before the player's farm is released.
function Offline.leave(player: Player)
	Offline.touch(player)
	restored[player] = nil
end

function Offline.start(getPlayers: () -> { Player })
	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for _, player in getPlayers() do
				Offline.touch(player)
			end
		end
	end)
end

return Offline
