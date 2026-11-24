-- Grid snap, rotation steps, carry reach and landing math for grab and build.
-- Angles are degrees in [0, 360).
local GrabMath = {}

export type Axis = "Turn" | "Tip" | "Roll"

local AXIS_ORDER: { Axis } = { "Turn", "Tip", "Roll" }
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

-- One step on the rotation grid. An angle left between grid lines by free rotation
-- moves to the next grid line in that direction instead of a full step past it.
function GrabMath.stepAngle(angle: number, direction: number, step: number): number
	local index = angle / step
	local nearest = math.floor(index + 0.5)
	local onGrid = math.abs(index - nearest) < EPSILON
	local target
	if onGrid then
		target = (nearest + direction) * step
	elseif direction > 0 then
		target = math.ceil(index) * step
	else
		target = math.floor(index) * step
	end
	return GrabMath.wrapAngle(target)
end

function GrabMath.nextAxis(axis: Axis): Axis
	for i, name in AXIS_ORDER do
		if name == axis then
			return AXIS_ORDER[i % #AXIS_ORDER + 1]
		end
	end
	return "Turn"
end

function GrabMath.clampHoldDistance(distance: number, min: number, max: number): number
	return math.clamp(distance, min, max)
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
