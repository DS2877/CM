--!strict
-- Social numbers (design doc §6).

local Social = {
	-- Water a friend: tapping another player's plot gives BOTH players faster growth.
	WaterGrowthBonus = 0.10, -- +10 % growth speed (grow time / 1.10)
	WaterSeconds = 120,
	WaterCooldown = 120, -- per waterer per farm
	WaterRange = 70, -- studs from that farm's center

	-- Friend bonus: +10 % luck per friend in the server, max 3.
	FriendLuckBonus = 0.10,
	FriendMax = 3,

	-- Likes: one heart per farm per day.
	LikeRange = 14,

	-- Leaderboards (OrderedDataStore). Weekly board resets every Monday 00:00 UTC.
	LeaderboardSize = 10,
	LeaderboardRefresh = 60, -- seconds between reads
	LeaderboardFlush = 60, -- seconds between writes

	-- Cross-server announcements (MessagingService) for announce level 3.
	AnnounceTopic = "CM_Announce",
}

return Social
