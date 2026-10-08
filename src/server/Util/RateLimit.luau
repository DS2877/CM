--!strict
-- Token-bucket rate limiter per player. `RateLimit.new(rate, burst)` returns a function that
-- answers "may this player act now?" and consumes a token if so.

local RateLimit = {}

type Bucket = { tokens: number, last: number }

function RateLimit.new(rate: number, burst: number): (player: Player) -> boolean
	local buckets: { [Player]: Bucket } = setmetatable({}, { __mode = "k" }) :: any
	return function(player: Player): boolean
		local now = os.clock()
		local b = buckets[player]
		if not b then
			b = { tokens = burst, last = now }
			buckets[player] = b
		end
		b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
		b.last = now
		if b.tokens < 1 then
			return false
		end
		b.tokens -= 1
		return true
	end
end

return RateLimit
