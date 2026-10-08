--!strict
-- CarrotDex: types found (layer 1) and type+mutation stamps (layer 2), with seed rewards at
-- milestones (Config/Dex). Secret Seeds come only from here and events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local DexConfig = require(Config.Dex)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local Seeds = require(script.Parent.Seeds)

local Dex = {}

local function foundCount(data: Data.PlayerData): number
	local n = 0
	for typeId in data.FoundTypes do
		if CarrotInfo.type(typeId) then
			n += 1
		end
	end
	return n
end

local function stampCount(data: Data.PlayerData): number
	local n = 0
	for _ in data.FoundStamps do
		n += 1
	end
	return n
end

function Dex.sync(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	player:SetAttribute("FoundCount", foundCount(data))
	player:SetAttribute("TotalTypes", CarrotInfo.TotalTypes)
	player:SetAttribute("StampCount", stampCount(data))
	-- Best rarity ever found: drives the title over the player's head (visible status)
	local best, bestOrder = "", 0
	for typeId in data.FoundTypes do
		local def = CarrotInfo.type(typeId)
		local order = if def then CarrotInfo.rarityOrder(def.rarity) else 0
		if order > bestOrder then
			best, bestOrder = if def then def.rarity else "", order
		end
	end
	player:SetAttribute("BestRarity", best)
	player:SetAttribute("TotalStamps", CarrotInfo.TotalStamps)
	local state: Types.DexState = { types = data.FoundTypes, stamps = data.FoundStamps }
	Remotes.get(Remotes.Names.DexSync):FireClient(player, state)
end

local function claimMilestones(player: Player, data: Data.PlayerData)
	local found = foundCount(data)
	local stamps = stampCount(data)
	while data.DexClaims.Types < #DexConfig.TypeMilestones do
		local m = DexConfig.TypeMilestones[data.DexClaims.Types + 1]
		if found < m.count then
			break
		end
		data.DexClaims.Types += 1
		Seeds.grant(player, m.seed, m.amount, string.format("CarrotDex %d found", m.count))
	end
	while data.DexClaims.Stamps < #DexConfig.StampMilestones do
		local m = DexConfig.StampMilestones[data.DexClaims.Stamps + 1]
		if stamps < m.count then
			break
		end
		data.DexClaims.Stamps += 1
		Seeds.grant(player, m.seed, m.amount, string.format("%d mutation stamps", m.count))
	end
end

-- Records a carrot. Returns (isNewType, foundCount). `silent` skips the client sync (bulk use).
function Dex.record(player: Player, carrot: Types.Carrot, silent: boolean?): (boolean, number)
	local data = Data.get(player)
	if not data then
		return false, 0
	end
	local isNew = not data.FoundTypes[carrot.type]
	data.FoundTypes[carrot.type] = true
	local newStamp = false
	for _, m in carrot.mutations do
		local key = carrot.type .. "|" .. m
		if not data.FoundStamps[key] then
			data.FoundStamps[key] = true
			newStamp = true
		end
	end
	if isNew or newStamp then
		claimMilestones(player, data)
		if not silent then
			Dex.sync(player)
		end
	end
	return isNew, foundCount(data)
end

-- Catch up on milestones (e.g. after a config change) when a player joins.
function Dex.onPlayerReady(player: Player)
	local data = Data.get(player)
	if data then
		claimMilestones(player, data)
	end
	Dex.sync(player)
end

return Dex
