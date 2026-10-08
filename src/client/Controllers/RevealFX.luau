--!strict
-- Three-step growth reveal (design doc §2). Only shown when something is really there:
--   1 shimmer in the soil  (Rare or better, or any mutation)  — from 25 % growth
--   2 sparks               (Epic or better)                   — from 50 % growth
--   3 light pillar + sound (Legendary or better), seen by everyone — from 75 % growth
-- The colors are fixed per step so they never hint at more than the step promises.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarrotInfo = require(ReplicatedStorage.Shared.CarrotInfo)
local Sound = require(script.Parent.Parent.Util.Sound)

local RevealFX = {}

export type Handle = {
	plot: BasePart,
	level: number,
	shimmer: ParticleEmitter?,
	sparks: ParticleEmitter?,
	pillar: Part?,
	light: PointLight?,
	fxFolder: Folder,
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PILLAR_COLOR = Color3.fromRGB(255, 215, 90)
local SHIMMER_COLOR = Color3.fromRGB(255, 250, 220)
local SPARK_COLOR = Color3.fromRGB(205, 140, 255)

-- Plot height (center at 0.4, top at 0.8). Reveal starts a step after these growth fractions.
RevealFX.Thresholds = { 0.25, 0.5, 0.75 }

function RevealFX.new(plot: BasePart, fxFolder: Folder): Handle
	return { plot = plot, level = 0, fxFolder = fxFolder }
end

local function makeEmitter(plot: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = plot
	return e
end

local function setShimmer(h: Handle, on: boolean)
	if on and not h.shimmer then
		h.shimmer = makeEmitter(h.plot, {
			Name = "RevealShimmer",
			Rate = 14,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.6, 1.8),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(SHIMMER_COLOR),
			Transparency = NumberSequence.new(0.1),
		})
	elseif not on and h.shimmer then
		h.shimmer:Destroy()
		h.shimmer = nil
	end
end

local function setSparks(h: Handle, on: boolean)
	if on and not h.sparks then
		h.sparks = makeEmitter(h.plot, {
			Name = "RevealSparks",
			Rate = 22,
			Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(6, 11),
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -18, 0),
			Size = NumberSequence.new(0.35, 0),
			Color = ColorSequence.new(SPARK_COLOR, Color3.new(1, 1, 1)),
		})
	elseif not on and h.sparks then
		h.sparks:Destroy()
		h.sparks = nil
	end
end

local function setPillar(h: Handle, on: boolean)
	if on and not h.pillar then
		local p = Instance.new("Part")
		p.Name = "RevealPillar"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = PILLAR_COLOR
		p.Transparency = 0.45
		p.Shape = Enum.PartType.Cylinder
		local height = 90
		p.Size = Vector3.new(height, 2.6, 2.6)
		p.CFrame = CFrame.new(h.plot.Position + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		p.Parent = h.fxFolder
		local light = Instance.new("PointLight")
		light.Color = PILLAR_COLOR
		light.Range = 18
		light.Brightness = 3
		light.Parent = h.plot
		h.pillar = p
		h.light = light
		Sound.play("Pillar", { parent = h.plot :: Instance, volume = 0.8 })
	elseif not on and h.pillar then
		h.pillar:Destroy()
		h.pillar = nil
		if h.light then
			h.light:Destroy()
			h.light = nil
		end
	end
end

-- Show reveal step `level` (0..3).
function RevealFX.set(h: Handle, level: number)
	if level == h.level then
		return
	end
	if level >= 1 and h.level < 1 then
		Sound.play("Shimmer", { parent = h.plot :: Instance, volume = 0.4 })
	end
	h.level = level
	setShimmer(h, level >= 1)
	setSparks(h, level >= 2)
	setPillar(h, level >= 3)
end

-- Once ready, the pillar takes the real rarity color.
function RevealFX.colorFor(h: Handle, rarityId: string)
	local r = CarrotInfo.rarity(rarityId)
	if r and h.pillar then
		local c = CarrotInfo.color(r.color)
		h.pillar.Color = c
		if h.light then
			h.light.Color = c
		end
	end
end

-- Gentle pulse for the pillar.
function RevealFX.animate(h: Handle, t: number)
	if h.pillar then
		h.pillar.Transparency = 0.4 + 0.15 * math.sin(t * 4)
	end
end

function RevealFX.clear(h: Handle)
	RevealFX.set(h, 0)
end

return RevealFX
