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
	["carrying holds both arms out front"] = function()
		local pose = RobotPoses.limbs("carry", 0, 0, true)
		expect(pose.UpperArm).toBeNear(2.2)
		expect(pose.LeftUpperArm).toBeNear(2.2)
	end,
	["restocking reaches up higher than studying"] = function()
		local reach = RobotPoses.limbs("restock", 0, 0, false)
		local study = RobotPoses.limbs("study", 0, 0, false)
		expect(reach.UpperArm > study.UpperArm + 1).toBeTruthy()
	end,
	["shelving pushes the arms up and out as the box slides on"] = function()
		local start = RobotPoses.limbs("shelve", 0, 0, false, 0)
		local done = RobotPoses.limbs("shelve", 0, 0, false, 1)
		expect(start.UpperArm).toBeNear(2.2)
		expect(done.UpperArm > start.UpperArm + 1).toBeTruthy()
		expect(done.Forearm < start.Forearm).toBeTruthy()
	end,
	["restocking keeps reaching instead of holding still"] = function()
		local a = RobotPoses.limbs("restock", 0, 0, false)
		local b = RobotPoses.limbs("restock", 0, 1.2, false)
		expect(math.abs(a.UpperArm - b.UpperArm) > 1).toBeTruthy()
	end,
	["sweeping swings the arms side to side"] = function()
		local a = RobotPoses.limbs("sweep", 0, 0.5, false)
		local b = RobotPoses.limbs("sweep", 0, 1.5, false)
		expect(math.abs(a.UpperArm - b.UpperArm) > 0.3).toBeTruthy()
	end,
	["a crouching robot bends its knees low"] = function()
		local pose = RobotPoses.limbs("crouch", 0, 0, false)
		expect(pose.Thigh > 1).toBeTruthy()
		expect(pose.Legs < 0).toBeTruthy()
	end,
	["offering holds the arms up higher than carrying"] = function()
		local offer = RobotPoses.limbs("offer", 0, 0, false)
		local carry = RobotPoses.limbs("carry", 0, 0, false)
		expect(offer.UpperArm > carry.UpperArm).toBeTruthy()
	end,
	["tugging heaves back and forth"] = function()
		local a = RobotPoses.limbs("tug", 0, 0, false)
		local b = RobotPoses.limbs("tug", 0, 0.3, false)
		expect(math.abs(a.Legs - b.Legs) > 0.05).toBeTruthy()
	end,
}
