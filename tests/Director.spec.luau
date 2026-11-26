local Director = require("../src/shared/Logic/Director")
local expect = require("./expect")

local SETTINGS = {
	BackOff = 0.5,
	NudgeAfter = 90,
	NudgeRamp = 180,
	NudgeMax = 2,
	MinGap = 160,
	MaxGap = 1400,
	BetweenSlack = 0.35,
	PastFort = 45,
	GroupClearance = 70,
	FortClearance = 40,
	Jitter = 25,
	RandomShare = 0.3,
	Weights = { midpoint = 3, pastFort = 2, installation = 2 },
}

local function rolls(...: number): () -> number
	local list = { ... }
	local index = 0
	return function()
		index = index % #list + 1
		return list[index]
	end
end

local function count(list: { any }, kind: string): number
	local n = 0
	for _, item in list do
		if item.kind == kind then
			n += 1
		end
	end
	return n
end

return {
	["players chained close together form one group, far ones their own"] = function()
		local groups = Director.cluster({
			{ x = 0, z = 0 },
			{ x = 30, z = 0 },
			{ x = 60, z = 0 }, -- chained through the middle one
			{ x = 500, z = 500 },
		}, 45)
		expect(#groups).toBe(2)
		local big = if groups[1].count == 3 then groups[1] else groups[2]
		expect(big.count).toBe(3)
		expect(big.x).toBeNear(30)
		expect(big.z).toBeNear(0)
		expect(#(big.members :: { number })).toBe(3)
		expect(#Director.cluster({}, 45)).toBe(0)
	end,
	["groups within meet range count as together"] = function()
		local near = { { x = 0, z = 0, count = 1 }, { x = 100, z = 0, count = 2 } }
		local far = { { x = 0, z = 0, count = 1 }, { x = 600, z = 0, count = 2 } }
		expect(Director.together(near, 110)).toBeTruthy()
		expect(Director.together(far, 110)).toBeFalsy()
	end,
	["it backs off while groups mix it up and nudges sooner the longer they're apart"] = function()
		expect(Director.pace(500, true, SETTINGS)).toBe(0.5)
		expect(Director.pace(30, false, SETTINGS)).toBe(1)
		expect(Director.pace(180, false, SETTINGS)).toBeNear(1.5)
		expect(Director.pace(5000, false, SETTINGS)).toBe(2)
	end,
	["two groups apart get a halfway spot"] = function()
		local groups = { { x = 0, z = 0, count = 2 }, { x = 400, z = 0, count = 1 } }
		local found = Director.candidates(groups, {}, {}, SETTINGS)
		expect(#found).toBe(1)
		expect(found[1].kind).toBe("midpoint")
		expect(found[1].x).toBeNear(200)
		expect(found[1].z).toBeNear(0)
	end,
	["groups already close or impossibly far get no halfway spot"] = function()
		local close = { { x = 0, z = 0, count = 1 }, { x = 120, z = 0, count = 1 } }
		local far = { { x = 0, z = 0, count = 1 }, { x = 2000, z = 0, count = 1 } }
		expect(#Director.candidates(close, {}, {}, SETTINGS)).toBe(0)
		expect(#Director.candidates(far, {}, {}, SETTINGS)).toBe(0)
	end,
	["a spot just past someone else's fort, on the far side from the group"] = function()
		local groups = { { x = 0, z = 0, count = 1 } }
		local forts = { { x = 300, z = 0 } }
		local found = Director.candidates(groups, forts, {}, SETTINGS)
		expect(count(found, "pastFort")).toBe(1)
		expect(found[1].x).toBeNear(345)
		expect(found[1].z).toBeNear(0)
	end,
	["never a spot past the group's own fort: that only pulls them home"] = function()
		local groups = Director.cluster({ { x = 0, z = 0, id = 7 } }, 50)
		local own = Director.cluster({ { x = 300, z = 0, id = 7 }, { x = 302, z = 0, id = 7 } }, 50)
		local forts = { { x = own[1].x, z = own[1].z, ids = own[1].ids } }
		expect(count(Director.candidates(groups, forts, {}, SETTINGS), "pastFort")).toBe(0)
		forts[1].ids = { [8] = true }
		expect(count(Director.candidates(groups, forts, {}, SETTINGS), "pastFort")).toBe(1)
	end,
	["an installation between two groups counts, one off to the side doesn't"] = function()
		local groups = { { x = 0, z = 0, count = 1 }, { x = 600, z = 0, count = 1 } }
		local halls = {
			{ x = 300, z = 120, room = "between" },
			{ x = 300, z = 700, room = "aside" },
		}
		local found = Director.candidates(groups, {}, halls, SETTINGS)
		expect(count(found, "installation")).toBe(1)
		for _, candidate in found do
			if candidate.kind == "installation" then
				expect(candidate.room).toBe("between")
			end
		end
	end,
	["never right on top of a fort or a lone player"] = function()
		-- the midpoint of the two outer groups lands on the lone player in the middle
		local groups = {
			{ x = 0, z = 0, count = 2 },
			{ x = 200, z = 0, count = 1 },
			{ x = 400, z = 0, count = 2 },
		}
		for _, candidate in Director.candidates(groups, {}, {}, SETTINGS) do
			for _, group in groups do
				local d = math.sqrt((candidate.x - group.x) ^ 2 + (candidate.z - group.z) ^ 2)
				expect(d >= SETTINGS.GroupClearance).toBeTruthy()
			end
		end
		local apart = { { x = 0, z = 0, count = 1 }, { x = 400, z = 0, count = 1 } }
		local fort = { x = 210, z = 0 }
		for _, candidate in Director.candidates(apart, { fort }, {}, SETTINGS) do
			expect(candidate.kind).toBe("pastFort")
			local d = math.sqrt((candidate.x - fort.x) ^ 2 + (candidate.z - fort.z) ^ 2)
			expect(d >= SETTINGS.FortClearance).toBeTruthy()
		end
	end,
	["picking sometimes goes random, otherwise lands near a candidate"] = function()
		local candidates = { { x = 200, z = 0, kind = "midpoint", weight = 3 } }
		expect(Director.pick(candidates, SETTINGS, rolls(0.1))).toBe(nil)
		expect(Director.pick({}, SETTINGS, rolls(0.9))).toBe(nil)
		local spot = Director.pick(candidates, SETTINGS, rolls(0.9, 0.5, 0.25, 1)) :: Director.Candidate
		expect(spot.kind).toBe("midpoint")
		local drift = math.sqrt((spot.x - 200) ^ 2 + spot.z ^ 2)
		expect(drift > 0 and drift <= SETTINGS.Jitter).toBeTruthy()
	end,
	["picking follows the weights"] = function()
		local candidates = {
			{ x = 0, z = 0, kind = "midpoint", weight = 3 },
			{ x = 900, z = 0, kind = "pastFort", weight = 1 },
		}
		expect((Director.pick(candidates, SETTINGS, rolls(0.9, 0.5, 0, 0)) :: any).kind).toBe("midpoint")
		expect((Director.pick(candidates, SETTINGS, rolls(0.9, 0.9, 0, 0)) :: any).kind).toBe("pastFort")
	end,
	["nearest finds the closest point"] = function()
		local signs = { { x = 0, z = 0, number = 1 }, { x = 100, z = 0, number = 2 } }
		expect(Director.nearest(signs, { x = 80, z = 10 }).number).toBe(2)
		expect(Director.nearest({}, { x = 0, z = 0 })).toBe(nil)
	end,
}
