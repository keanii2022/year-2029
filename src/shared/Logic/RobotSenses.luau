-- What a robot can see and hear, on the floor plane (x, z). Walls and props are the caller's
-- raycast; this only answers range, cone, stance and the day rule that sight stays in the room.
local RobotSenses = {}

export type Eye = { x: number, z: number, fx: number, fz: number, range: number }
export type Target = {
	x: number,
	z: number,
	stance: string?, -- "Walk" | "Sprint" | "Crouch"
	hidden: boolean?,
	sameRoom: boolean?,
}
export type Sense = {
	SightAngle: number,
	NightSightFactor: number,
	CrouchSightFactor: number,
	SprintSightFactor: number,
	FeelRadius: number,
	FootstepRadius: { [string]: number },
	BeamRange: number,
	BeamAngle: number,
}

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
end

function RobotSenses.sightRange(base: number, stance: string?, night: boolean, sense: Sense): number
	local range = base
	if night then
		range *= sense.NightSightFactor
	end
	if stance == "Crouch" then
		range *= sense.CrouchSightFactor
	elseif stance == "Sprint" then
		range *= sense.SprintSightFactor
	end
	return range
end

-- roomOnly: by day a calm robot only sees inside its own room.
function RobotSenses.canSee(
	eye: Eye,
	target: Target,
	sense: Sense,
	night: boolean,
	roomOnly: boolean
): boolean
	if target.hidden then
		return false
	end
	if roomOnly and not target.sameRoom then
		return false
	end
	local d = distance(eye.x, eye.z, target.x, target.z)
	if d <= sense.FeelRadius then
		return true
	end
	if d > RobotSenses.sightRange(eye.range, target.stance, night, sense) then
		return false
	end
	local length = math.sqrt(eye.fx ^ 2 + eye.fz ^ 2)
	if length < 1e-6 then
		return false
	end
	local dot = ((target.x - eye.x) * eye.fx + (target.z - eye.z) * eye.fz) / (d * length)
	return dot >= math.cos(math.rad(sense.SightAngle / 2))
end

-- How far a player's footsteps carry to a robot.
function RobotSenses.footstepRadius(stance: string?, sense: Sense): number
	return sense.FootstepRadius[stance or "Walk"] or 0
end

function RobotSenses.hearsSteps(
	robotX: number,
	robotZ: number,
	target: Target,
	sense: Sense,
	roomOnly: boolean
): boolean
	if target.hidden or (roomOnly and not target.sameRoom) then
		return false
	end
	local radius = RobotSenses.footstepRadius(target.stance, sense)
	return radius > 0 and distance(robotX, robotZ, target.x, target.z) <= radius
end

-- A flashlight beam from (px, pz) looking along (lx, lz) lands on the robot.
function RobotSenses.beamHits(
	px: number,
	pz: number,
	lx: number,
	lz: number,
	robotX: number,
	robotZ: number,
	sense: Sense
): boolean
	local d = distance(px, pz, robotX, robotZ)
	local length = math.sqrt(lx ^ 2 + lz ^ 2)
	if d > sense.BeamRange or d < 1e-6 or length < 1e-6 then
		return false
	end
	local dot = ((robotX - px) * lx + (robotZ - pz) * lz) / (d * length)
	return dot >= math.cos(math.rad(sense.BeamAngle))
end

-- How fast alert builds while a target is in view: full speed at the edge, triple up close.
function RobotSenses.noticeRate(d: number, range: number, noticeSeconds: number): number
	local closeness = 1 - math.clamp(d / math.max(range, 1), 0, 1)
	return (1 + 2 * closeness) / noticeSeconds
end

-- Nearest candidate; candidates are { id, x, z } and the robot is at (x, z).
function RobotSenses.nearest(x: number, z: number, candidates: { any }): (any, number)
	local best, bestDistance = nil, math.huge
	for _, candidate in candidates do
		local d = distance(x, z, candidate.x, candidate.z)
		if d < bestDistance then
			best, bestDistance = candidate, d
		end
	end
	return best, bestDistance
end

-- The loudest recent sound; ties go to the newest.
function RobotSenses.loudest(events: { any }): any
	local best = nil
	for _, event in events do
		if not best or event.rank > best.rank or (event.rank == best.rank and event.time >= best.time) then
			best = event
		end
	end
	return best
end

return RobotSenses
