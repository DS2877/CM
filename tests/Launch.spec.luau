--!strict
local Launch = require("../src/shared/Config/Launch")
local Seeds = require("../src/shared/Config/Seeds")
local Rarity = require("../src/shared/Config/Rarity")

return function()
	local seedIds = {}
	for _, s in Seeds do
		seedIds[s.id] = true
	end
	local function checkSeeds(seeds: { [string]: number }, where: string)
		for id, n in seeds do
			assert(seedIds[id], where .. ": unknown seed " .. id)
			assert(id ~= "Basic", where .. ": Basic seeds are unlimited, granting them is a no-op")
			assert(n > 0 and n <= 25, where .. ": amount should be a small gift, got " .. n)
		end
	end
	for code, def in Launch.Codes do
		assert(
			code == string.upper(code) and not string.find(code, "%s"),
			"codes are UPPER, no spaces: " .. code
		)
		checkSeeds(def.seeds, "code " .. code)
	end
	checkSeeds(Launch.GroupReward, "group reward")
	local found = false
	for _, r in Rarity do
		found = found or r.id == Launch.FavoriteAtRarity
	end
	assert(found, "FavoriteAtRarity must be a real rarity")
end
