--!strict
-- Music director (Config/Audio, assets in Config/Assets.Music / Ambience).
--   * Farm: calm folk-pop loop, the default state.
--   * Boom: upbeat market track while a market boom runs (global schedule, so everyone's music
--     switches together and the bell + music change tell you "go sell now").
--   * Ambience: a meadow bed everywhere plus crowd chatter positioned at the market.
-- States crossfade; big moments duck the music bus (Util/Sound.duck). The 🎵 toggle is saved in
-- the player's profile (server) and arrives as the "MusicOff" attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Assets = require(Config.Assets)
local Audio = require(Config.Audio)
local Events = require(Config.Events)
local EventSchedule = require(Shared.EventSchedule)
local Remotes = require(Shared.Remotes)

local Sound = require(script.Parent.Parent.Util.Sound)

local player = Players.LocalPlayer

local Music = {}

local cfg: EventSchedule.EventsConfig = Events :: any
local tracks: { [string]: Sound } = {}
local current = ""

local function fadeTo(state: string)
	if state == current then
		return
	end
	current = state
	for name, s in tracks do
		TweenService:Create(s, TweenInfo.new(Audio.CrossfadeSeconds, Enum.EasingStyle.Sine), {
			Volume = if name == state then 1 else 0,
		}):Play()
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
	for state, id in Assets.Music :: { [string]: string } do
		local s = Sound.loop(id, "Music")
		if s then
			tracks[state] = s
		end
	end
	local meadow = Sound.loop(Assets.Ambience.Meadow, "Ambience")
	if meadow then
		TweenService:Create(meadow, TweenInfo.new(3), { Volume = 1 }):Play()
	end
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		local anchor = world:WaitForChild("PriceBoardAnchor") :: BasePart
		local crowd = Sound.loop(Assets.Ambience.Market, "Ambience", anchor)
		if crowd then
			crowd.Volume = 1.2
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
		local state = EventSchedule.at(workspace:GetServerTimeNow(), cfg)
		local want = if state.boomActive and tracks.Boom then "Boom" else "Farm"
		fadeTo(want)
	end)
end

return Music
