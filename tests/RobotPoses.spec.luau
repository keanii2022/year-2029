local RobotPoses = require("../src/shared/Logic/RobotPoses")
local expect = require("./expect")

return {
	["walking swings the legs opposite each other"] = function()
		local pose = RobotPoses.limbs("walk", math.pi / 2, 0, true)
		expect(pose.Thigh).toBeNear(0.9)
		expect(pose.LeftThigh).toBeNear(-0.9)
		expect(pose.Leg1).toBeNear(-pose.Leg2)
	end,
	["standing still keeps the legs at rest"] = function()
		local pose = RobotPoses.limbs("walk", math.pi / 2, 0, false)
		expect(pose.Thigh).toBeNear(0)
	end,
	["a stalled robot holds the same frozen step"] = function()
		local a = RobotPoses.limbs("stall", 0, 1, false)
		local b = RobotPoses.limbs("stall", 3, 7, false)
		expect(a.Thigh).toBeNear(b.Thigh)
		expect(a.Head).toBeNear(b.Head)
	end,
	["unknown poses fall back to idle with every joint set"] = function()
		local pose = RobotPoses.limbs("nonsense", 0, 0, false)
		expect(pose.LeftForearm).toBe(0)
		expect(pose.Leg6).toBe(0)
	end,
}
