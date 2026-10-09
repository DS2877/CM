--!strict
-- Admin dashboard backend. Only admins (Config/Admin: experience owner, extra user ids, everyone
-- in Studio) may call AdminAction; everything is re-checked here, the client only asks.
--
-- Actions apply to a target player in this server (default: the admin). Event actions and
-- messages can go to "server" (this one) or "all" (every server, via MessagingService).
-- Broadcast messages are filtered with TextService before anyone sees them.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local AdminConfig = require(Config.Admin)
local Events = require(Config.Events)
local Upgrades = require(Config.Upgrades)
local CarrotsConfig = require(Config.Carrots)
local Products = require(Config.Products)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Upgrade = require(script.Parent.Upgrade)
local Seeds = require(script.Parent.Seeds)
local Dex = require(script.Parent.Dex)
local Farm = require(script.Parent.Farm)
local Product = require(script.Parent.Product)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local Admin = {}

local isAdminCache: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function computeAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(AdminConfig.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and typeof(rank) == "number" and rank >= AdminConfig.GroupMinRank
end

function Admin.isAdmin(player: Player): boolean
	local cached = isAdminCache[player]
	if cached == nil then
		cached = computeAdmin(player)
		isAdminCache[player] = cached
	end
	return cached == true
end

local function notice(player: Player, text: string, kind: string?)
	Remotes.get(Remotes.Names.Notice):FireClient(player, { text = text, kind = kind or "good" })
end

-- Cross-server ------------------------------------------------------------

local function applyGlobal(message: { [string]: any })
	local kind = message.kind
	if kind == "message" then
		Remotes.get(Remotes.Names.AdminMessage):FireAllClients({
			text = message.text,
			userId = message.userId,
			name = message.name,
		})
	elseif kind == "boom" then
		workspace:SetAttribute("AdminBoomId", message.boomId)
		workspace:SetAttribute("AdminBoomStart", message.boomStart)
		workspace:SetAttribute("AdminBoomEnd", message.boomEnd)
	elseif kind == "boomEnd" then
		workspace:SetAttribute("AdminBoomId", nil)
		workspace:SetAttribute("AdminBoomStart", nil)
		workspace:SetAttribute("AdminBoomEnd", nil)
	elseif kind == "events" then
		workspace:SetAttribute("AdminEventsOff", if message.off then true else nil)
	elseif kind == "daily" then
		workspace:SetAttribute("AdminDailyRarity", message.rarity)
	elseif kind == "serverLuck" then
		Product.serverLuck(tostring(message.name), message.mult, message.seconds)
	end
	-- Prices depend on events: resync every basket.
	for _, p in Players:GetPlayers() do
		Economy.sync(p)
	end
end

local function broadcast(message: { [string]: any }, scope: string)
	applyGlobal(message)
	if scope ~= "all" or RunService:IsStudio() then
		return
	end
	local payload = table.clone(message)
	payload.jobId = game.JobId
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(AdminConfig.Topic, payload)
		end)
		if not ok then
			warn("Admin broadcast failed:", err)
		end
	end)
end

local function filter(text: string, fromUserId: number): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, fromUserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and typeof(result) == "string" then result else nil
end

-- Actions -------------------------------------------------------------------

local function str(v: any, max: number?): string?
	if typeof(v) ~= "string" then
		return nil
	end
	return string.sub(v, 1, max or 60)
end

local function num(v: any): number?
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return nil
	end
	return v
end

local trackIds: { [string]: boolean } = {}
for _, t in Upgrades do
	trackIds[t.id] = true
end

local function resync(player: Player)
	Economy.sync(player)
	Upgrade.sync(player)
	Seeds.sync(player)
	Dex.sync(player)
	Product.syncBoosts(player)
	Farm.syncPity(player)
end

local function resetAccount(admin: Player, target: Player)
	-- Empty the farm first: otherwise the offline save ("what's in the ground") would write the
	-- old carrots back into the fresh profile when the player leaves.
	Farm.refresh(target)
	if not Data.reset(target) then
		return
	end
	-- Clear replicated state that the fresh profile no longer has.
	for name in target:GetAttributes() do
		if
			string.sub(name, 1, 4) == "Off_"
			or string.sub(name, 1, 5) == "Pass_"
			or string.sub(name, 1, 6) == "Boost_"
			or string.sub(name, 1, 7) == "Bought_"
		then
			target:SetAttribute(name, nil)
		end
	end
	Data.saveAndWait(target, 10)
	notice(admin, "Account reset – rejoining as a brand-new player…")
	-- Rejoin so everything (tutorial, offline basket, client state) starts from scratch.
	local ok = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { target })
	end)
	if not ok then
		Farm.refresh(target)
		resync(target)
		target:Kick("Your account was reset. Rejoin to start fresh!")
	end
end

type Handler = (admin: Player, target: Player, args: { [string]: any }) -> ()

