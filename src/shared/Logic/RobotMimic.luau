-- The mimic, no Roblox here: a robot replays a callout someone made a little while ago to lure people
-- in. Picks the call and the robot, the cover it calls from, who its head follows while it waits, and
-- when it pounces.
local RobotMimic = {}

export type Call = { speaker: any, index: number, x: number, z: number, time: number }
export type Candidate = { id: any, x: number, z: number }
-- clear: nothing solid there and no fort near; hidden: no caller can see it; cover: how many of the
-- probe rays round it hit something close (a rack end, a pillar, a corner)
export type Spot = { x: number, z: number, clear: boolean, hidden: boolean, cover: number }
export type Near = { id: any, x: number, z: number, visible: boolean }
export type Watcher = { id: any, distance: number, approaching: boolean, answered: boolean }
export type Lock = { id: any, since: number }

-- Newest call first whose age is inside Delay; the robot nearest the call that is still at least
-- Offset[1] away from it (so the copy comes from the wrong place) and within Offset[2].
function RobotMimic.pick(
	calls: { Call },
	robots: { Candidate },
	now: number,
	settings: { Delay: { number }, Offset: { number } }
): (Call?, any?)
	for i = #calls, 1, -1 do
		local call = calls[i]
		local age = now - call.time
		if age < settings.Delay[1] or age > settings.Delay[2] then
			continue
		end
		local bestId, bestDistance = nil, math.huge
		for _, robot in robots do
			local d = math.sqrt((robot.x - call.x) ^ 2 + (robot.z - call.z) ^ 2)
			if d >= settings.Offset[1] and d <= settings.Offset[2] and d < bestDistance then
				bestId, bestDistance = robot.id, d
			end
		end
		if bestId ~= nil then
			return call, bestId
		end
	end
	return nil, nil
end

-- Somewhere to hide and call from: clear, out of every caller's sight, within CoverRange of the robot.
-- Most cover wins; each stud of walking costs CoverDistanceCost. Nil when nowhere is good enough.
function RobotMimic.coverSpot(
	spots: { Spot },
	from: { x: number, z: number },
	settings: { CoverRange: { number }, CoverMin: number, CoverDistanceCost: number }
): Spot?
	local best, bestScore = nil, -math.huge
	for _, spot in spots do
		local d = math.sqrt((spot.x - from.x) ^ 2 + (spot.z - from.z) ^ 2)
		if
			spot.clear
			and spot.hidden
			and spot.cover >= settings.CoverMin
			and d >= settings.CoverRange[1]
			and d <= settings.CoverRange[2]
		then
			local score = spot.cover - d * settings.CoverDistanceCost
			if score > bestScore then
				best, bestScore = spot, score
			end
		end
	end
	return best
end

-- Who the waiting robot springs on: the nearest player it can see who is inside PounceRange, or
-- inside ViewRange and its view cone (ViewAngle degrees either side of where it faces).
function RobotMimic.pounce(
	robot: { x: number, z: number, fx: number, fz: number },
	players: { Near },
	settings: { PounceRange: number, ViewRange: number, ViewAngle: number }
): any?
	local bestId, bestDistance = nil, math.huge
	local cosLimit = math.cos(math.rad(settings.ViewAngle))
	local facing = math.sqrt(robot.fx ^ 2 + robot.fz ^ 2)
	for _, near in players do
		local dx, dz = near.x - robot.x, near.z - robot.z
		local d = math.sqrt(dx * dx + dz * dz)
		if not near.visible or d >= bestDistance then
			continue
		end
		local inCone = d <= settings.ViewRange
			and facing > 0
			and (d == 0 or (dx * robot.fx + dz * robot.fz) / (d * facing) >= cosLimit)
		if d <= settings.PounceRange or inCone then
			bestId, bestDistance = near.id, d
		end
	end
	return bestId
end

-- Who its head follows while it waits, without flicking between people. Inside TrackRange, someone
-- walking toward it or who answered the call beats someone who isn't; nearest wins. It holds whoever
-- it has until they leave the range, or after HoldSeconds someone else is SwitchMargin nearer.
function RobotMimic.track(
	lock: Lock?,
	watchers: { Watcher },
	now: number,
	settings: { TrackRange: number, HoldSeconds: number, SwitchMargin: number }
): Lock?
	local best: Watcher?, current: Watcher? = nil, nil
	for _, watcher in watchers do
		if watcher.distance > settings.TrackRange then
			continue
		end
		if lock and watcher.id == lock.id then
			current = watcher
		end
		local keen = watcher.approaching or watcher.answered
		local bestKeen = best and (best.approaching or best.answered)
		if not best or (keen and not bestKeen) or (keen == bestKeen and watcher.distance < best.distance) then
			best = watcher
		end
	end
	if lock and current then
		local held = now - lock.since >= settings.HoldSeconds
		if
			best
			and best ~= current
			and held
			and best.distance <= current.distance * (1 - settings.SwitchMargin)
		then
			return { id = best.id, since = now }
		end
		return lock
	end
	return if best then { id = best.id, since = now } else nil
end

return RobotMimic
