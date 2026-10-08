--!strict
-- Soft launch (phase 5, Config/Launch): promo codes, the Roblox group reward and the one-time
-- favorite prompt after a player's first big find. Everything is validated here; the client only
-- sends the code text it typed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local LaunchConfig = require(Config.Launch)
local EconomyConfig = require(Config.Economy)
local SeedsConfig = require(Config.Seeds)
local CarrotInfo = require(Shared.CarrotInfo)
local Remotes = require(Shared.Remotes)
local Data = require(script.Parent.Data)
local Seeds = require(script.Parent.Seeds)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Launch = {}

local seedNames: { [string]: string } = {}
for _, s in SeedsConfig do
	seedNames[s.id] = s.name
end

local function describe(seeds: { [string]: number }): string
	local parts = {}
	for id, n in seeds do
		table.insert(parts, string.format("%d %s%s", n, seedNames[id] or id, if n == 1 then "" else "s"))
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

local function grant(player: Player, seeds: { [string]: number })
	for id, n in seeds do
		Seeds.grant(player, id, n)
	end
end

local function notice(player: Player, text: string, kind: string?)
	Remotes.get(Remotes.Names.Notice):FireClient(player, { text = text, kind = kind })
end

function Launch.redeem(player: Player, raw: string)
	local data = Data.get(player)
	if not data then
		return
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	local def = LaunchConfig.Codes[code]
	if not def or not def.active then
		notice(player, "That code doesn't exist (or has expired)", "bad")
		return
	end
	if data.Codes[code] then
		notice(player, "You already used that code!", "bad")
		return
	end
	data.Codes[code] = true
	grant(player, def.seeds)
	notice(player, string.format("Code redeemed! +%s 🎁", describe(def.seeds)), "good")
end

-- Group reward: checked on join (IsInGroup yields, so it runs in its own thread).
function Launch.onPlayerReady(player: Player)
	local data = Data.get(player)
	if not data or LaunchConfig.GroupId == 0 or data.GroupRewarded then
		return
	end
	task.spawn(function()
		local ok, inGroup = pcall(function()
			return player:IsInGroup(LaunchConfig.GroupId)
		end)
		local fresh = Data.get(player)
		if not fresh or fresh.GroupRewarded then
			return
		end
		if ok and inGroup then
			fresh.GroupRewarded = true
			grant(player, LaunchConfig.GroupReward)
			notice(
				player,
				string.format("Thanks for joining the group! +%s", describe(LaunchConfig.GroupReward)),
				"good"
			)
		else
			task.delay(20, function()
				if player.Parent then
					notice(player, "Join our Roblox group for free Golden Seeds! 🌟")
				end
			end)
		end
	end)
end

-- Called after every harvest: first find at FavoriteAtRarity or better -> one favorite prompt.
function Launch.onHarvest(player: Player, rarityId: string)
	local data = Data.get(player)
	if not data or data.FavoritePrompted then
		return
	end
	if CarrotInfo.rarityOrder(rarityId) < CarrotInfo.rarityOrder(LaunchConfig.FavoriteAtRarity) then
		return
	end
	data.FavoritePrompted = true
	-- Let the big reveal play first
	task.delay(4, function()
		if player.Parent then
			Remotes.get(Remotes.Names.PromptFavorite):FireClient(player)
		end
	end)
end

function Launch.start()
	local limit = EconomyConfig.RateLimits.RedeemCode
	local allow = RateLimit.new(limit.rate, limit.burst)
	Remotes.get(Remotes.Names.RedeemCode).OnServerEvent:Connect(function(player, raw: unknown)
		if allow(player) and typeof(raw) == "string" and #raw > 0 and #raw <= 24 then
			Launch.redeem(player, raw :: string)
		end
	end)
end

return Launch
