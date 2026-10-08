--!strict
-- Carrot Market client entry point. Waits for the server to load the player's data, then
-- starts the controllers. The client only renders and sends intents.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Controllers = script.Controllers

local HUD = require(Controllers.HUD)
local Shop = require(Controllers.Shop)
local Seeds = require(Controllers.Seeds)
local Dex = require(Controllers.Dex)
local Farms = require(Controllers.Farms)
local MarketBoard = require(Controllers.MarketBoard)
local Music = require(Controllers.Music)
local Daily = require(Controllers.Daily)
local Tutorial = require(Controllers.Tutorial)
local Titles = require(Controllers.Titles)
local Ambience = require(Controllers.Ambience)
local Store = require(Controllers.Store)
local Plot = require(Controllers.Plot)
local HarvestFX = require(Controllers.HarvestFX)

-- Plots, pedestals and effects can render before data is loaded.
Plot.start()
Farms.start()

local waited = 0
while player:GetAttribute("Loaded") ~= true and waited < 60 do
	waited += task.wait(0.1)
end

HUD.start()
Shop.start()
Seeds.start()
Dex.start()
HarvestFX.start()
MarketBoard.start()
Music.start()
Daily.start()
Tutorial.start()
Titles.start()
Ambience.start()
Store.start()

-- Market VIP: the lounge door lets VIPs through (collision changed locally only).
local function vipDoor()
	local door = workspace:FindFirstChild("World")
	door = door and door:FindFirstChild("VipLounge")
	door = door and door:FindFirstChild("VIPDoor")
	if door and door:IsA("BasePart") then
		door.CanCollide = player:GetAttribute("Pass_MarketVIP") ~= true
	end
end
player:GetAttributeChangedSignal("Pass_MarketVIP"):Connect(vipDoor)
vipDoor()
