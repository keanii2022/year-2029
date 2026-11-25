-- Daily streaks: finishing the day's mission list counts that calendar day (UTC). A missed day
-- pauses the streak instead of wiping it, so coming back after a week picks up where you left off.
-- No Roblox here.
export type State = { days: number, lastDay: number }
export type Status = "new" | "done" | "live" | "paused"
export type Reward = { day: number, tokens: number }

local SECONDS_PER_DAY = 86400

local Streak = {}

function Streak.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / SECONDS_PER_DAY)
end

-- Counts today once. True when it counted (the first finished list of the day).
function Streak.complete(state: State, today: number): boolean
	if today <= state.lastDay then
		return false
	end
	state.days += 1
	state.lastDay = today
	return true
end

-- new: never finished a list. done: today already counted. live: yesterday counted, today is
-- open. paused: missed at least a day; the count waits.
function Streak.status(state: State, today: number): Status
	if state.days <= 0 then
		return "new"
	elseif state.lastDay >= today then
		return "done"
	elseif state.lastDay == today - 1 then
		return "live"
	end
	return "paused"
end

-- Rewards whose day was reached going from `before` days to `after` days
function Streak.rewardsReached(rewards: { Reward }, before: number, after: number): { Reward }
	local reached = {}
	for _, reward in rewards do
		if reward.day > before and reward.day <= after then
			table.insert(reached, reward)
		end
	end
	return reached
end

-- "STREAK 3", "STREAK 3 PAUSED", or "" before the first finished list
function Streak.label(texts: { [string]: string }, state: State, today: number): string
	local status = Streak.status(state, today)
	if status == "new" then
		return ""
	end
	local text = if status == "paused" then texts.Paused else texts.Live
	return (string.gsub(text, "{days}", tostring(state.days)))
end

return Streak
