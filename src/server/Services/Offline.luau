--!strict
-- Offline growth (design doc §4, the strongest D1 hook): plots keep growing while the player is
-- away and are harvested into a capped basket (Economy.OfflineCapSeconds / OfflineMaxCarrots).
-- On login the carrots are revealed one at a time, best last. Offline uses Basic seeds only, so
-- nobody loses bought seeds while away. All rolls happen here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local SeedsConfig = require(Config.Seeds)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Dex = require(script.Parent.Dex)
local Farm = require(script.Parent.Farm)

local Offline = {}

local basic: SeedsConfig.SeedDef = SeedsConfig[1]
for _, s in SeedsConfig do
	if s.id == "Basic" then
		basic = s
	end
end

local SAVE_INTERVAL = 30

-- Number of harvests each plot would have finished in `seconds`, capped in total.
local function harvestsPerPlot(player: Player, seconds: number): { number }
	local plots = Farm.unlockedPlots(player)
	local counts = {}
	local total = 0
	for i = 1, plots do
		counts[i] = math.floor(seconds / Farm.growTimeFor(player, i))
		total += counts[i]
	end
	if total > EconomyConfig.OfflineMaxCarrots then
		-- Scale down proportionally so every plot contributes.
		local scale = EconomyConfig.OfflineMaxCarrots / total
		total = 0
		for i = 1, plots do
			counts[i] = math.floor(counts[i] * scale)
			total += counts[i]
		end
		local i = 1
		while total < EconomyConfig.OfflineMaxCarrots do
			counts[i] += 1
			total += 1
			i = i % plots + 1
		end
	end
	return counts
end

-- Call right after the profile loads: remembers when the player was last seen and marks them
-- online. Returns the previous LastOnline to pass to Offline.reveal.
function Offline.checkIn(player: Player): number
	local data = Data.get(player)
	if not data then
		return 0
	end
	local last = data.LastOnline
	data.LastOnline = os.time()
	return last
end

-- Harvests what grew while the player was away and sends the reveal. Call once the farm is
-- assigned (grow times depend on plots and upgrades).
function Offline.reveal(player: Player, last: number)
	local data = Data.get(player)
	if not data or last <= 0 then
		return
	end
	local away = os.time() - last
	if away < EconomyConfig.OfflineMinSeconds then
		return
	end
	local seconds = math.min(away, EconomyConfig.OfflineCapSeconds)

	local carrots: { Types.RevealedCarrot } = {}
	local total, soldTotal = 0, 0
	for _, count in harvestsPerPlot(player, seconds) do
		for _ = 1, count do
			local roll = Farm.rollFor(player, basic)
			if roll then
				local carrot: Types.Carrot =
					{ type = roll.type, size = roll.size, mutations = roll.mutations }
				local value, autoSold = Economy.addCarrot(player, carrot)
				local isNew = Dex.record(player, carrot, true)
				total += value
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
		end
	end
	if #carrots == 0 then
		return
	end
	data.Stats.Harvests += #carrots
	Dex.sync(player)
	table.sort(carrots, function(a, b)
		if a.value ~= b.value then
			return a.value < b.value
		end
		return CarrotInfo.rarityOrder(a.rarity) < CarrotInfo.rarityOrder(b.rarity)
	end)
	local result: Types.OfflineResult = {
		seconds = seconds,
		carrots = carrots,
		total = total,
		soldTotal = soldTotal,
	}
	Remotes.get(Remotes.Names.OfflineReveal):FireClient(player, result)
end

-- Keep LastOnline fresh so a crash or shutdown still counts as "away from" the right time.
function Offline.touch(player: Player)
	local data = Data.get(player)
	if data then
		data.LastOnline = os.time()
	end
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
