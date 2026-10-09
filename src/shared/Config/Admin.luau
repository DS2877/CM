--!strict
-- Who may open the admin dashboard. The experience owner is always an admin (user-owned game:
-- the creator; group-owned: rank >= GroupMinRank). Everyone is an admin in Studio for testing.
-- Add extra admins by user id here.

local Admin = {
	UserIds = {} :: { number },
	GroupMinRank = 254,
	Topic = "CM_Admin", -- MessagingService topic for admin broadcasts to every server
	MessageSeconds = 9, -- how long the avatar speech bubble stays on screen
	MaxMessageLength = 140,
	DefaultBoomSeconds = 180,
	PartySeconds = 120, -- admin sky party (fireworks, beams, aurora) without a boom
	BunnyPartySeconds = 60, -- the market bunnies dance
	SuperSpeed = 60,
	MoonJumpPower = 120,
	GiantScale = 2.5,
	TinyScale = 0.4,
}

return Admin
