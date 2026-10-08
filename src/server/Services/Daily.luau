--!strict
-- Daily rewards and quests (Config/Daily, math in shared DailyPlan). Everything is decided here;
-- the client sends "claim the calendar" / "claim quest i" and gets the state back (DailySync).
--
-- Progress hooks: Daily.progress(player, kind, amount) is called by Farm (plant, harvest, rare,
-- mutation, water), Economy sales (sell, market, boom) and Upgrade purchases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local DailyConfig = require(Config.Daily)
local EconomyConfig = require(Config.Economy)
local SeedsConfig = require(Config.Seeds)
local DailyPlan = require(Shared.DailyPlan)
local Remotes = require(Shared.Remotes)
local Data = require(script.Parent.Data)
local Seeds = require(script.Parent.Seeds)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Daily = {}

export type QuestView = { text: string, target: number, progress: number, done: boolean, claimed: boolean }
export type DailyState = {
	canClaim: boolean,
	slot: number, -- calendar slot that the next claim gives (1..7)
	claims: number,
	quests: { QuestView },
	allBonusClaimed: boolean,
	secondsToReset: number,
}

-- Injected by init (Product depends on Farm, so Daily can't require Product directly).
local grantBoost: ((player: Player, boostId: string, seconds: number) -> ())? = nil
function Daily.setBoostGranter(fn: (player: Player, boostId: string, seconds: number) -> ())
	grantBoost = fn
end

local seedNames: { [string]: string } = {}
for _, s in SeedsConfig do
	seedNames[s.id] = s.name
end

local function today(): number
	return DailyPlan.day(os.time())
end

local function questDefs(day: number): { DailyConfig.QuestDef }
	local out = {}
	for _, i in DailyPlan.questsFor(day, #DailyConfig.QuestPool, DailyConfig.QuestsPerDay) do
		table.insert(out, DailyConfig.QuestPool[i])
	end
	return out
end

-- Roll the player's quest record over to today if needed.
local function current(data: Data.PlayerData): Data.DailyData
	local d = data.Daily
	local day = today()
	if d.QuestDay ~= day then
		d.QuestDay = day
		d.Progress = {}
		d.Claimed = {}
		d.AllClaimed = false
		for i = 1, DailyConfig.QuestsPerDay do
			d.Progress[i] = 0
			d.Claimed[i] = false
		end
	end
	return d
end

local function describe(seeds: { [string]: number }): string
	local parts = {}
	for id, n in seeds do
		table.insert(parts, string.format("%d %s%s", n, seedNames[id] or id, if n == 1 then "" else "s"))
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

local function grantSeeds(player: Player, seeds: { [string]: number }?)
	for id, n in seeds or {} do
		Seeds.grant(player, id, n)
	end
end

function Daily.state(player: Player): DailyState?
	local data = Data.get(player)
	if not data then
		return nil
	end
	local d = current(data)
	local quests: { QuestView } = {}
	for i, q in questDefs(d.QuestDay) do
		local progress = math.min(d.Progress[i] or 0, q.target)
		table.insert(quests, {
			text = string.format(q.text, q.target),
			target = q.target,
			progress = progress,
			done = progress >= q.target,
			claimed = d.Claimed[i] == true,
		})
	end
	return {
		canClaim = DailyPlan.canClaim(d.LastClaim, today()),
		slot = DailyPlan.calendarSlot(d.Claims, #DailyConfig.Calendar),
		claims = d.Claims,
		quests = quests,
		allBonusClaimed = d.AllClaimed,
		secondsToReset = (today() + 1) * 86400 - os.time(),
	}
end

function Daily.sync(player: Player)
	local s = Daily.state(player)
	if s then
		Remotes.get(Remotes.Names.DailySync):FireClient(player, s)
		local ready = s.canClaim
		for _, q in s.quests do
			ready = ready or (q.done and not q.claimed)
		end
		player:SetAttribute("DailyReady", ready)
	end
end

local function notice(player: Player, text: string)
	Remotes.get(Remotes.Names.Notice):FireClient(player, { text = text, kind = "good" })
end

function Daily.claimCalendar(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local d = current(data)
	if not DailyPlan.canClaim(d.LastClaim, today()) then
		return
	end
	local slot = DailyPlan.calendarSlot(d.Claims, #DailyConfig.Calendar)
	local reward = DailyConfig.Calendar[slot]
	d.LastClaim = today()
	d.Claims += 1
	grantSeeds(player, reward.seeds)
	if reward.boost and reward.boostSeconds and grantBoost then
		grantBoost(player, reward.boost, reward.boostSeconds)
	end
	notice(player, string.format("Day %d reward: %s %s", slot, reward.emoji, reward.label))
	Daily.sync(player)
end

function Daily.claimQuest(player: Player, index: number)
	local data = Data.get(player)
	if not data then
		return
	end
	local d = current(data)
	local q = questDefs(d.QuestDay)[index]
	if not q or d.Claimed[index] or (d.Progress[index] or 0) < q.target then
		return
	end
	d.Claimed[index] = true
	grantSeeds(player, q.reward)
	notice(player, string.format("Quest done! +%s", describe(q.reward)))
	-- All three done: the daily bonus
	local all = true
	for i = 1, DailyConfig.QuestsPerDay do
		all = all and d.Claimed[i] == true
	end
	if all and not d.AllClaimed then
		d.AllClaimed = true
		grantSeeds(player, DailyConfig.AllQuestsBonus)
		notice(player, string.format("All quests done! Bonus: %s 🎉", describe(DailyConfig.AllQuestsBonus)))
	end
	Daily.sync(player)
end

-- Count progress for every active quest of this kind.
function Daily.progress(player: Player, kind: string, amount: number?)
	local data = Data.get(player)
	if not data then
		return
	end
	local d = current(data)
	local changed = false
	for i, q in questDefs(d.QuestDay) do
		if q.kind == kind and not d.Claimed[i] then
			local before = d.Progress[i] or 0
			if before < q.target then
				d.Progress[i] = math.min(q.target, before + (amount or 1))
				changed = true
				if d.Progress[i] >= q.target then
					notice(
						player,
						string.format(
							"Quest complete: %s – claim it in Daily! ✅",
							string.format(q.text, q.target)
						)
					)
				end
			end
		end
	end
	if changed then
		Daily.sync(player)
	end
end

function Daily.onPlayerReady(player: Player)
	Daily.sync(player)
end

function Daily.start()
	local limit = EconomyConfig.RateLimits.DailyClaim
	local allow = RateLimit.new(limit.rate, limit.burst)
	Remotes.get(Remotes.Names.ClaimDaily).OnServerEvent:Connect(function(player)
		if allow(player) then
			Daily.claimCalendar(player)
		end
	end)
	Remotes.get(Remotes.Names.ClaimQuest).OnServerEvent:Connect(function(player, raw: unknown)
		if allow(player) and typeof(raw) == "number" and raw == raw and raw % 1 == 0 then
			Daily.claimQuest(player, raw :: number)
		end
	end)
	-- Midnight UTC: everyone online gets fresh quests and a claimable calendar day
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(30)
			if today() ~= lastDay then
				lastDay = today()
				for _, player in game:GetService("Players"):GetPlayers() do
					Daily.sync(player)
				end
			end
		end
	end)
end

return Daily
