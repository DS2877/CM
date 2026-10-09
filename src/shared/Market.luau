--!strict
-- Current market state for server and client: the os.time schedule plus any admin override
-- (replicated as workspace attributes by the Admin service).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local EventSchedule = require(script.Parent.EventSchedule)

local Market = {}

local cfg: EventSchedule.EventsConfig = Events :: any

local function attr(name: string): any
	return workspace:GetAttribute(name)
end

function Market.override(): EventSchedule.Override?
	local boomId, boomStart, boomEnd = attr("AdminBoomId"), attr("AdminBoomStart"), attr("AdminBoomEnd")
	local disabled, daily = attr("AdminEventsOff"), attr("AdminDailyRarity")
	if boomId == nil and disabled ~= true and daily == nil then
		return nil
	end
	return {
		boomId = if typeof(boomId) == "string" and boomId ~= "" then boomId else nil,
		boomStart = if typeof(boomStart) == "number" then boomStart else nil,
		boomEnd = if typeof(boomEnd) == "number" then boomEnd else nil,
		disabled = disabled == true,
		dailyRarity = if typeof(daily) == "string" and daily ~= "" then daily else nil,
	}
end

function Market.now(): number
	return if RunService:IsServer() then os.time() else workspace:GetServerTimeNow()
end

function Market.state(): EventSchedule.State
	return EventSchedule.at(Market.now(), cfg, Market.override())
end

return Market
