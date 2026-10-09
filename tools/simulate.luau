--!strict
-- Economy simulation (design doc §9): plays N runs of 4 hours with a typical active player and
-- reports income per minute, time between purchases and when each rarity first shows up.
-- Uses exactly the same config and math modules as the game.
--
--   lune run tools/simulate          -> prints a summary and writes tools/simulation-report.md
--
-- Player model: harvests each plot ~REACTION seconds after it is ready, then taps to plant it
-- again (PLANT_TAP seconds, Basic seeds; planting is manual). Harvests go into the basket.
-- Selling and upgrading happen in the world: the player walks to the market (TRIP seconds there
-- and back, plots keep growing meanwhile) when the basket is full, or as soon as the basket plus
-- cash pays for the next upgrade (the guide line points there). At the market everything sells
-- at the market price (MarketBonus) and the cheapest upgrades are bought.
-- No seeds, no boosts, no booms, no Robux.

local fs = require("@lune/fs")

local Roller = require("../src/shared/Roller")
local Value = require("../src/shared/Value")
local Progression = require("../src/shared/Progression")
local Format = require("../src/shared/Format")
local Rarity = require("../src/shared/Config/Rarity")
local Carrots = require("../src/shared/Config/Carrots")
local Sizes = require("../src/shared/Config/Sizes")
local Mutations = require("../src/shared/Config/Mutations")
local Upgrades = require("../src/shared/Config/Upgrades")
local Economy = require("../src/shared/Config/Economy")
local Events = require("../src/shared/Config/Events")

local RUNS = 24
local DURATION = 4 * 3600
local REACTION = 0.8
-- Harvest no longer auto-replants, and you have to walk to each plot: harvest, plant, step on.
local PLANT_TAP = 1.6
-- Farm -> Bunny Launcher (3.2 s flight) -> SELL mat -> Upgrade Workshop -> HOME launcher ->
-- farm, plus walking on the farm and the square.
local TRIP = 18

type Purchase = { t: number, track: string, level: number, cost: number }
type RunResult = {
	purchases: { Purchase },
	buysPerTrip: { number }, -- upgrades bought on each market trip, first 15 minutes
	incomeByMinute: { number },
	firstRarity: { [string]: number },
	levels: { [string]: number },
	cash: number,
	earned: number,
	trips: number,
}

local configs: Roller.RollConfigs = {
	rarities = Rarity :: any,
	carrots = Carrots :: any,
	sizes = Sizes :: any,
	mutations = Mutations.List :: any,
	maxMutationChance = Mutations.MaxTotalChance,
}

local trackById: { [string]: Upgrades.UpgradeDef } = {}
for _, t in Upgrades do
	trackById[t.id] = t
end
local rarityById: { [string]: Rarity.RarityDef } = {}
for _, r in Rarity do
	rarityById[r.id] = r
end
local typeById: { [string]: Carrots.CarrotDef } = {}
for _, c in Carrots do
	typeById[c.id] = c
end
local sizeById: { [string]: Sizes.SizeDef } = {}
for _, s in Sizes do
	sizeById[s.id] = s
end
local mutMult: { [string]: number } = {}
for _, m in Mutations.List do
	mutMult[m.id] = m.mult
end
local pityOrder = rarityById[Economy.PityRarity].order

