local RobotMotion = require("../src/shared/Logic/RobotMotion")
local expect = require("./expect")

local BURST = { Move = { 0.5, 1 }, Still = { 1, 2 }, Speed = 2 }
local TILT = { Every = 7, Hold = 2, Degrees = 20 }
local WATCHED = { Seconds = 3, Release = 1 }

return {
	["the head points at a target, as far as the neck goes"] = function()
		expect(RobotMotion.headYaw(0, 10, 150)).toBeNear(0)
		expect(RobotMotion.headYaw(10, 10, 150)).toBeNear(45)
		expect(RobotMotion.headYaw(0, -10, 150)).toBeNear(150)
	end,
	["the head turns at a steady speed and settles without overshoot"] = function()
		local yaw = RobotMotion.turnHead(0, 90, 0.1, 50, 20)
		expect(yaw).toBeNear(5)
		for _ = 1, 200 do
			yaw = RobotMotion.turnHead(yaw, 90, 0.1, 50, 20)
			expect(yaw <= 90).toBeTruthy()
		end
		expect(yaw).toBeNear(90)
		expect(RobotMotion.turnHead(10, -10, 0.1, 50, 20) < 10).toBeTruthy()
	end,
	["a tilt now and then, alternating sides, still the rest of the time"] = function()
		expect(RobotMotion.tilt(1, 0, TILT)).toBeNear(20)
		expect(RobotMotion.tilt(4, 0, TILT)).toBe(0)
		expect(RobotMotion.tilt(8, 0, TILT)).toBeNear(-20)
	end,
	["walking hunters burst, then hold dead still"] = function()
		local gate, factor = RobotMotion.burst(nil, 0, 0, BURST)
		expect(gate.moving).toBe(true)
		expect(factor).toBe(2)
		expect(gate.untilAt).toBeNear(0.5)
		gate, factor = RobotMotion.burst(gate, 0.3, 0, BURST)
		expect(factor).toBe(2)
		gate, factor = RobotMotion.burst(gate, 0.6, 1, BURST)
		expect(gate.moving).toBe(false)
		expect(factor).toBe(0)
		expect(gate.untilAt).toBeNear(2.6)
	end,
	["looking at it means facing it, close enough"] = function()
		local from, ahead = { x = 0, z = 0 }, { x = 0, z = 1 }
		expect(RobotMotion.looksAt(from, ahead, { x = 1, z = 20 }, 30, 10)).toBe(true)
		expect(RobotMotion.looksAt(from, ahead, { x = 10, z = 10 }, 30, 10)).toBe(false)
		expect(RobotMotion.looksAt(from, ahead, { x = 0, z = 40 }, 30, 10)).toBe(false)
		expect(RobotMotion.looksAt(from, ahead, { x = 0, z = -10 }, 30, 10)).toBe(false)
	end,
	["stared at long enough it freezes; looking away a while lets it go"] = function()
		local watch = RobotMotion.newWatch()
		for _ = 1, 14 do
			RobotMotion.watchStep(watch, true, 0.2, WATCHED)
		end
		expect(watch.frozen).toBe(false)
		RobotMotion.watchStep(watch, false, 0.2, WATCHED) -- a glance away doesn't reset it
		RobotMotion.watchStep(watch, true, 0.2, WATCHED)
		expect(watch.frozen).toBe(true)
		for _ = 1, 5 do
			RobotMotion.watchStep(watch, false, 0.2, WATCHED)
		end
		expect(watch.frozen).toBe(false)
		expect(watch.looked).toBe(0)
	end,
}
