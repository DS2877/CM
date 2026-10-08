--!strict
-- Pure offline-growth math (no Roblox APIs, tested in tests/OfflinePlan.spec.luau).
--
-- Only plots that were saved as growing take part: an empty plot never produces anything.
-- * Away less than minSeconds: every plot comes back as it was, minus the time away
--   (a finished one comes back ready to tap). Nothing is harvested for the player.
-- * Longer: the carrot already in the ground finishes as rolled ("saved"), then the plot keeps
--   producing slowly: one carrot per max(growTime / rate, minCycle) seconds. The floor matters:
--   without it, growth upgrades made offline as fast as playing (a full basket after 5 minutes).
--   Extra carrots are capped twice: by perHour x hours away (a short break is a small treat,
--   not a full basket) and by maxCarrots. Saved carrots always count; only extras are trimmed.

export type SavedInput = {
	index: number,
	remaining: number, -- seconds the saved carrot still needed
	growTime: number, -- current online grow time of this plot
}

export type PlotPlan = {
	index: number,
	restoreRemaining: number?, -- set: put the saved carrot back with this many seconds left
	finishSaved: boolean, -- the saved carrot is harvested into the offline basket
	extra: number, -- further offline harvests (Basic seeds)
	replant: boolean, -- plant fresh afterwards
}

export type Config = {
	minSeconds: number,
	capSeconds: number,
	maxCarrots: number,
	rate: number,
	minCycle: number, -- slowest-allowed seconds per offline carrot per plot (floor on speed)
	perHour: number, -- extra offline carrots per hour away, all plots together
}

export type Plan = {
	credited: boolean, -- true when there is an offline reveal
	seconds: number, -- time that counted (capped)
	plots: { PlotPlan },
	total: number, -- carrots going to the offline basket
}

local OfflinePlan = {}

function OfflinePlan.make(saved: { SavedInput }, away: number, cfg: Config): Plan
	away = math.max(0, away)
	local plan: Plan = { credited = false, seconds = 0, plots = {}, total = 0 }

	if away < cfg.minSeconds then
		for _, s in saved do
			table.insert(plan.plots, {
				index = s.index,
				restoreRemaining = math.max(0, s.remaining - away),
				finishSaved = false,
				extra = 0,
				replant = false,
			})
		end
		return plan
	end

	local seconds = math.min(away, cfg.capSeconds)
	plan.seconds = seconds
	local finished, extraTotal = 0, 0
	for _, s in saved do
		if s.remaining > seconds then
			table.insert(plan.plots, {
				index = s.index,
				restoreRemaining = s.remaining - seconds,
				finishSaved = false,
				extra = 0,
				replant = false,
			})
		else
			local cycle = math.max(s.growTime / math.max(cfg.rate, 1e-6), cfg.minCycle)
			local extra = if cycle > 0 then math.floor((seconds - s.remaining) / cycle) else 0
			finished += 1
			extraTotal += extra
			table.insert(plan.plots, {
				index = s.index,
				restoreRemaining = nil,
				finishSaved = true,
				extra = extra,
				replant = true,
			})
		end
	end

	-- Cap: trim the extra harvests proportionally, never the saved carrots.
	local byTime = math.floor(cfg.perHour * seconds / 3600)
	local room = math.max(0, math.min(cfg.maxCarrots - finished, byTime))
	if extraTotal > room then
		local scale = if extraTotal > 0 then room / extraTotal else 0
		local kept = 0
		for _, p in plan.plots do
			p.extra = math.floor(p.extra * scale)
			kept += p.extra
		end
		-- Hand out the rounding remainder one at a time to plots that were producing.
		local i = 1
		local guard = 0
		while kept < room and guard < #plan.plots * (room + 1) do
			local p = plan.plots[i]
			if p.finishSaved then
				p.extra += 1
				kept += 1
			end
			i = i % #plan.plots + 1
			guard += 1
		end
		extraTotal = kept
	end

	plan.total = finished + extraTotal
	plan.credited = plan.total > 0
	return plan
end

return OfflinePlan
