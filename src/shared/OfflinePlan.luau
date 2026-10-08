--!strict
-- Pure offline math (no Roblox APIs, tested in tests/OfflinePlan.spec.luau).
--
-- The rule (Philip, 8 Oct): you can't get more than you planted. While you're away, the carrots
-- you left in the ground simply keep growing in real time. When you come back each one is back in
-- its plot with its remaining time reduced by the time away; finished ones are ready to tap.
-- Nothing is harvested for you and no extra carrots exist. Empty plots stay empty.

export type SavedInput = {
	index: number,
	remaining: number, -- seconds the saved carrot still needed when you left
}

export type PlotPlan = {
	index: number,
	remaining: number, -- seconds left now (0 = ready to harvest)
}

export type Plan = {
	plots: { PlotPlan },
	ready: number, -- how many are fully grown now
}

local OfflinePlan = {}

function OfflinePlan.make(saved: { SavedInput }, away: number): Plan
	away = math.max(0, away)
	local plan: Plan = { plots = {}, ready = 0 }
	for _, s in saved do
		local remaining = math.max(0, s.remaining - away)
		if remaining <= 0 then
			plan.ready += 1
		end
		table.insert(plan.plots, { index = s.index, remaining = remaining })
	end
	return plan
end

return OfflinePlan
