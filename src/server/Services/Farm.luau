--!strict
-- Farms and plots. Assigns a farm on join, plants (rolls happen here), tracks growth, reveals
-- the carrot when ready and handles harvesting. Plot state is replicated to every client through
-- attributes on the plot part; clients only render it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local Mutations = require(Config.Mutations)
local Upgrades = require(Config.Upgrades)
local CarrotInfo = require(Shared.CarrotInfo)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Roller = require(Shared.Roller)
local Types = require(Shared.Types)

local Data = require(script.Parent.Data)
local Roll = require(script.Parent.Roll)
local Economy = require(script.Parent.Economy)
local Upgrade = require(script.Parent.Upgrade)
local Dex = require(script.Parent.Dex)
local Announce = require(script.Parent.Announce)
local WorldBuilder = require(script.Parent.WorldBuilder)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

type PlotRuntime = {
	index: number,
	part: BasePart,
	state: Types.PlotState,
	plantedAt: number,
	growTime: number,
	roll: Roller.RollResult?,
}

type FarmRuntime = {
	build: WorldBuilder.FarmBuild,
	owner: Player?,
	plots: { PlotRuntime },
}

local Farm = {}

local farms: { FarmRuntime } = {}
local farmOf: { [Player]: FarmRuntime } = {}

local growthTrack: Upgrades.UpgradeDef = Upgrades[1]
for _, t in Upgrades do
	if t.id == "GrowthSpeed" then
		growthTrack = t
	end
end

local pityOrder = CarrotInfo.rarityOrder(EconomyConfig.PityRarity)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setVisible(plot: BasePart, visible: boolean)
	local t = if visible then 0 else 1
	plot.Transparency = t
	plot.CanCollide = visible
	plot.CanQuery = visible
	for _, child in plot:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = t
			child.CanCollide = visible
		end
	end
end

local function clearPlot(plot: PlotRuntime)
	plot.state = "Empty"
	plot.plantedAt = 0
	plot.growTime = 0
	plot.roll = nil
	local p = plot.part
	p:SetAttribute("State", "Empty")
	p:SetAttribute("PlantedAt", 0)
	p:SetAttribute("GrowTime", 0)
	p:SetAttribute("RevealTier", 0)
	p:SetAttribute("Type", "")
	p:SetAttribute("Size", "")
	p:SetAttribute("Mutations", "")
	p:SetAttribute("Rarity", "")
end

local function revealTier(roll: Roller.RollResult): number
	local rarity = CarrotInfo.rarity(roll.rarity)
	local tier = if rarity then rarity.revealTier else 0
	if #roll.mutations > 0 then
		tier = math.max(tier, 1)
	end
	return tier
end

function Farm.unlockedPlots(player: Player): number
	local data = Data.get(player)
	local n = if data then data.Plots else EconomyConfig.StartingPlots
	return math.clamp(n, 1, EconomyConfig.MaxPlots)
end

function Farm.growTimeFor(player: Player, plotIndex: number): number
	local level = Upgrade.level(player, growthTrack.id)
	local factor = EconomyConfig.PlotGrowFactors[plotIndex] or 1
	return Progression.growTime(
		EconomyConfig.BaseGrowTime,
		EconomyConfig.MinGrowTime,
		growthTrack,
		level,
		factor
	)
end

local function plant(player: Player, plot: PlotRuntime)
	local maybeData = Data.get(player)
	if not maybeData then
		return
	end
	local data: Data.PlayerData = maybeData

	local ctx: Roller.RollContext = {}
	if data.Pity + 1 >= EconomyConfig.PityLegendary then
		ctx.minRarityOrder = pityOrder
	end
	data.Stats.Plantings += 1
	if not data.FirstMutationGiven and data.Stats.Plantings >= Mutations.GuaranteedFirstAtPlanting then
		ctx.forceMutation = Mutations.GuaranteedFirstId
	end

	local roll = Roll.carrot(ctx)
	if CarrotInfo.rarityOrder(roll.rarity) >= pityOrder then
		data.Pity = 0
	else
		data.Pity += 1
	end
	if #roll.mutations > 0 then
		data.FirstMutationGiven = true
	end

	local jitter = 1 + (Roll.number() * 2 - 1) * EconomyConfig.GrowJitter
	local growTime = math.max(EconomyConfig.MinGrowTime, Farm.growTimeFor(player, plot.index) * jitter)

	plot.state = "Growing"
	plot.plantedAt = now()
	plot.growTime = growTime
	plot.roll = roll

	local p = plot.part
	p:SetAttribute("Type", "")
	p:SetAttribute("Size", "")
	p:SetAttribute("Mutations", "")
	p:SetAttribute("Rarity", "")
	p:SetAttribute("RevealTier", revealTier(roll))
	p:SetAttribute("GrowTime", growTime)
	p:SetAttribute("PlantedAt", plot.plantedAt)
	p:SetAttribute("State", "Growing")
end

