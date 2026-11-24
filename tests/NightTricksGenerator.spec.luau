local Generator = require("../src/shared/Logic/NightTricksGenerator")
local expect = require("./expect")

local settings = { MaxFuel = 100, BurnPerSecond = 1, SputterAt = 10, PullChances = { 0.3, 0.6, 1 } }

return {
	["a broken generator won't start until fixed"] = function()
		local state = Generator.new(50)
		local _, result = Generator.pull(state, 0, settings)
		expect(result).toBe("broken")
		state, result = Generator.pull(Generator.fix(state), 0, settings)
		expect(result).toBe("started")
		expect(state.running).toBe(true)
	end,
	["pulls fail a few times but the last chance always catches"] = function()
		local state = Generator.fix(Generator.new(50))
		local result
		state, result = Generator.pull(state, 0.9, settings)
		expect(result).toBe("failed")
		state, result = Generator.pull(state, 0.9, settings)
		expect(result).toBe("failed")
		expect(Generator.pullChance(state.pulls, settings)).toBe(1)
		state, result = Generator.pull(state, 0.99, settings)
		expect(result).toBe("started")
		expect(state.pulls).toBe(0)
	end,
	["no fuel means no start"] = function()
		local _, result = Generator.pull(Generator.fix(Generator.new(0)), 0, settings)
		expect(result).toBe("empty")
	end,
	["burns fuel, sputters once when low, then dies"] = function()
		local state = Generator.pull(Generator.fix(Generator.new(15)), 0, settings)
		local event
		state, event = Generator.tick(state, 4, settings)
		expect(event).toBe(nil)
		state, event = Generator.tick(state, 2, settings)
		expect(event).toBe("sputter")
		expect(Generator.isSputtering(state, settings)).toBe(true)
		state, event = Generator.tick(state, 2, settings)
		expect(event).toBe(nil)
		state, event = Generator.tick(state, 20, settings)
		expect(event).toBe("died")
		expect(state.running).toBe(false)
		expect(state.fixed).toBe(true)
	end,
	["refuel caps at max and needs a new pull"] = function()
		local state = Generator.refuel(Generator.fix(Generator.new(80)), 50, settings)
		expect(state.fuel).toBe(100)
		expect(state.running).toBe(false)
	end,
}
