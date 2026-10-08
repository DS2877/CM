--!strict
-- Server-side rolls. All three rolls (type, size, mutation) happen here at planting time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Roller = require(Shared.Roller)
local Rarity = require(Config.Rarity)
local Carrots = require(Config.Carrots)
local Sizes = require(Config.Sizes)
local Mutations = require(Config.Mutations)

local Roll = {}

local rng = Random.new()
local function nextNumber(): number
	return rng:NextNumber()
end

-- Config defs carry extra fields; arrays are invariant in Luau, so cast to the narrower shapes.
local configs: Roller.RollConfigs = {
	rarities = Rarity :: any,
	carrots = Carrots :: any,
	sizes = Sizes :: any,
	mutations = Mutations.List :: any,
	maxMutationChance = Mutations.MaxTotalChance,
}

function Roll.carrot(ctx: Roller.RollContext): Roller.RollResult
	return Roller.roll(configs, ctx, nextNumber)
end

function Roll.number(): number
	return rng:NextNumber()
end

return Roll
