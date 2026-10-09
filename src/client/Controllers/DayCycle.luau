--!strict
-- Day / evening / night / morning (Config/DayCycle). Every client computes the time of day from
-- the server clock, so everyone sees the same sky. A boom party (BoomParty) can take over the
-- sky for a while: it calls DayCycle.setSuspended(true) and hands back with false.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.DayCycle)

local DayCycle = {}

local suspended = false

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Current ClockTime, phase name and darkness (0 day .. 1 night).
function DayCycle.now(): (number, string, number)
	return Config.at(workspace:GetServerTimeNow())
end

function DayCycle.darkness(): number
	local _, _, dark = DayCycle.now()
	return dark
end

function DayCycle.setSuspended(on: boolean)
	suspended = on
end

function DayCycle.start()
	local dayAmbient, nightAmbient = rgb(Config.DayAmbient), rgb(Config.NightAmbient)
	local dayOutdoor, nightOutdoor = rgb(Config.DayOutdoorAmbient), rgb(Config.NightOutdoorAmbient)
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local clock, _, dark = DayCycle.now()
		if not suspended then
			Lighting.ClockTime = clock
		end
		Lighting.Brightness = Config.DayBrightness + (Config.NightBrightness - Config.DayBrightness) * dark
		Lighting.Ambient = dayAmbient:Lerp(nightAmbient, dark)
		Lighting.OutdoorAmbient = dayOutdoor:Lerp(nightOutdoor, dark)
	end)
end

return DayCycle
