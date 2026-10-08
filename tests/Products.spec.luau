--!strict
-- Monetization rules (design doc §11) checked against config:
--   * everything sold for Robux has known contents: no Mystery Seeds, only real seeds/boosts
--   * every referenced boost/seed exists, ids are unique
local Products = require("../src/shared/Config/Products")
local Seeds = require("../src/shared/Config/Seeds")

return function()
	local seedById = {}
	for _, s in Seeds do
		seedById[s.id] = s
	end
	local boostById = {}
	for _, b in Products.Boosts do
		assert(not boostById[b.id], "duplicate boost " .. b.id)
		boostById[b.id] = b
		assert(b.mult >= 1, "boost multipliers never punish")
	end

	local ids = {}
	for _, p in Products.DeveloperProducts do
		assert(not ids[p.id], "duplicate product " .. p.id)
		ids[p.id] = true
		if p.seeds then
			for _, s in p.seeds do
				local def = seedById[s.seed]
				assert(def, p.id .. ": unknown seed " .. s.seed)
				assert(def.mystery == nil, p.id .. ": random (Mystery) seeds may not be sold for Robux")
				assert(s.amount > 0, p.id .. ": amount")
			end
		end
		if p.boosts then
			for _, b in p.boosts do
				assert(boostById[b.boost], p.id .. ": unknown boost " .. b.boost)
				assert(b.seconds > 0, p.id .. ": seconds")
			end
		end
		assert(p.kind ~= "bundle" or p.seeds or p.boosts, p.id .. ": bundle has contents")
	end
	assert(ids.StarterBundle, "Starter Bundle exists")
	for _, p in Products.DeveloperProducts do
		if p.id == "StarterBundle" then
			assert(p.once == true, "Starter Bundle can only be bought once")
		end
	end

	local passIds = {}
	for _, p in Products.GamePasses do
		assert(not passIds[p.id], "duplicate pass " .. p.id)
		passIds[p.id] = true
	end
	for _, needed in { "Growth2x", "AutoHarvest", "MarketVIP", "BigBasket", "Scanner" } do
		assert(passIds[needed], "missing pass " .. needed)
	end
end
