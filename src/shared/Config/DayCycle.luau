--!strict
-- Day / evening / night / morning cycle. Computed from the server clock, so every player in
-- every server sees the same time of day (Client/Controllers/DayCycle). Night stays bright
-- enough for kids to play: moonlit blue, never pitch black. Pure module (Lune-testable).

export type Phase = { name: string, untilFrac: number, fromClock: number, toClock: number }

local DayCycle = {
	CycleSeconds = 20 * 60, -- one full day
	-- Fractions of the cycle; ClockTime runs from -> to within each phase (hours, may pass 24).
	Phases = {
		{ name = "Morning", untilFrac = 0.12, fromClock = 5.5, toClock = 9 },
		{ name = "Day", untilFrac = 0.62, fromClock = 9, toClock = 16.5 },
		{ name = "Evening", untilFrac = 0.77, fromClock = 16.5, toClock = 19.5 },
		{ name = "Night", untilFrac = 1, fromClock = 19.5, toClock = 29.5 },
	} :: { Phase },
	-- Lighting at full day and at deepest night (blended by how dark it is)
	DayBrightness = 2.8,
	NightBrightness = 1.1,
	DayAmbient = { 130, 120, 110 },
	NightAmbient = { 95, 105, 145 },
	DayOutdoorAmbient = { 175, 168, 152 },
	NightOutdoorAmbient = { 110, 120, 170 },
}

-- Where in the day we are at time t: (ClockTime 0-24, phase name, darkness 0 = day .. 1 = night)
function DayCycle.at(t: number): (number, string, number)
	local frac = (t % DayCycle.CycleSeconds) / DayCycle.CycleSeconds
	local start = 0
	for _, p in DayCycle.Phases do
		if frac < p.untilFrac or p == DayCycle.Phases[#DayCycle.Phases] then
			local k = math.clamp((frac - start) / (p.untilFrac - start), 0, 1)
			local clock = (p.fromClock + (p.toClock - p.fromClock) * k) % 24
			-- darkness: 0 between 8 and 17, 1 between 20 and 5, smooth in between
			local darkness
			if clock >= 8 and clock <= 17 then
				darkness = 0
			elseif clock > 17 and clock < 20 then
				darkness = (clock - 17) / 3
			elseif clock > 5 and clock < 8 then
				darkness = 1 - (clock - 5) / 3
			else
				darkness = 1
			end
			return clock, p.name, darkness
		end
		start = p.untilFrac
	end
	return 12, "Day", 0
end

return DayCycle
