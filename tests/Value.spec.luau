--!strict
local Value = require("../src/shared/Value")
local Rarity = require("../src/shared/Config/Rarity")
local Sizes = require("../src/shared/Config/Sizes")
local Mutations = require("../src/shared/Config/Mutations")
local Economy = require("../src/shared/Config/Economy")

local function eq(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-6 then
		error(string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
	end
end

return function()
	-- Plain common carrot
	eq(Value.compute({ base = 10, size = 1 }), 10)
	-- Small common rounds to whole cash
	eq(Value.compute({ base = 10, size = 0.8 }), 8)
	-- Full formula: 120 * 1.5 * 3 * 2 * (1 + 0.5) * 2 * 3 = 9720
	eq(
		Value.compute({
			base = 120,
			size = 1.5,
			mutation = 3,
			market = 2,
			valueUpgrade = 0.5,
			prestige = 2,
			boosts = 3,
		}),
		9720
	)
	-- Boosts are capped at the configured cap (x6)
	eq(Value.compute({ base = 10, size = 1, boosts = 100, boostCap = Economy.BoostCap }), 60)
	eq(Value.boostMultiplier({ 2, 2, 4 }, 6), 6)
	eq(Value.boostMultiplier({ 2, 2 }, 6), 4)
	-- Multiple mutations multiply
	eq(Value.mutationMultiplier({ 3, 6 }), 18)
	eq(Value.mutationMultiplier({}), 1)
	-- Never below 1
	eq(Value.compute({ base = 0.1, size = 0.8 }), 1)

	-- Config sanity: rarity chances sum to 1, sizes sum to 1, base values strictly increase.
	local sum, last = 0, 0
	for _, r in Rarity do
		sum += r.chance
		assert(r.baseValue > last, "rarity base values must increase")
		last = r.baseValue
	end
	eq(math.floor(sum * 1e9 + 0.5) / 1e9, 1)
	local sizeSum = 0
	for _, s in Sizes do
		sizeSum += s.chance
	end
	eq(math.floor(sizeSum * 1e9 + 0.5) / 1e9, 1)
	local mutSum = 0
	for _, m in Mutations.List do
		mutSum += m.chance
	end
	eq(math.floor(mutSum * 1e9 + 0.5) / 1e9, 0.08)

	-- Biggest possible single carrot: Secret Giant Rainbow
	eq(Value.compute({ base = 2000000, size = 5, mutation = 10 }), 100000000)
end
