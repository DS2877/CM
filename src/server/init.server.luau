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
local Farm = require(Services.Farm)

Remotes.setup()
local world = WorldBuilder.build()

Economy.start(world.sellPrompt)
Upgrade.start()
Farm.start(world)

local function onPlayerAdded(player: Player)
	local data = Data.load(player)
	if not data then
		return
	end
	Economy.sync(player)
	Upgrade.sync(player)
	Dex.sync(player)
	Farm.onPlayerReady(player)
	player:SetAttribute("Loaded", true)
end

local function onPlayerRemoving(player: Player)
	Farm.release(player)
	Data.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
