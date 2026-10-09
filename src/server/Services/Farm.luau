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
local Seeds = require(script.Parent.Seeds)
local Buffs = require(script.Parent.Buffs)
local Leaderboards = require(script.Parent.Leaderboards)
local Perks = require(script.Parent.Perks)
local Telemetry = require(script.Parent.Telemetry)
local ProductsConfig = require(Config.Products)
local SocialConfig = require(Config.Social)
local SeedsConfig = require(Config.Seeds)
local Dex = require(script.Parent.Dex)
local Announce = require(script.Parent.Announce)
local Launch = require(script.Parent.Launch)
local Daily = require(script.Parent.Daily)
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

-- Friend bonus (set by the Social service): +10 % luck per friend in the server.
local function friendLuck(player: Player): number
	local v = player:GetAttribute("FriendBoost")
	return 1 + (if typeof(v) == "number" then v else 0)
end

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
			child.CanQuery = visible
			if child.Name == "Rim" then
				child.CanCollide = visible
			end
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
	return Upgrade.plots(player)
end

-- The farm's Legendary board (a physical sign everyone can read). Written only when the count
-- changes – a static board, not a ticking timer.
local function writePityBoard(build: WorldBuilder.FarmBuild, pity: number?)
	local max = EconomyConfig.PityLegendary
	local text = "Free farm"
	local fraction = 0
	if pity then
		local left = math.max(1, max - pity)
		text = if left == 1 then "NEXT PLANT!" else string.format("in %d plants", left)
		fraction = math.clamp(pity / max, 0, 1)
	end
	for _, label in build.pityTexts do
		label.Text = text
	end
	for _, fill in build.pityFills do
		fill.Size = UDim2.fromScale(fraction, 1)
	end
end

function Farm.syncPity(player: Player)
	local data = Data.get(player)
	if data then
		player:SetAttribute("Pity", data.Pity)
		player:SetAttribute("PityMax", EconomyConfig.PityLegendary)
		local farm = farmOf[player]
		if farm then
			writePityBoard(farm.build, data.Pity)
		end
	end
end

-- One server roll for this player with a seed's effect: upgrades, seed, pity and the scripted
-- first mutation all apply. Updates pity/first-mutation bookkeeping. Used for planting and for
-- offline growth.
-- Admin: a specific carrot (rarity/size/mutation; the type is picked within the rarity).
export type CarrotSpec = { rarity: string?, size: string?, mutation: string? }
local forcedRolls: { [Player]: CarrotSpec } = setmetatable({}, { __mode = "k" }) :: any
local CarrotsConfig = require(Config.Carrots)

local function rollFromSpec(spec: CarrotSpec): Roller.RollResult
	local rarity = spec.rarity or "Common"
	if not CarrotInfo.rarity(rarity) then
		rarity = "Common"
	end
	local carrot = Roller.rollType(CarrotsConfig :: any, rarity, Roll.number)
	local size = if spec.size and CarrotInfo.size(spec.size) then spec.size else "Normal"
	local mutation = spec.mutation
	return {
		rarity = rarity,
		type = carrot.id,
		size = size,
		mutations = if mutation and CarrotInfo.mutation(mutation) then { mutation } else {},
	}
end

-- Admin: the player's next planting rolls exactly this.
function Farm.forceNextRoll(player: Player, spec: CarrotSpec)
	forcedRolls[player] = spec
end

