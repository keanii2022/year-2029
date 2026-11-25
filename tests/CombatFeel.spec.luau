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

	["shotFeel uses the gun's own feel, else the default"] = function()
		local feels = {
			pistol = { sound = "p", kick = 2, twitch = 0, fovPunch = 1, shake = 0, weight = 1 },
			shotgun = { sound = "s", kick = 4, twitch = 1, fovPunch = 2, shake = 1, weight = 2 },
		}
		local gunFeel = { Boomer = "shotgun", Broken = "missing" }
		expect(CombatFeel.shotFeel(gunFeel, feels, "pistol", "Boomer").sound).toBe("s")
		expect(CombatFeel.shotFeel(gunFeel, feels, "pistol", "Unknown").sound).toBe("p")
		expect(CombatFeel.shotFeel(gunFeel, feels, "pistol", "Broken").sound).toBe("p")
		expect(CombatFeel.shotFeel(gunFeel, feels, "pistol", nil).sound).toBe("p")
	end,

	["kickAngles goes up by kick and twitches sideways inside the limit"] = function()
		local pitch, yaw = CombatFeel.kickAngles(3, 0.5, 0)
		expect(pitch).toBe(3)
		expect(yaw).toBeNear(-0.5)
		_, yaw = CombatFeel.kickAngles(3, 0.5, 1)
		expect(yaw).toBeNear(0.5)
		_, yaw = CombatFeel.kickAngles(3, 0.5, 0.5)
		expect(yaw).toBeNear(0)
	end,

	["shakeFade starts full and dies out by the end"] = function()
		expect(CombatFeel.shakeFade(0, 0.2)).toBe(1)
		expect(CombatFeel.shakeFade(0.1, 0.2)).toBeNear(0.25)
		expect(CombatFeel.shakeFade(0.2, 0.2)).toBe(0)
		expect(CombatFeel.shakeFade(-1, 0.2)).toBe(0)
		expect(CombatFeel.shakeFade(0.1, 0)).toBe(0)
	end,

	["impactKind rings metal and thuds everything else"] = function()
		expect(CombatFeel.impactKind("Metal")).toBe("metal")
		expect(CombatFeel.impactKind("DiamondPlate")).toBe("metal")
		expect(CombatFeel.impactKind("CorrodedMetal")).toBe("metal")
		expect(CombatFeel.impactKind("Concrete")).toBe("concrete")
		expect(CombatFeel.impactKind("Plastic")).toBe("concrete")
	end,

	["whizzes only for a head near the shot, past the shooter and before the hit"] = function()
		expect(CombatFeel.whizzes(30, 100, 2, 4, 6)).toBe(true)
		expect(CombatFeel.whizzes(30, 100, 5, 4, 6)).toBe(false)
		expect(CombatFeel.whizzes(3, 100, 1, 4, 6)).toBe(false)
		expect(CombatFeel.whizzes(102, 100, 3, 4, 6)).toBe(true)
		expect(CombatFeel.whizzes(150, 100, 3, 4, 6)).toBe(false)
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
