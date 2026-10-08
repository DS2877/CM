--!strict
-- Pure daily math (no Roblox APIs; tested in tests/Daily.spec.luau).

local DailyPlan = {}

-- UTC day number for a unix time.
function DailyPlan.day(t: number): number
	return math.floor(t / 86400)
end

-- Small deterministic hash (same as the market schedule's style).
local function hash(n: number): number
	local h = (n * 7919 + 104729) % 1000003
	h = (h * 6271 + 15485863) % 1000003
	h = (h * 3571 + 7) % 1000003
	return h
end

-- Indices into the quest pool for `day`: `count` distinct quests, same for everyone that day.
function DailyPlan.questsFor(day: number, poolSize: number, count: number): { number }
	local picked: { number } = {}
	local used: { [number]: boolean } = {}
	local k = 0
	while #picked < math.min(count, poolSize) do
		local i = hash(day * 13 + k) % poolSize + 1
		k += 1
		if not used[i] then
			used[i] = true
			table.insert(picked, i)
		end
	end
	return picked
end

-- Calendar slot (1-based) for the next claim, given how many days were claimed so far.
-- Missing days doesn't matter: the streak only counts claims (it pauses, never resets).
function DailyPlan.calendarSlot(claims: number, length: number): number
	return claims % length + 1
end

-- Can the player claim today? `lastDay` is the UTC day of their last claim (0 = never).
function DailyPlan.canClaim(lastDay: number, today: number): boolean
	return today > lastDay
end

return DailyPlan
