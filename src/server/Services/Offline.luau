--!strict
-- Offline: your planted carrots keep growing while you're away, and that's all.
--
-- What is in the ground when you leave is saved (Farm.snapshot): each plot's already-rolled
-- carrot and the time it still needed (also every 30 s, in case a server dies). On return each
-- carrot goes back in its plot with the time away subtracted; finished ones are ready to tap.
-- You harvest them yourself. You can never get more carrots than you planted, and empty plots
-- stay empty (OfflinePlan holds the math, with tests).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local OfflinePlan = require(Shared.OfflinePlan)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Farm = require(script.Parent.Farm)

local Offline = {}

local SAVE_INTERVAL = 30
local WELCOME_AFTER = 60 -- seconds away before a "welcome back" note is worth showing

-- Players whose saved plots have been put back. Until then the farm in the server is not theirs
-- yet, so saving it would wipe what they left in the ground.
local restored: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Saves what is in the ground and when. Safe to call any time; does nothing until the player's
-- saved plots have been restored (or if they have no farm in this server).
function Offline.touch(player: Player)
	local data = Data.get(player)
	if not data or not restored[player] then
		return
	end
	local saved = Farm.snapshot(player)
	if saved then
		data.Growing = saved
		data.LastOnline = os.time()
	end
end

-- Call once the farm is assigned. Puts the saved carrots back in their plots, grown by the time
-- the player was away.
function Offline.restore(player: Player)
	local data = Data.get(player)
	if not data or restored[player] then
		return
	end
	if player:GetAttribute("FarmId") == nil then
		-- No farm in this server (all taken): keep the saved plots for next time.
		return
	end

	local away = if data.LastOnline > 0 then os.time() - data.LastOnline else 0
	local saved = data.Growing
	data.Growing = {}

	local inputs: { OfflinePlan.SavedInput } = {}
	local savedBy: { [number]: Data.SavedPlot } = {}
	for key, s in saved do
		local index = tonumber(key)
		if index and index >= 1 and index <= Farm.unlockedPlots(player) then
			savedBy[index] = s
			table.insert(inputs, { index = index, remaining = s.Remaining })
		end
	end

	local plan = OfflinePlan.make(inputs, away)
	local ready = 0
	for _, p in plan.plots do
		local s = savedBy[p.index]
		local roll = s and Farm.rollFromKey(s.Key)
		-- A carrot whose type no longer exists in the config is simply gone (never happens in
		-- normal play; config ids are stable).
		if s and roll then
			if Farm.restorePlot(player, p.index, roll, p.remaining, s.GrowTime, s.Seed) then
				if p.remaining <= 0 then
					ready += 1
				end
			else
				-- The player already replanted this plot in the first second: the carrot they
				-- left goes to their basket instead of vanishing (still never more than planted).
				local carrot: Types.Carrot =
					{ type = roll.type, size = roll.size, mutations = roll.mutations }
				Economy.addCarrot(player, carrot)
			end
		end
	end

	restored[player] = true
	Offline.touch(player)

	if away >= WELCOME_AFTER then
		local notice = Remotes.get(Remotes.Names.Notice)
		if ready > 0 then
			notice:FireClient(player, {
				text = string.format(
					"Welcome back! %d carrot%s ready to harvest 🥕",
					ready,
					if ready == 1 then " is" else "s are"
				),
				kind = "good",
			})
		elseif #plan.plots == 0 and data.Stats.Plantings > 0 then
			notice:FireClient(player, {
				text = "Tip: plant before you leave – carrots keep growing while you're away!",
				kind = "good",
			})
		end
	end
end

-- Last save before the player's farm is released.
function Offline.leave(player: Player)
	Offline.touch(player)
	restored[player] = nil
end

function Offline.start(getPlayers: () -> { Player })
	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for _, player in getPlayers() do
				Offline.touch(player)
			end
		end
	end)
end

return Offline
