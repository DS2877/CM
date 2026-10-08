--!strict
-- Pure roll logic: rarity -> type, size and mutation are three independent rolls.
-- Configs and the RNG are passed in, so this runs both on the server and in Lune tests.

export type Rng = () -> number -- uniform in [0, 1)

export type RarityLike = { id: string, order: number, chance: number }
export type CarrotLike = { id: string, rarity: string, weight: number }
export type SizeLike = { id: string, order: number, chance: number }
export type MutationLike = { id: string, chance: number }

export type RollConfigs = {
	rarities: { RarityLike },
	carrots: { CarrotLike },
	sizes: { SizeLike },
	mutations: { MutationLike },
	maxMutationChance: number,
}

export type RollContext = {
	luck: number?, -- multiplies every non-Common rarity weight
	sizeLuck: number?, -- multiplies every above-Normal size weight
	mutationLuck: number?, -- multiplies total mutation chance
	minRarityOrder: number?, -- pity / seeds: never roll below this rarity
	forceMutation: string?, -- scripted first mutation
}

export type RollResult = {
	rarity: string,
	type: string,
	size: string,
	mutations: { string },
}

local Roller = {}

local function pickWeighted<T>(items: { T }, weights: { number }, rng: Rng): T
	local total = 0
	for _, w in weights do
		total += w
	end
	local r = rng() * total
	for i, w in weights do
		if r < w then
			return items[i]
		end
		r -= w
	end
	-- Floating point edge: return the last item with positive weight.
	for i = #items, 1, -1 do
		if weights[i] > 0 then
			return items[i]
		end
	end
	return items[#items]
end

function Roller.rarityWeights(rarities: { RarityLike }, ctx: RollContext): { number }
	local luck = ctx.luck or 1
	local minOrder = ctx.minRarityOrder or 1
	local weights = {}
	for i, r in rarities do
		local w = r.chance
		if r.order > 1 then
			w *= luck
		end
		if r.order < minOrder then
			w = 0
		end
		weights[i] = w
	end
	return weights
end

function Roller.rollRarity(rarities: { RarityLike }, ctx: RollContext, rng: Rng): RarityLike
	return pickWeighted(rarities, Roller.rarityWeights(rarities, ctx), rng)
end

function Roller.rollType(carrots: { CarrotLike }, rarityId: string, rng: Rng): CarrotLike
	local pool = {}
	local weights = {}
	for _, c in carrots do
		if c.rarity == rarityId then
			table.insert(pool, c)
			table.insert(weights, c.weight)
		end
	end
	assert(#pool > 0, "No carrot type for rarity " .. rarityId)
	return pickWeighted(pool, weights, rng)
end

function Roller.rollSize(sizes: { SizeLike }, ctx: RollContext, rng: Rng): SizeLike
	local sizeLuck = ctx.sizeLuck or 1
	local weights = {}
	for i, s in sizes do
		weights[i] = if s.order > 2 then s.chance * sizeLuck else s.chance
	end
	return pickWeighted(sizes, weights, rng)
end

function Roller.rollMutation(
	mutations: { MutationLike },
	maxChance: number,
	ctx: RollContext,
	rng: Rng
): string?
	if ctx.forceMutation then
		return ctx.forceMutation
	end
	local total = 0
	local weights = {}
	for i, m in mutations do
		total += m.chance
		weights[i] = m.chance
	end
	if total <= 0 then
		return nil
	end
	local chance = math.min(total * (ctx.mutationLuck or 1), maxChance)
	if rng() >= chance then
		return nil
	end
	return pickWeighted(mutations, weights, rng).id
end

function Roller.roll(configs: RollConfigs, ctx: RollContext, rng: Rng): RollResult
	local rarity = Roller.rollRarity(configs.rarities, ctx, rng)
	local carrot = Roller.rollType(configs.carrots, rarity.id, rng)
	local size = Roller.rollSize(configs.sizes, ctx, rng)
	local mutation = Roller.rollMutation(configs.mutations, configs.maxMutationChance, ctx, rng)
	return {
		rarity = rarity.id,
		type = carrot.id,
		size = size.id,
		mutations = if mutation then { mutation } else {},
	}
end

return Roller
