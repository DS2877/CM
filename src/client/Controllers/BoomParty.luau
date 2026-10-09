--!strict
-- The sky party while a market boom is on (or when an admin throws one). Impossible to miss from
-- anywhere on the map:
--   * the day slides into a glowing dusk, tinted in the boom's colors (Config/Party themes)
--   * fireworks burst high in the sky all around you
--   * searchlights sweep the sky from around the plaza
--   * aurora ribbons wave across the whole sky
--   * glowing lanterns float up from the market
-- Everything is local and cosmetic; it switches off smoothly when the boom ends.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Party = require(Shared.Config.Party)
local Market = require(Shared.Market)
local Remotes = require(Shared.Remotes)

local BoomParty = {}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

type Beam = { part: Part, base: Vector3, phase: number, speed: number }
type Lantern = { part: Part, speed: number, sway: number }

local folder: Folder
local active = false
local themeColors: { Color3 } = {}
local beams: { Beam } = {}
local aurora: { { part: Part, band: number, x: number } } = {}
local lanterns: { Lantern } = {}
local fireworkAcc = 0

-- What the lighting looks like normally (restored after the party)
local normal = {
	clock = Lighting.ClockTime,
	tint = Color3.new(1, 1, 1),
	saturation = 0,
	atmosphereColor = Color3.new(1, 1, 1),
	haze = 0,
	glare = 0,
	bloom = 0,
}
local atmosphere: Atmosphere? = nil
local cc: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil

local function tween(obj: Instance, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(Party.TransitionSeconds, Enum.EasingStyle.Sine), props):Play()
end

