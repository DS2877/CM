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
local Product = require(Services.Product)
local Telemetry = require(Services.Telemetry)

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
Product.start()
Farm.onRareHarvest(Product.onRareHarvest)

-- Saved 🎵 setting (purely cosmetic, but persistent so it's remembered next session)
do
	local RateLimit = require(script.Util.RateLimit)
	local EconomyConfig = require(ReplicatedStorage.Shared.Config.Economy)
	local limit = EconomyConfig.RateLimits.SetMusic
	local allow = RateLimit.new(limit.rate, limit.burst)
	Remotes.get(Remotes.Names.SetMusic).OnServerEvent:Connect(function(player, raw: unknown)
		local data = Data.get(player)
		if data and allow(player) and typeof(raw) == "boolean" then
			data.MusicOff = not raw
			player:SetAttribute("MusicOff", data.MusicOff)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local data = Data.load(player)
	if not data then
		return
	end
	player:SetAttribute("MusicOff", data.MusicOff == true)
	Telemetry.funnel(player, "Join")
	Product.onPlayerReady(player)
	Economy.sync(player)
	Upgrade.sync(player)
	Seeds.sync(player)
	Dex.onPlayerReady(player)
	Farm.onPlayerReady(player)
	player:SetAttribute("Loaded", true)
	-- Put back what the player left growing in the ground
	Offline.restore(player)
end

local function onPlayerRemoving(player: Player)
	Offline.leave(player)
	Farm.release(player)
	Data.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
