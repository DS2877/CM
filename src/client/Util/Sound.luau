--!strict
-- Plays sounds by name from Config/Assets. Empty IDs are silent (asset not uploaded yet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Sound = {}

export type Options = {
	volume: number?,
	speed: number?,
	parent: Instance?, -- a BasePart/Attachment makes it positional
}

function Sound.play(name: string, options: Options?)
	local id = (Assets.Sounds :: any)[name] :: string?
	if not id or id == "" then
		return
	end
	local o: Options = options or {}
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = o.volume or 0.5
	s.PlaybackSpeed = o.speed or 1
	s.RollOffMaxDistance = 160
	if o.parent then
		s.Parent = o.parent
	else
		s.Parent = SoundService
	end
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

return Sound
