-- Trying to make a builder robot stand stuck forever: every leg must end in give_up eventually, no
-- matter how it creeps, stalls or bumps walls, and skipped pieces must come back on time.
local BuildPlan = require("../src/shared/Logic/BuildPlan")
local expect = require("./expect")

local SETTINGS = {
	FetchTimeout = 35,
	CarryTimeout = 45,
	StuckSeconds = 3,
	Repaths = 2,
	ProgressStep = 1,
}

-- Steps a leg at 5 Hz until it gives up; returns when it did (nil if it never did within limit).
local function runUntilGiveUp(
	leg,
	distanceAt: (number) -> number,
	blockedAt: (number) -> boolean,
	limit: number
)
	local t = leg.since
	while t <= leg.since + limit do
		t += 0.2
		if BuildPlan.step(leg, t, distanceAt(t), blockedAt(t), SETTINGS) == "give_up" then
			return t
		end
	end
	return nil
end

local function never()
	return false
end

return {
	["the timeout is strict: exactly at it keeps going, just past gives up"] = function()
		local fetch = BuildPlan.leg("fetch", 0, 100)
		expect(BuildPlan.step(fetch, 35, 100 - 35 * 2, false, SETTINGS)).toBe("go")
		expect(BuildPlan.step(fetch, 35.001, 0, false, SETTINGS)).toBe("give_up")
		local carry = BuildPlan.leg("carry", 0, 100)
		expect(BuildPlan.step(carry, 45, 100 - 45 * 2, false, SETTINGS)).toBe("go")
		expect(BuildPlan.step(carry, 45.001, 0, false, SETTINGS)).toBe("give_up")
	end,
	["creeping just over a stud at a time can't outlive the timeout"] = function()
		local leg = BuildPlan.leg("carry", 0, 1000)
		local gaveUp = runUntilGiveUp(leg, function(t)
			return 1000 - math.floor(t / 2.9) * 1.01
		end, never, 1000)
		expect(gaveUp ~= nil).toBeTruthy()
		expect((gaveUp :: number) <= 45.2).toBeTruthy()
	end,
	["standing dead still gives up after the re-paths, well inside the timeout"] = function()
		local leg = BuildPlan.leg("fetch", 0, 30)
		local gaveUp = runUntilGiveUp(leg, function()
			return 30
		end, never, 1000)
		expect(gaveUp ~= nil).toBeTruthy()
		-- three stalls of a bit over 3 s each: re-path, re-path, give up
		expect((gaveUp :: number) < 10).toBeTruthy()
	end,
	["a wall in the way the whole time gives up within a few seconds"] = function()
		local leg = BuildPlan.leg("carry", 0, 30)
		local gaveUp = runUntilGiveUp(leg, function()
			return 30
		end, function()
			return true
		end, 1000)
		expect(gaveUp ~= nil).toBeTruthy()
		expect((gaveUp :: number) < 4).toBeTruthy()
	end,
	["blocked exactly one second is still a go, a hair over re-paths"] = function()
		local leg = BuildPlan.leg("carry", 0, 20)
		expect(BuildPlan.step(leg, 1, 20, true, SETTINGS)).toBe("go")
		expect(BuildPlan.step(leg, 1.001, 20, true, SETTINGS)).toBe("repath")
	end,
	["bouncing back and forth across a doorway is not progress"] = function()
		local leg = BuildPlan.leg("fetch", 0, 20)
		local gaveUp = runUntilGiveUp(leg, function(t)
			return if math.floor(t * 5) % 2 == 0 then 20 else 19.5
		end, never, 1000)
		expect(gaveUp ~= nil).toBeTruthy()
		expect((gaveUp :: number) < 10).toBeTruthy()
	end,
	["walking away from the goal never counts as progress"] = function()
		local leg = BuildPlan.leg("fetch", 0, 10)
		local gaveUp = runUntilGiveUp(leg, function(t)
			return 10 + t
		end, never, 1000)
		expect(gaveUp ~= nil).toBeTruthy()
		expect((gaveUp :: number) < 10).toBeTruthy()
	end,
	["once given up it stays given up"] = function()
		local leg = BuildPlan.leg("fetch", 0, 30)
		runUntilGiveUp(leg, function()
			return 30
		end, never, 1000)
		expect(BuildPlan.step(leg, 100, 30, false, SETTINGS)).toBe("give_up")
		expect(BuildPlan.step(leg, 100.2, 0, false, SETTINGS)).toBe("give_up")
	end,
	["zero re-paths allowed gives up on the first stall"] = function()
		local strict = table.clone(SETTINGS)
		strict.Repaths = 0
		local leg = BuildPlan.leg("carry", 0, 20)
		expect(BuildPlan.step(leg, 3.5, 20, false, strict)).toBe("give_up")
	end,
	["a NaN distance can't hang the leg"] = function()
		local leg = BuildPlan.leg("fetch", 0, 0 / 0)
		local gaveUp = runUntilGiveUp(leg, function()
			return 0 / 0
		end, never, 1000)
		expect(gaveUp ~= nil).toBeTruthy()
	end,
	["an infinite starting distance still takes real progress after"] = function()
		local leg = BuildPlan.leg("fetch", 0, math.huge)
		expect(BuildPlan.step(leg, 1, 1e9, false, SETTINGS)).toBe("go")
		expect(leg.best).toBe(1e9)
	end,

	-- Skip timers ---------------------------------------------------------------------------------

	["a skipped piece comes back exactly when its time is up"] = function()
		local skipped = {}
		BuildPlan.skip(skipped, "crate", 10, 120)
		expect(BuildPlan.skipping(skipped, 129.999).crate).toBe(true)
		expect(BuildPlan.skipping(skipped, 130).crate).toBe(nil)
		expect(skipped.crate).toBe(nil) -- forgotten, not just hidden
	end,
	["skipping again pushes the time out instead of stacking"] = function()
		local skipped = {}
		BuildPlan.skip(skipped, "crate", 0, 120)
		BuildPlan.skip(skipped, "crate", 100, 120)
		expect(BuildPlan.skipping(skipped, 150).crate).toBe(true)
		expect(BuildPlan.skipping(skipped, 220).crate).toBe(nil)
	end,
	["ten thousand expired skips are all forgotten in one pass"] = function()
		local skipped = {}
		for i = 1, 10000 do
			BuildPlan.skip(skipped, i, 0, if i % 2 == 0 then 10 else 1000)
		end
		local set = BuildPlan.skipping(skipped, 500)
		local live, kept = 0, 0
		for _ in set do
			live += 1
		end
		for _ in skipped do
			kept += 1
		end
		expect(live).toBe(5000)
		expect(kept).toBe(5000)
	end,
	["an empty skip list is an empty set"] = function()
		expect(next(BuildPlan.skipping({}, 0))).toBe(nil)
	end,
	["full counts the cap itself as full, and a zero cap is always full"] = function()
		expect(BuildPlan.full(5, 6)).toBe(false)
		expect(BuildPlan.full(6, 6)).toBe(true)
		expect(BuildPlan.full(0, 0)).toBe(true)
		expect(BuildPlan.full(-1, 6)).toBe(false)
	end,
}
