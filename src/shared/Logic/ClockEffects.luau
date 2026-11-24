-- Timing for the lighting and sound cues: the red siren pulse, the flicker when the lights die,
-- and when the spoken countdown starts.
local ClockEffects = {}

-- 0 to 1 and back, `rate` times a second. Starts dark so the first flash reads as the alarm kicking in.
function ClockEffects.sirenPulse(elapsed: number, rate: number): number
	return math.abs(math.sin(elapsed * rate * math.pi))
end

-- Pattern is alternating segment lengths in seconds, starting with lights off.
-- Returns whether the lights are on at `elapsed`, and whether the flicker is over (lights stay off after).
function ClockEffects.flicker(elapsed: number, pattern: { number }): (boolean, boolean)
	local t = 0
	for index, duration in pattern do
		t += duration
		if elapsed < t then
			return index % 2 == 0, false
		end
	end
	return false, true
end

-- Seconds from now until the countdown line should start so its last word lands on lights out.
-- nil when there's no longer room for the whole line (joined late).
function ClockEffects.countdownDelay(timeLeft: number, lead: number): number?
	if timeLeft < lead then
		return nil
	end
	return timeLeft - lead
end

return ClockEffects
