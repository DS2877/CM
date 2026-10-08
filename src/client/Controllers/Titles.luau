--!strict
-- Visible status: a title over every player's head from the rarest carrot they've ever found
-- ("BestRarity", set by the server from the CarrotDex), in that rarity's color (Divine cycles the
-- rainbow, Secret pulses black/white). Social proof and envy: "how is he a Cosmic Grower?!"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarrotInfo = require(ReplicatedStorage.Shared.CarrotInfo)
local UI = require(script.Parent.Parent.Util.UI)

local Titles = {}

local TITLE_BY_RARITY: { [string]: string } = {
	Common = "Sprout",
	Uncommon = "Gardener",
	Rare = "Farmer",
	Epic = "Harvester",
	Legendary = "Legendary Farmer",
	Mythic = "Mythic Hunter",
	Cosmic = "Cosmic Grower",
	Secret = "Keeper of Secrets",
	Divine = "Divine Farmer",
}

local labels: { [Player]: { label: TextLabel, rarity: CarrotInfo.RarityDef? } } = {}

local function attach(player: Player)
	local function build()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") then
			return
		end
		local old = head:FindFirstChild("CarrotTitle")
		if old then
			old:Destroy()
		end
		local rarityId = player:GetAttribute("BestRarity")
		local def = if typeof(rarityId) == "string" then CarrotInfo.rarity(rarityId) else nil
		if not def then
			labels[player] = nil
			return
		end
		local bb: BillboardGui = UI.new("BillboardGui", {
			Name = "CarrotTitle",
			Adornee = head,
			Size = UDim2.fromOffset(200, 26),
			StudsOffset = Vector3.new(0, 3.7, 0),
			MaxDistance = 80,
			LightInfluence = 0,
			Parent = head,
		})
		local label = UI.bigText({
			Size = UDim2.fromScale(1, 1),
			Text = "🥕 " .. (TITLE_BY_RARITY[def.id] or def.name),
			TextColor3 = CarrotInfo.rarityColor(def, os.clock()),
			Parent = bb,
		}, Color3.fromRGB(15, 12, 20), 2)
		labels[player] = { label = label, rarity = def }
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		task.wait(0.6) -- after Roblox's own nametag and the VIP tag
		build()
	end)
	player:GetAttributeChangedSignal("BestRarity"):Connect(build)
	task.spawn(build)
end

function Titles.start()
	for _, p in Players:GetPlayers() do
		attach(p)
	end
	Players.PlayerAdded:Connect(attach)
	Players.PlayerRemoving:Connect(function(p)
		labels[p] = nil
	end)
	-- Animate the special rarities (rainbow / black-white)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, entry in labels do
			local def = entry.rarity
			if def and def.style and entry.label.Parent then
				entry.label.TextColor3 = CarrotInfo.rarityColor(def, t)
			end
		end
	end)
end

return Titles
