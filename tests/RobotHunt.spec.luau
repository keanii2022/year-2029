local RobotHunt = require("../src/shared/Logic/RobotHunt")
local expect = require("./expect")

local DREAD = { ChaseRange = 90, HuntRange = 60, HuntWeight = 0.5 }
local SEARCH = { SearchRadius = 20, SearchFindChance = 0.5 }

return {
	["flankers land either side of the target, a little past it"] = function()
		local left = RobotHunt.flankPoint({ x = 0, z = 0 }, { x = 0, z = 20 }, 10, 1)
		local right = RobotHunt.flankPoint({ x = 0, z = 0 }, { x = 0, z = 20 }, 10, -1)
		expect(left.x).toBeNear(-10)
		expect(right.x).toBeNear(10)
		expect(left.z).toBeNear(25)
		local same = RobotHunt.flankPoint({ x = 5, z = 5 }, { x = 5, z = 5 }, 10, 1)
		expect(same.x).toBe(5)
	end,
	["the nearest robots in reach answer, capped"] = function()
		local picked = RobotHunt.responders({ x = 0, z = 0 }, {
			{ id = "far", x = 200, z = 0 },
			{ id = "b", x = 40, z = 0 },
			{ id = "a", x = 10, z = 0 },
			{ id = "c", x = 60, z = 0 },
		}, 100, 2)
		expect(#picked).toBe(2)
		expect(picked[1]).toBe("a")
		expect(picked[2]).toBe("b")
	end,
	["a search goes to a nearby hiding spot on a good roll, else round the sighting"] = function()
		local around = { x = 0, z = 0 }
		local spot = RobotHunt.searchPoint(around, { x = 8, z = 0 }, SEARCH, 0.2, 0, 1)
		expect(spot.x).toBe(8)
		local ring = RobotHunt.searchPoint(around, { x = 8, z = 0 }, SEARCH, 0.9, 0, 1)
		expect(ring.x).toBeNear(20)
		local tooFar = RobotHunt.searchPoint(around, { x = 50, z = 0 }, SEARCH, 0, math.pi, 0)
		expect(tooFar.x).toBeNear(-7)
	end,
	["dread climbs as a chaser closes in; calm robots weigh nothing"] = function()
		expect(RobotHunt.dread(0, "chase", true, DREAD)).toBe(1)
		expect(RobotHunt.dread(45, "chase", false, DREAD)).toBeNear(0.5)
		expect(RobotHunt.dread(200, "chase", true, DREAD)).toBe(0)
		expect(RobotHunt.dread(0, "sweep", true, DREAD)).toBeNear(0.5)
		expect(RobotHunt.dread(0, "sweep", false, DREAD)).toBe(0)
		expect(RobotHunt.dread(5, "study", true, DREAD)).toBe(0)
	end,
	["a night chase lunges up close, then cools down"] = function()
		local lunge = { Range = 15 }
		expect(RobotHunt.shouldLunge("chase", 10, true, 5, 0, lunge)).toBe(true)
		expect(RobotHunt.shouldLunge("chase", 20, true, 5, 0, lunge)).toBe(false)
		expect(RobotHunt.shouldLunge("chase", 10, false, 5, 0, lunge)).toBe(false)
		expect(RobotHunt.shouldLunge("suspicious", 10, true, 5, 0, lunge)).toBe(false)
		expect(RobotHunt.shouldLunge("chase", nil, true, 5, 0, lunge)).toBe(false)
		expect(RobotHunt.shouldLunge("chase", 10, true, 5, 6, lunge)).toBe(false)
	end,
}
