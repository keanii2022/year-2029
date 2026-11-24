local CombatFeel = require("../src/shared/Logic/CombatFeel")
local expect = require("./expect")

return {
	["travelTime is distance over speed inside the limits"] = function()
		expect(CombatFeel.travelTime(100, 500, 0.05, 0.2)).toBeNear(0.2)
		expect(CombatFeel.travelTime(50, 500, 0.05, 0.2)).toBeNear(0.1)
		expect(CombatFeel.travelTime(2, 500, 0.05, 0.2)).toBe(0.05)
		expect(CombatFeel.travelTime(1000, 500, 0.05, 0.2)).toBe(0.2)
	end,

	["streakSpan grows from the muzzle, trails behind, and stops at the hit"] = function()
		local tail, head, done = CombatFeel.streakSpan(100, 0, 0.1, 8)
		expect(tail).toBe(0)
		expect(head).toBe(0)
		expect(done).toBe(false)

		tail, head, done = CombatFeel.streakSpan(100, 0.05, 0.1, 8)
		expect(head).toBeNear(50)
		expect(tail).toBeNear(42)
		expect(done).toBe(false)

		tail, head, done = CombatFeel.streakSpan(100, 0.2, 0.1, 8)
		expect(head).toBe(100)
		expect(tail).toBe(92)
		expect(done).toBe(true)
	end,

	["streakSpan never starts behind the muzzle on short shots"] = function()
		local tail, head = CombatFeel.streakSpan(3, 0.05, 0.1, 8)
		expect(tail).toBe(0)
		expect(head).toBeNear(1.5)
	end,

	["streakSpan with no travel time lands at once"] = function()
		local _, head, done = CombatFeel.streakSpan(40, 0, 0, 8)
		expect(head).toBe(40)
		expect(done).toBe(true)
	end,

	["recoil snaps up then eases back to rest"] = function()
		expect(CombatFeel.recoil(-1, 0.03, 0.2)).toBe(0)
		expect(CombatFeel.recoil(0.015, 0.03, 0.2)).toBeNear(0.5)
		expect(CombatFeel.recoil(0.03, 0.03, 0.2)).toBeNear(1)
		expect(CombatFeel.recoil(0.13, 0.03, 0.2)).toBeNear(0.25)
		expect(CombatFeel.recoil(0.23, 0.03, 0.2)).toBe(0)
		expect(CombatFeel.recoil(5, 0.03, 0.2)).toBe(0)
	end,

	["recoil falls steadily after the peak"] = function()
		local previous = CombatFeel.recoil(0.03, 0.03, 0.2)
		for step = 1, 10 do
			local now = CombatFeel.recoil(0.03 + step * 0.02, 0.03, 0.2)
			expect(now <= previous).toBe(true)
			previous = now
		end
	end,
}
