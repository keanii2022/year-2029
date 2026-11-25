-- Pure maths for how a shot looks and sounds: the travelling bullet streak, the recoil kick and
-- shake, which impact a surface gets and who hears a shot whiz past.
local CombatFeel = {}

-- Seconds the visual bullet takes to cross distance studs. Clamped so close shots still show a
-- streak and far shots land about when the server's confirmation comes back.
function CombatFeel.travelTime(distance: number, speed: number, minTime: number, maxTime: number): number
	return math.clamp(distance / speed, minTime, maxTime)
end

-- Where the streak sits along the shot at elapsed seconds, as distances from the muzzle.
-- The head runs ahead and the tail trails length studs behind it, both held inside the shot.
-- done is true once the head has reached the hit.
function CombatFeel.streakSpan(
	distance: number,
	elapsed: number,
	travelTime: number,
	length: number
): (number, number, boolean)
	local progress = if travelTime > 0 then elapsed / travelTime else 1
	local head = math.clamp(progress, 0, 1) * distance
	local tail = math.max(head - length, 0)
	return tail, head, progress >= 1
end

-- Kick strength from 0 to 1, sinceShot seconds after a shot: snaps up over rise seconds, then
-- eases back down to rest over settle seconds.
function CombatFeel.recoil(sinceShot: number, rise: number, settle: number): number
	if sinceShot < 0 then
		return 0
	end
	if sinceShot < rise then
		return sinceShot / rise
	end
	local back = (sinceShot - rise) / settle
	if back >= 1 then
		return 0
	end
	return (1 - back) * (1 - back)
end

export type ShotFeel = {
	sound: string,
	oncePerPull: number?,
	takes: { string }?,
	kick: number,
	twitch: number,
	fovPunch: number,
	shake: number,
	weight: number,
	followUp: string?,
	followUpDelay: number?,
}

-- The feel a gun shoots with: its own from gunFeel, else the default one.
function CombatFeel.shotFeel(
	gunFeel: { [string]: string },
	feels: { [string]: ShotFeel },
	defaultFeel: string,
	gunId: string?
): ShotFeel
	local name = gunId and gunFeel[gunId]
	return (name and feels[name]) or feels[defaultFeel]
end

-- Camera kick for one shot in degrees: straight up by kick, sideways by up to twitch either way.
-- roll is a random number from 0 to 1.
function CombatFeel.kickAngles(kick: number, twitch: number, roll: number): (number, number)
	return kick, (roll * 2 - 1) * twitch
end

-- Screen shake strength from 1 right after the shot down to 0 at duration, easing out.
function CombatFeel.shakeFade(sinceShot: number, duration: number): number
	if sinceShot < 0 or duration <= 0 or sinceShot >= duration then
		return 0
	end
	local left = 1 - sinceShot / duration
	return left * left
end

local METAL_MATERIALS = {
	Metal = true,
	DiamondPlate = true,
	CorrodedMetal = true,
	Foil = true,
}

-- Which impact sound and look a surface gets, from its material's name.
function CombatFeel.impactKind(materialName: string): "metal" | "concrete"
	return if METAL_MATERIALS[materialName] then "metal" else "concrete"
end

-- Whether a shot passed close enough to someone's head for them to hear it whiz by.
-- along: how far down the shot the head sits (studs from the shooter), shotLength: how far the
-- shot flew, miss: the head's distance from the closest point on the shot.
function CombatFeel.whizzes(
	along: number,
	shotLength: number,
	miss: number,
	radius: number,
	minDistance: number
): boolean
	return miss <= radius and along >= minDistance and along <= shotLength + radius
end

return CombatFeel
