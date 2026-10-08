--!strict
-- Global market schedule, computed from a unix time so every server (and every client, for
-- countdowns) agrees without communication. Pure module (no Roblox APIs): pass in os.time()
-- or workspace:GetServerTimeNow() and the Events config.

export type BoomDef = {
	id: string,
	name: string,
	description: string,
	kind: string,
	targets: { string }?,
	mult: number,
	weight: number,
}

export type EventsConfig = {
	Enabled: boolean,
	CycleSeconds: number,
	BoomSeconds: number,
	Booms: { BoomDef },
	DailyMult: number,
	DailyRarities: { string },
}

export type State = {
	cycle: number,
	boomActive: boolean,
	boom: BoomDef, -- the boom of this cycle (active or upcoming)
	boomStart: number,
	boomEnd: number,
	nextBoom: BoomDef, -- the boom after this one
	day: number,
	dailyRarity: string,
	dailyMult: number,
}

export type CarrotFacts = {
	rarity: string,
	size: string,
	mutations: { string },
}

local EventSchedule = {}

-- Small deterministic integer hash (stays well inside double precision).
local function hash(n: number): number
	local h = (n * 7919 + 104729) % 1000003
	h = (h * 6271 + 15485863) % 1000003
	h = (h * 3571 + 7) % 1000003
	return h
end

local function pickBoom(cfg: EventsConfig, cycle: number): BoomDef
	local total = 0
	for _, b in cfg.Booms do
		total += b.weight
	end
	local r = hash(cycle) % 1000 / 1000 * total
	for _, b in cfg.Booms do
		if r < b.weight then
			return b
		end
		r -= b.weight
	end
	return cfg.Booms[#cfg.Booms]
end

function EventSchedule.at(t: number, cfg: EventsConfig): State
	local cycle = math.floor(t / cfg.CycleSeconds)
	local cycleStart = cycle * cfg.CycleSeconds
	local boomStart = cycleStart + cfg.CycleSeconds - cfg.BoomSeconds
	local boomEnd = cycleStart + cfg.CycleSeconds
	local day = math.floor(t / 86400)
	local dailyRarity = cfg.DailyRarities[hash(day + 31337) % #cfg.DailyRarities + 1]
	return {
		cycle = cycle,
		boomActive = cfg.Enabled and t >= boomStart and t < boomEnd,
		boom = pickBoom(cfg, cycle),
		boomStart = boomStart,
		boomEnd = boomEnd,
		nextBoom = pickBoom(cfg, cycle + 1),
		day = day,
		dailyRarity = dailyRarity,
		dailyMult = cfg.DailyMult,
	}
end

function EventSchedule.boomApplies(boom: BoomDef, carrot: CarrotFacts): boolean
	local targets = boom.targets
	if boom.kind == "all" then
		return true
	elseif not targets then
		return false
	elseif boom.kind == "rarity" then
		return table.find(targets, carrot.rarity) ~= nil
	elseif boom.kind == "size" then
		return table.find(targets, carrot.size) ~= nil
	elseif boom.kind == "mutation" then
		for _, m in carrot.mutations do
			if table.find(targets, m) then
				return true
			end
		end
	end
	return false
end

-- Market multiplier for a carrot: daily modifier everywhere, boom only when sold at the market.
-- Always >= 1: waiting can only give more, never less.
function EventSchedule.multiplier(state: State, carrot: CarrotFacts, atMarket: boolean): number
	local m = 1
	if carrot.rarity == state.dailyRarity then
		m *= state.dailyMult
	end
	if state.boomActive and atMarket and EventSchedule.boomApplies(state.boom, carrot) then
		m *= state.boom.mult
	end
	return math.max(1, m)
end

return EventSchedule
