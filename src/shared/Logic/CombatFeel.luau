-- Pure timing for how a shot looks: the travelling bullet streak and the recoil kick.
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

return CombatFeel
