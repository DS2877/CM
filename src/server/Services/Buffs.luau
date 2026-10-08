--!strict
-- Timed buffs that only tick while the player is in the server (design doc: boosts count play
-- time). Replicated as "Buff_<name>" = server time when it ends, so clients can count down.

local Players = game:GetService("Players")

local Buffs = {}

local active: { [Player]: { [string]: number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function Buffs.add(player: Player, name: string, seconds: number)
	local list = active[player]
	if not list then
		list = {}
		active[player] = list
	end
	assert(list, "buff list")
	-- Refresh rather than stack: watering again just restarts the timer.
	list[name] = now() + seconds
	player:SetAttribute("Buff_" .. name, list[name])
end

function Buffs.isActive(player: Player, name: string): boolean
	local list = active[player]
	local ends = list and list[name]
	return ends ~= nil and ends > now()
end

function Buffs.start()
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)
end

return Buffs
