--!strict
-- The payoff moments: harvest pop scaled by value, value text in rarity color, carrots flying
-- into the basket, cash flying into the wallet on sell, and server-wide announcements.
--   Common      pop + number
--   Rare+       colored burst, rarity name
--   Legendary+  slow spin, camera zoom, screen text, sound everyone hears

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CarrotInfo = require(Shared.CarrotInfo)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local CarrotModel = require(script.Parent.Parent.Util.CarrotModel)
local HUD = require(script.Parent.HUD)
local Plot = require(script.Parent.Plot)

local player = Players.LocalPlayer

local HarvestFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local CASH_GREEN = Color3.fromRGB(120, 235, 110)

local function anchorPart(position: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "FXAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = Plot.fxFolder()
	return p
end

local function burst(position: Vector3, color: Color3, count: number, speed: number)
	local holder = anchorPart(position)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Drag = 2
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.Parent = holder
	e:Emit(count)
	task.delay(2, function()
		holder:Destroy()
	end)
end

local function floatText(position: Vector3, lines: { { text: string, color: Color3 } }, big: boolean)
	local holder = anchorPart(position)
	local height = if big then 3.2 else 2
	local bb: BillboardGui = UI.new("BillboardGui", {
		Size = UDim2.new(if big then 14 else 9, 0, height, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 1, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 200,
		Parent = holder,
	})
	local labels: { TextLabel } = {}
	for i, line in lines do
		local l = UI.bigText({
			Position = UDim2.fromScale(0, (i - 1) / #lines),
			Size = UDim2.fromScale(1, 1 / #lines),
			Text = line.text,
			TextColor3 = line.color,
			Parent = bb,
		}, Color3.new(0, 0, 0), 3)
		table.insert(labels, l)
	end
	UI.bump(bb :: any, 0.4)
	UI.tween(bb, 1.3, { StudsOffsetWorldSpace = Vector3.new(0, if big then 6 else 4, 0) })
	task.delay(if big then 1.8 else 0.9, function()
		for _, l in labels do
			UI.tween(l, 0.4, { TextTransparency = 1 })
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				UI.tween(stroke, 0.4, { Transparency = 1 })
			end
		end
		task.wait(0.45)
		holder:Destroy()
	end)
end

-- A small icon flying along an arc in the FX layer. `kind` is "carrot" or "cash".
local function flyIcon(kind: string, from: Vector2, to: Vector2, delay: number, onArrive: (() -> ())?)
	task.delay(delay, function()
		local root = HUD.fxRoot()
		local icon: Frame = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(from.X, from.Y),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = if kind == "cash" then CASH_GREEN else Color3.fromRGB(245, 130, 30),
			Parent = root,
		}, {
			UI.corner(17),
			UI.stroke(if kind == "cash" then Color3.fromRGB(30, 110, 30) else Color3.fromRGB(120, 60, 10), 2),
		})
		if kind == "cash" then
			UI.label({
				Size = UDim2.fromScale(1, 1),
				Text = "$",
				TextColor3 = Color3.fromRGB(20, 80, 20),
				Parent = icon,
			})
		else
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.15),
				Size = UDim2.fromOffset(10, 14),
				BackgroundColor3 = Color3.fromRGB(80, 180, 60),
				Parent = icon,
			}, { UI.corner(5) })
		end
		local duration = 0.55
		local start = os.clock()
		local arc = math.min(140, (to - from).Magnitude * 0.35)
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / duration, 0, 1)
			local eased = t * t * (3 - 2 * t)
			local p = from:Lerp(to, eased) - Vector2.new(0, arc * math.sin(math.pi * t))
			icon.Position = UDim2.fromOffset(p.X, p.Y)
			local s = 1 - 0.35 * t
			icon.Size = UDim2.fromOffset(34 * s, 34 * s)
			if t >= 1 then
				conn:Disconnect()
				icon:Destroy()
				if onArrive then
					onArrive()
				end
			end
		end)
	end)
end

local function worldToFx(position: Vector3): Vector2
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector2.new(400, 200)
	end
	local v, onScreen = camera:WorldToViewportPoint(position)
	if not onScreen then
		return camera.ViewportSize / 2
	end
	return Vector2.new(v.X, v.Y)
end

