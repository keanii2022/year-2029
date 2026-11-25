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

function RobotRooms.needHunters(
	players: { Point & { id: any } },
	hunters: { Point },
	nearRadius: number,
	maxHunters: number
): { any }
	local needing = {}
	local placed = table.clone(hunters)
	for _, player in players do
		if #placed >= maxHunters then
			break
		end
		if nearestPlayer(player.x, player.z, placed) > nearRadius then
			table.insert(needing, player.id)
			-- the hunter about to spawn counts for the next player too, so a group gets one, not one each
			table.insert(placed, { x = player.x, z = player.z })
		end
	end
	return needing
end

function RobotRooms.distanceToNearest(x: number, z: number, players: { Point }): number
	return nearestPlayer(x, z, players)
end

return RobotRooms
