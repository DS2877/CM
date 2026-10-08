--!strict
-- Friend bonus (design doc §6): +10 % luck per friend in the same server, max 3. Drives invites.
-- Replicated as the "FriendBoost" attribute (0.0 – 0.3), which Farm uses when rolling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialConfig = require(ReplicatedStorage.Shared.Config.Social)

local Social = {}

-- friendPairs["a:b"] (a < b) = true when the two are Roblox friends
local friendPairs: { [string]: boolean } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function recompute()
	for _, p in Players:GetPlayers() do
		local n = 0
		for _, other in Players:GetPlayers() do
			if other ~= p and friendPairs[pairKey(p.UserId, other.UserId)] then
				n += 1
			end
		end
		n = math.min(n, SocialConfig.FriendMax)
		p:SetAttribute("FriendBoost", n * SocialConfig.FriendLuckBonus)
		p:SetAttribute("FriendCount", n)
	end
end

local function onJoin(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				friendPairs[pairKey(player.UserId, other.UserId)] = true
			end
		end
	end
	recompute()
end

function Social.start()
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function()
		task.defer(recompute)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
end

return Social
