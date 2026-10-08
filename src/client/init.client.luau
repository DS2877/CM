--!strict
-- Carrot Market client entry point. Waits for the server to load the player's data, then
-- starts the controllers. The client only renders and sends intents.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Controllers = script.Controllers

local HUD = require(Controllers.HUD)
local Shop = require(Controllers.Shop)
local Plot = require(Controllers.Plot)
local HarvestFX = require(Controllers.HarvestFX)

-- Plots and effects can render before data is loaded.
Plot.start()

local waited = 0
while player:GetAttribute("Loaded") ~= true and waited < 60 do
	waited += task.wait(0.1)
end

HUD.start()
Shop.start()
HarvestFX.start()
