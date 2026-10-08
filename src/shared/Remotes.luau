--!strict
-- All RemoteEvents in one place. The server creates them, clients wait for them.
-- Client -> server remotes carry intents only ("act on plot 3"), never values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	-- client -> server
	PlotAction = "PlotAction", -- (plotIndex: number)
	SellAll = "SellAll", -- ()
	BuyUpgrade = "BuyUpgrade", -- (trackId: string)
	BuySeed = "BuySeed", -- (seedId: string, amount: number)
	SelectSeed = "SelectSeed", -- (seedId: string)
	-- server -> client
	HarvestResult = "HarvestResult", -- (Types.HarvestResult)
	SellResult = "SellResult", -- (Types.SellResult)
	Announce = "Announce", -- (Types.Announcement)
	Notice = "Notice", -- (Types.Notice)
	DexSync = "DexSync", -- (Types.DexState)
	OfflineReveal = "OfflineReveal", -- (Types.OfflineResult)
}

local FOLDER_NAME = "Remotes"

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end
		local f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server: create every remote up front.
function Remotes.setup()
	assert(RunService:IsServer(), "Remotes.setup is server-only")
	local f = folder()
	for _, name: string in Remotes.Names :: { [string]: string } do
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	local f = folder()
	if RunService:IsServer() then
		local r = f:FindFirstChild(name)
		assert(r and r:IsA("RemoteEvent"), "Unknown remote " .. name)
		return r
	end
	return f:WaitForChild(name) :: RemoteEvent
end

return Remotes
