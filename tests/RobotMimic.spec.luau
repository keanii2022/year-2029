local RobotMimic = require("../src/shared/Logic/RobotMimic")
local expect = require("./expect")

local MIMIC = { Delay = { 6, 40 }, Offset = { 25, 90 } }

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
}
