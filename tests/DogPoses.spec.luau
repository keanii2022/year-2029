local DogPoses = require("../src/shared/Logic/DogPoses")
local expect = require("./expect")

return {
	["trotting moves diagonal legs together"] = function()
		local pose = DogPoses.limbs("follow", math.pi / 2, 0, true, false)
		expect(pose.LegFL).toBeNear(pose.LegBR)
		expect(pose.LegFR).toBeNear(-pose.LegFL)
	end,
	["standing still keeps the legs down"] = function()
		local pose = DogPoses.limbs("wander", math.pi / 2, 0, false, false)
		expect(pose.LegFL).toBe(0)
	end,
	["sitting folds the back legs and tips the body up"] = function()
		local pose = DogPoses.limbs("sit", 0, 0, false, false)
		expect(pose.LegBL > 1).toBeTruthy()
		expect(pose.LegFL).toBe(0)
		local drop, pitch = DogPoses.body("sit")
		expect(drop > 0).toBeTruthy()
		expect(pitch > 0).toBeTruthy()
	end,
	["a trusting dog wags, a scared one tucks its tail"] = function()
		local wag = DogPoses.limbs("sit", 0, 0.1, false, true)
		expect(wag.Tail ~= 0).toBeTruthy()
		local scared = DogPoses.limbs("flee", 0, 0.1, true, false)
		expect(scared.Tail).toBe(-1)
	end,
	["biting opens the jaw wide"] = function()
		expect(DogPoses.limbs("bite", 0, 0, false, false).Jaw > 1).toBeTruthy()
	end,
}
