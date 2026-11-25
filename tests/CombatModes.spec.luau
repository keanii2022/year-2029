local CombatModes = require("../src/shared/Logic/CombatModes")
local expect = require("./expect")

local semi = { mode = "semi", fireInterval = 0.22 }
local auto = { mode = "auto", fireInterval = 0.09 }
local burst = { mode = "burst", fireInterval = 0.45, burstCount = 3, burstInterval = 0.08 }
local pump = { mode = "pump", fireInterval = 0.9 }

return {
	["shots per pull: burst fires its count, everything else one"] = function()
		expect(CombatModes.shotsPerPull(semi :: any)).toBe(1)
		expect(CombatModes.shotsPerPull(auto :: any)).toBe(1)
		expect(CombatModes.shotsPerPull(pump :: any)).toBe(1)
		expect(CombatModes.shotsPerPull(burst :: any)).toBe(3)
	end,
	["only auto keeps firing while held"] = function()
		expect(CombatModes.holdsToFire(auto :: any)).toBeTruthy()
		expect(CombatModes.holdsToFire(semi :: any)).toBeFalsy()
		expect(CombatModes.holdsToFire(burst :: any)).toBeFalsy()
		expect(CombatModes.holdsToFire({ mode = "single-action", fireInterval = 0.5 } :: any)).toBeFalsy()
	end,
	["gapAfter runs quick inside a burst, full interval after it"] = function()
		expect(CombatModes.gapAfter(burst :: any, 1)).toBe(0.08)
		expect(CombatModes.gapAfter(burst :: any, 2)).toBe(0.08)
		expect(CombatModes.gapAfter(burst :: any, 3)).toBe(0.45)
		expect(CombatModes.gapAfter(semi :: any, 1)).toBe(0.22)
	end,
	["minGap lets a burst through and then makes it wait"] = function()
		expect(CombatModes.minGap(burst :: any, 0)).toBe(0.45)
		expect(CombatModes.minGap(burst :: any, 1)).toBe(0.08)
		expect(CombatModes.minGap(burst :: any, 2)).toBe(0.08)
		expect(CombatModes.minGap(burst :: any, 3)).toBe(0.45)
		expect(CombatModes.minGap(pump :: any, 1)).toBe(0.9)
	end,
	["burstAfterShot counts up, restarts when spent or after a pause"] = function()
		expect(CombatModes.burstAfterShot(burst :: any, 0, 5, 0.8)).toBe(1)
		expect(CombatModes.burstAfterShot(burst :: any, 1, 0.08, 0.8)).toBe(2)
		expect(CombatModes.burstAfterShot(burst :: any, 2, 0.08, 0.8)).toBe(3)
		expect(CombatModes.burstAfterShot(burst :: any, 3, 0.5, 0.8)).toBe(1)
		expect(CombatModes.burstAfterShot(burst :: any, 1, 0.4, 0.8)).toBe(1)
		expect(CombatModes.burstAfterShot(semi :: any, 0, 1, 0.8)).toBe(0)
	end,
	["a three-shot burst can't be stretched into a fourth quick shot"] = function()
		local count, allowed = 0, 0
		for _ = 1, 4 do
			if 0.08 >= CombatModes.minGap(burst :: any, count) then
				allowed += 1
				count = CombatModes.burstAfterShot(burst :: any, count, 0.08, 0.8)
			end
		end
		-- The first quick shot only counts once a burst has started, so a fresh pull waits the interval.
		expect(allowed).toBe(0)
		count = CombatModes.burstAfterShot(burst :: any, 0, 5, 0.8)
		for _ = 1, 4 do
			if 0.08 >= CombatModes.minGap(burst :: any, count) then
				allowed += 1
				count = CombatModes.burstAfterShot(burst :: any, count, 0.08, 0.8)
			end
		end
		expect(allowed).toBe(2)
	end,
	["pellet pattern: centre first, the rest within the spread"] = function()
		local offsets = CombatModes.pelletOffsets(8, 6)
		expect(#offsets).toBe(8)
		expect(offsets[1].x).toBe(0)
		expect(offsets[1].y).toBe(0)
		for index = 2, 8 do
			local radius = math.sqrt(offsets[index].x ^ 2 + offsets[index].y ^ 2)
			expect(radius <= 6.0001).toBeTruthy()
			expect(radius > 3).toBeTruthy()
		end
		expect(CombatModes.pelletOffsets(8, 6)[4].x).toBe(offsets[4].x)
	end,
	["pump slides back then forward"] = function()
		expect(CombatModes.pumpTravel(0, 0.5)).toBe(0)
		expect(CombatModes.pumpTravel(0.25, 0.5)).toBe(1)
		expect(CombatModes.pumpTravel(0.125, 0.5)).toBeNear(0.5)
		expect(CombatModes.pumpTravel(0.375, 0.5)).toBeNear(0.5)
		expect(CombatModes.pumpTravel(0.5, 0.5)).toBe(0)
	end,
	["hammer cocks back, holds, snaps forward on the shot"] = function()
		expect(CombatModes.hammerLift(10, 10, 0.2, 0, 0.05)).toBe(0)
		expect(CombatModes.hammerLift(10.1, 10, 0.2, 0, 0.05)).toBeNear(0.5)
		expect(CombatModes.hammerLift(11, 10, 0.2, 0, 0.05)).toBe(1)
		expect(CombatModes.hammerLift(11.025, 10, 0.2, 11, 0.05)).toBeNear(0.5)
		expect(CombatModes.hammerLift(11.1, 10, 0.2, 11, 0.05)).toBe(0)
	end,
	["drum turns one chamber per shot and with the cock"] = function()
		expect(CombatModes.drumTurn(6, 6, 6, 0)).toBe(0)
		expect(CombatModes.drumTurn(5, 6, 6, 0)).toBe(1)
		expect(CombatModes.drumTurn(5, 6, 6, 0.5)).toBe(1.5)
		expect(CombatModes.drumTurn(0, 6, 6, 0)).toBe(0)
		expect(CombatModes.drumTurn(1, 6, 6, 1)).toBe(0)
	end,
}
