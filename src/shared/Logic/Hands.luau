-- Pure motion curves for the first-person hands. A pose is where a hand's grip sits in camera
-- space (studs, camera looks along -z) plus its turn in degrees. Kinds: Eat, Drink, Heal, Open.
local Hands = {}

export type Pose = { x: number, y: number, z: number, pitch: number, yaw: number, roll: number }

export type Settings = {
	Rest: Pose,
	Poses: { [string]: { right: Pose, left: Pose? } },
	RaiseTime: number,
	LowerTime: number,
	BiteInterval: number,
	BiteLength: number,
	BitePush: Pose,
	ChewBob: number,
	ChewSpeed: number,
	DrinkTilt: number,
	DrinkLift: number,
	SipBob: number,
	WrapTurns: number,
	WrapRadius: number,
	OpenPull: number,
	OpenTwist: number,
	ReachTime: number,
}

function Hands.smooth(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return a * a * (3 - 2 * a)
end

function Hands.lerp(a: Pose, b: Pose, alpha: number): Pose
	return {
		x = a.x + (b.x - a.x) * alpha,
		y = a.y + (b.y - a.y) * alpha,
		z = a.z + (b.z - a.z) * alpha,
		pitch = a.pitch + (b.pitch - a.pitch) * alpha,
		yaw = a.yaw + (b.yaw - a.yaw) * alpha,
		roll = a.roll + (b.roll - a.roll) * alpha,
	}
end

function Hands.add(a: Pose, b: Pose, scale: number): Pose
	return {
		x = a.x + b.x * scale,
		y = a.y + b.y * scale,
		z = a.z + b.z * scale,
		pitch = a.pitch + b.pitch * scale,
		yaw = a.yaw + b.yaw * scale,
		roll = a.roll + b.roll * scale,
	}
end

-- How far the hands are up, 0..1: they rise over raiseTime, stay up until duration, then drop
-- over lowerTime.
function Hands.raise(t: number, duration: number, raiseTime: number, lowerTime: number): number
	if t < 0 then
		return 0
	end
	if t < duration then
		return Hands.smooth(if raiseTime > 0 then t / raiseTime else 1)
	end
	return 1 - Hands.smooth(if lowerTime > 0 then (t - duration) / lowerTime else 1)
end

function Hands.finished(t: number, duration: number, lowerTime: number): boolean
	return t >= duration + lowerTime
end

-- 0..1 bump at the start of every interval after start, each length seconds long.
function Hands.pulse(t: number, start: number, interval: number, length: number): number
	if t < start or interval <= 0 or length <= 0 then
		return 0
	end
	local phase = (t - start) % interval
	if phase >= length then
		return 0
	end
	return math.sin(math.pi * phase / length)
end

-- How many bite moments (one every interval from start, until stop) fall in (previous, now].
function Hands.bitesBetween(
	previous: number,
	now: number,
	start: number,
	interval: number,
	stop: number
): number
	if interval <= 0 then
		return 0
	end
	local function count(t: number): number
		if t < start then
			return 0
		end
		return math.floor((math.min(t, stop) - start) / interval) + 1
	end
	return math.max(count(now) - count(previous), 0)
end

-- Share of the action's held part (after the raise, before the end) that has passed, 0..1.
local function heldProgress(t: number, duration: number, raiseTime: number): number
	local span = duration - raiseTime
	if span <= 0 then
		return if t >= duration then 1 else 0
	end
	return math.clamp((t - raiseTime) / span, 0, 1)
end

-- Right and left hand poses t seconds into a supply use lasting duration seconds.
function Hands.pose(kind: string, t: number, duration: number, s: Settings): (Pose, Pose)
	local up = Hands.raise(t, duration, s.RaiseTime, s.LowerTime)
	local held = s.Poses[kind] or s.Poses.Eat
	local right = held.right
	local left = held.left or s.Rest
	local progress = heldProgress(t, duration, s.RaiseTime)
	local active = t < duration and t >= s.RaiseTime

	if kind == "Eat" then
		local bite = Hands.pulse(t, s.RaiseTime, s.BiteInterval, s.BiteLength)
		right = Hands.add(right, s.BitePush, bite)
		if active then
			right = Hands.add(
				right,
				{ x = 0, y = s.ChewBob, z = 0, pitch = 0, yaw = 0, roll = 0 },
				math.sin(t * s.ChewSpeed)
			)
		end
	elseif kind == "Drink" then
		local tip = Hands.smooth(progress * 2)
		local sip = if active then math.sin(t * s.ChewSpeed) * s.SipBob else 0
		right = Hands.add(
			right,
			{ x = 0, y = s.DrinkLift + sip, z = 0, pitch = s.DrinkTilt, yaw = 0, roll = 0 },
			tip
		)
	elseif kind == "Heal" then
		local angle = progress * s.WrapTurns * 2 * math.pi
		local circle = {
			x = math.cos(angle) * s.WrapRadius,
			y = math.sin(angle) * s.WrapRadius * 0.6,
			z = math.sin(angle) * s.WrapRadius * 0.5,
			pitch = 0,
			yaw = 0,
			roll = math.deg(angle) * 0.15,
		}
		right = Hands.add(right, circle, if active then 1 else 0)
	elseif kind == "Open" then
		local pull = Hands.smooth(progress * 1.5)
		right =
			Hands.add(right, { x = s.OpenPull, y = 0, z = 0, pitch = 0, yaw = 0, roll = -s.OpenTwist }, pull)
		left =
			Hands.add(left, { x = -s.OpenPull, y = 0, z = 0, pitch = 0, yaw = 0, roll = s.OpenTwist }, pull)
	end

	return Hands.lerp(s.Rest, right, up), Hands.lerp(s.Rest, left, up)
end

-- Quick out-and-back reach, 0 at rest, 1 at full stretch halfway through reachTime.
function Hands.reach(t: number, reachTime: number): number
	if t <= 0 or t >= reachTime or reachTime <= 0 then
		return 0
	end
	return math.sin(math.pi * t / reachTime)
end

-- Where a reaching hand points: start pushed distance studs along the camera-space direction,
-- with the forward part kept so the hand never reaches behind you.
function Hands.reachTarget(start: Pose, dx: number, dy: number, dz: number, distance: number): Pose
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length < 1e-6 then
		return Hands.add(start, { x = 0, y = 0, z = -distance, pitch = 0, yaw = 0, roll = 0 }, 1)
	end
	local nx, ny, nz = dx / length, dy / length, math.min(dz / length, -0.3)
	return Hands.add(start, { x = nx, y = ny, z = nz, pitch = 0, yaw = 0, roll = 0 }, distance)
end

return Hands
