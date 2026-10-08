--!strict
-- Carrot Market server entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Services = script.Services

local WorldBuilder = require(Services.WorldBuilder)
local Data = require(Services.Data)
local Economy = require(Services.Economy)
local Upgrade = require(Services.Upgrade)
local Dex = require(Services.Dex)
local Seeds = require(Services.Seeds)
local Farm = require(Services.Farm)
local Offline = require(Services.Offline)
local Buffs = require(Services.Buffs)
local Social = require(Services.Social)
local Announce = require(Services.Announce)
local Leaderboards = require(Services.Leaderboards)

Remotes.setup()
local world = WorldBuilder.build()

Economy.start(world.sellPrompt, world.marketCFrame.Position)
Upgrade.start()
Seeds.start()
Farm.start(world)
Offline.start(function()
	return Players:GetPlayers()
end)
Buffs.start()
Social.start()
Announce.start()
Leaderboards.start(world.leaderboards)
Economy.onSale(function(player, total)
	Leaderboards.report(player, "BiggestSale", total)
end)

local function onPlayerAdded(player: Player)
	local data = Data.load(player)
	if not data then
		return
	end
	local lastOnline = Offline.checkIn(player)
	Economy.sync(player)
	Upgrade.sync(player)
	Seeds.sync(player)
	Dex.onPlayerReady(player)
	Farm.onPlayerReady(player)
	player:SetAttribute("Loaded", true)
	-- Give the client a moment to start its controllers before the offline reveal arrives.
	task.delay(2, function()
		if player.Parent then
			Offline.reveal(player, lastOnline)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	Offline.touch(player)
	Farm.release(player)
	Data.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
