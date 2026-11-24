local Body = require("../src/shared/Logic/NightTricksBody")
local expect = require("./expect")

local battery = { DrainPerSecond = 1, LowAt = 20, FlickerSlot = 0.1, FlickerDim = 0.15 }
local breath = { Max = 100, DrainPerSecond = 20, RefillPerSecond = 10, MinToStart = 25 }
local winded = { SprintGain = 1, Rest = 0.5, Max = 10, BreatheAbove = 4 }

return {
	["battery drains only while on and stops at zero"] = function()
		expect(Body.drainBattery(50, false, 10, battery)).toBe(50)
		expect(Body.drainBattery(50, true, 10, battery)).toBe(40)
		expect(Body.drainBattery(5, true, 10, battery)).toBe(0)
	end,
	["switching on a dead light swaps a spare or stays dead"] = function()
		expect(Body.switchOn(10, false)).toBe("on")
		expect(Body.switchOn(0, true)).toBe("swap")
		expect(Body.switchOn(0, false)).toBe("dead")
	end,
	["flicker is full above low, off at zero, and dips when low"] = function()
		expect(Body.flicker(80, 3.3, battery)).toBe(1)
		expect(Body.flicker(0, 3.3, battery)).toBe(0)
		local dips = 0
		for i = 1, 200 do
			if Body.flicker(1, i * 0.1, battery) < 1 then
				dips += 1
			end
		end
		expect(dips > 40 and dips < 180).toBeTruthy()
	end,
	["holding breath drains and gasps when empty"] = function()
		local state = { level = 30, holding = true }
		local nextState, event = Body.stepBreath(state, 1, breath)
		expect(nextState.level).toBe(10)
		expect(nextState.holding).toBe(true)
		expect(event).toBe(nil)
		nextState, event = Body.stepBreath(nextState, 1, breath)
		expect(nextState.level).toBe(0)
		expect(nextState.holding).toBe(false)
		expect(event).toBe("gasp")
	end,
	["breath refills when not holding and caps at max"] = function()
		local nextState = Body.stepBreath({ level = 95, holding = false }, 1, breath)
		expect(nextState.level).toBe(100)
	end,
	["can only hold while hidden with enough breath"] = function()
		expect(Body.canHold({ level = 50, holding = false }, true, breath)).toBe(true)
		expect(Body.canHold({ level = 50, holding = false }, false, breath)).toBe(false)
		expect(Body.canHold({ level = 10, holding = false }, true, breath)).toBe(false)
	end,
	["winded after a sprint, not during"] = function()
		local effort = 0
		for _ = 1, 6 do
			effort = Body.stepEffort(effort, true, 1, winded)
		end
		expect(effort).toBe(6)
		expect(Body.isWinded(effort, true, winded)).toBe(false)
		expect(Body.isWinded(effort, false, winded)).toBe(true)
		effort = Body.stepEffort(effort, false, 10, winded)
		expect(effort).toBe(1)
		expect(Body.isWinded(effort, false, winded)).toBe(false)
	end,
}
