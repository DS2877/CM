--!strict
-- Global market events (phase 3). Schedule is derived from os.time so all servers agree.

local Events = {
	Enabled = false,
	CycleSeconds = 600,
	BoomSeconds = 180,
	BoomMultiplier = 2,
}

return Events
