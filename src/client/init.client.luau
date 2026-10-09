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
local Guide = require(Controllers.Guide)
local Tutorial = require(Controllers.Tutorial)
local Titles = require(Controllers.Titles)
local Ambience = require(Controllers.Ambience)
local Store = require(Controllers.Store)
local Broadcast = require(Controllers.Broadcast)
local AdminPanel = require(Controllers.AdminPanel)
local Plot = require(Controllers.Plot)
local HarvestFX = require(Controllers.HarvestFX)
local FarmLevel = require(Controllers.FarmLevel)
local MegaBunny = require(Controllers.MegaBunny)

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
Guide.start()
Tutorial.start()
Titles.start()
Ambience.start()
Store.start()
Broadcast.start()
AdminPanel.start()
FarmLevel.start()
MegaBunny.start()

-- First view after (re)spawning on your farm: look down over the plots from behind and above,
-- not at the back of the gate sign. The server moves you onto your spawn pad; once you're
-- there, tilt the camera once (the normal camera takes over from that angle).
local function framePlots(character: Model)
	local rootInst = character:WaitForChild("HumanoidRootPart", 10)
	if not rootInst or not rootInst:IsA("BasePart") then
		return
	end
	local root = rootInst :: BasePart
	local farms = workspace:FindFirstChild("Farms")
	local farm = farms and farms:FindFirstChild("Farm_" .. tostring(player:GetAttribute("FarmId")))
	local groundInst = farm and farm:FindFirstChild("FarmGround")
	if not groundInst or not groundInst:IsA("BasePart") then
		return
	end
	local ground = groundInst :: BasePart
	-- Wait (briefly) until the server has put us on the farm
	local waitedFor = 0
	while (root.Position - ground.Position).Magnitude > 60 and waitedFor < 3 do
		waitedFor += task.wait(0.1)
	end
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local flat = Vector3.new(ground.Position.X - root.Position.X, 0, ground.Position.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		return
	end
	local forward = flat.Unit
	-- High enough to look over the gate beam behind you (it's ~14 studs up)
	local eye = root.Position - forward * 6 + Vector3.new(0, 16, 0)
	camera.CFrame = CFrame.lookAt(eye, root.Position + forward * 10)
end
player.CharacterAdded:Connect(function(character)
	task.spawn(framePlots, character)
end)
if player.Character then
	task.spawn(framePlots, player.Character)
end

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
