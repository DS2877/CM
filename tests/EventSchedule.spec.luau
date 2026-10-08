--!strict
local EventSchedule = require("../src/shared/EventSchedule")
local Events = require("../src/shared/Config/Events")

local cfg: EventSchedule.EventsConfig = Events :: any

return function()
	-- Same time -> same state (all servers agree)
	local t0 = 1791460800 -- some fixed unix time
	local a = EventSchedule.at(t0, cfg)
	local b = EventSchedule.at(t0, cfg)
	assert(a.boom.id == b.boom.id and a.boomStart == b.boomStart, "deterministic")

	-- Boom window: last BoomSeconds of every cycle
	local cycleStart = math.floor(t0 / Events.CycleSeconds) * Events.CycleSeconds
	assert(not EventSchedule.at(cycleStart, cfg).boomActive, "no boom at cycle start")
	local boomStart = cycleStart + Events.CycleSeconds - Events.BoomSeconds
	assert(EventSchedule.at(boomStart, cfg).boomActive, "boom starts on time")
	assert(EventSchedule.at(boomStart + Events.BoomSeconds - 1, cfg).boomActive, "boom lasts")
	assert(not EventSchedule.at(boomStart + Events.BoomSeconds, cfg).boomActive, "boom ends")

	-- Boom share of time matches config, and every boom type shows up over a day
	local active, seen = 0, {}
	for t = t0, t0 + 86400 - 1, 10 do
		local s = EventSchedule.at(t, cfg)
		if s.boomActive then
			active += 1
			seen[s.boom.id] = true
		end
	end
	local share = active / 8640
	local expected = Events.BoomSeconds / Events.CycleSeconds
	assert(math.abs(share - expected) < 0.01, "boom share " .. share)
	for _, boom in Events.Booms do
		assert(seen[boom.id], "boom " .. boom.id .. " never happened in a day")
	end

	-- Multipliers never go below 1 and boom only pays at the market
	local carrot = { rarity = "Rare", size = "Giant", mutations = { "Golden" } }
	for t = t0, t0 + 3 * 86400, 37 do
		local s = EventSchedule.at(t, cfg)
		local here = EventSchedule.multiplier(s, carrot, false)
		local market = EventSchedule.multiplier(s, carrot, true)
		assert(here >= 1 and market >= here, "multiplier >= 1 and market >= anywhere")
		if not s.boomActive then
			assert(market == here, "no boom -> no market bonus")
		end
	end

	-- Boom targeting
	local all = { id = "x", name = "x", description = "", kind = "all", mult = 2, weight = 1 }
	assert(EventSchedule.boomApplies(all, carrot), "all applies")
	local rar = {
		id = "y",
		name = "y",
		description = "",
		kind = "rarity",
		targets = { "Epic" },
		mult = 3,
		weight = 1,
	}
	assert(not EventSchedule.boomApplies(rar, carrot), "rarity mismatch")
	local mut = {
		id = "z",
		name = "z",
		description = "",
		kind = "mutation",
		targets = { "Golden" },
		mult = 3,
		weight = 1,
	}
	assert(EventSchedule.boomApplies(mut, carrot), "mutation match")
end
