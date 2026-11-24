local Loudness = require("../src/shared/Logic/Loudness")
local expect = require("./expect")

local LEVELS = {
	quiet = { players = 20, robots = 0, robotsInRoom = true },
	normal = { players = 45, robots = 25 },
	loud = { players = 120, robots = 80 },
}

return {
	["players hear each level out to its range"] = function()
		expect(Loudness.hears(LEVELS, "quiet", "player", 20)).toBeTruthy()
		expect(Loudness.hears(LEVELS, "quiet", "player", 21)).toBeFalsy()
		expect(Loudness.hears(LEVELS, "normal", "player", 45)).toBeTruthy()
		expect(Loudness.hears(LEVELS, "loud", "player", 119)).toBeTruthy()
		expect(Loudness.hears(LEVELS, "loud", "player", 121)).toBeFalsy()
	end,
	["robots hear less far than players"] = function()
		expect(Loudness.hears(LEVELS, "normal", "robot", 30)).toBeFalsy()
		expect(Loudness.hears(LEVELS, "loud", "robot", 80)).toBeTruthy()
		expect(Loudness.hears(LEVELS, "loud", "robot", 81)).toBeFalsy()
	end,
	["robots hear quiet sounds only in their own room"] = function()
		expect(Loudness.hears(LEVELS, "quiet", "robot", 2)).toBeFalsy()
		expect(Loudness.hears(LEVELS, "quiet", "robot", 2, true)).toBeTruthy()
		expect(Loudness.hears(LEVELS, "quiet", "robot", 25, true)).toBeFalsy()
	end,
	["a boombox reaches a stranger far beyond a lamp click"] = function()
		expect(Loudness.hears(LEVELS, "loud", "player", 100)).toBeTruthy()
		expect(Loudness.hears(LEVELS, "quiet", "player", 100)).toBeFalsy()
	end,
	["strength falls from 1 at the source to 0 at the edge"] = function()
		expect(Loudness.strength(LEVELS, "loud", "robot", 0)).toBe(1)
		expect(Loudness.strength(LEVELS, "loud", "robot", 40)).toBeNear(0.5)
		expect(Loudness.strength(LEVELS, "loud", "robot", 90)).toBe(0)
		expect(Loudness.strength(LEVELS, "quiet", "robot", 5)).toBe(0)
	end,
	["rollOff matches the player hearing range"] = function()
		local min, max = Loudness.rollOff(LEVELS, "loud", 0.1)
		expect(max).toBe(120)
		expect(min).toBeNear(12)
	end,
	["unknown levels are rejected and heard by no one"] = function()
		expect(Loudness.isLevel("loud")).toBeTruthy()
		expect(Loudness.isLevel("deafening")).toBeFalsy()
		expect(Loudness.hears(LEVELS, "deafening" :: any, "player", 1)).toBeFalsy()
	end,
	["prune drops old events and caps the count"] = function()
		local events = {
			{ level = "quiet", time = 1 },
			{ level = "loud", time = 8 },
			{ level = "normal", time = 9 },
			{ level = "normal", time = 10 },
		}
		local kept = Loudness.prune(events :: any, 10, 5, 10)
		expect(#kept).toBe(3)
		expect(kept[1].time).toBe(8)
		kept = Loudness.prune(events :: any, 10, 5, 2)
		expect(#kept).toBe(2)
		expect(kept[1].time).toBe(9)
	end,
	["loudest picks the highest level, newest on a tie"] = function()
		local events = {
			{ level = "loud", time = 1 },
			{ level = "normal", time = 5 },
			{ level = "loud", time = 3 },
		}
		expect((Loudness.loudest(events :: any) :: any).time).toBe(3)
		expect(Loudness.loudest({})).toBe(nil)
	end,
}
