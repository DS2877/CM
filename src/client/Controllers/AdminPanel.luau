--!strict
-- Admin dashboard (only shown to admins; the server re-checks every action).
-- Dark control-room look: tabs down the left (Fun, Events, Carrots, Money, Farm, Perks, Message,
-- Account), big emoji tiles on the right, and the Target / Scope chips always visible under the
-- tabs. Built for touch: big tiles, cycle tiles instead of dropdowns.

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
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.Util.UI)
local Panel = require(script.Parent.Parent.Util.Panel)
local Sound = require(script.Parent.Parent.Util.Sound)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local AdminPanel = {}

local BG = Color3.fromRGB(28, 30, 46)
local CARD = Color3.fromRGB(44, 47, 70)
local DARK = Color3.fromRGB(16, 17, 28)
local TEXT = Color3.fromRGB(235, 238, 255)
local DIM = Color3.fromRGB(150, 155, 190)
local COLORS: { [string]: Color3 } = {
	blue = Color3.fromRGB(80, 160, 255),
	green = Color3.fromRGB(80, 210, 110),
	orange = Color3.fromRGB(255, 160, 50),
	pink = Color3.fromRGB(255, 110, 190),
	red = Color3.fromRGB(255, 85, 95),
	purple = Color3.fromRGB(165, 110, 255),
	gold = Color3.fromRGB(255, 205, 60),
	gray = Color3.fromRGB(130, 135, 160),
}

local panel: Panel.Panel
local built = false
local targetUserId: number? = nil -- nil = me
local scope = "server" -- "server" | "all"
local tabs: { { button: TextButton, page: ScrollingFrame, color: Color3 } } = {}

local function send(action: string, args: { [string]: any }?)
	local payload: { [string]: any } = args or {}
	payload.target = targetUserId
	payload.scope = payload.scope or scope
	Remotes.get(Remotes.Names.AdminAction):FireServer(action, payload)
	Sound.play("Click")
end

-- A tile: colored accent bar, big emoji, short label. Returns (button, label).
local tileOrder = 0
local function tile(
	page: Instance,
	emoji: string,
	text: string,
	color: string,
	onTap: () -> ()
): (TextButton, TextLabel)
	tileOrder += 1
	local accent = COLORS[color] or COLORS.blue
	local b: TextButton = UI.new("TextButton", {
		BackgroundColor3 = CARD,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = tileOrder,
		Parent = page,
	}, { UI.corner(12), UI.stroke(accent, 1.5, 0.35) })
	UI.new("Frame", {
		Size = UDim2.new(0, 5, 1, -12),
		Position = UDim2.fromOffset(5, 6),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = b,
	}, { UI.corner(3) })
	UI.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(0, 30, 1, -12),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	local l = UI.label({
		Position = UDim2.fromOffset(48, 8),
		Size = UDim2.new(1, -54, 1, -16),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEXT,
		Parent = b,
	})
	b.Activated:Connect(function()
		UI.bump(b, 0.08)
		onTap()
	end)
	return b, l
end

-- A tile that cycles through values when tapped; returns a getter.
local function cycleTile(page: Instance, emoji: string, label: string, values: { string }): () -> string
	local i = 1
	local _, l = tile(page, emoji, "", "purple", function() end)
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

local function header(page: Instance, text: string)
	tileOrder += 1
	-- A full-width row in the grid: use a frame as wide as the page via UISizeConstraint trick
	local l = UI.label({
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DIM,
		LayoutOrder = tileOrder,
		Parent = page,
	})
	return l
end

local function textBox(page: Instance, placeholder: string): TextBox
	tileOrder += 1
	return UI.new("TextBox", {
		BackgroundColor3 = DARK,
		PlaceholderText = placeholder,
		PlaceholderColor3 = DIM,
		Text = "",
		ClearTextOnFocus = false,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = TEXT,
		LayoutOrder = tileOrder,
		Parent = page,
	}, {
		UI.corner(10),
		UI.stroke(COLORS.blue, 1.5, 0.3),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
	})
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

local function selectTab(index: number)
	for i, t in tabs do
		local on = i == index
		t.page.Visible = on
		t.button.BackgroundColor3 = if on then t.color else CARD
		local l = t.button:FindFirstChildOfClass("TextLabel")
		if l then
			l.TextColor3 = if on then DARK else TEXT
		end
	end
end

local function addTab(
	column: Frame,
	content: Frame,
	emoji: string,
	name: string,
	color: string
): ScrollingFrame
	local accent = COLORS[color] or COLORS.blue
	local index = #tabs + 1
	local b: TextButton = UI.new("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = CARD,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = index,
		Parent = column,
	}, { UI.corner(9) })
	UI.label({
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 1, -10),
		Text = emoji .. "  " .. name,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEXT,
		Parent = b,
	})
	local page: ScrollingFrame = UI.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = content,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.333, -6, 0, 44),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	table.insert(tabs, { button = b, page = page, color = accent })
	b.Activated:Connect(function()
		Sound.play("Click")
		selectTab(index)
	end)
	return page