local function cameraPunch(strength: number, hold: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local base = 70
	UI.tween(camera, 0.35, { FieldOfView = base - strength }, Enum.EasingStyle.Quad)
	task.delay(0.35 + hold, function()
		UI.tween(camera, 0.7, { FieldOfView = base }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end)
end

local function flash(color: Color3)
	local f: Frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.35,
		Parent = HUD.fxRoot(),
	})
	UI.tween(f, 0.8, { BackgroundTransparency = 1 })
	task.delay(0.85, function()
		f:Destroy()
	end)
end

-- Animate the harvested carrot: jump + spin, then shrink away.
local function animateCarrot(model: Model, base: CFrame, big: boolean, onDone: () -> ())
	local rise = if big then 6 else 3.2
	local upTime = if big then 2.2 else 0.4
	local spin = if big then math.pi * 2 else math.pi * 2
	local outTime = 0.22
	local startScale = model:GetScale()
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t < upTime then
			local k = t / upTime
			local eased = 1 - (1 - k) ^ 3
			model:PivotTo(base * CFrame.new(0, rise * eased, 0) * CFrame.Angles(0, spin * eased, 0))
		elseif t < upTime + outTime then
			local k = (t - upTime) / outTime
			model:ScaleTo(math.max(0.05, startScale * (1 - k)))
			model:PivotTo(base * CFrame.new(0, rise + k * 1.5, 0) * CFrame.Angles(0, spin, 0))
		else
			conn:Disconnect()
			model:Destroy()
			onDone()
		end
	end)
end

local function onHarvest(r: Types.HarvestResult)
	local part = Plot.myPlot(r.plot)
	if not part then
		return
	end
	Plot.hideCarrot(r.plot)

	local rarity = CarrotInfo.rarity(r.rarity)
	local order = if rarity then rarity.order else 1
	local color = if rarity then CarrotInfo.rarityColor(rarity, os.clock()) else Color3.new(1, 1, 1)
	local sizeDef = CarrotInfo.size(r.size)
	local scale = if sizeDef then sizeDef.scale else 1
	local big = order >= 5

	local model = CarrotModel.build(r.type, r.mutations, scale)
	local length = CarrotModel.length(model)
	local base = Plot.readyCFrame(part, length, r.plot)
	model:PivotTo(base)
	model.Parent = Plot.fxFolder()

	local top = part.Position + Vector3.new(0, part.Size.Y / 2 + 1, 0)
	local carrot: Types.Carrot = { type = r.type, size = r.size, mutations = r.mutations }

	-- Sound and burst scale with value
	if big then
		Sound.play(if order >= 6 then "HarvestMythic" else "HarvestLegendary")
		cameraPunch(18, 1.6)
		flash(color)
		burst(top, color, 140, 24)
		burst(top + Vector3.new(0, 2, 0), Color3.new(1, 1, 1), 60, 30)
	elseif order >= 3 or #r.mutations > 0 then
		Sound.play(if order >= 4 then "HarvestEpic" else "HarvestRare")
		local mut = r.mutations[1] and CarrotInfo.mutation(r.mutations[1])
		burst(top, if mut then CarrotInfo.color(mut.color) else color, 30 + order * 12, 16)
	else
		-- Quick streaks through the farm climb in pitch
		Sound.combo("Harvest")
		burst(top, if order >= 2 then color else Color3.fromRGB(255, 220, 90), 16 + order * 6, 10)
	end

	-- Value text
	local lines = { { text = "+" .. Format.cash(r.value), color = CASH_GREEN } }
	if order >= 2 or #r.mutations > 0 or r.size ~= "Normal" then
		local name = CarrotInfo.displayName(carrot)
		if order >= 3 and rarity then
			name = string.upper(rarity.name) .. " " .. name
		end
		table.insert(lines, { text = name, color = color })
	end
	floatText(top + Vector3.new(0, length * 0.5, 0), lines, big)

	animateCarrot(model, base, big, function()
		-- Fly into the basket (or straight to cash if the basket was full)
		local from = worldToFx(top + Vector3.new(0, 3, 0))
		if r.autoSold then
			flyIcon("cash", from, HUD.centerOf("cash"), 0, function()
				HUD.bump("cash", 0.08)
			end)
		else
			local icons = math.clamp(order, 1, 5)
			for i = 1, icons do
				flyIcon("carrot", from, HUD.centerOf("sell"), (i - 1) * 0.06, function()
					HUD.bump("sell", 0.08)
				end)
			end
		end
	end)

	if r.isNewType then
		local def = CarrotInfo.type(r.type)
		HUD.toast(
			string.format("NEW! %s (%d/%d)", if def then def.name else r.type, r.found, r.totalTypes),
			color,
			4
		)
		Sound.play("Discover")
	end
	if #r.mutations > 0 and order < 4 then
		local mut = CarrotInfo.mutation(r.mutations[1])
		if mut then
			HUD.toast(
				string.format("✨ %s x%s", mut.name, Format.number(mut.mult)),
				CarrotInfo.color(mut.color),
				3.5
			)
			Sound.play("Mutation")
		end
	end
