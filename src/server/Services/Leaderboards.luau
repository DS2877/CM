--!strict
-- Leaderboards on boards around the plaza (design doc §6): best carrot this week (resets every
-- Monday 00:00 UTC so new players can place), biggest single sale, CarrotDex progress.
-- OrderedDataStore writes are batched and only ever raise a score. Names are cached.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local EconomyConfig = require(Config.Economy)
local SocialConfig = require(Config.Social)
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Leaderboards = {}

local WEEK = 7 * 86400
local MONDAY_OFFSET = 4 * 86400 -- the unix epoch was a Thursday

local pending: { [string]: { [number]: number } } = {} -- board id -> userId -> score
local names: { [number]: string } = {}

local function week(): number
	return math.floor((os.time() - MONDAY_OFFSET) / WEEK)
end

local function storeName(id: string): string
	local name = EconomyConfig.DataStoreName .. "_LB_" .. id
	if id == "WeeklyBest" then
		name ..= "_W" .. week()
	end
	return name
end

local function store(id: string): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName(id))
	end)
	return if ok then result else nil
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and typeof(result) == "string" then result else "Player"
	names[userId] = name
	return name
end

local function formatScore(id: string, score: number): string
	if id == "Dex" then
		return string.format("%d/%d", score, CarrotInfo.TotalTypes)
	end
	return Format.cash(score)
end

-- Report a score; only raises. Flushed in batches.
function Leaderboards.report(player: Player, id: string, score: number)
	if score <= 0 then
		return
	end
	local board = pending[id]
	if not board then
		board = {}
		pending[id] = board
	end
	assert(board, "board")
	local current = board[player.UserId]
	if not current or score > current then
		board[player.UserId] = math.floor(score)
	end
end

local function flush()
	local batch = pending
	pending = {}
	for id, scores in batch do
		local s = store(id)
		if s then
			for userId, score in scores do
				pcall(function()
					s:UpdateAsync(tostring(userId), function(old: any): any
						if typeof(old) == "number" and old >= score then
							return nil
						end
						return score
					end)
				end)
			end
		end
	end
end

local function refresh(board: WorldBuilder.LeaderboardBuild)
	local s = store(board.id)
	if not s then
		return
	end
	local ok, pages = pcall(function()
		return s:GetSortedAsync(false, SocialConfig.LeaderboardSize)
	end)
	if not ok or not pages then
		return
	end
	local entries = pages:GetCurrentPage()
	for i, row in board.rows do
		local entry = entries[i]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.name.Text = nameOf(userId)
			row.value.Text = formatScore(board.id, entry.value)
		else
			row.name.Text = "—"
			row.value.Text = ""
		end
	end
end

function Leaderboards.start(boards: { WorldBuilder.LeaderboardBuild })
	for _, board in boards do
		for _, row in board.rows do
			row.name.Text = "—"
		end
	end
	task.spawn(function()
		while true do
			for _, board in boards do
				refresh(board)
			end
			task.wait(SocialConfig.LeaderboardRefresh)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SocialConfig.LeaderboardFlush)
			flush()
		end
	end)
	game:BindToClose(flush)
end

return Leaderboards
