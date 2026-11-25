-- Pure server-side speed check. Each step earns distance at the allowed speed (times Slack) into a
-- budget capped at BurstSeconds of movement, so lag that bunches movement up still fits. Moving more
-- than the budget is a strike; far over in one go, or MaxStrikes strikes, means pull back.
local MoveCheck = {}

export type Settings = {
	Slack: number,
	BurstSeconds: number,
	BadlyOver: number,
	MaxStrikes: number,
	StrikeDecay: number,
}
export type State = { credit: number, strikes: number }

function MoveCheck.new(maxSpeed: number, settings: Settings): State
	return { credit = maxSpeed * settings.BurstSeconds, strikes = 0 }
end

-- moved: horizontal studs since the last step. True when the player should be pulled back.
function MoveCheck.step(
	state: State,
	moved: number,
	dt: number,
	maxSpeed: number,
	settings: Settings
): boolean
	local cap = maxSpeed * settings.BurstSeconds
	state.credit = math.min(cap, state.credit + maxSpeed * settings.Slack * dt) - moved
	if state.credit >= 0 then
		state.strikes = math.max(0, state.strikes - settings.StrikeDecay * dt)
		return false
	end
	local over = -state.credit
	state.credit = 0
	state.strikes += 1
	if over > settings.BadlyOver or state.strikes >= settings.MaxStrikes then
		state.strikes = 0
		return true
	end
	return false
end

return MoveCheck