function Farm.rollFor(player: Player, seed: SeedsConfig.SeedDef): Roller.RollResult?
	local maybeData = Data.get(player)
	if not maybeData then
		return nil
	end
	local data: Data.PlayerData = maybeData
	local forced = forcedRolls[player]
	if forced then
		forcedRolls[player] = nil
		data.Stats.Plantings += 1
		return rollFromSpec(forced)
	end

	local ctx: Roller.RollContext = {
		luck = Upgrade.luck(player)
			* seed.luck
			* friendLuck(player)
			* Perks.luckBoost(player)
			* Perks.serverLuck(),
		mutationLuck = Upgrade.mutationLuck(player) * seed.mutationLuck,
		sizeLuck = Upgrade.sizeLuck(player),
	}
	local minOrder = 1
	if seed.minRarity then
		minOrder = CarrotInfo.rarityOrder(seed.minRarity)
	end
	if data.Pity + 1 >= EconomyConfig.PityLegendary then
		minOrder = math.max(minOrder, pityOrder)
	end
	if minOrder > 1 then
		ctx.minRarityOrder = minOrder
	end
	data.Stats.Plantings += 1
	if seed.forceMutation then
		ctx.forceMutation = seed.forceMutation
	elseif not data.FirstMutationGiven and data.Stats.Plantings >= Mutations.GuaranteedFirstAtPlanting then
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
	Farm.syncPity(player)
	return roll
end

function Farm.growTimeFor(player: Player, plotIndex: number): number
	local level = Upgrade.level(player, growthTrack.id)
	local factor = EconomyConfig.PlotGrowFactors[plotIndex] or 1
	local t = Progression.growTime(
		EconomyConfig.BaseGrowTime,
		EconomyConfig.MinGrowTime,
		growthTrack,
		level,
		factor
	)
	if Buffs.isActive(player, "Watered") then
		t = math.max(EconomyConfig.MinGrowTime, t / (1 + SocialConfig.WaterGrowthBonus))
	end
	if Perks.hasPass(player, "Growth2x") then
		t = math.max(ProductsConfig.GrowthPassMinTime, t / ProductsConfig.GrowthPassMult)
	end
	return t
end

-- Puts an already-rolled carrot in the ground. `plantedAt` may lie in the past (a plot restored
-- after a rejoin keeps its progress).
local function setGrowing(
	plot: PlotRuntime,
	roll: Roller.RollResult,
	growTime: number,
	plantedAt: number,
	seedId: string
)
	plot.state = "Growing"
	plot.plantedAt = plantedAt
	plot.growTime = growTime
	plot.roll = roll

	local p = plot.part
	p:SetAttribute("Type", "")
	p:SetAttribute("Size", "")
	p:SetAttribute("Mutations", "")
	p:SetAttribute("Rarity", "")
	p:SetAttribute("RevealTier", revealTier(roll))
	p:SetAttribute("Seed", seedId)
	p:SetAttribute("GrowTime", growTime)
	p:SetAttribute("PlantedAt", plantedAt)
	p:SetAttribute("State", "Growing")
end

local function plant(player: Player, plot: PlotRuntime)
	local seed, seedId = Seeds.consume(player)
	local maybeRoll = Farm.rollFor(player, seed)
	if not maybeRoll then
		return
	end
	local jitter = 1 + (Roll.number() * 2 - 1) * EconomyConfig.GrowJitter
	local growTime = math.max(EconomyConfig.MinGrowTime, Farm.growTimeFor(player, plot.index) * jitter)
	setGrowing(plot, maybeRoll, growTime, now(), seedId)
	Telemetry.funnel(player, "FirstPlant")
	Daily.progress(player, "plant")
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

local rareCallbacks: { (player: Player) -> () } = {}

-- Called after a Rare-or-better harvest (the Starter Bundle offer listens to this).
function Farm.onRareHarvest(callback: (player: Player) -> ())
	table.insert(rareCallbacks, callback)
end

local fullNoticeAt: { [Player]: number } = {}

