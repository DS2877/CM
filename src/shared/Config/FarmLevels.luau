--!strict
-- Farm Level: what each level adds to the look of a farm (plots and prices are the FarmSize track
-- in Config/Upgrades; farm level = that track's level + 1). Every level adds something you can
-- see from the path, so it's easy to tell who is ahead. Built by Server/Services/FarmDecor.
--
-- 20 levels for now. Room for 40: add entries here (any `id` FarmDecor knows) and append
-- costs/plots in Config/Upgrades. Unknown ids are skipped, so config can run ahead of art.
-- Pure module (no Roblox APIs).

export type Unlock = {
	level: number, -- farm level that unlocks it (2 = first level-up)
	id: string, -- FarmDecor builder id
	name: string,
	emoji: string,
}

local FarmLevels = {}

FarmLevels.MaxLevel = 20

FarmLevels.Unlocks = {
	{ level = 2, id = "Flowers", name = "Flower boxes", emoji = "🌷" },
	{ level = 3, id = "Scarecrow", name = "Scarecrow", emoji = "🎃" },
	{ level = 4, id = "Lanterns", name = "Gate lanterns & mailbox", emoji = "🏮" },
	{ level = 5, id = "HayBales", name = "Hay bales", emoji = "🌾" },
	{ level = 6, id = "Chickens", name = "Chickens", emoji = "🐔" },
	{ level = 7, id = "Well", name = "Water well", emoji = "🪣" },
	{ level = 8, id = "AppleTrees", name = "Apple trees", emoji = "🍎" },
	{ level = 9, id = "Windmill", name = "Windmill", emoji = "🌬️" },
	{ level = 10, id = "WhiteFence", name = "White picket fence", emoji = "🤍" },
	{ level = 11, id = "Silo", name = "Silo", emoji = "🏗️" },
	{ level = 12, id = "Pond", name = "Duck pond", emoji = "🦆" },
	{ level = 13, id = "Cow", name = "Cow", emoji = "🐄" },
	{ level = 14, id = "Greenhouse", name = "Greenhouse", emoji = "🪴" },
	{ level = 15, id = "Banners", name = "Corner banners", emoji = "🚩" },
	{ level = 16, id = "Tractor", name = "Tractor", emoji = "🚜" },
	{ level = 17, id = "Fountain", name = "Fountain", emoji = "⛲" },
	{ level = 18, id = "GoldTrim", name = "Gold gate & lamp posts", emoji = "✨" },
	{ level = 19, id = "Rainbow", name = "Rainbow arch", emoji = "🌈" },
	{ level = 20, id = "GoldenCarrot", name = "Giant golden carrot", emoji = "🥕" },
} :: { Unlock }

-- Everything a farm at `level` has (in unlock order).
function FarmLevels.unlocked(level: number): { Unlock }
	local out = {}
	for _, u in FarmLevels.Unlocks do
		if u.level <= level then
			table.insert(out, u)
		end
	end
	return out
end

-- What reaching `level` adds (usually one thing).
function FarmLevels.at(level: number): { Unlock }
	local out = {}
	for _, u in FarmLevels.Unlocks do
		if u.level == level then
			table.insert(out, u)
		end
	end
	return out
end

return FarmLevels
