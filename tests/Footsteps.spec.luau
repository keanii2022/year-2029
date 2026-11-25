local Footsteps = require("../src/shared/Logic/Footsteps")
local expect = require("./expect")

local SETTINGS = {
	Walk = { Prefix = "walk_", Volume = 0.4, RollOff = { 6, 50 } },
	Sprint = { Prefix = "run_", Volume = 0.8, RollOff = { 8, 90 } },
	Crouch = { Sound = "crouch_step", Volume = 0.1, RollOff = { 2, 14 } },
}

return {
	["floors fall back to concrete"] = function()
		local floors = { Metal = "metal", WoodPlanks = "wood" }
		expect(Footsteps.floor("Metal", floors)).toBe("metal")
		expect(Footsteps.floor("WoodPlanks", floors)).toBe("wood")
		expect(Footsteps.floor("SmoothPlastic", floors)).toBe("concrete")
	end,
	["stance picks the sound and how far it carries"] = function()
		expect(Footsteps.step("Walk", "metal", SETTINGS).sound).toBe("walk_metal")
		local run = Footsteps.step("Sprint", "wood", SETTINGS)
		expect(run.sound).toBe("run_wood")
		expect(run.volume).toBe(0.8)
		local crouch = Footsteps.step("Crouch", "metal", SETTINGS)
		expect(crouch.sound).toBe("crouch_step")
		expect(crouch.rollOff[2]).toBe(14)
	end,
	["a foot lands as the bob passes 0 and pi"] = function()
		expect(Footsteps.footDown(0.5, 1)).toBe(false)
		expect(Footsteps.footDown(3, 3.3)).toBe(true)
		expect(Footsteps.footDown(6.2, 0.1)).toBe(true)
	end,
	["walked distance turns into steps"] = function()
		local down, left = Footsteps.advance(3, 1, 3.5)
		expect(down).toBe(true)
		expect(left).toBeNear(0.5)
		down, left = Footsteps.advance(1, 1, 3.5)
		expect(down).toBe(false)
		expect(left).toBe(2)
	end,
}