local function makeReady(plot: PlotRuntime)
	local maybeRoll = plot.roll
	if not maybeRoll then
		return
	end
	local roll: Roller.RollResult = maybeRoll
	plot.state = "Ready"
	local p = plot.part
	p:SetAttribute("Type", roll.type)
	p:SetAttribute("Size", roll.size)
	p:SetAttribute("Mutations", table.concat(roll.mutations, "+"))
	p:SetAttribute("Rarity", roll.rarity)
	p:SetAttribute("State", "Ready")
end

local function harvest(player: Player, plot: PlotRuntime)
	local maybeData, maybeRoll = Data.get(player), plot.roll
	if not maybeData or not maybeRoll then
		return
	end
	local data: Data.PlayerData, roll: Roller.RollResult = maybeData, maybeRoll
	if plot.state ~= "Ready" then
		makeReady(plot)
	end

	local carrot: Types.Carrot = { type = roll.type, size = roll.size, mutations = roll.mutations }
	local value, autoSold = Economy.addCarrot(player, carrot)
	local isNew, found = Dex.record(player, carrot)
	data.Stats.Harvests += 1

	local result: Types.HarvestResult = {
		plot = plot.index,
		type = carrot.type,
		size = carrot.size,
		mutations = carrot.mutations,
		rarity = roll.rarity,
		value = value,
		isNewType = isNew,
		autoSold = autoSold,
		found = found,
		totalTypes = CarrotInfo.TotalTypes,
	}
	Remotes.get(Remotes.Names.HarvestResult):FireClient(player, result)
	Announce.harvest(player, carrot, value)

	clearPlot(plot)
	if EconomyConfig.AutoReplant then
		plant(player, plot)
	end
end

local function onPlotAction(player: Player, index: number)
	local farm = farmOf[player]
	if not farm or index < 1 or index > Farm.unlockedPlots(player) then
		return
	end
	local plot = farm.plots[index]
	if not plot then
		return
	end
	if plot.state == "Empty" then
		plant(player, plot)
		return
	end
	-- Tolerance: the client may see it finish a moment before the server tick does.
	local ready = plot.state == "Ready"
		or now() >= plot.plantedAt + plot.growTime - EconomyConfig.HarvestTolerance
	if ready then
		harvest(player, plot)
	end
end

local function pivotCharacter(player: Player, farm: FarmRuntime)
	local character = player.Character
	if not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and farmOf[player] == farm then
		character:PivotTo(farm.build.spawnCFrame)
	end
end

local function applyUnlocked(farm: FarmRuntime, count: number)
	for i, plot in farm.plots do
		local unlocked = i <= count
		setVisible(plot.part, unlocked)
		plot.part:SetAttribute("Unlocked", unlocked)
		if not unlocked then
			clearPlot(plot)
		end
	end
end

function Farm.onPlayerReady(player: Player)
	local found: FarmRuntime? = nil
	for _, f in farms do
		if f.owner == nil then
			found = f
			break
		end
	end
	if not found then
		Remotes.get(Remotes.Names.Notice):FireClient(player, {
			text = "All farms are taken in this server. Try another server!",
			kind = "bad",
		})
		return
	end
	local farm: FarmRuntime = found

	farm.owner = player
	farmOf[player] = farm
	local model = farm.build.model
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	farm.build.signTitle.Text = player.DisplayName .. "'s Farm"
	farm.build.signSubtitle.Text = "@" .. player.Name
	applyUnlocked(farm, Farm.unlockedPlots(player))
	player:SetAttribute("FarmId", farm.build.id)

	player.CharacterAdded:Connect(function()
		task.defer(pivotCharacter, player, farm)
	end)
	task.spawn(pivotCharacter, player, farm)
end

function Farm.release(player: Player)
	local farm = farmOf[player]
	if not farm then
		return
	end
	farmOf[player] = nil
	farm.owner = nil
	local model = farm.build.model
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	farm.build.signTitle.Text = "Free Farm"
	farm.build.signSubtitle.Text = ""
	applyUnlocked(farm, 0)
end

function Farm.start(world: WorldBuilder.WorldBuild)
	for _, build in world.farms do
		local runtime: FarmRuntime = { build = build, owner = nil, plots = {} }
		for i, part in build.plots do
			runtime.plots[i] = {
				index = i,
				part = part,
				state = "Empty",
				plantedAt = 0,
				growTime = 0,
				roll = nil,
			}
			setVisible(part, false)
		end
		table.insert(farms, runtime)
	end

	local limit = EconomyConfig.RateLimits.PlotAction
	local allow = RateLimit.new(limit.rate, limit.burst)
	Remotes.get(Remotes.Names.PlotAction).OnServerEvent:Connect(function(player, raw: unknown)
		if not allow(player) or typeof(raw) ~= "number" then
			return
		end
		local index = raw :: number
		if index ~= index or index % 1 ~= 0 then
			return
		end
		onPlotAction(player, index)
	end)

	-- Growth tick: reveal plots whose time is up.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local t = now()
		for _, farm in farms do
			if farm.owner then
				for _, plot in farm.plots do
					if plot.state == "Growing" and t >= plot.plantedAt + plot.growTime then
						makeReady(plot)
					end
				end
			end
		end
	end)
end

return Farm
