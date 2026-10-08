--!strict
-- Upgrade purchases and their effects. Costs and effects come from Config/Upgrades via the
-- shared Progression math, so the client previews exactly what the server charges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Upgrades = require(Config.Upgrades)
local EconomyConfig = require(Config.Economy)
local Mutations = require(Config.Mutations)
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

local purchasedCallbacks: { (player: Player, trackId: string, level: number) -> () } = {}

function Upgrade.track(id: string): Upgrades.UpgradeDef
	local t = trackById[id]
	assert(t, "Unknown upgrade track " .. id)
	return t
end

function Upgrade.level(player: Player, id: string): number
	local data = Data.get(player)
	return if data then data.Upgrades[id] or 0 else 0
end

-- Effects ------------------------------------------------------------------

function Upgrade.luck(player: Player): number
	return Progression.multiplier(Upgrade.track("Luck"), Upgrade.level(player, "Luck"))
end

function Upgrade.mutationLuck(player: Player): number
	return Progression.mutationLuck(Upgrade.luck(player), Mutations.LuckFactor)
end

function Upgrade.valueBonus(player: Player): number
	return Progression.bonus(Upgrade.track("Value"), Upgrade.level(player, "Value"))
end

function Upgrade.sizeLuck(player: Player): number
	return Progression.multiplier(Upgrade.track("HarvestPower"), Upgrade.level(player, "HarvestPower"))
end

function Upgrade.plots(player: Player): number
	local n = Progression.plots(
		Upgrade.track("FarmSize"),
		Upgrade.level(player, "FarmSize"),
		EconomyConfig.StartingPlots
	)
	return math.clamp(n, 1, EconomyConfig.MaxPlots)
end

-- Purchases ----------------------------------------------------------------

function Upgrade.onPurchased(callback: (player: Player, trackId: string, level: number) -> ())
	table.insert(purchasedCallbacks, callback)
end

function Upgrade.sync(player: Player)
	for _, t in Upgrades do
		player:SetAttribute("Upg_" .. t.id, Upgrade.level(player, t.id))
	end
	player:SetAttribute("Plots", Upgrade.plots(player))
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
	-- Value changes what the basket is worth
	Economy.sync(player)
	Upgrade.sync(player)
	local text = string.format("%s upgraded to level %d!", track.name, level + 1)
	if id == "FarmSize" then
		text = string.format("Your farm grew to %d plots!", Upgrade.plots(player))
	end
	Remotes.get(Remotes.Names.Notice):FireClient(player, { text = text, kind = "good" })
	for _, cb in purchasedCallbacks do
		task.spawn(cb, player, id, level + 1)
	end
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
