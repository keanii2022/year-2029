local Movement = require("../src/shared/Logic/Movement")
local expect = require("./expect")

local config = {
	WalkSpeed = 14,
	SprintSpeed = 22,
	CrouchSpeed = 7,
	BobStride = 7,
	BobSide = 0.08,
	BobUp = 0.06,
	BobRoll = 0.6,
	BobMaxAmount = 1.6,
	SwayPerTurn = 1.8,
	SwayMax = 4,
}

return {
	["crouch wins over sprint"] = function()
		expect(Movement.stance(true, true, 1)).toBe("Crouch")
	end,
	["sprint only while moving"] = function()
		expect(Movement.stance(true, false, 1)).toBe("Sprint")
		expect(Movement.stance(true, false, 0)).toBe("Walk")
		expect(Movement.stance(false, false, 1)).toBe("Walk")
	end,
	["target speed per stance"] = function()
		expect(Movement.targetSpeed(config, "Walk")).toBe(14)
		expect(Movement.targetSpeed(config, "Sprint")).toBe(22)
		expect(Movement.targetSpeed(config, "Crouch")).toBe(7)
	end,
	["isStance rejects junk"] = function()
		expect(Movement.isStance("Sprint")).toBeTruthy()
		expect(Movement.isStance("Fly")).toBeFalsy()
		expect(Movement.isStance(5)).toBeFalsy()
	end,
	["smooth eases without overshooting"] = function()
		local value = Movement.smooth(0, 10, 8, 1 / 60)
		expect(value > 0 and value < 10).toBeTruthy()
		expect(Movement.smooth(0, 10, 8, 100)).toBeNear(10, 1e-3)
	end,
	["smooth is frame-rate independent"] = function()
		local one = Movement.smooth(0, 10, 5, 0.1)
		local two = Movement.smooth(Movement.smooth(0, 10, 5, 0.05), 10, 5, 0.05)
		expect(two).toBeNear(one)
	end,
	["bob amount scales with speed and caps"] = function()
		expect(Movement.bobAmount(config, 0)).toBe(0)
		expect(Movement.bobAmount(config, 14)).toBe(1)
		expect(Movement.bobAmount(config, 100)).toBe(1.6)
	end,
	["phase completes one cycle per stride"] = function()
		local phase = Movement.advancePhase(config, 0, 7, 0.5)
		expect(phase).toBeNear(math.pi)
		expect(Movement.advancePhase(config, phase, 7, 0.5)).toBeNear(0)
	end,
	["bob is still when amount is zero"] = function()
		local side, up, roll = Movement.bobOffset(config, 1.2, 0)
		expect(side).toBe(0)
		expect(up == 0).toBeTruthy()
		expect(roll).toBe(0)
	end,
	["bob dips down, never up"] = function()
		for phase = 0, 6, 0.5 do
			local _, up = Movement.bobOffset(config, phase, 1)
			expect(up <= 0).toBeTruthy()
		end
	end,
	["sway leans against the turn and clamps"] = function()
		expect(Movement.swayTarget(config, 1)).toBeNear(-1.8)
		expect(Movement.swayTarget(config, -100)).toBe(4)
	end,
}
