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
	["a wary dog stays low and still, tail quiet"] = function()
		local drop, pitch = DogPoses.body("watch")
		expect(drop > 0).toBeTruthy()
		expect(pitch < 0).toBeTruthy()
		expect(DogPoses.limbs("watch", 0, 1, false, false).Tail).toBe(0)
		expect(DogPoses.limbs("backoff", 0, 1, true, false).Tail).toBe(-1)
	end,
	["willing but unsure: a slow, small wag"] = function()
		local biggest = 0
		for t = 0, 3, 0.1 do
			biggest = math.max(biggest, math.abs(DogPoses.limbs("settle", 0, t, false, false).Tail))
		end
		expect(biggest > 0.2 and biggest < 0.5).toBeTruthy()
	end,
	["a head tilt tell turns the head"] = function()
		expect(DogPoses.limbs("sit", 0, 0, false, false, "tilt").Head).toBe(0.7)
	end,
}