end

local function trackLevel(id: string): number
	local v = player:GetAttribute("Upg_" .. id)
	return if typeof(v) == "number" then v else 0
end

local function build()
	panel = Panel.new("Admin", "Admin Dashboard", Color3.fromRGB(110, 90, 220), DARK, Vector2.new(720, 360))
	panel.frame.BackgroundColor3 = BG
	panel.body.Visible = false

	-- Left column: tabs, then the target & scope chips
	local column: Frame = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.new(0, 132, 1, -72),
		BackgroundTransparency = 1,
		Parent = panel.frame,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local content: Frame = UI.new("Frame", {
		Position = UDim2.fromOffset(152, 62),
		Size = UDim2.new(1, -160, 1, -72),
		BackgroundTransparency = 1,
		Parent = panel.frame,
	})

	local fun = addTab(column, content, "🎉", "Fun", "pink")
	local ev = addTab(column, content, "🔔", "Events", "orange")
	local carrots = addTab(column, content, "🥕", "Carrots", "gold")
	local money = addTab(column, content, "💰", "Money", "green")
	local farm = addTab(column, content, "🏡", "Farm", "blue")
	local perks = addTab(column, content, "⭐", "Perks", "purple")
	local msg = addTab(column, content, "💬", "Message", "pink")
	local acc = addTab(column, content, "🔄", "Account", "red")

	-- Target & scope chips (always visible)
	local function chip(order: number, color: Color3): (TextButton, TextLabel)
		local b: TextButton = UI.new("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = DARK,
			Text = "",
			LayoutOrder = 100 + order,
			Parent = column,
		}, { UI.corner(14), UI.stroke(color, 1.5) })
		local l = UI.label({
			Position = UDim2.fromOffset(8, 5),
			Size = UDim2.new(1, -16, 1, -10),
			Text = "",
			TextColor3 = color,
			Parent = b,
		})
		return b, l
	end
	local targetButton, targetLabel = chip(1, COLORS.blue)
	targetLabel.Text = "🎯 Me"
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
		targetLabel.Text = "🎯 " .. (if nextPlayer == player then "Me" else nextPlayer.DisplayName)
	end)
	local scopeButton, scopeLabel = chip(2, COLORS.orange)
	scopeLabel.Text = "📡 This server"
	scopeButton.Activated:Connect(function()
		scope = if scope == "server" then "all" else "server"
		scopeLabel.Text = if scope == "all" then "🌍 ALL servers" else "📡 This server"
	end)

	-- 🎉 Fun ---------------------------------------------------------------
	tile(fun, "🎆", "Sky party (2 min)", "pink", function()
		send("Party")
	end)
	tile(fun, "🛑", "Stop sky party", "gray", function()
		send("StopParty")
	end)
	tile(fun, "🐰", "Bunny dance", "pink", function()
		send("BunnyParty")
	end)
	tile(fun, "🥕", "Carrot rain", "orange", function()
		send("CarrotRain")
	end)
	tile(fun, "🎊", "Confetti blast", "gold", function()
		send("Confetti")
	end)
	tile(fun, "🦖", "Giant mode", "purple", function()
		send("SetBody", { mode = "giant" })
	end)
	tile(fun, "🐜", "Tiny mode", "purple", function()
		send("SetBody", { mode = "tiny" })
	end)
	tile(fun, "⚡", "Super speed", "blue", function()
		send("SetBody", { mode = "speed" })
	end)
	tile(fun, "🌙", "Moon jump", "blue", function()
		send("SetBody", { mode = "moon" })
	end)
	tile(fun, "🙂", "Normal body", "gray", function()
		send("SetBody", { mode = "normal" })
	end)
	tile(fun, "🧲", "Bring target", "green", function()
		send("Teleport", { where = "bring" })
	end)
	tile(fun, "🚀", "Go to target", "green", function()
		send("Teleport", { where = "toTarget" })
	end)
	tile(fun, "🏪", "Target → market", "green", function()
		send("Teleport", { where = "market" })
	end)
	tile(fun, "🏡", "Target → farm", "green", function()
		send("Teleport", { where = "farm" })
	end)

	-- 🔔 Events ---------------------------------------------------------------
	for _, b in Events.Booms do
		tile(ev, "🔔", b.name, "orange", function()
			send("StartBoom", { boom = b.id })
		end)
	end
	tile(ev, "🛑", "End boom", "red", function()
		send("EndBoom")
	end)
	tile(ev, "⏸", "Events OFF", "gray", function()
		send("SetEvents", { off = true })
	end)
	tile(ev, "▶️", "Events ON", "green", function()
		send("SetEvents", { off = false })
	end)
	local daily = cycleTile(
		ev,
		"⭐",
		"Daily",
		ids(Rarity, function(r)
			return r.id
		end)
	)
	tile(ev, "✅", "Set daily", "blue", function()
		send("SetDaily", { rarity = daily() })
	end)
	tile(ev, "🍀", "Server Luck x2", "green", function()
		send("ServerLuck", { mult = 2 })
	end)
	tile(ev, "🍀", "Server Luck x5", "green", function()
		send("ServerLuck", { mult = 5 })
	end)

	-- 🥕 Carrots ---------------------------------------------------------------
	local rarity = cycleTile(
		carrots,
		"💎",
		"Rarity",
		ids(Rarity, function(r)
			return r.id
		end)
	)
	local size = cycleTile(
		carrots,
		"📏",
		"Size",
		ids(Sizes, function(s)
			return s.id
		end)
	)
	local mutationList = { "None" }
	for _, m in Mutations.List do
		table.insert(mutationList, m.id)
	end
	local mutation = cycleTile(carrots, "✨", "Mutation", mutationList)
	local function spec(): { [string]: any }
		local m = mutation()
		return { rarity = rarity(), size = size(), mutation = if m == "None" then nil else m }
	end
	tile(carrots, "🥕", "Spawn one", "gold", function()
		send("SpawnCarrot", spec())
	end)
	tile(carrots, "🌾", "Fill whole farm", "gold", function()
		send("FillFarm", spec())
	end)
	tile(carrots, "🎲", "Force next roll", "orange", function()
		send("ForceNextRoll", spec())
	end)
	tile(carrots, "⏩", "Instant grow", "green", function()
		send("InstantGrow")
	end)
	tile(carrots, "👑", "Legendary next", "orange", function()
		send("SetPity", { value = EconomyConfig.PityLegendary - 1 })
	end)

	-- 💰 Money ---------------------------------------------------------------
	local amount = textBox(money, "Amount: 5000, 2.5M, 1B")
	tile(money, "➕", "Add amount", "green", function()
		local v = parseAmount(amount.Text)
		if v then
			send("AddCash", { amount = v })
		end
	end)
	tile(money, "✏️", "Set to amount", "orange", function()
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
		tile(money, "💵", quick.label, "green", function()
			send("AddCash", { amount = quick.amount })
		end)
	end
	tile(money, "🫙", "Cash → 0", "red", function()
		send("SetCash", { amount = 0 })
	end)
	for _, s in SeedsConfig do
		if s.id ~= "Basic" then
			tile(money, s.emoji, "+10 " .. s.name, "blue", function()
				send("GiveSeeds", { seed = s.id, amount = 10 })
			end)
		end
	end

	-- 🏡 Farm & upgrades ---------------------------------------------------------
	tile(farm, "🚀", "Max everything", "green", function()
		send("MaxUpgrades")
	end)
	tile(farm, "♻️", "Reset upgrades", "red", function()
		send("ResetUpgrades")
	end)
	for _, t in Upgrades do
		tile(farm, t.emoji, "+1 " .. t.name, "blue", function()
			send("SetUpgrade", { track = t.id, level = trackLevel(t.id) + 1 })
		end)
		tile(farm, t.emoji, "-1 " .. t.name, "gray", function()
			send("SetUpgrade", { track = t.id, level = math.max(0, trackLevel(t.id) - 1) })
		end)
		if t.id == "FarmSize" then
			tile(farm, "🏰", "Farm level MAX", "gold", function()
				send("SetUpgrade", { track = t.id, level = Progression.maxLevel(t) })
			end)
		end
	end

	-- ⭐ Perks ---------------------------------------------------------------
	for _, p in Products.GamePasses do
		tile(perks, "🎁", "Give " .. p.name, "pink", function()
			send("SetPass", { pass = p.id, owned = true })
		end)
		tile(perks, "✖️", "Take " .. p.name, "gray", function()
			send("SetPass", { pass = p.id, owned = false })
		end)
	end
	for _, b in Products.Boosts do
		tile(perks, b.emoji, b.name .. " 15m", "green", function()
			send("GiveBoost", { boost = b.id, seconds = 900 })
		end)
	end

	-- 💬 Message ---------------------------------------------------------------
	local message = textBox(msg, "Message for everyone (your avatar + speech bubble)…")
	tile(msg, "🌍", "Send to ALL servers", "pink", function()
		if #message.Text > 0 then
			send("Message", { text = message.Text, scope = "all" })
			message.Text = ""
			HUD.toast("Message sent to every server!", COLORS.pink)
		end
	end)
	tile(msg, "📡", "Send here only", "purple", function()
		if #message.Text > 0 then
			send("Message", { text = message.Text, scope = "server" })
			message.Text = ""
		end
	end)
	header(msg, "Messages are filtered by Roblox before anyone sees them.")

	-- 🔄 Account ---------------------------------------------------------------
	tile(acc, "📖", "Complete Dex", "blue", function()
		send("CompleteDex")
	end)
	local armed = false
	local resetButton, resetLabel = tile(acc, "💣", "Reset account", "red", function() end)
	resetButton.Activated:Connect(function()
		if not armed then
			armed = true
			resetLabel.Text = "Tap again to reset!"
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

	selectTab(1)
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
