--!strict
-- Soft launch (phase 5): promo codes, Roblox group reward, the favorite prompt.
-- Rewards are always in-game seeds (never Robux items, never cash bundles), so codes stay a
-- friendly gift rather than an economy lever.

export type CodeDef = {
	seeds: { [string]: number }, -- seed id -> amount
	active: boolean, -- set false to retire a code (players who already used it keep the reward)
}

local Launch = {
	-- Codes are case-insensitive. Share them in the Roblox group / Discord / thumbnails.
	Codes = {
		CARROTS = { seeds = { Rare = 5 }, active = true },
		LAUNCH = { seeds = { Golden = 3 }, active = true },
		MARKETBOOM = { seeds = { Mystery = 3 }, active = true },
	} :: { [string]: CodeDef },

	-- Roblox group for the join reward. 0 = disabled until Philip creates the group.
	GroupId = 0,
	GroupReward = { Golden = 3, Rare = 5 } :: { [string]: number },

	-- Ask for a favorite the moment a player finds their first carrot of this rarity or better
	-- (the happiest moment), once per player.
	FavoriteAtRarity = "Legendary",
}

return Launch
