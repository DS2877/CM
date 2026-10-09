--!strict
-- Read-only view of what a player has bought, as set by the Product service (server-side
-- attributes; clients can't change them). Kept separate so Farm/Economy/Offline can use perks
-- without a require cycle with Product.

local Perks = {}

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- Owned AND switched on (players can turn bought passes off; they're on by default).
function Perks.hasPass(player: Player, passId: string): boolean
	return player:GetAttribute("Pass_" .. passId) == true
		and player:GetAttribute("Off_Pass_" .. passId) ~= true
end

-- Strongest active personal luck boost (1 = none).
function Perks.luckBoost(player: Player): number
	return num(player, "LuckBoost", 1)
end

-- Active value boosts multiplied together (capped later by Economy.BoostCap).
function Perks.valueBoost(player: Player): number
	return num(player, "ValueBoost", 1)
end

-- Server Luck bought by someone in this server (1 = none).
function Perks.serverLuck(): number
	if num(workspace, "ServerLuckEnds", 0) > workspace:GetServerTimeNow() then
		return num(workspace, "ServerLuck", 1)
	end
	return 1
end

return Perks
