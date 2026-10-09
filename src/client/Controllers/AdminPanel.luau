--!strict
-- Admin dashboard (only shown to admins; the server re-checks every action).
-- Sections: target & scope, message all servers, events, spawns, money & items, upgrades,
-- passes & boosts, account. Built for touch: big buttons, cycle buttons instead of dropdowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Events = require(Config.Events)
local Rarity = require(Config.Rarity)
local Sizes = require(Config.Sizes)
local Mutations = require(Config.Mutations)
local SeedsConfig = require(Config.Seeds)
local Upgrades = require(Config.Upgrades)
local Products = require(Config.Products)
local EconomyConfig = require(Config.Economy)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local AdminPanel = {}

local DARK = Color3.fromRGB(40, 40, 60)
local COLORS = {
	blue = { Color3.fromRGB(80, 170, 255), Color3.fromRGB(20, 70, 150) },
	green = { Color3.fromRGB(90, 210, 90), Color3.fromRGB(25, 100, 35) },
	orange = { Color3.fromRGB(255, 165, 50), Color3.fromRGB(140, 70, 0) },
	pink = { Color3.fromRGB(255, 120, 190), Color3.fromRGB(140, 30, 90) },
	red = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(130, 20, 20) },
	gray = { Color3.fromRGB(190, 190, 205), Color3.fromRGB(90, 90, 105) },
}

local panel: Panel.Panel
local built = false
local order = 0
local targetUserId: number? = nil -- nil = me
local scope = "server" -- "server" | "all"

local function nextOrder(): number
	order += 1
	return order
end

local function send(action: string, args: { [string]: any }?)
	local payload: { [string]: any } = args or {}
	payload.target = targetUserId
	payload.scope = scope
	Remotes.get(Remotes.Names.AdminAction):FireServer(action, payload)
end

local function section(title: string): Frame
	if title == "" then
		return UI.new("Frame", {
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = panel.body,
		}, {
			UI.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(148, 42),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	UI.bigText({
		Size = UDim2.new(1, -12, 0, 26),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		LayoutOrder = nextOrder(),
		Parent = panel.body,
	}, DARK, 2.5)
	return UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = panel.body,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(148, 42),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local buttonOrder = 0
local function button(parent: Instance, text: string, color: string, onTap: () -> ()): (TextButton, TextLabel)
	local c = COLORS[color] or COLORS.blue
	buttonOrder += 1
	local b, l = Panel.button({ LayoutOrder = buttonOrder, Parent = parent }, c[1], c[2], text)
	b.Activated:Connect(function()
		UI.bump(b, 0.12)
		onTap()
	end)
	return b, l
end

-- A button that cycles through values when tapped; returns a getter.
local function cycle(parent: Instance, label: string, values: { string }, color: string): () -> string
	local i = 1
	local _, l = button(parent, "", color, function() end)
	local b = l.Parent :: TextButton
	local function render()
		l.Text = label .. ": " .. values[i]
	end
	b.Activated:Connect(function()
		i = i % #values + 1
		render()
	end)
	render()
	return function()
		return values[i]
	end
end

local function textBox(placeholder: string, height: number?): TextBox
	return UI.new("TextBox", {
		Size = UDim2.new(1, -12, 0, height or 40),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		PlaceholderText = placeholder,
		Text = "",
		ClearTextOnFocus = false,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(40, 40, 60),
		LayoutOrder = nextOrder(),
		Parent = panel.body,
	}, { UI.corner(10), UI.stroke(DARK, 2), UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10) }) })
end

