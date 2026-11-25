local BuildPlan = require("../src/shared/Logic/BuildPlan")
local expect = require("./expect")

local SETTINGS = {
	FetchTimeout = 35,
	CarryTimeout = 45,
	StuckSeconds = 3,
	Repaths = 2,
	ProgressStep = 1,
}

return {
	["steady progress keeps going"] = function()
		local leg = BuildPlan.leg("fetch", 0, 30)
		for t = 1, 20 do
			expect(BuildPlan.step(leg, t, 30 - t * 1.4, false, SETTINGS)).toBe("go")
		end
	end,
	["a stall re-paths, then gives up after a few"] = function()
		local leg = BuildPlan.leg("carry", 0, 20)
		expect(BuildPlan.step(leg, 2, 20, false, SETTINGS)).toBe("go")
		expect(BuildPlan.step(leg, 3.5, 20, false, SETTINGS)).toBe("repath")
		expect(BuildPlan.step(leg, 5, 20, false, SETTINGS)).toBe("go")
		expect(BuildPlan.step(leg, 7, 20, false, SETTINGS)).toBe("repath")
		expect(BuildPlan.step(leg, 10.5, 20, false, SETTINGS)).toBe("give_up")
	end,
	["a wall in the way re-paths sooner"] = function()
		local leg = BuildPlan.leg("carry", 0, 20)
		expect(BuildPlan.step(leg, 0.5, 20, true, SETTINGS)).toBe("go")
		expect(BuildPlan.step(leg, 1.2, 20, true, SETTINGS)).toBe("repath")
	end,
	["progress after a re-path resets the count"] = function()
		local leg = BuildPlan.leg("fetch", 0, 20)
		BuildPlan.step(leg, 3.5, 20, false, SETTINGS)
		expect(leg.repaths).toBe(1)
		BuildPlan.step(leg, 4, 15, false, SETTINGS)
		expect(leg.repaths).toBe(0)
	end,
	["each leg has its own timeout"] = function()
		local fetch = BuildPlan.leg("fetch", 0, 500)
		local carry = BuildPlan.leg("carry", 0, 500)
		for t = 1, 40 do
			BuildPlan.step(fetch, t, 500 - t * 5, false, SETTINGS)
			BuildPlan.step(carry, t, 500 - t * 5, false, SETTINGS)
		end
		expect(BuildPlan.step(fetch, 41, 280, false, SETTINGS)).toBe("give_up")
		expect(BuildPlan.step(carry, 41, 280, false, SETTINGS)).toBe("go")
	end,
	["a full plan stops the builder"] = function()
		expect(BuildPlan.full(5, 6)).toBeFalsy()
		expect(BuildPlan.full(6, 6)).toBeTruthy()
	end,
	["skipped pieces come back after a while"] = function()
		local skipped = {}
		BuildPlan.skip(skipped, "crate", 0, 120)
		expect(BuildPlan.skipping(skipped, 60).crate).toBe(true)
		expect(BuildPlan.skipping(skipped, 121).crate).toBe(nil)
		expect(skipped.crate).toBe(nil)
	end,
}