local function harvest(player: Player, plot: PlotRuntime)
	local maybeData, maybeRoll = Data.get(player), plot.roll
	if not maybeData or not maybeRoll then
		return
	end
	-- Full basket: the carrot stays ready on its plot (nothing is lost) until you've sold at the
	-- market. That trip is the loop: farm -> market -> upgrade -> farm.
	if Economy.basketFull(player) then
		local t = os.clock()
		if t - (fullNoticeAt[player] or 0) > 3 then
			fullNoticeAt[player] = t
			Remotes.get(Remotes.Names.Notice):FireClient(player, {
				text = "Basket full! Walk to the market to sell 🧺",
				kind = "bad",
			})
		end
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
	Telemetry.funnel(player, "FirstHarvest")
	local order = CarrotInfo.rarityOrder(roll.rarity)
	if order >= 3 then
		Telemetry.funnel(player, "FirstRare")
		Telemetry.event(player, "RareHarvest", value, { roll.rarity, roll.mutations[1] or "None" })
		for _, cb in rareCallbacks do
			task.spawn(cb, player)
		end
	end
	if #roll.mutations > 0 then
		Telemetry.funnel(player, "FirstMutation")
	end
	Leaderboards.report(player, "WeeklyBest", value)
	Leaderboards.report(player, "Dex", found)
	Announce.harvest(player, carrot, value)
	Launch.onHarvest(player, roll.rarity)
	Daily.progress(player, "harvest")
	if CarrotInfo.rarityOrder(roll.rarity) >= 3 then
		Daily.progress(player, "rare")
	end
	if #roll.mutations > 0 then
		Daily.progress(player, "mutation")
	end

	clearPlot(plot)
	-- Planting is the player's move. The Auto Harvest pass is the convenience upgrade: it harvests
	-- and replants (with the selected seed) while you're in the game.
	if EconomyConfig.AutoReplant or Perks.hasPass(player, "AutoHarvest") then
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

-- Pedestal + sign: best carrot ever and likes, shown to everyone via farm attributes.
local function refreshShowcase(farm: FarmRuntime)
	local model = farm.build.model
	local owner = farm.owner
	local data = owner and Data.get(owner)
	if not owner or not data then
		model:SetAttribute("BestType", "")
		model:SetAttribute("BestSize", "")
		model:SetAttribute("BestMutations", "")
		model:SetAttribute("BestValue", 0)
		model:SetAttribute("Likes", 0)
		farm.build.signSubtitle.Text = ""
		farm.build.likePrompt.Enabled = false
		return
	end
	model:SetAttribute("BestType", data.Best.Type)
	model:SetAttribute("BestSize", data.Best.Size)
	model:SetAttribute("BestMutations", data.Best.Mutations)
	model:SetAttribute("BestValue", data.Best.Value)
	model:SetAttribute("Likes", data.Likes)
	farm.build.signSubtitle.Text = string.format("❤ %d   @%s", data.Likes, owner.Name)
	farm.build.likePrompt.Enabled = true
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function onLike(liker: Player, farm: FarmRuntime)
	local owner = farm.owner
	local likerData, ownerData = Data.get(liker), owner and Data.get(owner)
	if not owner or not likerData or not ownerData then
		return
	end
	local notice = Remotes.get(Remotes.Names.Notice)
	if owner == liker then
		notice:FireClient(liker, { text = "That's your own farm – ask a friend for a like!" })
		return
	end
	if likerData.LikedToday.Day ~= today() then
		likerData.LikedToday = { Day = today(), Users = {} }
	end
	local key = tostring(owner.UserId)
	if likerData.LikedToday.Users[key] then
		notice:FireClient(liker, { text = "You already liked this farm today ❤" })
		return
	end
	likerData.LikedToday.Users[key] = true
	ownerData.Likes += 1
	refreshShowcase(farm)
	notice:FireClient(
		liker,
		{ text = string.format("You liked %s's farm! ❤", owner.DisplayName), kind = "good" }
	)
	notice:FireClient(
		owner,
		{ text = string.format("%s liked your farm! ❤", liker.DisplayName), kind = "good" }
	)
end

