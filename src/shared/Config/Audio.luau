--!strict
-- Audio direction and mix. IDs live in Config/Assets (Sounds / Music / Ambience); this file says
-- how each cue behaves. Change the mix here, never in controllers.
--
-- Identity: "sunny folk-pop farmers' market". Acoustic and warm (ukulele, marimba, light hand
-- percussion, whistles). Music sits UNDER the game: the stars are the carrot reveals, so the music
-- ducks whenever something big happens.
--
-- Mix hierarchy (loudest first): rare reveals / fanfares > harvest + sell > UI > music > ambience.
-- Repeated sounds get pitch variation so they never machine-gun; quick harvest streaks climb in
-- pitch like coin pickups ("combo"), which makes tapping through a full farm feel great.

export type Group = "Music" | "Ambience" | "SFX" | "UI"

export type Cue = {
	group: Group,
	volume: number,
	pitch: { number }, -- {min, max} random playback speed
	cooldown: number?, -- seconds before the cue may play again
	duck: number?, -- seconds to duck the music (big moments)
	positional: boolean?, -- played from a part in the world when one is given
	-- Fallback when the cue has no own asset yet: borrow another cue's sound with a pitch change,
	-- so the game is never silent and never the same "ping" for everything.
	fallback: string?,
	fallbackPitch: number?,
}

local Audio = {
	-- Bus volumes (SoundGroups)
	Groups = {
		Music = 0.32,
		Ambience = 0.28,
		SFX = 0.75,
		UI = 0.5,
	},

	-- Music ducking: how far the music bus drops (fraction of its volume) and how fast
	DuckTo = 0.25,
	DuckFadeIn = 0.15,
	DuckFadeOut = 1.2,

	-- Crossfade between music states (farm <-> boom)
	CrossfadeSeconds = 2.5,

	-- Harvest combo: harvests within this window climb one step each, up to MaxSteps
	ComboWindow = 1.4,
	ComboStep = 0.06, -- playback speed added per step (~1 semitone)
	ComboMaxSteps = 8,

	Cues = {
		-- UI ---------------------------------------------------------------------------------
		Click = { group = "UI", volume = 0.5, pitch = { 0.96, 1.04 }, cooldown = 0.05 },
		Open = {
			group = "UI",
			volume = 0.45,
			pitch = { 1.0, 1.05 },
			fallback = "Click",
			fallbackPitch = 1.15,
		},
		Purchase = { group = "UI", volume = 0.7, pitch = { 1, 1 } },
		Denied = {
			group = "UI",
			volume = 0.45,
			pitch = { 1, 1 },
			cooldown = 0.3,
			fallback = "Click",
			fallbackPitch = 0.6,
		},
		GoalReady = {
			group = "UI",
			volume = 0.5,
			pitch = { 1, 1 },
			cooldown = 3,
			fallback = "Purchase",
			fallbackPitch = 1.35,
		},

		-- Farm -------------------------------------------------------------------------------
		Plant = { group = "SFX", volume = 0.45, pitch = { 0.9, 1.1 }, cooldown = 0.04 },
		Harvest = { group = "SFX", volume = 0.6, pitch = { 0.97, 1.03 } }, -- combo pitch on top
		HarvestRare = {
			group = "SFX",
			volume = 0.7,
			pitch = { 1, 1 },
			fallback = "Harvest",
			fallbackPitch = 1.3,
		},
		HarvestEpic = {
			group = "SFX",
			volume = 0.8,
			pitch = { 1, 1 },
			fallback = "Discover",
			fallbackPitch = 1.1,
		},
		HarvestLegendary = { group = "SFX", volume = 0.95, pitch = { 1, 1 }, duck = 3 },
		HarvestMythic = {
			group = "SFX",
			volume = 1,
			pitch = { 1, 1 },
			duck = 4.5,
			fallback = "HarvestLegendary",
			fallbackPitch = 0.85,
		},
		Mutation = {
			group = "SFX",
			volume = 0.6,
			pitch = { 1, 1.05 },
			fallback = "Discover",
			fallbackPitch = 1.4,
		},
		Discover = { group = "SFX", volume = 0.75, pitch = { 1, 1 }, duck = 1.5 },
		Shimmer = { group = "SFX", volume = 0.35, pitch = { 0.95, 1.05 }, positional = true, cooldown = 0.2 },
		Sparks = {
			group = "SFX",
			volume = 0.5,
			pitch = { 1, 1.05 },
			positional = true,
			fallback = "Shimmer",
			fallbackPitch = 1.25,
		},
		Pillar = { group = "SFX", volume = 0.8, pitch = { 1, 1 }, positional = true, duck = 2 },
		Water = { group = "SFX", volume = 0.55, pitch = { 0.95, 1.05 }, positional = true },

		-- Economy ----------------------------------------------------------------------------
		Sell = { group = "SFX", volume = 0.65, pitch = { 1, 1 } },
		SellBoom = {
			group = "SFX",
			volume = 0.9,
			pitch = { 1, 1 },
			duck = 2.5,
			fallback = "HarvestLegendary",
			fallbackPitch = 1.15,
		},
		Upgrade = {
			group = "SFX",
			volume = 0.65,
			pitch = { 1, 1 },
			fallback = "Purchase",
			fallbackPitch = 1.2,
		},

		-- Market & social ----------------------------------------------------------------------
		Bell = { group = "SFX", volume = 0.85, pitch = { 1, 1 }, duck = 2 },
		BoomEnd = { group = "SFX", volume = 0.45, pitch = { 1, 1 }, fallback = "Bell", fallbackPitch = 0.8 },
		Announce = {
			group = "SFX",
			volume = 0.5,
			pitch = { 1, 1 },
			cooldown = 2,
			fallback = "HarvestLegendary",
			fallbackPitch = 1.3,
		},

		-- Offline reveal -------------------------------------------------------------------------
		RevealTick = { group = "SFX", volume = 0.4, pitch = { 1, 1 }, fallback = "Harvest" },
	} :: { [string]: Cue },
}

return Audio
