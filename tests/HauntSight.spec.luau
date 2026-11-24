local HauntSight = require("../src/shared/Logic/HauntSight")
local expect = require("./expect")

local function v(x, y, z)
	return { X = x, Y = y, Z = z }
end

local ORIGIN = v(0, 0, 0)
local NORTH = v(0, 0, 1)

return {
	["a point ahead is seen, one behind is not"] = function()
		expect(HauntSight.inView(ORIGIN, NORTH, v(0, 0, 10), 70, 100)).toBeTruthy()
		expect(HauntSight.inView(ORIGIN, NORTH, v(0, 0, -10), 70, 100)).toBeFalsy()
	end,
	["the cone edge and the range both cut off"] = function()
		expect(HauntSight.inView(ORIGIN, NORTH, v(10, 0, 10), 46, 100)).toBeTruthy()
		expect(HauntSight.inView(ORIGIN, NORTH, v(10, 0, 10), 44, 100)).toBeFalsy()
		expect(HauntSight.inView(ORIGIN, NORTH, v(0, 0, 101), 70, 100)).toBeFalsy()
	end,
	["a mannequin is watched if any one viewer sees it"] = function()
		local viewers = {
			{ eye = ORIGIN, look = v(0, 0, -1) },
			{ eye = v(0, 0, 20), look = v(0, 0, -1) },
		}
		expect(HauntSight.anyoneLooking(viewers, v(0, 0, 10), 70, 100)).toBeTruthy()
		expect(HauntSight.anyoneLooking({ viewers[1] }, v(0, 0, 10), 70, 100)).toBeFalsy()
	end,
	["nearest skips anyone out of range"] = function()
		local index, distance = HauntSight.nearest(ORIGIN, { v(50, 0, 0), v(0, 0, 20), v(5, 0, 0) }, 30)
		expect(index).toBe(3)
		expect(distance).toBe(5)
		expect((HauntSight.nearest(ORIGIN, { v(50, 0, 0) }, 30))).toBe(nil)
	end,
	["yaw points a camera's front at the target"] = function()
		expect(HauntSight.yawTo(0, 1)).toBeNear(0)
		expect(HauntSight.yawTo(1, 0)).toBeNear(90)
		expect(HauntSight.yawTo(-1, 0)).toBeNear(-90)
	end,
	["turning takes the short way and caps the step"] = function()
		expect(HauntSight.angleDelta(170, -170)).toBeNear(20)
		expect(HauntSight.angleDelta(-170, 170)).toBeNear(-20)
		expect(HauntSight.turnToward(0, 90, 10)).toBeNear(10)
		expect(HauntSight.turnToward(0, -90, 10)).toBeNear(-10)
		expect(HauntSight.turnToward(0, 5, 10)).toBeNear(5)
	end,
	["off axis turns the look direction sideways"] = function()
		local x, z = HauntSight.offAxis(0, 1, 90, 1)
		expect(math.abs(x)).toBeNear(1)
		expect(z).toBeNear(0)
		local lx, lz = HauntSight.offAxis(0, 2, 30, -1)
		expect(math.sqrt(lx * lx + lz * lz)).toBeNear(1)
		expect(lz).toBeNear(math.cos(math.rad(30)))
	end,
	["critters run away from the threat"] = function()
		expect(HauntSight.fleeSign(10, 0)).toBe(1)
		expect(HauntSight.fleeSign(-10, 0)).toBe(-1)
	end,
}
