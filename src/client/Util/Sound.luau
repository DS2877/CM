--!strict
-- Sound engine. Cues are defined in Config/Audio (mix, pitch, cooldown, ducking) and their IDs in
-- Config/Assets. Every cue plays through a bus (SoundGroup) so the mix and the music toggle work
-- in one place.
--   Sound.play("Harvest")                     -- 2D
--   Sound.play("Pillar", { parent = plot })   -- 3D, from a part
--   Sound.combo("Harvest")                    -- climbs in pitch during quick streaks
--   Sound.duck(3)                             -- music steps aside for a big moment

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage.Shared.Config
local Assets = require(Config.Assets)
local Audio = require(Config.Audio)

local Sound = {}

export type Options = {
	volume: number?, -- multiplier on the cue's volume
	speed: number?, -- multiplier on the cue's pitch
	parent: Instance?, -- a BasePart/Attachment makes it positional (for positional cues)
}

local groups: { [string]: SoundGroup } = {}
local lastPlayed: { [string]: number } = {}
local musicBase = Audio.Groups.Music
local musicEnabled = true
local duckUntil = 0
local comboStep = 0
local comboLast = 0

local function group(name: string): SoundGroup
	local g = groups[name]
	if g then
		return g
	end
	local sg = Instance.new("SoundGroup")
	sg.Name = "Bus_" .. name
	sg.Volume = (Audio.Groups :: any)[name] or 0.5
	sg.Parent = SoundService
	groups[name] = sg
	return sg
end

-- Resolve a cue to (asset id, extra pitch). Follows fallbacks so an unassigned cue borrows a
-- related sound at another pitch instead of going silent.
local function resolve(name: string): (string?, number)
	local pitch = 1
	local current: string? = name
	for _ = 1, 4 do
		if not current then
			break
		end
		local raw = (Assets.Sounds :: any)[current]
		local id: string? = nil
		if typeof(raw) == "table" and #raw > 0 then
			id = raw[math.random(1, #raw)]
		elseif typeof(raw) == "string" and raw ~= "" then
			id = raw
		end
		if id then
			return id, pitch
		end
		local cue = Audio.Cues[current]
		if not cue or not cue.fallback then
			break
		end
		pitch *= cue.fallbackPitch or 1
		current = cue.fallback
	end
	return nil, 1
end

function Sound.bus(name: string): SoundGroup
	return group(name)
end

function Sound.play(name: string, options: Options?)
	local cue = Audio.Cues[name]
	if not cue then
		return
	end
	local clock = os.clock()
	if cue.cooldown and lastPlayed[name] and clock - lastPlayed[name] < cue.cooldown then
		return
	end
	local id, fallbackPitch = resolve(name)
	if not id then
		return
	end
	lastPlayed[name] = clock
	local o: Options = options or {}
	local lo, hi = cue.pitch[1] or 1, cue.pitch[2] or cue.pitch[1] or 1
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = cue.volume * (o.volume or 1)
	s.PlaybackSpeed = (lo + (hi - lo) * math.random()) * fallbackPitch * (o.speed or 1)
	s.SoundGroup = group(cue.group)
	if cue.positional and o.parent then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 140
		s.Parent = o.parent
	else
		s.Parent = SoundService
	end
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(12, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	if cue.duck then
		Sound.duck(cue.duck)
	end
end

-- Quick streaks climb in pitch (one step per play inside the window), like coin pickups.
function Sound.combo(name: string, options: Options?)
	local clock = os.clock()
	if clock - comboLast <= Audio.ComboWindow then
		comboStep = math.min(comboStep + 1, Audio.ComboMaxSteps)
	else
		comboStep = 0
	end
	comboLast = clock
	local o: Options = options or {}
	Sound.play(name, {
		volume = o.volume,
		parent = o.parent,
		speed = (o.speed or 1) * (1 + comboStep * Audio.ComboStep),
	})
end

local function musicTarget(): number
	if not musicEnabled then
		return 0
	end
	if os.clock() < duckUntil then
		return musicBase * Audio.DuckTo
	end
	return musicBase
end

local function applyMusic(fade: number)
	local bus = group("Music")
	TweenService:Create(bus, TweenInfo.new(fade), { Volume = musicTarget() }):Play()
end

-- Music steps aside for `seconds` (a big reveal, the market bell), then comes back gently.
function Sound.duck(seconds: number)
	local untilTime = os.clock() + seconds
	if untilTime <= duckUntil then
		return
	end
	duckUntil = untilTime
	applyMusic(Audio.DuckFadeIn)
	task.delay(seconds, function()
		if os.clock() >= duckUntil - 0.01 then
			applyMusic(Audio.DuckFadeOut)
		end
	end)
end

function Sound.setMusicEnabled(enabled: boolean)
	musicEnabled = enabled
	applyMusic(0.6)
	-- Ambience follows the music toggle at a lower level, so "music off" is genuinely quiet.
	local amb = group("Ambience")
	TweenService:Create(amb, TweenInfo.new(0.6), {
		Volume = if enabled then Audio.Groups.Ambience else Audio.Groups.Ambience * 0.4,
	}):Play()
end

function Sound.musicEnabled(): boolean
	return musicEnabled
end

-- A looping track on a bus (music/ambience). Returns nil when the asset isn't set.
function Sound.loop(id: string, busName: string, parent: Instance?): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = group(busName)
	if parent then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 90
		s.Parent = parent
	else
		s.Parent = SoundService
	end
	s:Play()
	return s
end

return Sound
