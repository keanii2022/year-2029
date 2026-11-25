-- How robots move and look, no Roblox here: a head that turns too smoothly on a stiff body, a body
-- that holds dead still between short bursts, a head tilt now and then, and a day robot noticing
-- it's being stared at.
local RobotMotion = {}

export type Point = { x: number, z: number }
export type Burst = { moving: boolean, untilAt: number }
export type Watch = { looked: number, away: number, frozen: boolean }

-- Head yaw in degrees for a target at (localX, localZ) in the body's space (+z ahead), as far as the
-- neck goes.
function RobotMotion.headYaw(localX: number, localZ: number, maxTurn: number): number
	return math.clamp(math.deg(math.atan2(localX, localZ)), -maxTurn, maxTurn)
end

-- One step of the head toward target: a steady speed (degrees per second), slowing over the last
-- ease degrees so it settles without overshoot. Never twitchy, which is the point.
function RobotMotion.turnHead(
	current: number,
	target: number,
	dt: number,
	speed: number,
	ease: number
): number
	local gap = target - current
	local rate = speed * math.clamp(math.abs(gap) / ease, 0.15, 1)
	return current + math.sign(gap) * math.min(math.abs(gap), rate * dt)
end

-- Degrees of sideways head tilt at clock: every Every seconds it leans for Hold seconds, easing in and
-- out, alternating sides. seed (0..1) staggers robots so they don't tilt together.
function RobotMotion.tilt(
	clock: number,
	seed: number,
	tilt: { Every: number, Hold: number, Degrees: number }
): number
	local t = clock + seed * tilt.Every
	local into = t % tilt.Every
	if into >= tilt.Hold then
		return 0
	end
	local side = if math.floor(t / tilt.Every) % 2 == 0 then 1 else -1
	return side * tilt.Degrees * math.sin(math.pi * into / tilt.Hold)
end

-- Walking hunters hold dead still, then burst. Returns the gate (moving or still until untilAt) and
-- the walk speed factor for now. roll (0..1) picks each stretch's length inside its range.
function RobotMotion.burst(
	gate: Burst?,
	now: number,
	roll: number,
	settings: { Move: { number }, Still: { number }, Speed: number }
): (Burst, number)
	local current = gate
	if not current or now >= current.untilAt then
		local moving = not (current and current.moving)
		local range = if moving then settings.Move else settings.Still
		current = { moving = moving, untilAt = now + range[1] + (range[2] - range[1]) * roll }
	end
	return current, if current.moving then settings.Speed else 0
end

-- True when someone at from, facing look, has at within range and inside angle degrees of dead ahead.
function RobotMotion.looksAt(from: Point, look: Point, at: Point, range: number, angle: number): boolean
	local dx, dz = at.x - from.x, at.z - from.z
	local d = math.sqrt(dx * dx + dz * dz)
	local lookLength = math.sqrt(look.x * look.x + look.z * look.z)
	if d > range or d < 0.01 or lookLength < 0.01 then
		return false
	end
	return (dx * look.x + dz * look.z) / (d * lookLength) >= math.cos(math.rad(angle))
end

function RobotMotion.newWatch(): Watch
	return { looked = 0, away = 0, frozen = false }
end

-- Being stared at: Seconds of looking freezes it; Release seconds of looking away lets it go (a
-- glance away before then doesn't reset the count).
function RobotMotion.watchStep(
	watch: Watch,
	looking: boolean,
	dt: number,
	settings: { Seconds: number, Release: number }
): Watch
	if looking then
		watch.looked += dt
		watch.away = 0
		if watch.looked >= settings.Seconds then
			watch.frozen = true
		end
	else
		watch.away += dt
		if watch.away >= settings.Release then
			watch.looked = 0
			watch.frozen = false
		end
	end
	return watch
end

return RobotMotion
