-- Hunting as a pack, no Roblox here: who answers a robot's call and where they run to, where a robot
-- looks next after losing you, and how much dread one robot puts on the local player.
local RobotHunt = {}

export type Point = { x: number, z: number }
export type Candidate = Point & { id: any }

local function distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- A spot beside the target, off to one side of the caller's line and a little past it, so robots
-- answering a call come at you from the flanks instead of piling in behind the first. side: 1 or -1.
function RobotHunt.flankPoint(caller: Point, target: Point, offset: number, side: number): Point
	local dx, dz = target.x - caller.x, target.z - caller.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		return { x = target.x, z = target.z }
	end
	local ax, az = dx / length, dz / length
	return {
		x = target.x - az * offset * side + ax * offset * 0.5,
		z = target.z + ax * offset * side + az * offset * 0.5,
	}
end

-- The nearest candidates within radius of at, nearest first, at most max of them.
function RobotHunt.responders(at: Point, candidates: { Candidate }, radius: number, max: number): { any }
	local inReach = {}
	for _, candidate in candidates do
		local d = distance(at, candidate)
		if d <= radius then
			table.insert(inReach, { id = candidate.id, d = d })
		end
	end
	table.sort(inReach, function(a, b)
		return a.d < b.d
	end)
	local picked = {}
	for i = 1, math.min(max, #inReach) do
		table.insert(picked, inReach[i].id)
	end
	return picked
end

-- Where to look next round the last sighting. If the one it lost is tucked in a hiding spot close
-- by, it goes straight there findChance of the time; otherwise a spot on a ring round the sighting.
-- roll, angle (radians) and reach (0..1) are the caller's random numbers.
function RobotHunt.searchPoint(
	around: Point,
	hiding: Point?,
	settings: { SearchRadius: number, SearchFindChance: number },
	roll: number,
	angle: number,
	reach: number
): Point
	if hiding and distance(around, hiding) <= settings.SearchRadius and roll < settings.SearchFindChance then
		return { x = hiding.x, z = hiding.z }
	end
	local r = settings.SearchRadius * (0.35 + 0.65 * reach)
	return { x = around.x + math.cos(angle) * r, z = around.z + math.sin(angle) * r }
end

-- 0..1: how much one robot weighs on you. One chasing you fills it as it closes in; one awake and
-- hunting nearby (any robot at night, a prowler by day) puts on HuntWeight at most; calm ones none.
function RobotHunt.dread(
	d: number,
	state: string?,
	awake: boolean,
	settings: { ChaseRange: number, HuntRange: number, HuntWeight: number }
): number
	if state == "chase" then
		return math.clamp(1 - d / settings.ChaseRange, 0, 1)
	end
	local hunting = state == "suspicious" or (awake and (state == "sweep" or state == "investigate"))
	if hunting then
		return settings.HuntWeight * math.clamp(1 - d / settings.HuntRange, 0, 1)
	end
	return 0
end

return RobotHunt
