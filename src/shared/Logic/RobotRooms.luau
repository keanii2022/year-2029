-- Which robot rooms are awake. Only rooms near a player get a live robot, so a 90-room map stays cheap.
-- Positions are on the floor plane (x, z).
local RobotRooms = {}

export type Room = { id: number, cx: number, cz: number }
export type Point = { x: number, z: number }
export type Settings = { ActivationRadius: number, DeactivationRadius: number, MaxLiveChoreBots: number }

local function nearestPlayer(x: number, z: number, players: { Point }): number
	local best = math.huge
	for _, player in players do
		best = math.min(best, math.sqrt((player.x - x) ^ 2 + (player.z - z) ^ 2))
	end
	return best
end

-- Rooms that should have a live robot. Rooms already awake stay awake out to DeactivationRadius,
-- so a robot doesn't blink out when you step back over the line. Closest rooms win the cap.
-- skip: rooms that can't have a robot right now (destroyed today).
function RobotRooms.active(
	rooms: { Room },
	players: { Point },
	current: { [number]: boolean },
	settings: Settings,
	skip: { [number]: any }?
): { [number]: boolean }
	local wanted = {}
	for _, room in rooms do
		if skip and skip[room.id] then
			continue
		end
		local d = nearestPlayer(room.cx, room.cz, players)
		local limit = if current[room.id] then settings.DeactivationRadius else settings.ActivationRadius
		if d <= limit then
			table.insert(wanted, { id = room.id, d = d, awake = current[room.id] == true })
		end
	end
	table.sort(wanted, function(a, b)
		if a.awake ~= b.awake then
			return a.awake
		end
		return a.d < b.d
	end)
	local result = {}
	for i = 1, math.min(#wanted, settings.MaxLiveChoreBots) do
		result[wanted[i].id] = true
	end
	return result
end

-- The chore bot that lives in a room of this kind.
function RobotRooms.botFor(kind: string, roomBots: { [string]: string }, fallback: string): string
	return roomBots[kind] or fallback
end

-- Players with no hunter close by, in the order given, while there is room under the cap.
-- How many robots live in an installation of this floor area: one per areaPerBot, kept inside range.
-- extra (0 or 1, rolled by the caller) adds a little variety between halls of the same size.
function RobotRooms.botCount(area: number, range: { number }, areaPerBot: number, extra: number): number
	local wanted = math.floor(area / math.max(areaPerBot, 1)) + extra
	return math.clamp(wanted, range[1], range[2])
end

-- Picks a spot at least spacing from every taken spot, trying the candidates in order. Falls back to
-- the candidate farthest from its nearest neighbour when none is far enough. Spots are { x, z }.
function RobotRooms.spreadSpot(candidates: { Point }, taken: { Point }, spacing: number): Point?
	local best, bestGap = nil, -1
	for _, candidate in candidates do
		local gap = math.huge
		for _, other in taken do
			gap = math.min(gap, math.sqrt((candidate.x - other.x) ^ 2 + (candidate.z - other.z) ^ 2))
		end
		if gap >= spacing then
			return candidate
		end
		if gap > bestGap then
			best, bestGap = candidate, gap
		end
	end
	return best
end

local function countWithin(x: number, z: number, points: { Point }, radius: number): number
	local count = 0
	for _, point in points do
		if (point.x - x) ^ 2 + (point.z - z) ^ 2 <= radius * radius then
			count += 1
		end
	end
	return count
end

-- Players with fewer than perPlayer (default 1) hunters within nearRadius, one new hunter each per call.
function RobotRooms.needHunters(
	players: { Point & { id: any } },
	hunters: { Point },
	nearRadius: number,
	maxHunters: number,
	perPlayer: number?
): { any }
	local needing = {}
	local placed = table.clone(hunters)
	for _, player in players do
		if #placed >= maxHunters then
			break
		end
		if countWithin(player.x, player.z, placed, nearRadius) < (perPlayer or 1) then
			table.insert(needing, player.id)
			-- the hunter about to spawn counts for the next player too, so a group gets one, not one each
			table.insert(placed, { x = player.x, z = player.z })
		end
	end
	return needing
end

-- Where a doorway robot stands: inset studs inside the door, plus the way out it faces (unit x, z).
-- Doors sit on a side ("north" is the low z wall) at `at` studs along it, warehouse-local.
function RobotRooms.doorPost(room: any, door: { side: string, at: number }, inset: number): (Point, Point)
	if door.side == "north" then
		return { x = room.x0 + door.at, z = room.z0 + inset }, { x = 0, z = -1 }
	elseif door.side == "south" then
		return { x = room.x0 + door.at, z = room.z1 - inset }, { x = 0, z = 1 }
	elseif door.side == "west" then
		return { x = room.x0 + inset, z = room.z0 + door.at }, { x = -1, z = 0 }
	end
	return { x = room.x1 - inset, z = room.z0 + door.at }, { x = 1, z = 0 }
end

-- Where a room's keeper stands: `reach` studs in front of the stash on the room's side, facing the
-- stash, so its back is mostly to the way in. Falls back to the room's middle facing +z.
function RobotRooms.keeperPost(room: any, reach: number): (Point, Point)
	local stash = room.stash
	if not stash then
		return { x = room.cx, z = room.cz }, { x = 0, z = 1 }
	end
	local dx, dz = room.cx - stash.x, room.cz - stash.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		dx, dz, length = 0, -1, 1
	end
	dx, dz = dx / length, dz / length
	return { x = stash.x + dx * reach, z = stash.z + dz * reach }, { x = -dx, z = -dz }
end

-- The keeper works with its back turned for `work` seconds, then looks round for `glance`, over and
-- over. offset staggers keepers so they don't all turn at once.
function RobotRooms.keeperGlancing(now: number, offset: number, work: number, glance: number): boolean
	return (now + offset) % (work + glance) >= work
end

-- True when (x, z) is within radius of any of the room's doorways (warehouse-local studs)
function RobotRooms.nearDoor(room: any, x: number, z: number, radius: number): boolean
	for _, door in room.doors or {} do
		local at = RobotRooms.doorPost(room, door, 0)
		if (at.x - x) ^ 2 + (at.z - z) ^ 2 < radius * radius then
			return true
		end
	end
	return false
end

function RobotRooms.distanceToNearest(x: number, z: number, players: { Point }): number
	return nearestPlayer(x, z, players)
end

return RobotRooms