-- Water a friend: both get faster growth for a while (once per farm per cooldown).
local waterCooldowns: { [Player]: { [number]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function onWater(player: Player, farmId: number)
	local farm = farms[farmId]
	local owner = farm and farm.owner
	if not farm or not owner or owner == player then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if ((root :: BasePart).Position - farm.build.center.Position).Magnitude > SocialConfig.WaterRange then
		return
	end
	local list = waterCooldowns[player]
	if not list then
		list = {}
		waterCooldowns[player] = list
	end
	assert(list, "cooldown list")
	local last = list[owner.UserId]
	local clock = os.clock()
	local notice = Remotes.get(Remotes.Names.Notice)
	if last and clock - last < SocialConfig.WaterCooldown then
		notice:FireClient(player, {
			text = string.format(
				"You can water again in %ds 💧",
				math.ceil(SocialConfig.WaterCooldown - (clock - last))
			),
		})
		return
	end
	list[owner.UserId] = clock
	Buffs.add(player, "Watered", SocialConfig.WaterSeconds)
	Buffs.add(owner, "Watered", SocialConfig.WaterSeconds)
	local pct = math.floor(SocialConfig.WaterGrowthBonus * 100 + 0.5)
	notice:FireClient(player, {
		text = string.format("You watered %s's farm! +%d%% growth for both 💧", owner.DisplayName, pct),
		kind = "good",
	})
	notice:FireClient(owner, {
		text = string.format("%s watered your farm! +%d%% growth for both 💧", player.DisplayName, pct),
		kind = "good",
	})
	Remotes.get(Remotes.Names.Watered):FireAllClients(farm.build.id, player.DisplayName)
	Daily.progress(player, "water")
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
	Farm.syncPity(player)
	refreshShowcase(farm)

	player.CharacterAdded:Connect(function()
		task.defer(pivotCharacter, player, farm)
	end)
	task.spawn(pivotCharacter, player, farm)
end

-- Admin: put a specific carrot, fully grown, on one of the player's plots right now
-- (the plot whose carrot is least far along, so you see the reveal immediately).
function Farm.spawnCarrot(player: Player, spec: CarrotSpec): boolean
	local farm = farmOf[player]
	if not farm then
		return false
	end
	local target: PlotRuntime? = nil
	for i = 1, Farm.unlockedPlots(player) do
		local plot = farm.plots[i]
		if plot and plot.state ~= "Ready" then
			target = plot
			break
		end
	end
	target = target or farm.plots[1]
	if not target then
		return false
	end
	local plot: PlotRuntime = target
	local roll = rollFromSpec(spec)
	plot.roll = roll
	plot.state = "Growing"
	plot.plantedAt = now() - 0.05
	plot.growTime = 0.05
	local p = plot.part
	p:SetAttribute("RevealTier", revealTier(roll))
	p:SetAttribute("GrowTime", 0.05)
	p:SetAttribute("PlantedAt", plot.plantedAt)
	p:SetAttribute("State", "Growing")
	makeReady(plot)
	return true
end

-- Admin: rebuild a player's farm after an account reset or upgrade change.
function Farm.refresh(player: Player)
	local farm = farmOf[player]
	if not farm then
		return
	end
	for _, plot in farm.plots do
		clearPlot(plot)
	end
	applyUnlocked(farm, Farm.unlockedPlots(player))
	refreshShowcase(farm)
	Farm.syncPity(player)
end

-- Instant Grow (developer product): every growing carrot on the player's farm is ready now.
function Farm.instantGrow(player: Player)
	local farm = farmOf[player]
	if not farm then
		return
	end
	local t = now()
	for _, plot in farm.plots do
		if plot.state == "Growing" then
			plot.growTime = math.max(0, t - plot.plantedAt)
			plot.part:SetAttribute("GrowTime", math.max(0.1, plot.growTime))
			makeReady(plot)
		end
	end
end

-- Saved plots ---------------------------------------------------------------
-- What is in the ground survives leaving: each growing or ready plot is saved with its
-- already-rolled carrot and the time it still needs. Empty plots save nothing, so they never
-- produce anything offline.

-- Current plots of the player's farm, or nil when they have no farm (nothing to save then).
function Farm.snapshot(player: Player): { [string]: Data.SavedPlot }?
	local farm = farmOf[player]
	if not farm then
		return nil
	end
	local saved: { [string]: Data.SavedPlot } = {}
	local t = now()
	for i, plot in farm.plots do
		local roll = plot.roll
		if i <= Farm.unlockedPlots(player) and roll and plot.state ~= "Empty" then
			local carrot: Types.Carrot = { type = roll.type, size = roll.size, mutations = roll.mutations }
			saved[tostring(i)] = {
				Key = CarrotInfo.key(carrot),
				Remaining = math.max(0, plot.plantedAt + plot.growTime - t),
				GrowTime = plot.growTime,
				Seed = tostring(plot.part:GetAttribute("Seed") or "Basic"),
			}
		end
	end
	return saved
end

-- Rebuilds a roll from a saved plot. Nil if the carrot no longer exists in the config.
function Farm.rollFromKey(key: string): Roller.RollResult?
	local carrot = CarrotInfo.fromKey(key)
	if not carrot then
		return nil
	end
	return {
		type = carrot.type,
		size = carrot.size,
		mutations = carrot.mutations,
		rarity = CarrotInfo.rarityOfType(carrot.type).id,
	}
end

-- Puts a saved carrot back in the ground with `remaining` seconds left (0 = ready to harvest).
-- Returns false if the plot is not free (the player already planted it), so the caller can hand
-- the saved carrot over another way instead of overwriting a fresh planting.
function Farm.restorePlot(
	player: Player,
	index: number,
	roll: Roller.RollResult,
	remaining: number,
	growTime: number,
	seedId: string
): boolean
	local farm = farmOf[player]
	local plot = farm and farm.plots[index]
	if not plot or index > Farm.unlockedPlots(player) or plot.state ~= "Empty" then
		return false
	end
	growTime = math.max(EconomyConfig.MinGrowTime, growTime)
	remaining = math.clamp(remaining, 0, growTime)
	setGrowing(plot, roll, growTime, now() - (growTime - remaining), seedId)
	if remaining <= 0 then
		makeReady(plot)
	end
	return true
end

-- Plants a fresh carrot (the player's selected seed) in an empty plot.
function Farm.replant(player: Player, index: number)
	local farm = farmOf[player]
	local plot = farm and farm.plots[index]
	if plot and plot.state == "Empty" and index <= Farm.unlockedPlots(player) then
		plant(player, plot)
	end
end

function Farm.release(player: Player)
	fullNoticeAt[player] = nil
	local farm = farmOf[player]
	if not farm then
		return
	end
	farmOf[player] = nil
	farm.owner = nil
	local model = farm.build.model
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	writePityBoard(farm.build, nil)
	farm.build.signTitle.Text = "Free Farm"
	applyUnlocked(farm, 0)
	refreshShowcase(farm)
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
		writePityBoard(build, nil)
		table.insert(farms, runtime)
	end

	for _, farm in farms do
		farm.build.likePrompt.Triggered:Connect(function(liker)
			onLike(liker, farm)
		end)
	end
	Economy.onNewBest(function(player)
		local farm = farmOf[player]
		if farm then
			refreshShowcase(farm)
		end
	end)
	local waterLimit = EconomyConfig.RateLimits.WaterFarm
	local allowWater = RateLimit.new(waterLimit.rate, waterLimit.burst)
	Remotes.get(Remotes.Names.WaterFarm).OnServerEvent:Connect(function(player, raw: unknown)
		if not allowWater(player) or typeof(raw) ~= "number" then
			return
		end
		local farmId = raw :: number
		if farmId == farmId and farmId % 1 == 0 then
			onWater(player, farmId)
		end
	end)

	-- Farm Size upgrade: open the new plots right away (growing plots are kept).
	Upgrade.onPurchased(function(player, trackId)
		local farm = farmOf[player]
		if farm and trackId == "FarmSize" then
			applyUnlocked(farm, Farm.unlockedPlots(player))
		end
	end)

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
						local owner = farm.owner
						if owner and Perks.hasPass(owner, "AutoHarvest") then
							-- Auto Harvest (only while the owner is in the server): give the
							-- ready pop a moment to show, then harvest.
							task.delay(0.8, function()
								if farm.owner == owner and (plot.state :: string) == "Ready" then
									harvest(owner, plot)
								end
							end)
						end
					end
				end
			end
		end
	end)
end

return Farm