local function parseAmount(text: string): number?
	local s = string.lower((string.gsub(text, "[%s,$]", "")))
	local n, suffix = string.match(s, "^([%d%.]+)(%a*)$")
	local value = tonumber(n)
	if not value then
		return nil
	end
	local mult = ({ [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 })[suffix or ""]
	return if mult then value * mult else nil
end

local function ids<T>(list: { T }, key: (T) -> string): { string }
	local out = {}
	for _, v in list do
		table.insert(out, key(v))
	end
	return out
end

local function build()
	panel = Panel.new("Admin", "Admin", Color3.fromRGB(70, 70, 100), DARK, Vector2.new(660, 330))
	panel.frame.BackgroundColor3 = Color3.fromRGB(235, 235, 245)
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	UI.new("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = panel.body })

	-- Target & scope
	local who = section("🎯 Target & scope")
	local _, targetLabel = button(who, "Target: Me", "blue", function() end)
	local targetButton = targetLabel.Parent :: TextButton
	targetButton.Activated:Connect(function()
		local list = Players:GetPlayers()
		local idx = 0
		for i, p in list do
			if p.UserId == (targetUserId or player.UserId) then
				idx = i
			end
		end
		local nextPlayer = list[idx % #list + 1]
		targetUserId = if nextPlayer == player then nil else nextPlayer.UserId
		targetLabel.Text = "Target: " .. (if nextPlayer == player then "Me" else nextPlayer.DisplayName)
	end)
	local _, scopeLabel = button(who, "Scope: This server", "orange", function() end)
	local scopeButton = scopeLabel.Parent :: TextButton
	scopeButton.Activated:Connect(function()
		scope = if scope == "server" then "all" else "server"
		scopeLabel.Text = if scope == "all" then "Scope: ALL servers" else "Scope: This server"
	end)

	-- Message
	section("💬 Message every server (your avatar + speech bubble)")
	local message = textBox("Type a message to all players…", 48)
	local sendRow = section("")
	button(sendRow, "Send to ALL 💬", "pink", function()
		if #message.Text > 0 then
			Remotes.get(Remotes.Names.AdminAction)
				:FireServer("Message", { text = message.Text, scope = "all" })
			message.Text = ""
			HUD.toast("Message sent to every server!", Color3.fromRGB(255, 140, 200))
		end
	end)
	button(sendRow, "Send here only", "pink", function()
		if #message.Text > 0 then
			Remotes.get(Remotes.Names.AdminAction)
				:FireServer("Message", { text = message.Text, scope = "server" })
			message.Text = ""
		end
	end)

	-- Events
	local ev = section("🔔 Events (uses Scope)")
	for _, b in Events.Booms do
		button(ev, "Start " .. b.name, "orange", function()
			send("StartBoom", { boom = b.id })
		end)
	end
	button(ev, "End boom", "red", function()
		send("EndBoom")
	end)
	button(ev, "Events OFF", "gray", function()
		send("SetEvents", { off = true })
	end)
	button(ev, "Events ON", "green", function()
		send("SetEvents", { off = false })
	end)
	local daily = cycle(
		ev,
		"Daily",
		ids(Rarity, function(r)
			return r.id
		end),
		"blue"
	)
	button(ev, "Set daily", "blue", function()
		send("SetDaily", { rarity = daily() })
	end)
	button(ev, "Server Luck x2", "green", function()
		send("ServerLuck", { mult = 2 })
	end)
	button(ev, "Server Luck x5", "green", function()
		send("ServerLuck", { mult = 5 })
	end)

	-- Spawns
	local sp = section("🥕 Spawn carrots (on target's farm)")
	local rarity = cycle(
		sp,
		"Rarity",
		ids(Rarity, function(r)
			return r.id
		end),
		"blue"
	)
	local size = cycle(
		sp,
		"Size",
		ids(Sizes, function(s)
			return s.id
		end),
		"blue"
	)
	local mutationList = { "None" }
	for _, m in Mutations.List do
		table.insert(mutationList, m.id)
	end
	local mutation = cycle(sp, "Mutation", mutationList, "blue")
	local function spec(): { [string]: any }
		local m = mutation()
		return { rarity = rarity(), size = size(), mutation = if m == "None" then nil else m }
	end
	button(sp, "Spawn now!", "green", function()
		send("SpawnCarrot", spec())
	end)
	button(sp, "Force next roll", "orange", function()
		send("ForceNextRoll", spec())
	end)
	button(sp, "Instant grow", "green", function()
		send("InstantGrow")
	end)
	button(sp, "Legendary next (pity)", "orange", function()
		send("SetPity", { value = EconomyConfig.PityLegendary - 1 })
	end)

	-- Money & items
	section("💰 Money & items")
	local amount = textBox("Amount, e.g. 5000, 2.5M, 1B")
	local money = section("")
	button(money, "+ Add cash", "green", function()
		local v = parseAmount(amount.Text)
		if v then
			send("AddCash", { amount = v })
		end
	end)
	button(money, "Set cash", "orange", function()
		local v = parseAmount(amount.Text)
		if v then
			send("SetCash", { amount = v })
		end
	end)
	local quicks: { { label: string, amount: number } } = {
		{ label = "+1K", amount = 1e3 },
		{ label = "+1M", amount = 1e6 },
		{ label = "+1B", amount = 1e9 },
		{ label = "+1T", amount = 1e12 },
	}
	for _, quick in quicks do
		button(money, quick.label, "green", function()
			send("AddCash", { amount = quick.amount })
		end)
	end
	button(money, "Cash → 0", "red", function()
		send("SetCash", { amount = 0 })
	end)
	for _, s in SeedsConfig do
		if s.id ~= "Basic" then
			button(money, "+10 " .. s.name, "blue", function()
				send("GiveSeeds", { seed = s.id, amount = 10 })
			end)
		end
	end

	-- Upgrades
	local up = section("⬆ Upgrades")
	button(up, "Max all", "green", function()
		send("MaxUpgrades")
	end)
	button(up, "Reset all", "red", function()
		send("ResetUpgrades")
	end)
	for _, t in Upgrades do
		button(up, "+1 " .. t.name, "blue", function()
			local current = player:GetAttribute("Upg_" .. t.id)
			local level = if typeof(current) == "number" then current else 0
			send("SetUpgrade", { track = t.id, level = level + 1 })
		end)
	end

	-- Passes & boosts
	local pb = section("⭐ Passes & boosts")
	for _, p in Products.GamePasses do
		button(pb, "Give " .. p.name, "pink", function()
			send("SetPass", { pass = p.id, owned = true })
		end)
		button(pb, "Take " .. p.name, "gray", function()
			send("SetPass", { pass = p.id, owned = false })
		end)
	end
	for _, b in Products.Boosts do
		button(pb, b.name .. " 15m", "green", function()
			send("GiveBoost", { boost = b.id, seconds = 900 })
		end)
	end

	-- Account
	local acc = section("🔄 Account")
	button(acc, "Complete Dex", "blue", function()
		send("CompleteDex")
	end)
	local armed = false
	local _, resetLabel = button(acc, "Reset account", "red", function() end)
	local resetButton = resetLabel.Parent :: TextButton
	resetButton.Activated:Connect(function()
		if not armed then
			armed = true
			resetLabel.Text = "Tap again!"
			task.delay(3, function()
				armed = false
				resetLabel.Text = "Reset account"
			end)
			return
		end
		armed = false
		resetLabel.Text = "Resetting…"
		send("ResetAccount")
	end)
end

function AdminPanel.start()
	local function check()
		if player:GetAttribute("IsAdmin") == true and not built then
			built = true
			build()
			HUD.addCornerButton("Admin", "⚙️", Color3.fromRGB(70, 70, 100), DARK, panel.toggle)
		end
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(check)
	check()
end

return AdminPanel
