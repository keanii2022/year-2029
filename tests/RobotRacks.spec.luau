local RobotRacks = require("../src/shared/Logic/RobotRacks")
local expect = require("./expect")

local RACKS = { Distance = { 16, 34 }, Along = { -28, -16, 0, 16, 28 }, Inset = 3 }

return {
	["it perches behind the player and lands on their side of the rack"] = function()
		local shelves = { { x0 = -100, x1 = 100, z = 7, depth = 5 } }
		local top, land = RobotRacks.dropSpot(shelves, { x = 0, z = 0 }, { x = 1, z = 0 }, RACKS, 0)
		expect(top and top.x < 0).toBeTruthy()
		expect(top and top.z).toBe(7)
		expect(land and land.z).toBeNear(7 - 2.5 - 3)
	end,
	["it faces ahead only when nothing is behind"] = function()
		local shelves = { { x0 = 10, x1 = 100, z = 7, depth = 5 } }
		local top = RobotRacks.dropSpot(shelves, { x = 0, z = 0 }, { x = 1, z = 0 }, RACKS, 0)
		expect(top and top.x > 0).toBeTruthy()
	end,
	["no rack in range, no drop"] = function()
		local far = { { x0 = -100, x1 = 100, z = 200, depth = 5 } }
		local top, land = RobotRacks.dropSpot(far, { x = 0, z = 0 }, { x = 1, z = 0 }, RACKS, 0.5)
		expect(top).toBe(nil)
		expect(land).toBe(nil)
	end,
}
