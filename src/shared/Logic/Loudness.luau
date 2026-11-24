-- Hearing math: who hears a sound of a given loudness at what distance. No walls yet.
-- Robots and players have their own ranges; quiet sounds reach robots only in the same room.
local Loudness = {}

export type Level = "quiet" | "normal" | "loud"
export type Listener = "player" | "robot"
export type Range = { players: number, robots: number, robotsInRoom: boolean? }
export type Levels = { [string]: Range }
export type Event = { level: Level, time: number }

local RANK = { quiet = 1, normal = 2, loud = 3 }

function Loudness.isLevel(value: any): boolean
	return type(value) == "string" and RANK[value] ~= nil
end

function Loudness.rank(level: Level): number
	return RANK[level] or 0
end

-- Hearing distance in studs. sameRoom only matters for robots and quiet sounds.
function Loudness.range(levels: Levels, level: Level, listener: Listener, sameRoom: boolean?): number
	local range = levels[level]
	if not range then
		return 0
	end
	if listener == "player" then
		return range.players
	end
	if range.robotsInRoom and sameRoom then
		return math.max(range.robots, range.players)
	end
	return range.robots
end

function Loudness.hears(
	levels: Levels,
	level: Level,
	listener: Listener,
	distance: number,
	sameRoom: boolean?
): boolean
	local range = Loudness.range(levels, level, listener, sameRoom)
	return range > 0 and distance <= range
end

-- 1 at the source, falling to 0 at the edge of hearing. Lets a robot pick the strongest sound.
function Loudness.strength(
	levels: Levels,
	level: Level,
	listener: Listener,
	distance: number,
	sameRoom: boolean?
): number
	local range = Loudness.range(levels, level, listener, sameRoom)
	if range <= 0 or distance > range then
		return 0
	end
	return 1 - distance / range
end

-- RollOffMinDistance and RollOffMaxDistance for a 3D Sound, so players hear it as far as its level says.
function Loudness.rollOff(levels: Levels, level: Level, minFraction: number): (number, number)
	local max = Loudness.range(levels, level, "player")
	return max * minFraction, max
end

-- Drops events older than maxAge and keeps at most maxCount of the newest. Events stay oldest first.
function Loudness.prune<T>(events: { T & Event }, now: number, maxAge: number, maxCount: number): { T & Event }
	local kept = {}
	for _, event in events do
		if now - event.time <= maxAge then
			table.insert(kept, event)
		end
	end
	while #kept > maxCount do
		table.remove(kept, 1)
	end
	return kept
end

-- Loudest event, newest wins a tie.
function Loudness.loudest<T>(events: { T & Event }): (T & Event)?
	local best = nil
	for _, event in events do
		if
			not best
			or Loudness.rank(event.level) > Loudness.rank(best.level)
			or (Loudness.rank(event.level) == Loudness.rank(best.level) and event.time >= best.time)
		then
			best = event
		end
	end
	return best
end

return Loudness
