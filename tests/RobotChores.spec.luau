local RobotChores = require("../src/shared/Logic/RobotChores")
local expect = require("./expect")

local SETTINGS = { MinDistance = 20, MaxDistance = 75, Reach = 85 }
local HOME = { x = 0, z = 0 }

return {
	["each chore bot type has its own chore"] = function()
		local choreFor = { carrier = "carry", cleaner = "sweep", cook = "restock" }
		expect(RobotChores.choreFor("carrier", choreFor)).toBe("carry")
		expect(RobotChores.choreFor("cook", choreFor)).toBe("restock")
		expect(RobotChores.choreFor("mystery", choreFor)).toBe("sweep")
	end,
	["a carrier brings the box out and shelves it"] = function()
		local out, work = RobotChores.poses("carry")
		expect(out).toBe("carry")
		expect(work).toBe("shelve")
		out, work = RobotChores.poses("sweep")
		expect(out).toBe("walk")
		expect(work).toBe("sweep")
	end,
	["it picks a spot the player sees from a distance and the robot can reach"] = function()
		local spots = {
			{ x = 5, z = 0, kind = "aisle", dx = 0, dz = 1 }, -- too close to the player
			{ x = 40, z = 0, kind = "aisle", dx = 0, dz = 1 }, -- just right
			{ x = 200, z = 0, kind = "aisle", dx = 0, dz = 1 }, -- too far from home
		}
		local viewer = { x = 0, z = 5 }
		for _, roll in { 0, 0.5, 0.99 } do
			local goal = RobotChores.pickSpot(spots, HOME, viewer, SETTINGS, roll)
			expect(goal and goal.x).toBe(40)
		end
	end,
	["it faces the rack beside an aisle spot"] = function()
		local spots = { { x = 40, z = 2, kind = "aisle", dx = 0, dz = 1 } }
		local _, face = RobotChores.pickSpot(spots, HOME, { x = 0, z = 0 }, SETTINGS, 0)
		expect(face and face.z).toBeNear(-1)
	end,
	["no spot in range means no errand"] = function()
		local spots = { { x = 300, z = 0, kind = "end", dx = 0, dz = 1 } }
		expect(RobotChores.pickSpot(spots, HOME, { x = 290, z = 0 }, SETTINGS, 0.3)).toBe(nil)
		expect(RobotChores.pickSpot({}, HOME, HOME, SETTINGS, 0.3)).toBe(nil)
	end,
	["a carrier holds the box, slides it onto the shelf, then lets go"] = function()
		local progress, placed = RobotChores.shelve(0.5, 0.8, 1.6)
		expect(progress).toBe(0)
		expect(placed).toBe(false)
		progress, placed = RobotChores.shelve(1.6, 0.8, 1.6)
		expect(progress).toBeNear(0.5)
		expect(placed).toBe(false)
		progress, placed = RobotChores.shelve(3, 0.8, 1.6)
		expect(progress).toBe(1)
		expect(placed).toBe(true)
	end,
	["only as many go out as a player is missing"] = function()
		expect(RobotChores.needed(0, 2)).toBe(2)
		expect(RobotChores.needed(1, 2)).toBe(1)
		expect(RobotChores.needed(3, 2)).toBe(0)
	end,
}
