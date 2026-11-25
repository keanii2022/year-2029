local GrabMath = require("../src/shared/Logic/GrabMath")
local expect = require("./expect")

return {
	["snapToGrid rounds to the nearest grid line"] = function()
		expect(GrabMath.snapToGrid(3.4, 1)).toBe(3)
		expect(GrabMath.snapToGrid(3.6, 1)).toBe(4)
		expect(GrabMath.snapToGrid(-2.6, 2)).toBe(-2)
		expect(GrabMath.snapToGrid(-3.1, 2)).toBe(-4)
	end,
	["wrapAngle keeps angles in 0 to 360"] = function()
		expect(GrabMath.wrapAngle(370)).toBeNear(10)
		expect(GrabMath.wrapAngle(-15)).toBeNear(345)
		expect(GrabMath.wrapAngle(360)).toBe(0)
	end,
	["rotateSpeed waits for a hold, then ramps up"] = function()
		expect(GrabMath.rotateSpeed(0.1, 0.2, 180, 600, 1)).toBe(0)
		expect(GrabMath.rotateSpeed(0.2, 0.2, 180, 600, 1)).toBeNear(180)
		expect(GrabMath.rotateSpeed(0.7, 0.2, 180, 600, 1)).toBeNear(390)
		expect(GrabMath.rotateSpeed(5, 0.2, 180, 600, 1)).toBeNear(600)
	end,
	["snapTurn rounds a hold to the nearest step"] = function()
		expect(GrabMath.snapTurn(15, 15)).toBeNear(0)
		expect(GrabMath.snapTurn(20, 15)).toBeNear(-5)
		expect(GrabMath.snapTurn(25, 15)).toBeNear(5)
		expect(GrabMath.snapTurn(-20, 15)).toBeNear(5)
	end,
	["quarterYaw snaps the camera to the nearest wall direction"] = function()
		expect(GrabMath.quarterYaw(0, -1)).toBe(0)
		expect(GrabMath.quarterYaw(-1, 0)).toBeNear(90)
		expect(GrabMath.quarterYaw(0.3, 1)).toBeNear(180)
		expect(GrabMath.quarterYaw(0.9, -0.4)).toBeNear(270)
	end,
	["clampToReach pulls far points in and pushes near points out"] = function()
		local x, y, z = GrabMath.clampToReach(0, 0, 0, 20, 0, 0, 4, 12)
		expect(x).toBeNear(12)
		expect(y).toBeNear(0)
		expect(z).toBeNear(0)
		x, _, _ = GrabMath.clampToReach(0, 0, 0, 1, 0, 0, 4, 12)
		expect(x).toBeNear(4)
		x, _, z = GrabMath.clampToReach(5, 0, 5, 5, 0, 5, 4, 12)
		expect(x).toBeNear(5)
		expect(z).toBeNear(9)
	end,
	["clampToReach leaves points inside the range alone"] = function()
		local x, y, z = GrabMath.clampToReach(1, 1, 1, 4, 5, 1, 4, 12)
		expect(x).toBeNear(4)
		expect(y).toBeNear(5)
		expect(z).toBeNear(1)
	end,
	["verticalHalfExtent follows the rotation"] = function()
		-- upright 4x7x1 door
		expect(GrabMath.verticalHalfExtent(4, 7, 1, 0, 1, 0)).toBeNear(3.5)
		-- tipped flat onto its back
		expect(GrabMath.verticalHalfExtent(4, 7, 1, 0, 0, 1)).toBeNear(0.5)
		-- tipped 45 degrees
		local h = math.sqrt(0.5)
		expect(GrabMath.verticalHalfExtent(4, 7, 1, 0, h, h)).toBeNear(8 * h / 2)
	end,
	["landingY rests a box on what the cast hit"] = function()
		-- crate of height 3 cast from y=10 with a 0.98 box, floor at 0, so the 1.47 half box travels 8.53
		local y = GrabMath.landingY(10, 8.53, 1.5, 0.98)
		expect(y).toBeNear(1.5)
	end,
	["carrySpeedMultiplier slows heavy props"] = function()
		expect(GrabMath.carrySpeedMultiplier(10, 15, 80, 0.55)).toBe(1)
		expect(GrabMath.carrySpeedMultiplier(100, 15, 80, 0.55)).toBe(0.55)
		expect(GrabMath.carrySpeedMultiplier(47.5, 15, 80, 0.55)).toBeNear(0.775)
	end,
}
