--!strict
-- 1,000,000 rolls must match the configured chances.
-- Outcomes with >= 2,000 expected hits must be within +/-5 % (relative) of their chance.
-- Rarer outcomes (Mythic, Secret, Giant...) can't be measured that tightly with 1M samples,
-- so they must be within 5 standard deviations instead.
local Roller = require("../src/shared/Roller")
local Rarity = require("../src/shared/Config/Rarity")
local Carrots = require("../src/shared/Config/Carrots")
local Sizes = require("../src/shared/Config/Sizes")
local Mutations = require("../src/shared/Config/Mutations")

local N = 1000000

local configs: Roller.RollConfigs = {
	rarities = Rarity,
	carrots = Carrots,
	sizes = Sizes,
	mutations = Mutations.List,
	maxMutationChance = Mutations.MaxTotalChance,
}

local function check(label: string, observed: number, p: number)
	local expected = N * p
	local tolerance
	if expected >= 2000 then
		tolerance = expected * 0.05
	else
		tolerance = math.max(5 * math.sqrt(expected * (1 - p)), 3)
	end
	if math.abs(observed - expected) > tolerance then
		error(string.format("%s: observed %d, expected %.1f (+/- %.1f)", label, observed, expected, tolerance))
	end
end

return function()
	math.randomseed(12345)
	local function nextNumber(): number
		return math.random()
	end

	local rarityCount: { [string]: number } = {}
	local sizeCount: { [string]: number } = {}
	local mutationCount: { [string]: number } = {}
	local typeCount: { [string]: number } = {}
	for _ = 1, N do
		local r = Roller.roll(configs, {}, nextNumber)
		rarityCount[r.rarity] = (rarityCount[r.rarity] or 0) + 1
		sizeCount[r.size] = (sizeCount[r.size] or 0) + 1
		typeCount[r.type] = (typeCount[r.type] or 0) + 1
		local m = r.mutations[1] or "None"
		mutationCount[m] = (mutationCount[m] or 0) + 1
	end

	for _, r in Rarity do
		check("rarity " .. r.id, rarityCount[r.id] or 0, r.chance)
	end
	for _, s in Sizes do
		check("size " .. s.id, sizeCount[s.id] or 0, s.chance)
	end
	local anyMutation = 0
	for _, m in Mutations.List do
		check("mutation " .. m.id, mutationCount[m.id] or 0, m.chance)
		anyMutation += m.chance
	end
	check("no mutation", mutationCount.None or 0, 1 - anyMutation)
	-- Classic and Baby split Common evenly
	check("type Classic", typeCount.Classic or 0, 0.35)

	-- Pity: minimum rarity is always respected
	for _ = 1, 2000 do
		local r = Roller.roll(configs, { minRarityOrder = 5 }, nextNumber)
		assert(r.rarity == "Legendary" or r.rarity == "Mythic" or r.rarity == "Secret", "pity broke: " .. r.rarity)
	end
	-- Forced mutation
	local forced = Roller.roll(configs, { forceMutation = "Golden" }, nextNumber)
	assert(forced.mutations[1] == "Golden", "forced mutation not applied")
	-- Luck shifts weight away from Common
	local w1 = Roller.rarityWeights(Rarity, { luck = 1 })
	local w2 = Roller.rarityWeights(Rarity, { luck = 2 })
	assert(w2[5] == w1[5] * 2 and w2[1] == w1[1], "luck should double non-common weights")
end
