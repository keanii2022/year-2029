local RobotWeapons = require("../src/shared/Logic/RobotWeapons")
local expect = require("./expect")

return {
	["an EMP catches robots inside its radius only"] = function()
		local hit = RobotWeapons.inBlast(0, 0, 10, {
			{ id = 1, x = 3, z = 4 },
			{ id = 2, x = 10, z = 0 },
			{ id = 3, x = 8, z = 8 },
		})
		expect(#hit).toBe(2)
		expect(hit[1]).toBe(1)
		expect(hit[2]).toBe(2)
	end,
	["disruptor waits out its cooldown"] = function()
		expect(RobotWeapons.ready(nil, 5, 45)).toBeTruthy()
		expect(RobotWeapons.ready(0, 44, 45)).toBeFalsy()
		expect(RobotWeapons.ready(0, 45, 45)).toBeTruthy()
	end,
	["rewards the item list doesn't know yet are set aside"] = function()
		local known, unknown = RobotWeapons.knownRewards(
			{ { id = "BlasterCells", count = 5 }, { id = "EmpCharge", count = 2 } },
			{ BlasterCells = {} }
		)
		expect(#known).toBe(1)
		expect(known[1].count).toBe(5)
		expect(unknown[1]).toBe("EmpCharge")
	end,
}
