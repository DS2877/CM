--!strict
-- Upgrade purchases. Costs come from Config/Upgrades via shared Progression math.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Upgrades = require(Config.Upgrades)
local EconomyConfig = require(Config.Economy)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Upgrade = {}

local trackById: { [string]: Upgrades.UpgradeDef } = {}
for _, t in Upgrades do
	trackById[t.id] = t
end

function Upgrade.track(id: string): Upgrades.UpgradeDef?
	return trackById[id]
end

function Upgrade.level(player: Player, id: string): number
	local data = Data.get(player)
	return if data then data.Upgrades[id] or 0 else 0
end

function Upgrade.sync(player: Player)
	for _, t in Upgrades do
		player:SetAttribute("Upg_" .. t.id, Upgrade.level(player, t.id))
	end
end

function Upgrade.buy(player: Player, id: string): boolean
	local data = Data.get(player)
	local track = trackById[id]
	if not data or not track or not track.enabled then
		return false
	end
	local level = data.Upgrades[id] or 0
	if Progression.isMaxed(track, level) then
		return false
	end
	local cost = Progression.cost(track, level)
	if not Economy.spend(player, cost, "upgrade_" .. id) then
		return false
	end
	data.Upgrades[id] = level + 1
	data.Stats.Upgrades += 1
	Upgrade.sync(player)
	Remotes.get(Remotes.Names.Notice):FireClient(player, {
		text = string.format("%s upgraded to level %d!", track.name, level + 1),
		kind = "good",
	})
	return true
end

function Upgrade.start()
	local limit = EconomyConfig.RateLimits.BuyUpgrade
	local allow = RateLimit.new(limit.rate, limit.burst)
	Remotes.get(Remotes.Names.BuyUpgrade).OnServerEvent:Connect(function(player, raw: unknown)
		if not allow(player) or typeof(raw) ~= "string" then
			return
		end
		local id = raw :: string
		if #id <= 40 then
			Upgrade.buy(player, id)
		end
	end)
end

return Upgrade
