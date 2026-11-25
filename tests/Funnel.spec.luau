local Funnel = require("../src/shared/Logic/Funnel")
local expect = require("./expect")

local steps = {
	{ name = "Joined" },
	{ name = "FirstLoot" },
	{ name = "FirstGrab" },
	{ name = "HeardSiren" },
	{ name = "SurvivedNight" },
}

return {
	["each step logs once"] = function()
		local progress = {}
		expect(#Funnel.reach(progress, steps, "Joined")).toBe(1)
		expect(#Funnel.reach(progress, steps, "Joined")).toBe(0)
	end,
	["skipping ahead fills in the earlier steps in order"] = function()
		local progress = {}
		local logged = Funnel.reach(progress, steps, "FirstGrab")
		expect(#logged).toBe(3)
		expect(logged[1]).toBe(1)
		expect(logged[3]).toBe(3)
		expect(#Funnel.reach(progress, steps, "FirstLoot")).toBe(0)
	end,
	["unknown moments log nothing"] = function()
		expect(#Funnel.reach({}, steps, "Danced")).toBe(0)
		expect(Funnel.stepOf(steps, "Danced")).toBe(nil)
	end,
}
