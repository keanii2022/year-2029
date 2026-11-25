-- Grid snap, rotation steps, carry reach and landing math for grab and build.
-- Angles are degrees in [0, 360).
local GrabMath = {}

export type Axis = "Turn" | "Tip"

local EPSILON = 1e-4

function GrabMath.snapToGrid(value: number, grid: number): number
	return math.floor(value / grid + 0.5) * grid
end

function GrabMath.wrapAngle(angle: number): number
	local wrapped = angle % 360
	if wrapped > 360 - EPSILON then
		return 0
	end
	return wrapped
end

-- The camera's yaw in degrees, snapped to the nearest quarter turn. Tip follows this
-- instead of the exact camera so props stay square with the walls. lookX / lookZ are the camera's
-- look vector; Roblox yaw 0 looks down -Z.
function GrabMath.quarterYaw(lookX: number, lookZ: number): number
	local yaw = math.deg(math.atan2(-lookX, -lookZ))
	return GrabMath.wrapAngle(math.floor(yaw / 90 + 0.5) * 90)
end

function GrabMath.clampHoldDistance(distance: number, min: number, max: number): number
	return math.clamp(distance, min, max)
end

-- The distance that counts against reach for an offset from the player. The first upAllowance
-- studs straight up are free, so stock on high shelves is reachable from the floor.
function GrabMath.reachGap(dx: number, dy: number, dz: number, upAllowance: number): number
	local up = if dy > 0 then math.max(dy - upAllowance, 0) else dy
	return math.sqrt(dx * dx + up * up + dz * dz)
end

-- Pulls a requested carry point back inside [minDistance, maxDistance] of the origin.
function GrabMath.clampToReach(
	ox: number,
	oy: number,
	oz: number,
	tx: number,
	ty: number,
	tz: number,
	minDistance: number,
	maxDistance: number
): (number, number, number)
	local dx, dy, dz = tx - ox, ty - oy, tz - oz
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	if distance < EPSILON then
		return ox, oy, oz + minDistance
	end
	local clamped = math.clamp(distance, minDistance, maxDistance)
	local scale = clamped / distance
	return ox + dx * scale, oy + dy * scale, oz + dz * scale
end

-- Half the height of a rotated box. upX/upY/upZ are the world Y parts of the box's
-- right, up and look vectors.
function GrabMath.verticalHalfExtent(
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	upX: number,
	upY: number,
	upZ: number
): number
	return (math.abs(upX) * sizeX + math.abs(upY) * sizeY + math.abs(upZ) * sizeZ) / 2
end

-- Landing height of a box center after a downward cast. The cast uses a box shrunk by
-- `shrink` so it can slide past neighbours, so its bottom starts higher than the real one; that difference is added back.
function GrabMath.landingY(startY: number, castDistance: number, halfExtent: number, shrink: number): number
	return startY - castDistance + halfExtent * (1 - shrink)
end

function GrabMath.carrySpeedMultiplier(
	mass: number,
	lightMass: number,
	heavyMass: number,
	minMultiplier: number
): number
	if mass <= lightMass then
		return 1
	end
	if mass >= heavyMass then
		return minMultiplier
	end
	local t = (mass - lightMass) / (heavyMass - lightMass)
	return 1 - t * (1 - minMultiplier)
end

return GrabMath
