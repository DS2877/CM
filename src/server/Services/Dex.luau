--!strict
-- CarrotDex: which types (layer 1) and type+mutation stamps (layer 2) a player has found.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)

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

function Dex.sync(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	player:SetAttribute("FoundCount", foundCount(data))
	player:SetAttribute("TotalTypes", CarrotInfo.TotalTypes)
	Remotes.get(Remotes.Names.FoundTypes):FireClient(player, data.FoundTypes)
end

-- Returns (isNewType, foundCount).
function Dex.record(player: Player, carrot: Types.Carrot): (boolean, number)
	local data = Data.get(player)
	if not data then
		return false, 0
	end
	local isNew = not data.FoundTypes[carrot.type]
	data.FoundTypes[carrot.type] = true
	for _, m in carrot.mutations do
		data.FoundStamps[carrot.type .. "|" .. m] = true
	end
	if isNew then
		Dex.sync(player)
	end
	return isNew, foundCount(data)
end

return Dex
