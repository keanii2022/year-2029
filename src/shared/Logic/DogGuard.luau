-- Who the dog protects against and when it may bite. Raiders are players who touched what it guards;
-- it remembers them for a while. Bites are rate limited, and one robot can't be stunned over and over.
export type Point = { x: number, z: number }
export type Memory = { [any]: number } -- id -> time

local DogGuard = {}

function DogGuard.isStranger(userId: number?, ownerId: number?): boolean
	return userId ~= nil and userId ~= ownerId
end

function DogGuard.inRadius(center: Point, point: Point, radius: number): boolean
	local dx, dz = point.x - center.x, point.z - center.z
	return dx * dx + dz * dz <= radius * radius
end

-- What the dog is protecting: its guard spot, its owner while following, or itself while staying.
function DogGuard.protectPoint(command: string?, guardSpot: Point?, owner: Point?, dog: Point): Point
	if command == "guard" and guardSpot then
		return guardSpot
	elseif command == "follow" and owner then
		return owner
	end
	return dog
end

-- A carried prop or a looted pile inside the guard radius sets it off when a stranger did it.
function DogGuard.isOffence(
	byUserId: number?,
	ownerId: number?,
	spot: Point,
	at: Point,
	radius: number
): boolean
	return DogGuard.isStranger(byUserId, ownerId) and DogGuard.inRadius(spot, at, radius)
end

function DogGuard.remember(memory: Memory, id: any, untilTime: number)
	memory[id] = untilTime
end

function DogGuard.remembers(memory: Memory, id: any, now: number): boolean
	local untilTime = memory[id]
	return untilTime ~= nil and now < untilTime
end

function DogGuard.forget(memory: Memory, now: number)
	for id, untilTime in memory do
		if now >= untilTime then
			memory[id] = nil
		end
	end
end

-- Closest of the candidates (id, distance), or nil.
function DogGuard.nearest(candidates: { { id: any, distance: number } }): (any?, number?)
	local bestId, bestDistance = nil, math.huge
	for _, candidate in candidates do
		if candidate.distance < bestDistance then
			bestId, bestDistance = candidate.id, candidate.distance
		end
	end
	if bestId == nil then
		return nil, nil
	end
	return bestId, bestDistance
end

return DogGuard
