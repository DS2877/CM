--!strict
-- Daily reasons to come back (design doc §4): a 7-day reward calendar and three daily quests.
-- Days are UTC days (same for everyone, like the daily market). The streak PAUSES when you miss
-- a day instead of resetting: missing a day never costs you progress, so coming back always feels
-- good (guilt mechanics churn players and are unkind to kids).

export type Reward = {
	seeds: { [string]: number }?, -- seed id -> amount
	boost: string?, -- Config/Products boost id, granted as play-time minutes
	boostSeconds: number?,
	label: string, -- what the calendar shows
	emoji: string,
}

export type QuestDef = {
	id: string,
	kind: string, -- "harvest" | "plant" | "sell" | "rare" | "mutation" | "market" | "boom" | "upgrade" | "water"
	target: number,
	text: string, -- "%d" is the target
	reward: { [string]: number }, -- seeds
}

local Daily = {
	-- Day 1..7, then it loops (day 7 is the big one).
	Calendar = {
		{ seeds = { Rare = 3 }, label = "3 Rare Seeds", emoji = "🌱" },
		{ seeds = { Golden = 2 }, label = "2 Golden Seeds", emoji = "✨" },
		{ boost = "Luck2", boostSeconds = 15 * 60, label = "Luck x2, 15 min", emoji = "🍀" },
		{ seeds = { Mystery = 3 }, label = "3 Mystery Seeds", emoji = "❓" },
		{ boost = "Value2", boostSeconds = 15 * 60, label = "Value x2, 15 min", emoji = "💰" },
		{ seeds = { Golden = 5 }, label = "5 Golden Seeds", emoji = "✨" },
		{ seeds = { Secret = 1, Golden = 3 }, label = "Secret Seed!", emoji = "🌌" },
	} :: { Reward },

	-- Three quests per day are drawn from this pool (same three for everyone that day, so
	-- friends can talk about them). Targets are tuned for 10-20 minutes of play, and every quest
	-- must be doable solo (no "water a friend" quest: an impossible daily feels unfair).
	QuestPool = {
		{ id = "harvest", kind = "harvest", target = 60, text = "Harvest %d carrots", reward = { Rare = 3 } },
		{ id = "plant", kind = "plant", target = 60, text = "Plant %d seeds", reward = { Rare = 3 } },
		{ id = "sell", kind = "sell", target = 80, text = "Sell %d carrots", reward = { Rare = 3 } },
		{
			id = "rare",
			kind = "rare",
			target = 5,
			text = "Find %d Rare-or-better carrots",
			reward = { Golden = 2 },
		},
		{
			id = "mutation",
			kind = "mutation",
			target = 2,
			text = "Find %d mutated carrots",
			reward = { Golden = 2 },
		},
		{
			id = "market",
			kind = "market",
			target = 2,
			text = "Sell at the market %d times",
			reward = { Mystery = 2 },
		},
		{
			id = "boom",
			kind = "boom",
			target = 1,
			text = "Sell during a market boom",
			reward = { Mystery = 3 },
		},
		{ id = "upgrade", kind = "upgrade", target = 3, text = "Buy %d upgrades", reward = { Golden = 2 } },
	} :: { QuestDef },
	QuestsPerDay = 3,

	-- Finishing all three quests in a day
	AllQuestsBonus = { Golden = 3, Mystery = 2 } :: { [string]: number },
}

return Daily
