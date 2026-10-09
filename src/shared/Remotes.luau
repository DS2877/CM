--!strict
-- All RemoteEvents in one place. The server creates them, clients wait for them.
-- Client -> server remotes carry intents only ("act on plot 3"), never values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	-- client -> server
	PlotAction = "PlotAction", -- (plotIndex: number)
	BuyUpgrade = "BuyUpgrade", -- (trackId: string)
	BuySeed = "BuySeed", -- (seedId: string, amount: number)
	SelectSeed = "SelectSeed", -- (seedId: string)
	WaterFarm = "WaterFarm", -- (farmId: number)
	SetGiftTarget = "SetGiftTarget", -- (targetUserId: number, passId: string)
	Track = "Track", -- (event: string, detail: string) whitelisted analytics from UI
	TogglePerk = "TogglePerk", -- (key: string) "Pass_X" or "Boost_Y": switch a bought perk on/off
	AdminAction = "AdminAction", -- (action: string, args: table) admins only, re-checked on the server
	SetMusic = "SetMusic", -- (enabled: boolean) saved setting
	RedeemCode = "RedeemCode", -- (code: string)
	ClaimDaily = "ClaimDaily", -- () claim today's calendar reward
	ClaimQuest = "ClaimQuest", -- (index: number)
	TutorialDone = "TutorialDone", -- () the guided first minute finished
	-- server -> client
	HarvestResult = "HarvestResult", -- (Types.HarvestResult)
	SellResult = "SellResult", -- (Types.SellResult)
	Announce = "Announce", -- (Types.Announcement)
	Notice = "Notice", -- (Types.Notice)
	DexSync = "DexSync", -- (Types.DexState)
	Watered = "Watered", -- (farmId: number, byName: string)
	Offer = "Offer", -- (productId: string) show a contextual offer once
	AdminMessage = "AdminMessage", -- ({ text, userId, name }) dev message bubble, all servers
	PromptFavorite = "PromptFavorite", -- () ask the client to show the favorite prompt (once)
	DailySync = "DailySync", -- (Daily.DailyState)
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
