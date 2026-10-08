--!strict
local DailyPlan = require("../src/shared/DailyPlan")
local Daily = require("../src/shared/Config/Daily")
local Seeds = require("../src/shared/Config/Seeds")
local Products = require("../src/shared/Config/Products")

return function()
	-- Quests: distinct, stable for a day, vary across days
	local a = DailyPlan.questsFor(20000, #Daily.QuestPool, Daily.QuestsPerDay)
	local b = DailyPlan.questsFor(20000, #Daily.QuestPool, Daily.QuestsPerDay)
	assert(#a == Daily.QuestsPerDay, "three quests a day")
	assert(a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3], "quests are distinct")
	assert(a[1] == b[1] and a[2] == b[2] and a[3] == b[3], "same quests all day")
	local differs = false
	for d = 20001, 20010 do
		local c = DailyPlan.questsFor(d, #Daily.QuestPool, Daily.QuestsPerDay)
		differs = differs or c[1] ~= a[1] or c[2] ~= a[2]
	end
	assert(differs, "quests change from day to day")

	-- Streak pauses, never resets: slot only depends on claims
	assert(DailyPlan.calendarSlot(0, 7) == 1 and DailyPlan.calendarSlot(6, 7) == 7, "slots 1..7")
	assert(DailyPlan.calendarSlot(7, 7) == 1, "loops after day 7")
	assert(DailyPlan.canClaim(0, 20000) and not DailyPlan.canClaim(20000, 20000), "once per day")
	assert(DailyPlan.canClaim(19990, 20000), "missing days still lets you claim (no reset)")

	-- Rewards reference real seeds / boosts and are never Robux items
	local seedIds = {}
	for _, s in Seeds do
		seedIds[s.id] = true
	end
	local boostIds = {}
	for _, bdef in Products.Boosts do
		boostIds[bdef.id] = true
	end
	local function checkSeeds(seeds: { [string]: number }?, where: string)
		for id, n in seeds or {} do
			assert(seedIds[id] and id ~= "Basic" and n > 0, where .. ": bad seed " .. id)
		end
	end
	for i, r in Daily.Calendar do
		checkSeeds(r.seeds, "calendar day " .. i)
		if r.boost then
			assert(boostIds[r.boost] and (r.boostSeconds or 0) > 0, "calendar boost " .. r.boost)
		end
	end
	for _, q in Daily.QuestPool do
		assert(q.target > 0, "quest target " .. q.id)
		checkSeeds(q.reward, "quest " .. q.id)
	end
	checkSeeds(Daily.AllQuestsBonus, "all-quests bonus")
end