local handlers: { [string]: Handler } = {
	-- Money and items
	AddCash = function(admin, target, args)
		local amount = num(args.amount)
		local data = Data.get(target)
		if amount and data then
			data.Cash = math.max(0, data.Cash + math.floor(amount))
			Economy.sync(target)
			notice(admin, string.format("Cash for %s is now %d", target.DisplayName, data.Cash))
		end
	end,
	SetCash = function(_admin, target, args)
		local amount = num(args.amount)
		local data = Data.get(target)
		if amount and data then
			data.Cash = math.max(0, math.floor(amount))
			Economy.sync(target)
		end
	end,
	GiveSeeds = function(_admin, target, args)
		local id, amount = str(args.seed), num(args.amount)
		if id and amount and Seeds.def(id) then
			Seeds.grant(target, id, math.floor(amount), "Admin")
		end
	end,
	SetUpgrade = function(_admin, target, args)
		local id, level = str(args.track), num(args.level)
		if id and level and trackIds[id] then
			Upgrade.setLevel(target, id, level)
		end
	end,
	MaxUpgrades = function(_admin, target, _args)
		for _, t in Upgrades do
			Upgrade.setLevel(target, t.id, Progression.maxLevel(t))
		end
	end,
	ResetUpgrades = function(_admin, target, _args)
		for _, t in Upgrades do
			Upgrade.setLevel(target, t.id, 0)
		end
	end,
	GiveBoost = function(_admin, target, args)
		local id, seconds = str(args.boost), num(args.seconds)
		if id and seconds then
			Product.addBoost(target, id, math.floor(seconds))
		end
	end,
	SetPass = function(_admin, target, args)
		local id = str(args.pass)
		if id then
			Product.setPassOwned(target, id, args.owned == true)
		end
	end,
	SetPity = function(_admin, target, args)
		local data, value = Data.get(target), num(args.value)
		if data and value then
			data.Pity = math.max(0, math.floor(value))
			Farm.syncPity(target)
		end
	end,
	CompleteDex = function(_admin, target, _args)
		local data = Data.get(target)
		if data then
			for _, c in CarrotsConfig do
				data.FoundTypes[c.id] = true
			end
			Dex.onPlayerReady(target)
		end
	end,
	ResetAccount = function(admin, target, _args)
		resetAccount(admin, target)
	end,

	-- Spawns
	SpawnCarrot = function(admin, target, args)
		local ok = Farm.spawnCarrot(target, {
			rarity = str(args.rarity),
			size = str(args.size),
			mutation = str(args.mutation),
		})
		if not ok then
			notice(admin, "That player has no farm right now", "bad")
		end
	end,
	ForceNextRoll = function(admin, target, args)
		Farm.forceNextRoll(target, {
			rarity = str(args.rarity),
			size = str(args.size),
			mutation = str(args.mutation),
		})
		notice(admin, "Next planting is forced ✔")
	end,
	InstantGrow = function(_admin, target, _args)
		Farm.instantGrow(target)
	end,

	-- Events
	StartBoom = function(admin, _target, args)
		local id = str(args.boom)
		local valid = false
		for _, b in Events.Booms do
			valid = valid or b.id == id
		end
		if not id or not valid then
			return
		end
		local seconds = num(args.seconds) or AdminConfig.DefaultBoomSeconds
		local start = os.time()
		broadcast(
			{ kind = "boom", boomId = id, boomStart = start, boomEnd = start + seconds },
			str(args.scope) or "server"
		)
		notice(admin, "Boom started 🔔")
	end,
	EndBoom = function(_admin, _target, args)
		broadcast({ kind = "boomEnd" }, str(args.scope) or "server")
	end,
	SetEvents = function(_admin, _target, args)
		broadcast({ kind = "events", off = args.off == true }, str(args.scope) or "server")
	end,
	SetDaily = function(_admin, _target, args)
		broadcast({ kind = "daily", rarity = str(args.rarity) }, str(args.scope) or "server")
	end,
	ServerLuck = function(admin, _target, args)
		broadcast({
			kind = "serverLuck",
			name = admin.DisplayName,
			mult = num(args.mult) or Products.ServerLuckMult,
			seconds = num(args.seconds) or Products.ServerLuckSeconds,
		}, str(args.scope) or "server")
	end,

	-- Messages
	Message = function(admin, _target, args)
		local raw = str(args.text, AdminConfig.MaxMessageLength)
		if not raw or #raw == 0 then
			return
		end
		local text = filter(raw, admin.UserId)
		if not text then
			notice(admin, "Message could not be filtered, try again", "bad")
			return
		end
		broadcast(
			{ kind = "message", text = text, userId = admin.UserId, name = admin.DisplayName },
			str(args.scope) or "all"
		)
	end,
}

function Admin.start()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("IsAdmin", Admin.isAdmin(player))
	end)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("IsAdmin", Admin.isAdmin(p))
	end

	local allow = RateLimit.new(8, 16)
	Remotes.get(Remotes.Names.AdminAction).OnServerEvent
		:Connect(function(admin, rawAction: unknown, rawArgs: unknown)
			if not Admin.isAdmin(admin) or not allow(admin) or typeof(rawAction) ~= "string" then
				return
			end
			local handler = handlers[rawAction :: string]
			if not handler then
				return
			end
			local args: { [string]: any } = if typeof(rawArgs) == "table" then rawArgs :: any else {}
			local target = admin
			local targetId = num(args.target)
			if targetId then
				local found = Players:GetPlayerByUserId(targetId)
				if found then
					target = found
				end
			end
			local ok, err = pcall(function()
				handler(admin, target, args)
			end)
			if not ok then
				warn("Admin action failed:", rawAction, err)
				notice(admin, "Admin action failed: " .. tostring(rawAction), "bad")
			end
		end)

	if not RunService:IsStudio() then
		task.spawn(function()
			pcall(function()
				MessagingService:SubscribeAsync(AdminConfig.Topic, function(message)
					local data = message.Data
					if typeof(data) == "table" and data.jobId ~= game.JobId then
						applyGlobal(data)
					end
				end)
			end)
		end)
	end
end

return Admin
