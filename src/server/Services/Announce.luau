--!strict
-- Announcements in three levels (design doc §6):
--   1 = toast to the finder (Epic), 2 = whole server (Legendary), 3 = whole server + all servers (Mythic, Secret).
-- Cross-server (MessagingService) arrives in phase 3; until then level 3 behaves like level 2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Announce = {}

function Announce.harvest(player: Player, carrot: Types.Carrot, value: number)
	local rarity = CarrotInfo.rarityOfType(carrot.type)
	local scope = rarity.announce
	-- A mutation on a Rare or better is worth a personal toast too.
	if scope == 0 and #carrot.mutations > 0 and rarity.order >= 3 then
		scope = 1
	end
	if scope == 0 then
		return
	end
	local msg: Types.Announcement = {
		playerName = player.DisplayName,
		userId = player.UserId,
		type = carrot.type,
		size = carrot.size,
		mutations = carrot.mutations,
		rarity = rarity.id,
		value = value,
		scope = scope,
	}
	local remote = Remotes.get(Remotes.Names.Announce)
	if scope == 1 then
		remote:FireClient(player, msg)
	else
		remote:FireAllClients(msg)
	end
end

return Announce