local function neon(size: Vector3, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Transparency = transparency
	p.Parent = folder
	return p
end

local function randomColor(): Color3
	return themeColors[math.random(1, #themeColors)]
end

local function clearProps()
	for _, b in beams do
		b.part:Destroy()
	end
	for _, a in aurora do
		a.part:Destroy()
	end
	for _, l in lanterns do
		l.part:Destroy()
	end
	table.clear(beams)
	table.clear(aurora)
	table.clear(lanterns)
end

local function spawnLantern(startHigh: boolean?)
	local a = math.random() * math.pi * 2
	local r = math.random() * 32
	local p = neon(Vector3.new(1.2, 1.5, 1.2), randomColor(), 0.1)
	p.Shape = Enum.PartType.Ball
	p.Position = Vector3.new(math.cos(a) * r, if startHigh then math.random(5, 120) else 3, math.sin(a) * r)
	table.insert(lanterns, { part = p, speed = 3 + math.random() * 3, sway = math.random() * 6 })
end

local function startParty(themeId: string?)
	local theme = (themeId and Party.Themes[themeId]) or Party.Default
	themeColors = {}
	for _, c in theme.colors do
		table.insert(themeColors, rgb(c))
	end
	active = true
	tween(Lighting, { ClockTime = Party.BoomClockTime })
	if cc then
		tween(cc, { TintColor = rgb(theme.tint), Saturation = normal.saturation + 0.25 })
	end
	if atmosphere then
		tween(atmosphere, { Color = rgb(theme.sky), Haze = 1.6, Glare = 1.2 })
	end
	if bloom then
		tween(bloom, { Intensity = math.max(normal.bloom, 0.9) })
	end
	clearProps()
	-- Searchlights around the plaza edge
	for i = 1, Party.SkyBeams do
		local a = (i / Party.SkyBeams) * math.pi * 2
		local base = Vector3.new(math.cos(a) * 42, 0, math.sin(a) * 42)
		local p = neon(Vector3.new(260, 3, 3), themeColors[(i - 1) % #themeColors + 1], 0.6)
		p.Shape = Enum.PartType.Cylinder
		table.insert(beams, { part = p, base = base, phase = a, speed = 0.4 + (i % 3) * 0.15 })
	end
	-- Aurora: wavy ribbons of glowing segments across the sky
	for band = 1, Party.AuroraBands do
		for k = 0, 23 do
			local p = neon(Vector3.new(34, 14, 1), themeColors[(band - 1) % #themeColors + 1], 0.72)
			table.insert(aurora, { part = p, band = band, x = -400 + k * 34 })
		end
	end
	for _ = 1, Party.Lanterns do
		spawnLantern(true)
	end
end

local function stopParty()
	active = false
	tween(Lighting, { ClockTime = normal.clock })
	if cc then
		tween(cc, { TintColor = normal.tint, Saturation = normal.saturation })
	end
	if atmosphere then
		tween(atmosphere, { Color = normal.atmosphereColor, Haze = normal.haze, Glare = normal.glare })
	end
	if bloom then
		tween(bloom, { Intensity = normal.bloom })
	end
	-- let the props fade away
	for _, b in beams do
		TweenService:Create(b.part, TweenInfo.new(2), { Transparency = 1 }):Play()
	end
	for _, a in aurora do
		TweenService:Create(a.part, TweenInfo.new(2), { Transparency = 1 }):Play()
	end
	task.delay(2.2, function()
		if not active then
			clearProps()
		end
	end)
end

local function firework(center: Vector3)
	local a = math.random() * math.pi * 2
	local r = 40 + math.random() * Party.FireworkRadius
	local ground = Vector3.new(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r)
	local height = 70 + math.random() * 70
	local color = randomColor()
	local rocket = neon(Vector3.new(0.6, 1.6, 0.6), color, 0)
	rocket.Position = ground + Vector3.new(0, height * 0.35, 0)
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(0.6, 0)
	trail.Lifetime = NumberRange.new(0.4, 0.6)
	trail.Rate = 60
	trail.Speed = NumberRange.new(0)
	trail.Parent = rocket
	local flight = TweenService:Create(
		rocket,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = ground + Vector3.new(0, height, 0) }
	)
	flight:Play()
	flight.Completed:Connect(function()
		rocket.Transparency = 1
		trail.Enabled = false
		local burst = Instance.new("ParticleEmitter")
		local second = randomColor()
		burst.Color = ColorSequence.new(color, second)
		burst.LightEmission = 1
		burst.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
		burst.Lifetime = NumberRange.new(1.4, 2.2)
		burst.Speed = NumberRange.new(28, 40)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 2
		burst.Acceleration = Vector3.new(0, -8, 0)
		burst.Rate = 0
		burst.Parent = rocket
		burst:Emit(140)
		local flash = Instance.new("PointLight")
		flash.Color = color
		flash.Range = 60
		flash.Brightness = 4
		flash.Parent = rocket
		TweenService:Create(flash, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(rocket, 4)
end

local function animate(dt: number)
	local camera = workspace.CurrentCamera
	if not active or not camera then
		return
	end
	local t = os.clock()
	local center = camera.Focus.Position
	fireworkAcc += dt * Party.FireworksPerSecond
	while fireworkAcc >= 1 do
		fireworkAcc -= 1
		firework(center)
	end
	for i, b in beams do
		-- sweep: tilt 15-40 degrees from vertical, turning around
		local yaw = b.phase + t * b.speed
		local tilt = math.rad(15 + 25 * (0.5 + 0.5 * math.sin(t * 0.7 + b.phase)))
		local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)).UpVector
		local mid = b.base + dir * 130
		b.part.CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.rad(90), 0)
		b.part.Color = themeColors[(math.floor(t * 0.5) + i) % #themeColors + 1]
	end
	for _, a in aurora do
		local y = 170 + a.band * 18 + math.sin(a.x / 70 + t * 0.6 + a.band) * 12
		local z = -120 + a.band * 110 + math.sin(a.x / 110 + t * 0.4 + a.band * 2) * 40
		a.part.CFrame = CFrame.new(a.x, y, z) * CFrame.Angles(0, 0, math.sin(a.x / 50 + t) * 0.3)
	end
	for i = #lanterns, 1, -1 do
		local l = lanterns[i]
		local p = l.part
		p.Position += Vector3.new(math.sin(t + l.sway) * 0.02, l.speed * dt, 0)
		if p.Position.Y > 160 then
			p:Destroy()
			table.remove(lanterns, i)
			spawnLantern(false)
		end
	end
end

-- Admin fun: carrots raining from the sky around you (cosmetic, they bounce and vanish).
local function carrotRain()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local center = camera.Focus.Position
	for i = 1, 70 do
		task.delay(i * 0.08, function()
			local c = Instance.new("Part")
			c.Size = Vector3.new(0.7, 2, 0.7)
			c.Color = Color3.fromRGB(255, 136, 36)
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.CFrame = CFrame.new(
				center + Vector3.new(math.random(-45, 45), 60 + math.random() * 20, math.random(-45, 45))
			) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			local leaf = Instance.new("Part")
			leaf.Size = Vector3.new(0.4, 0.9, 0.4)
			leaf.Color = Color3.fromRGB(80, 180, 70)
			leaf.CanCollide = false
			leaf.CanQuery = false
			leaf.Massless = true
			leaf.CFrame = c.CFrame * CFrame.new(0, 1.4, 0)
			local w = Instance.new("WeldConstraint")
			w.Part0 = c
			w.Part1 = leaf
			w.Parent = leaf
			leaf.Parent = folder
			c.Parent = folder
			Debris:AddItem(c, 7)
			Debris:AddItem(leaf, 7)
		end)
	end
end

-- Admin fun: a big burst of confetti on screen-ish (around the camera).
local function confettiBurst()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local p = neon(Vector3.one, Color3.new(1, 1, 1), 1)
	p.Position = camera.Focus.Position + Vector3.new(0, 25, 0)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 100)),
	})
	e.Size = NumberSequence.new(0.6)
	e.Lifetime = NumberRange.new(3, 4)
	e.Speed = NumberRange.new(20, 35)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -10, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rate = 0
	e.Parent = p
	e:Emit(400)
	Debris:AddItem(p, 5)
end

-- A party is on during a boom, or while an admin party runs (workspace AdminPartyUntil).
local function wanted(): (boolean, string?)
	local state = Market.state()
	if state.boomActive then
		return true, state.boom.id
	end
	local admin = workspace:GetAttribute("AdminPartyUntil")
	if typeof(admin) == "number" and admin > workspace:GetServerTimeNow() then
		return true, nil
	end
	return false, nil
end

function BoomParty.start()
	folder = Instance.new("Folder")
	folder.Name = "BoomParty"
	folder.Parent = workspace
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	normal.clock = Lighting.ClockTime
	if cc then
		normal.tint = cc.TintColor
		normal.saturation = cc.Saturation
	end
	if atmosphere then
		normal.atmosphereColor = atmosphere.Color
		normal.haze = atmosphere.Haze
		normal.glare = atmosphere.Glare
	end
	if bloom then
		normal.bloom = bloom.Intensity
	end
	Remotes.get(Remotes.Names.AdminFx).OnClientEvent:Connect(function(fx)
		if typeof(fx) ~= "table" then
			return
		end
		if fx.kind == "carrotRain" then
			carrotRain()
		elseif fx.kind == "confetti" then
			confettiBurst()
		end
	end)
	local currentTheme: string? = nil
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			local on, themeId = wanted()
			if on and (not active or themeId ~= currentTheme) then
				currentTheme = themeId
				startParty(themeId)
			elseif not on and active then
				stopParty()
			end
		end
		animate(dt)
	end)
end

return BoomParty
