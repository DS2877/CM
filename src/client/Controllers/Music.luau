--!strict
-- Music director (mix in Config/Audio, playlists in Config/Assets.Music / Ambience).
--   * Farm: a playlist of calm ukulele/acoustic tracks, the default state.
--   * Boom: upbeat country/folk while a market boom runs (global schedule, so everyone's music
--     switches together; with the bell it says "go sell now").
--   * Ambience: a birdsong meadow bed everywhere plus crowd walla positioned at the market.
-- Each state plays its playlist in order (wrapping). Switching states crossfades: the old
-- state's track pauses at silence and resumes where it left off when its state returns, so
-- the farm music doesn't restart after every boom. Big moments duck the music bus
-- (Util/Sound.duck). The 🎵 toggle is saved in the profile and arrives as "MusicOff".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Assets = require(Config.Assets)
local Audio = require(Config.Audio)
local Market = require(Shared.Market)
local Remotes = require(Shared.Remotes)

local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local Music = {}

type Channel = {
	playlist: { string },
	index: number,
	sound: Sound?,
	active: boolean,
	fade: Tween?,
}

local channels: { [string]: Channel } = {}
local current = ""

local function list(raw: any): { string }
	if typeof(raw) == "string" then
		return if raw ~= "" then { raw } else {}
	end
	local out = {}
	if typeof(raw) == "table" then
		for _, id in raw do
			if typeof(id) == "string" and id ~= "" then
				table.insert(out, id)
			end
		end
	end
	return out
end

local function fade(ch: Channel, target: number, seconds: number, after: (() -> ())?)
	local s = ch.sound
	if not s then
		return
	end
	if ch.fade then
		ch.fade:Cancel()
	end
	local t = TweenService:Create(s, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = target })
	ch.fade = t
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and after then
			after()
		end
	end)
	t:Play()
end

-- Start the channel's current track (creating the Sound), at silence.
local function load(ch: Channel)
	local id = ch.playlist[ch.index]
	if not id then
		return
	end
	if ch.sound then
		ch.sound:Destroy()
	end
	local s = Instance.new("Sound")
	s.Name = "Music"
	s.SoundId = id
	s.Volume = 0
	s.Looped = #ch.playlist == 1
	s.SoundGroup = Sound.bus("Music")
	s.Parent = SoundService
	ch.sound = s
	s.Ended:Connect(function()
		-- Next track in the playlist; keep playing if this state is still the active one.
		ch.index = ch.index % #ch.playlist + 1
		load(ch)
		local nextSound = ch.sound
		if nextSound and ch.active then
			nextSound:Play()
			fade(ch, 1, 1.5)
		end
	end)
end

local function activate(name: string)
	if name == current then
		return
	end
	current = name
	for state, ch in channels do
		local s = ch.sound
		if not s then
			continue
		end
		if state == name then
			ch.active = true
			if s.IsPaused or not s.IsPlaying then
				s:Resume()
				if not s.IsPlaying then
					s:Play()
				end
			end
			fade(ch, 1, Audio.CrossfadeSeconds)
		elseif ch.active then
			ch.active = false
			fade(ch, 0, Audio.CrossfadeSeconds, function()
				if not ch.active and ch.sound then
					ch.sound:Pause()
				end
			end)
		end
	end
end

local function applyToggle()
	Sound.setMusicEnabled(player:GetAttribute("MusicOff") ~= true)
end

function Music.toggle()
	local off = player:GetAttribute("MusicOff") == true
	-- Optimistic: switch now, the server saves it and echoes the attribute.
	player:SetAttribute("MusicOff", not off)
	Remotes.get(Remotes.Names.SetMusic):FireServer(off)
end

function Music.start()
	for state, raw in Assets.Music :: { [string]: any } do
		local playlist = list(raw)
		if #playlist > 0 then
			local ch: Channel = { playlist = playlist, index = 1, sound = nil, active = false, fade = nil }
			channels[state] = ch
			load(ch)
		end
	end

	local meadow = Sound.loop(Assets.Ambience.Meadow, "Ambience")
	if meadow then
		TweenService:Create(meadow, TweenInfo.new(4), { Volume = 1 }):Play()
	end
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		local market = world:WaitForChild("Market")
		local anchor = market:WaitForChild("SellPoint") :: BasePart
		local crowd = Sound.loop(Assets.Ambience.Market, "Ambience", anchor)
		if crowd then
			crowd.Volume = 0.9
		end
	end)

	applyToggle()
	player:GetAttributeChangedSignal("MusicOff"):Connect(applyToggle)

	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local state = Market.state()
		local want = if state.boomActive and channels.Boom then "Boom" else "Farm"
		if channels[want] then
			activate(want)
		end
	end)
end

return Music