local function simulate(seed: number): RunResult
	math.randomseed(seed)
	local rng = function(): number
		return math.random()
	end

	local levels: { [string]: number } = {}
	for _, t in Upgrades do
		levels[t.id] = 0
	end
	local cash = Economy.StartingCash
	local earned = 0
	local pity = 0
	local plantings = 0
	local firstMutationGiven = false
	local purchases: { Purchase } = {}
	local incomeByMinute: { number } = {}
	local firstRarity: { [string]: number } = {}
	local buysPerTrip: { number } = {}

	local function growTime(plot: number): number
		local factor = Economy.PlotGrowFactors[plot] or 1
		local base = Progression.growTime(
			Economy.BaseGrowTime,
			Economy.MinGrowTime,
			trackById.GrowthSpeed,
			levels.GrowthSpeed,
			factor
		)
		return math.max(Economy.MinGrowTime, base * (1 + (rng() * 2 - 1) * Economy.GrowJitter))
	end

	local basketCount = 0
	local basketValue = 0
	local busyUntil = 0
	local trips = 0

	local function capacity(): number
		return Progression.stepValue(trackById.BasketSize, levels.BasketSize, Economy.BasketCapacity)
	end

	local function cheapestCost(): number
		local best = math.huge
		for _, track in Upgrades do
			if track.enabled and not Progression.isMaxed(track, levels[track.id]) then
				best = math.min(best, Progression.cost(track, levels[track.id]))
			end
		end
		return best
	end

	local function plotCount(): number
		return Progression.plots(trackById.FarmSize, levels.FarmSize, Economy.StartingPlots)
	end

	-- readyAt per plot; the player plants every plot in the first few seconds.
	local readyAt: { number } = {}
	for i = 1, plotCount() do
		readyAt[i] = 1 + i * 0.7 + growTime(i)
	end

	local function buyAll(t: number)
		while true do
			local best: Upgrades.UpgradeDef? = nil
			local bestCost = math.huge
			for _, track in Upgrades do
				if track.enabled and not Progression.isMaxed(track, levels[track.id]) then
					local c = Progression.cost(track, levels[track.id])
					if c < bestCost then
						best, bestCost = track, c
					end
				end
			end
			if not best or bestCost > cash then
				return
			end
			cash -= bestCost
			levels[best.id] += 1
			table.insert(purchases, { t = t, track = best.id, level = levels[best.id], cost = bestCost })
			if best.id == "FarmSize" then
				for i = #readyAt + 1, plotCount() do
					readyAt[i] = t + 1 + growTime(i)
				end
			end
		end
	end

	while true do
		local plot, soonest = 1, math.huge
		for i, r in readyAt do
			if r < soonest then
				plot, soonest = i, r
			end
		end
		local t = math.max(soonest + REACTION, busyUntil)
		if t > DURATION then
			break
		end

		-- Roll (happens at planting in the game; equivalent here)
		local luck = Progression.multiplier(trackById.Luck, levels.Luck)
		local ctx: Roller.RollContext = {
			luck = luck,
			mutationLuck = Progression.mutationLuck(luck, Mutations.LuckFactor),
			sizeLuck = Progression.multiplier(trackById.HarvestPower, levels.HarvestPower),
		}
		if pity + 1 >= Economy.PityLegendary then
			ctx.minRarityOrder = pityOrder
		end
		plantings += 1
		if not firstMutationGiven and plantings >= Mutations.GuaranteedFirstAtPlanting then
			ctx.forceMutation = Mutations.GuaranteedFirstId
		end
		local roll = Roller.roll(configs, ctx, rng)
		local rarity = rarityById[roll.rarity]
		if rarity.order >= pityOrder then
			pity = 0
		else
			pity += 1
		end
		if #roll.mutations > 0 then
			firstMutationGiven = true
		end
		if not firstRarity[roll.rarity] then
			firstRarity[roll.rarity] = t
		end

		local mults = {}
		for _, m in roll.mutations do
			table.insert(mults, mutMult[m])
		end
		local value = Value.compute({
			base = rarity.baseValue * typeById[roll.type].valueMult,
			size = sizeById[roll.size].mult,
			mutation = Value.mutationMultiplier(mults),
			valueUpgrade = Progression.bonus(trackById.Value, levels.Value),
		})
		basketCount += 1
		basketValue += value * Events.MarketBonus
		readyAt[plot] = t + PLANT_TAP + growTime(plot)

		-- Walk to the market when the basket is full or it pays for the next upgrade
		if basketCount >= capacity() or cash + basketValue >= cheapestCost() then
			local sellAt = t + TRIP / 2
			cash += basketValue
			earned += basketValue
			local minute = math.floor(sellAt / 60) + 1
			incomeByMinute[minute] = (incomeByMinute[minute] or 0) + basketValue
			basketCount, basketValue = 0, 0
			local before = #purchases
			buyAll(sellAt)
			if sellAt < 900 then
				table.insert(buysPerTrip, #purchases - before)
			end
			busyUntil = t + TRIP
			trips += 1
		end
	end

	return {
		purchases = purchases,
		buysPerTrip = buysPerTrip,
		incomeByMinute = incomeByMinute,
		firstRarity = firstRarity,
		levels = levels,
		cash = cash,
		earned = earned,
		trips = trips,
	}
end

local function median(list: { number }): number
	if #list == 0 then
		return 0 / 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	local mid = (#sorted + 1) / 2
	return (sorted[math.floor(mid)] + sorted[math.ceil(mid)]) / 2
end

local results: { RunResult } = {}
for run = 1, RUNS do
	table.insert(results, simulate(run * 7919))
end

local lines: { string } = {}
local function out(s: string)
	table.insert(lines, s)
	print(s)
end

out("# Economy simulation report")
out("")
out(
	string.format(
		"%d runs x %s, active player (harvest %.1fs after ready, %ds market trip when the basket is full or pays for the next upgrade, buy cheapest upgrade). No seeds/boosts/booms.",
		RUNS,
		Format.duration(DURATION),
		REACTION,
		TRIP
	)
)
out("")

-- Time between purchases by window (target: 30-90 s first 10 min, 2-3 min at 30 min, 3-5 min after 1 h)
local windows = {
	{ 0, 600, "0-10 min", "30-90 s" },
	{ 600, 1800, "10-30 min", "~1-2 min" },
	{ 1800, 3600, "30-60 min", "2-3 min" },
	{ 3600, 7200, "1-2 h", "3-5 min" },
	{ 7200, 14400, "2-4 h", "soft wall (prestige later)" },
}
out("## Time to next purchase (median)")
out("")
out("| Window | Median gap | Purchase moments/run | Target |")
out("|---|---|---|---|")
for _, w in windows do
	local gaps = {}
	local count = 0
	for _, r in results do
		-- Purchases in the same moment (one lucky sale buying several) count as one.
		local prev = 0
		for _, p in r.purchases do
			if p.t > prev + 1 then
				if p.t >= w[1] and p.t < w[2] then
					table.insert(gaps, p.t - prev)
					count += 1
				end
				prev = p.t
			end
		end
	end
	out(
		string.format(
			"| %s | %s | %.1f | %s |",
			w[3],
			if #gaps > 0 then Format.duration(median(gaps)) else "none",
			count / RUNS,
			w[4]
		)
	)
end
out("")

out("## Income per minute (median)")
out("")
out("| Minute | Income/min |")
out("|---|---|")
for _, m in { 1, 3, 5, 10, 20, 30, 60, 90, 120, 180, 240 } do
	local values = {}
	for _, r in results do
		-- smooth over a 5-minute window around m (heavy-tailed rolls)
		local sum, n = 0, 0
		for k = math.max(1, m - 2), m + 2 do
			if k <= DURATION / 60 then
				sum += r.incomeByMinute[k] or 0
				n += 1
			end
		end
		table.insert(values, sum / math.max(1, n))
	end
	out(string.format("| %d | %s |", m, Format.cash(median(values))))
end
out("")

out("## First time each rarity appears (median, runs where it appeared)")
out("")
out("| Rarity | Median time | Runs with it |")
out("|---|---|---|")
for _, rar in Rarity do
	local times = {}
	for _, r in results do
		if r.firstRarity[rar.id] then
			table.insert(times, r.firstRarity[rar.id])
		end
	end
	out(
		string.format(
			"| %s | %s | %d/%d |",
			rar.name,
			if #times > 0 then Format.duration(median(times)) else "-",
			#times,
			RUNS
		)
	)
end
out("")

out("## Upgrade levels after 4 h (median)")
out("")
out("| Track | Level | Max |")
out("|---|---|---|")
for _, t in Upgrades do
	local lv = {}
	for _, r in results do
		table.insert(lv, r.levels[t.id])
	end
	out(string.format("| %s | %d | %d |", t.name, median(lv), Progression.maxLevel(t)))
end
out("")

local farmTimes = {}
for _, r in results do
	for _, p in r.purchases do
		if p.track == "FarmSize" then
			farmTimes[p.level] = farmTimes[p.level] or {}
			table.insert(farmTimes[p.level], p.t)
		end
	end
end
out("## Farm Size purchases (median time)")
out("")
local fs4 = trackById.FarmSize
for level = 1, Progression.maxLevel(fs4) do
	local times = farmTimes[level] or {}
	out(
		string.format(
			"- %d plots: %s (%d/%d runs)",
			Progression.plots(fs4, level, Economy.StartingPlots),
			if #times > 0 then Format.duration(median(times)) else "not reached",
			#times,
			RUNS
		)
	)
end
out("")

do
	-- What Philip felt: one full basket buying a pile of upgrades. A full-basket trip should buy 1-3.
	local full, all = {}, {}
	for _, r in results do
		for _, n in r.buysPerTrip do
			table.insert(all, n)
		end
	end
	for _, r in results do
		local worst = 0
		for _, n in r.buysPerTrip do
			worst = math.max(worst, n)
		end
		table.insert(full, worst)
	end
	out(
		string.format(
			"Upgrades bought per market trip, first 15 min: median %.1f, worst trip per run (median) %.0f",
			median(all),
			median(full)
		)
	)
	out("")
end

do
	local perHour = {}
	for _, r in results do
		table.insert(perHour, r.trips / (DURATION / 3600))
	end
	out(string.format("Market trips per hour (median): %.0f", median(perHour)))
	out("")
end

fs.writeFile("tools/simulation-report.md", table.concat(lines, "\n") .. "\n")
print("\nWrote tools/simulation-report.md")
