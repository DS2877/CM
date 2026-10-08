--!strict
-- Announcements in three levels (design doc §6):
--   1 = toast to the finder (Epic), 2 = whole server (Legendary), 3 = whole server + every other
--   server via MessagingService (Mythic, Secret): the strongest proof that it can happen.

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local SocialConfig = require(Shared.Config.Social)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Announce = {}

local MIN_PUBLISH_GAP = 2 -- seconds between cross-server publishes from this server
local lastPublish = 0

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
		otherServer = false,
	}
	local remote = Remotes.get(Remotes.Names.Announce)
	if scope == 1 then
		remote:FireClient(player, msg)
		return
	end
	remote:FireAllClients(msg)
	if scope >= 3 and not RunService:IsStudio() and os.clock() - lastPublish > MIN_PUBLISH_GAP then
		lastPublish = os.clock()
		task.spawn(function()
			local payload = table.clone(msg)
			payload.jobId = game.JobId
			pcall(function()
				MessagingService:PublishAsync(SocialConfig.AnnounceTopic, payload)
			end)
		end)
	end
end

function Announce.start()
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(SocialConfig.AnnounceTopic, function(message)
				local data = message.Data
				if typeof(data) ~= "table" or data.jobId == game.JobId then
					return
				end
				local typeId = data.type
				if typeof(typeId) ~= "string" or not CarrotInfo.type(typeId) then
					return
				end
				local msg: Types.Announcement = {
					playerName = if typeof(data.playerName) == "string" then data.playerName else "Someone",
					userId = 0,
					type = typeId,
					size = if typeof(data.size) == "string" then data.size else "Normal",
					mutations = if typeof(data.mutations) == "table" then data.mutations else {},
					rarity = CarrotInfo.rarityOfType(typeId).id,
					value = if typeof(data.value) == "number" then data.value else 0,
					scope = 3,
					otherServer = true,
				}
				Remotes.get(Remotes.Names.Announce):FireAllClients(msg)
			end)
		end)
	end)
end

return Announce
