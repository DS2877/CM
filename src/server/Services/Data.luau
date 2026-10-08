--!strict
-- Player data with ProfileStore (session locking). Versioned profile with migrations from day one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Config = ReplicatedStorage.Shared.Config
local Economy = require(Config.Economy)

export type Stats = {
	Plantings: number,
	Harvests: number,
	Sold: number,
	TotalEarned: number,
	BestValue: number,
	BiggestSale: number,
	Upgrades: number,
}

-- A plot that was growing when the player left: the carrot is already rolled, so it comes back
-- exactly as promised (including any glow the player saw).
export type SavedPlot = {
	Key: string, -- CarrotInfo.key of the rolled carrot
	Remaining: number, -- seconds it still needed when saved (0 = ready)
	GrowTime: number,
	Seed: string,
}

-- Best carrot ever (shown on the farm pedestal).
export type BestCarrot = { Type: string, Size: string, Mutations: string, Value: number }

export type PlayerData = {
	Version: number,
	Cash: number,
	Plots: number,
	Upgrades: { [string]: number },
	FoundTypes: { [string]: boolean },
	FoundStamps: { [string]: boolean }, -- "type|mutation" (CarrotDex layer 2, phase 2)
	Basket: { [string]: number }, -- carrot key -> count
	Pity: number,
	FirstMutationGiven: boolean,
	Seeds: { [string]: number }, -- seed id -> count (Basic is unlimited, not stored)
	SelectedSeed: string,
	DexClaims: { Types: number, Stamps: number }, -- milestones already rewarded
	LastOnline: number, -- os.time() when last seen, for offline growth
	Growing: { [string]: SavedPlot }, -- plot index (as string) -> what was in the ground
	Best: BestCarrot,
	Likes: number, -- hearts received on your farm
	LikedToday: { Day: number, Users: { [string]: boolean } }, -- farms you liked today
	-- Phase 4: monetization
	Receipts: { string }, -- processed PurchaseIds (newest last, capped) for idempotent receipts
	Boosts: { [string]: number }, -- boost id -> seconds of PLAY time left
	GiftedPasses: { [string]: boolean }, -- passes received as gifts
	Bought: { [string]: boolean }, -- one-time products already bought
	StarterOffered: boolean,
	VipDailyDay: number,
	Funnel: { [string]: boolean }, -- onboarding funnel steps already logged
	MusicOff: boolean, -- player turned music off (🎵 toggle)
	Codes: { [string]: boolean }, -- promo codes already redeemed
	GroupRewarded: boolean,
	FavoritePrompted: boolean,
	Stats: Stats,
}

local TEMPLATE: PlayerData = {
	Version = Economy.ProfileVersion,
	Cash = Economy.StartingCash,
	Plots = Economy.StartingPlots,
	Upgrades = {},
	FoundTypes = {},
	FoundStamps = {},
	Basket = {},
	Pity = 0,
	FirstMutationGiven = false,
	Seeds = {},
	SelectedSeed = "Basic",
	DexClaims = { Types = 0, Stamps = 0 },
	LastOnline = 0,
	Growing = {},
	Best = { Type = "", Size = "", Mutations = "", Value = 0 },
	Likes = 0,
	LikedToday = { Day = 0, Users = {} },
	Receipts = {},
	Boosts = {},
	GiftedPasses = {},
	Bought = {},
	StarterOffered = false,
	VipDailyDay = 0,
	Funnel = {},
	MusicOff = false,
	Codes = {},
	GroupRewarded = false,
	FavoritePrompted = false,
	Stats = {
		Plantings = 0,
		Harvests = 0,
		Sold = 0,
		TotalEarned = 0,
		BestValue = 0,
		BiggestSale = 0,
		Upgrades = 0,
	},
}

-- Migrations: MIGRATIONS[n] upgrades a profile from version n to n + 1.
local MIGRATIONS: { [number]: (data: PlayerData) -> () } = {
	-- v1 -> v2 (phase 2): seeds, Dex rewards and offline growth. New fields come from Reconcile;
	-- old v1 players get no offline basket on their first v2 login.
	[1] = function(data: PlayerData)
		data.LastOnline = 0
	end,
	-- v2 -> v3 (phase 3): pedestal, likes, biggest sale. Filled by Reconcile; nothing to convert.
	[2] = function(_data: PlayerData) end,
	-- v3 -> v4 (phase 4): receipts, boosts, gifts. Filled by Reconcile.
	[3] = function(_data: PlayerData) end,
	-- v4 -> v5: plots are saved when you leave. Offline growth only finishes what was saved, so
	-- profiles from before this start with nothing in the ground (no phantom offline basket).
	[4] = function(data: PlayerData)
		data.Growing = {}
	end,
}

local Data = {}

-- (player, data, message) -> true when the message was handled
local messageHandlers: { (player: Player, data: PlayerData, message: any) -> boolean } = {}

local store = ProfileStore.New(Economy.DataStoreName, TEMPLATE)
local profiles: { [Player]: any } = {}

local function migrate(data: PlayerData)
	local version = data.Version or 0
	while version < Economy.ProfileVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.Version = version
	-- Fill nested defaults that Reconcile may not cover after migrations.
	for key, value in TEMPLATE.Stats :: any do
		if (data.Stats :: any)[key] == nil then
			(data.Stats :: any)[key] = value
		end
	end
end

-- Yields. Returns the data, or nil if the player left or the profile could not be loaded.
function Data.load(player: Player): PlayerData?
	local profile = store:StartSessionAsync(
		"Player_" .. player.UserId,
		{
			Cancel = function()
				return player.Parent ~= Players
			end,
		} :: any
	)
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Could not load your farm. Please rejoin in a moment.")
		end
		return nil
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)

	-- Messages from other servers (gifted passes while this player was elsewhere/offline).
	profile:MessageHandler(function(message: any, processed: () -> ())
		for _, handler in messageHandlers do
			if handler(player, profile.Data, message) then
				processed()
				return
			end
		end
	end)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your farm was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	profiles[player] = profile
	return profile.Data
end

function Data.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Saves now and waits until the DataStore write finished (for purchases). Returns success.
function Data.saveAndWait(player: Player, timeout: number?): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	local done = false
	local conn = profile.OnAfterSave:Connect(function()
		done = true
	end)
	profile:Save()
	local waited = 0
	local limit = timeout or 15
	while not done and waited < limit and profile:IsActive() do
		waited += task.wait(0.1)
	end
	conn:Disconnect()
	return done
end

-- Deliver a message to a player's profile, wherever they are (or next time they join).
function Data.message(userId: number, message: { [string]: any }): boolean
	local ok, result = pcall(function()
		return store:MessageAsync("Player_" .. userId, message)
	end)
	return ok and result == true
end

function Data.onMessage(handler: (player: Player, data: PlayerData, message: any) -> boolean)
	table.insert(messageHandlers, handler)
end

function Data.release(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		profile:EndSession()
	end
end

return Data
