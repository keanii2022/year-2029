-- The untamed dog's far-off calls: a bark, a soft howl or a whine every so often, so players know
-- there's a dog somewhere without it being easy to find. More around dawn and dusk, quiet at night
-- unless something scared it. Each call plays from a spot bounced off toward a wall, and sounds
-- more muffled the farther away you are.
export type Mood = "dawn" | "day" | "dusk" | "night"
export type Call = "Bark" | "Howl" | "Whine"
export type Settings = {
	Gap: { number }, -- seconds between calls
	EdgeGapScale: number, -- dawn and dusk gaps are this much shorter
	EdgeSeconds: number, -- first and last seconds of the day that count as dawn and dusk
	QuietRange: number, -- no far calls while someone is this close; it's in front of them
	Weights: { [string]: { [string]: number } }, -- per mood (and "scared"): call -> weight
	Bounce: { number }, -- studs from the dog the call seems to come from
	WallPad: number, -- stop this far short of the wall it bounces off
	Muffle: { Near: number, Far: number, HighCut: number, MidCut: number },
}

local DogCalls = {}

local CALLS: { Call } = { "Bark", "Howl", "Whine" }

-- Siren counts as dusk; the light is going.
function DogCalls.mood(phase: string, elapsed: number, timeLeft: number, edgeSeconds: number): Mood
	if phase == "Night" then
		return "night"
	elseif phase == "Siren" then
		return "dusk"
	elseif elapsed < edgeSeconds then
		return "dawn"
	elseif timeLeft < edgeSeconds then
		return "dusk"
	end
	return "day"
end

-- Seconds until the next call, or nil when it keeps quiet (night and not scared). roll is 0-1.
function DogCalls.gap(mood: Mood, scared: boolean, roll: number, settings: Settings): number?
	if mood == "night" and not scared then
		return nil
	end
	local gap = settings.Gap[1] + (settings.Gap[2] - settings.Gap[1]) * roll
	if mood == "dawn" or mood == "dusk" then
		gap *= settings.EdgeGapScale
	end
	return gap
end

function DogCalls.shouldCall(nearestDistance: number?, settings: Settings): boolean
	return nearestDistance == nil or nearestDistance > settings.QuietRange
end

-- Which call, weighted by mood; a scared dog mostly whines. roll is 0-1.
function DogCalls.pick(mood: Mood, scared: boolean, roll: number, settings: Settings): Call
	local weights = settings.Weights[if scared then "scared" else mood] or settings.Weights.day
	local total = 0
	for _, call in CALLS do
		total += weights[call] or 0
	end
	local pick = roll * total
	for _, call in CALLS do
		local weight = weights[call] or 0
		if weight > 0 and pick < weight then
			return call
		end
		pick -= weight
	end
	return "Whine"
end

-- How far toward the chosen direction the call seems to come from: a roll inside Bounce, cut short
-- by a wall in the way (wallDistance, nil when open), but never closer than the minimum.
function DogCalls.bounceDistance(wallDistance: number?, roll: number, settings: Settings): number
	local low, high = settings.Bounce[1], settings.Bounce[2]
	local distance = low + (high - low) * roll
	if wallDistance then
		distance = math.min(distance, wallDistance - settings.WallPad)
	end
	return math.max(low, distance)
end

-- Sound names to try for a Config.Dog.Sounds key, in order: its own, then its fallback's.
function DogCalls.soundNames(
	key: string,
	sounds: { [string]: string },
	fallbacks: { [string]: string }
): { string }
	local names = { sounds[key] }
	local fallback = fallbacks[key]
	if fallback and sounds[fallback] then
		table.insert(names, sounds[fallback])
	end
	return names
end

-- Equalizer cuts (dB, negative) for a listener this far away: none up close, full past Far.
function DogCalls.muffle(distance: number, settings: Settings): (number, number)
	local muffle = settings.Muffle
	local t = math.clamp((distance - muffle.Near) / (muffle.Far - muffle.Near), 0, 1)
	return muffle.HighCut * t, muffle.MidCut * t
end

return DogCalls
