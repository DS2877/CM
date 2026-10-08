--!strict
-- Analytics via Roblox AnalyticsService (design doc §10) – no custom system.
--   Onboarding funnel: join → first plant → harvest → sell → upgrade → first Rare → first
--   mutation → opened CarrotDex (each step logged once per player, remembered in the profile).
--   Economy: cash in per source, cash out per sink.
--   Custom: rarity/mutation distribution (Rare+ only, to keep volume sane), offer views/clicks.
-- Every call is wrapped in pcall: analytics must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")

local Data = require(script.Parent.Data)

local Telemetry = {}

local FUNNEL = {
	"Join",
	"FirstPlant",
	"FirstHarvest",
	"FirstSell",
	"FirstUpgrade",
	"FirstRare",
	"FirstMutation",
	"OpenedDex",
}

local function fields(values: { string }?): { [string]: string }?
	if not values then
		return nil
	end
	local keys = {
		Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
		Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
		Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
	}
	local out = {}
	for i, v in values do
		if keys[i] then
			out[keys[i]] = v
		end
	end
	return out
end

function Telemetry.funnel(player: Player, step: string)
	local data = Data.get(player)
	local index = table.find(FUNNEL, step)
	if not data or not index or data.Funnel[step] then
		return
	end
	data.Funnel[step] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, step)
	end)
end

-- Cash earned. `source`: "sell", "sell_market", "harvest_autosell", ...
function Telemetry.source(player: Player, amount: number, source: string)
	local data = Data.get(player)
	if not data or amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Cash",
			amount,
			data.Cash,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			source
		)
	end)
end

-- Cash spent. `sink`: "upgrade_Luck", "seed_Rare", ...
function Telemetry.sink(player: Player, amount: number, sink: string)
	local data = Data.get(player)
	if not data or amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Cash",
			amount,
			data.Cash,
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			sink
		)
	end)
end

function Telemetry.event(player: Player, name: string, value: number?, values: { string }?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields(values))
	end)
end

return Telemetry
