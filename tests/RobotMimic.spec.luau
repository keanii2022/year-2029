local RobotMimic = require("../src/shared/Logic/RobotMimic")
local expect = require("./expect")

local MIMIC = { Delay = { 6, 40 }, Offset = { 25, 90 } }
local COVER = { CoverRange = { 3, 20 }, CoverMin = 1, CoverDistanceCost = 0.1 }
local POUNCE = { PounceRange = 10, ViewRange = 18, ViewAngle = 35 }
local TRACK = { TrackRange = 30, HoldSeconds = 3, SwitchMargin = 0.25 }

local function spot(x: number, clear: boolean, hidden: boolean, cover: number)
	return { x = x, z = 0, clear = clear, hidden = hidden, cover = cover }
end

local function watcher(id: string, distance: number, approaching: boolean?, answered: boolean?)
	return { id = id, distance = distance, approaching = approaching == true, answered = answered == true }
end

return {
	["a robot away from the caller copies a call from a little while ago"] = function()
		local calls = { { speaker = "p1", index = 2, x = 0, z = 0, time = 0 } }
		local robots = {
			{ id = "close", x = 10, z = 0 },
			{ id = "right", x = 40, z = 0 },
			{ id = "far", x = 200, z = 0 },
		}
		local call, id = RobotMimic.pick(calls, robots, 10, MIMIC)
		expect(call and call.index).toBe(2)
		expect(id).toBe("right")
	end,
	["too fresh, too old, or no robot in reach: nothing"] = function()
		local calls = { { speaker = "p1", index = 0, x = 0, z = 0, time = 0 } }
		local robots = { { id = "a", x = 40, z = 0 } }
		expect(RobotMimic.pick(calls, robots, 2, MIMIC)).toBe(nil)
		expect(RobotMimic.pick(calls, robots, 60, MIMIC)).toBe(nil)
		expect(RobotMimic.pick(calls, { { id = "b", x = 5, z = 0 } }, 10, MIMIC)).toBe(nil)
	end,
	["the newest call goes first"] = function()
		local calls = {
			{ speaker = "p1", index = 1, x = 0, z = 0, time = 0 },
			{ speaker = "p2", index = 4, x = 0, z = 0, time = 5 },
		}
		local call = RobotMimic.pick(calls, { { id = "a", x = 40, z = 0 } }, 15, MIMIC)
		expect(call and call.index).toBe(4)
	end,
	["cover: hidden and clear only, the most cover wins, walking far costs"] = function()
		local from = { x = 0, z = 0 }
		local spots = {
			spot(5, false, true, 6), -- inside a wall or a fort
			spot(6, true, false, 6), -- a caller can see it
			spot(8, true, true, 2),
			spot(10, true, true, 4),
			spot(40, true, true, 8), -- too far
		}
		local best = RobotMimic.coverSpot(spots, from, COVER)
		expect(best and best.x).toBe(10)
		expect(RobotMimic.coverSpot({ spot(6, true, false, 6), spot(4, true, true, 0) }, from, COVER)).toBe(
			nil
		)
	end,
	["pounce: close by, or close in its view cone, and only if it can see them"] = function()
		local robot = { x = 0, z = 0, fx = 0, fz = 1 }
		local function near(id: string, x: number, z: number, visible: boolean)
			return { id = id, x = x, z = z, visible = visible }
		end
		expect(RobotMimic.pounce(robot, { near("a", 0, 15, true) }, POUNCE)).toBe("a")
		expect(RobotMimic.pounce(robot, { near("a", 15, 0, true) }, POUNCE)).toBe(nil)
		expect(RobotMimic.pounce(robot, { near("a", 8, 0, true) }, POUNCE)).toBe("a")
		expect(RobotMimic.pounce(robot, { near("a", 8, 0, false) }, POUNCE)).toBe(nil)
		expect(RobotMimic.pounce(robot, { near("a", 0, 25, true) }, POUNCE)).toBe(nil)
		expect(RobotMimic.pounce(robot, { near("far", 0, 16, true), near("close", 5, 0, true) }, POUNCE)).toBe(
			"close"
		)
	end,
	["track: someone coming over or who answered beats someone nearer standing about"] = function()
		local lock = RobotMimic.track(nil, { watcher("idle", 10), watcher("coming", 20, true) }, 0, TRACK)
		expect(lock and lock.id).toBe("coming")
		lock = RobotMimic.track(nil, { watcher("idle", 10), watcher("answered", 25, false, true) }, 0, TRACK)
		expect(lock and lock.id).toBe("answered")
		expect(RobotMimic.track(nil, { watcher("far", 40, true) }, 0, TRACK)).toBe(nil)
	end,
	["track: holds the lock, switches only after the hold and when someone is a quarter nearer"] = function()
		local lock = { id = "a", since = 0 }
		local players = { watcher("a", 20, true), watcher("b", 10, true), watcher("c", 18, true) }
		expect((RobotMimic.track(lock, players, 1, TRACK) :: any).id).toBe("a") -- inside the hold
		local switched = RobotMimic.track(lock, players, 4, TRACK) :: any
		expect(switched.id).toBe("b")
		expect(switched.since).toBe(4)
		-- after the hold, but nobody 25% nearer: keeps it
		local kept =
			RobotMimic.track(lock, { watcher("a", 20, true), watcher("c", 16, true) }, 4, TRACK) :: any
		expect(kept.id).toBe("a")
		expect(kept.since).toBe(0)
	end,
	["track: the lock leaves range, the next one takes over at once"] = function()
		local lock = { id = "a", since = 2 }
		local next = RobotMimic.track(lock, { watcher("a", 35, true), watcher("b", 22) }, 3, TRACK) :: any
		expect(next.id).toBe("b")
		expect(next.since).toBe(3)
	end,
}
