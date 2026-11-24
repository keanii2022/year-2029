-- Day and night clock math. Phases loop Day -> Siren -> Night -> Day; reaching Day again is
-- morning, which bumps the day counter. Times are server seconds (workspace:GetServerTimeNow()).
export type Phase = "Day" | "Siren" | "Night"
export type Lengths = { Day: number, Siren: number, Night: number }
export type State = { phase: Phase, endsAt: number, day: number }
export type Transition = { from: Phase, to: Phase, day: number, startedAt: number }

local Clock = {}

local NEXT: { [Phase]: Phase } = { Day = "Siren", Siren = "Night", Night = "Day" }

function Clock.next(phase: Phase): Phase
	return NEXT[phase]
end

function Clock.isNight(phase: Phase): boolean
	return phase == "Night"
end

-- Short lengths win when the debug switch is on, so playtests can loop in a minute or two.
function Clock.lengths(settings: { Lengths: Lengths, ShortCycle: boolean, ShortLengths: Lengths }): Lengths
	local lengths = if settings.ShortCycle then settings.ShortLengths else settings.Lengths
	for phase in NEXT do
		assert(lengths[phase] > 0, `{phase} length must be above zero`)
	end
	return lengths
end

function Clock.start(now: number, lengths: Lengths): State
	return { phase = "Day", endsAt = now + lengths.Day, day = 1 }
end

-- Moves the clock up to now. A long server hitch can cross several phases, so each one is listed in order.
function Clock.advance(state: State, now: number, lengths: Lengths): (State, { Transition })
	local phase, endsAt, day = state.phase, state.endsAt, state.day
	local transitions: { Transition } = {}
	while now >= endsAt do
		local from = phase
		phase = NEXT[phase]
		if phase == "Day" then
			day += 1
		end
		table.insert(transitions, { from = from, to = phase, day = day, startedAt = endsAt })
		endsAt += lengths[phase]
	end
	return { phase = phase, endsAt = endsAt, day = day }, transitions
end

function Clock.timeLeft(endsAt: number, now: number): number
	return math.max(0, endsAt - now)
end

return Clock
