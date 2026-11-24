local ClockEffects = require("../src/shared/Logic/ClockEffects")
local expect = require("./expect")

local PATTERN = { 0.1, 0.2, 0.1, 0.3 }

return {
	["siren pulse starts dark and peaks mid flash"] = function()
		expect(ClockEffects.sirenPulse(0, 1)).toBeNear(0)
		expect(ClockEffects.sirenPulse(0.5, 1)).toBeNear(1)
		expect(ClockEffects.sirenPulse(0.25, 2)).toBeNear(1)
	end,
	["flicker starts with lights off"] = function()
		local on, done = ClockEffects.flicker(0.05, PATTERN)
		expect(on).toBeFalsy()
		expect(done).toBeFalsy()
	end,
	["flicker comes back on between the off beats"] = function()
		expect((ClockEffects.flicker(0.2, PATTERN))).toBeTruthy()
		expect((ClockEffects.flicker(0.35, PATTERN))).toBeFalsy()
		expect((ClockEffects.flicker(0.5, PATTERN))).toBeTruthy()
	end,
	["flicker ends dark"] = function()
		local on, done = ClockEffects.flicker(0.8, PATTERN)
		expect(on).toBeFalsy()
		expect(done).toBeTruthy()
	end,
	["countdown starts so it ends on lights out"] = function()
		expect(ClockEffects.countdownDelay(60, 11)).toBe(49)
		expect(ClockEffects.countdownDelay(11, 11)).toBe(0)
	end,
	["countdown skipped when there is no room left"] = function()
		expect(ClockEffects.countdownDelay(5, 11)).toBe(nil)
	end,
}