end

local function onSell(r: Types.SellResult)
	local boom = r.boom == true and r.bonus > 1.001
	local coins = math.clamp(math.floor(2 + math.log10(math.max(1, r.total)) * 1.5), 3, 10)
	if boom then
		-- "Sell All under a boom should feel like a jackpot"
		coins = math.min(14, coins + 4)
		HUD.banner(
			string.format("BOOM SALE! x%s", tostring(math.floor(r.bonus * 10 + 0.5) / 10)),
			Color3.fromRGB(255, 170, 40),
			3
		)
		Sound.play("SellBoom")
	end
	local from = HUD.centerOf("sell")
	local to = HUD.centerOf("cash")
	-- Bigger sales sound a touch brighter
	Sound.play("Sell", { speed = 1 + math.min(0.25, coins / 80) })
	HUD.bump("sell", 0.12)
	for i = 1, coins do
		local jitter = Vector2.new(math.random(-20, 20), math.random(-20, 20))
		flyIcon("cash", from + jitter, to, (i - 1) * 0.045, function()
			HUD.bump("cash", 0.06)
		end)
	end
	-- Big center gain popup ("+$1,234" with a cash icon), then it shrinks into the wallet.
	local root = HUD.fxRoot()
	local s = HUD.scale()
	local center = root.AbsoluteSize * Vector2.new(0.5, 0.42)
	local height = math.floor(math.clamp(26 + math.log10(math.max(1, r.total)) * 2.5, 28, 44) * s)
	local popup: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(height * 6, height),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	local icon = UI.icon("Cash", "💵")
	icon.Size = UDim2.fromOffset(height, height)
	icon.LayoutOrder = 1
	icon.Parent = popup
	UI.bigText({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		TextScaled = false,
		TextSize = height,
		Text = "+" .. Format.cash(r.total),
		TextColor3 = CASH_GREEN,
		LayoutOrder = 2,
		Parent = popup,
	}, Color3.fromRGB(10, 50, 10), 4)
	UI.bump(popup, 0.6)
	task.delay(0.75, function()
		UI.tween(
			popup,
			0.45,
			{ Position = UDim2.fromOffset(to.X + height * 2, to.Y) },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		local scale = popup:FindFirstChild("Bump") :: UIScale?
		if scale then
			UI.tween(scale, 0.45, { Scale = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(0.45)
		HUD.bump("cash", 0.25)
		popup:Destroy()
	end)
end

local function onAnnounce(a: Types.Announcement)
	local rarity = CarrotInfo.rarity(a.rarity)
	local color = if rarity then CarrotInfo.rarityColor(rarity, os.clock()) else Color3.new(1, 1, 1)
	local rarityName = if rarity then string.upper(rarity.name) else a.rarity
	local carrot: Types.Carrot = { type = a.type, size = a.size, mutations = a.mutations }
	local name = CarrotInfo.displayName(carrot)
	local isMe = a.userId == player.UserId and not a.otherServer

	if a.otherServer then
		HUD.banner(
			string.format("🌍 %s found a %s %s in another server!", a.playerName, rarityName, name),
			color,
			6
		)
		Sound.play("Announce")
		return
	end
	if a.scope <= 1 then
		HUD.toast(string.format("%s! %s %s", rarityName, name, Format.cash(a.value)), color, 3)
		return
	end
	if isMe then
		HUD.banner(string.format("%s! %s  %s", rarityName, name, Format.cash(a.value)), color, 5)
	else
		HUD.banner(string.format("%s found a %s %s!", a.playerName, rarityName, name), color, 5)
		Sound.play("Announce")
	end
end

function HarvestFX.start()
	Remotes.get(Remotes.Names.HarvestResult).OnClientEvent:Connect(onHarvest)
	Remotes.get(Remotes.Names.SellResult).OnClientEvent:Connect(onSell)
	Remotes.get(Remotes.Names.Announce).OnClientEvent:Connect(onAnnounce)
end

return HarvestFX
