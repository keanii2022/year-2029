-- Looking math for haunts: is a point inside someone's view cone, who is nearest, which way to turn
-- a camera, where the edge of a flashlight beam is. Points are anything with X, Y, Z (Vector3 works).
local HauntSight = {}

export type Point = { X: number, Y: number, Z: number }
export type Viewer = { eye: Point, look: Point }

function HauntSight.distance(a: Point, b: Point): number
	local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- look need not be unit length. A target right on the eye counts as seen.
function HauntSight.inView(eye: Point, look: Point, target: Point, halfAngle: number, range: number): boolean
	local dx, dy, dz = target.X - eye.X, target.Y - eye.Y, target.Z - eye.Z
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	if distance > range then
		return false
	end
	if distance < 1e-6 then
		return true
	end
	local lookLength = math.sqrt(look.X * look.X + look.Y * look.Y + look.Z * look.Z)
	if lookLength < 1e-6 then
		return false
	end
	local cosine = (dx * look.X + dy * look.Y + dz * look.Z) / (distance * lookLength)
	return cosine >= math.cos(math.rad(halfAngle))
end

function HauntSight.anyoneLooking(
	viewers: { Viewer },
	target: Point,
	halfAngle: number,
	range: number
): boolean
	for _, viewer in viewers do
		if HauntSight.inView(viewer.eye, viewer.look, target, halfAngle, range) then
			return true
		end
	end
	return false
end

-- Index and distance of the nearest point within range, or nil.
function HauntSight.nearest(from: Point, points: { Point }, range: number): (number?, number)
	local best, bestDistance = nil, range
	for index, point in points do
		local distance = HauntSight.distance(from, point)
		if distance <= bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best, bestDistance
end

-- Degrees to turn around +y so a model's front (+z) points at a target offset (x, z) in model space.
function HauntSight.yawTo(localX: number, localZ: number): number
	return math.deg(math.atan2(localX, localZ))
end

-- Shortest signed difference from one heading to another, in (-180, 180].
function HauntSight.angleDelta(from: number, to: number): number
	local delta = (to - from) % 360
	if delta > 180 then
		delta -= 360
	end
	return delta
end

-- Moves a heading toward a target by at most maxStep degrees, the short way round.
function HauntSight.turnToward(current: number, target: number, maxStep: number): number
	local delta = HauntSight.angleDelta(current, target)
	if math.abs(delta) <= maxStep then
		return current + delta
	end
	return current + math.sign(delta) * maxStep
end

-- A flat direction (x, z) turned off the look direction by angle degrees; side 1 or -1.
function HauntSight.offAxis(lookX: number, lookZ: number, angle: number, side: number): (number, number)
	local length = math.sqrt(lookX * lookX + lookZ * lookZ)
	if length < 1e-6 then
		lookX, lookZ, length = 0, 1, 1
	end
	local x, z = lookX / length, lookZ / length
	local radians = math.rad(angle) * side
	local c, s = math.cos(radians), math.sin(radians)
	return x * c - z * s, x * s + z * c
end

-- Critters in aisles run along the aisle (x), away from the threat.
function HauntSight.fleeSign(critterX: number, threatX: number): number
	return if critterX >= threatX then 1 else -1
end

return HauntSight
