--!strict
-- The sky party during a market boom (Client/Controllers/BoomParty). Every boom has its own
-- colors so you can tell from anywhere which one is on. All effects are client-side.

export type Theme = {
	tint: { number }, -- color tint over the whole world
	sky: { number }, -- atmosphere / haze color
	colors: { { number } }, -- fireworks, sky beams, aurora
}

local Party = {
	-- Dusk during a boom: the sky turns golden/pink so lights and fireworks glow.
	BoomClockTime = 18.2,
	TransitionSeconds = 3,
	FireworksPerSecond = 3, -- around the camera, high in the sky
	FireworkRadius = 180,
	SkyBeams = 10, -- sweeping searchlights around the plaza edge
	AuroraBands = 3,
	Lanterns = 28, -- glowing lanterns floating up from the plaza

	Themes = {
		Craze = {
			tint = { 255, 236, 205 },
			sky = { 255, 170, 90 },
			colors = { { 255, 200, 60 }, { 255, 120, 40 }, { 255, 90, 140 }, { 255, 255, 255 } },
		},
		RareRush = {
			tint = { 215, 220, 255 },
			sky = { 120, 120, 255 },
			colors = { { 70, 150, 255 }, { 175, 80, 255 }, { 120, 230, 255 }, { 255, 255, 255 } },
		},
		GoldRush = {
			tint = { 255, 240, 190 },
			sky = { 255, 210, 90 },
			colors = { { 255, 215, 60 }, { 255, 245, 160 }, { 255, 170, 30 }, { 255, 255, 255 } },
		},
		BigBonanza = {
			tint = { 220, 255, 215 },
			sky = { 120, 230, 140 },
			colors = { { 110, 230, 90 }, { 255, 230, 70 }, { 60, 200, 160 }, { 255, 255, 255 } },
		},
		CommonCraze = {
			tint = { 255, 220, 240 },
			sky = { 255, 130, 200 },
			colors = { { 255, 110, 180 }, { 255, 170, 220 }, { 180, 120, 255 }, { 255, 255, 255 } },
		},
	} :: { [string]: Theme },

	Default = {
		tint = { 255, 236, 205 },
		sky = { 255, 170, 90 },
		colors = { { 255, 200, 60 }, { 255, 90, 140 }, { 90, 200, 255 }, { 120, 230, 100 } },
	} :: Theme,
}

return Party
