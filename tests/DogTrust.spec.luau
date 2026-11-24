local DogTrust = require("../src/shared/Logic/DogTrust")
local expect = require("./expect")

local SETTINGS = {
	Max = 100,
	VisitCap = 24,
	VisitGap = 90,
	DayCap = 40,
	FeedCooldown = 3,
	DecayPerMinute = 0.4,
	Stages = { Eats = 20, Wags = 45, Follows = 75 },
}

return {
	["one visit is capped"] = function()
		local record = DogTrust.new()
		expect((DogTrust.feed(record, 16, 0, 1, SETTINGS))).toBe(16)
		expect((DogTrust.feed(record, 16, 10, 1, SETTINGS))).toBe(8)
		local added, refusal = DogTrust.feed(record, 16, 20, 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("visit")
	end,
	["coming back later starts a new visit, but the day is capped"] = function()
		local record = DogTrust.new()
		DogTrust.feed(record, 24, 0, 1, SETTINGS)
		expect((DogTrust.feed(record, 24, 200, 1, SETTINGS))).toBe(16)
		local added, refusal = DogTrust.feed(record, 24, 400, 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("day")
		expect(record.trust).toBe(40)
	end,
	["it takes two days to follow"] = function()
		local record = DogTrust.new()
		for i = 0, 3 do
			DogTrust.feed(record, 24, i * 200, 1, SETTINGS)
		end
		expect(DogTrust.stage(record.trust, SETTINGS) == "follows").toBeFalsy()
		for i = 0, 3 do
			DogTrust.feed(record, 24, 1000 + i * 200, 2, SETTINGS)
		end
		expect(DogTrust.stage(record.trust, SETTINGS)).toBe("follows")
	end,
	["feeding too fast is refused"] = function()
		local record = DogTrust.new()
		DogTrust.feed(record, 5, 0, 1, SETTINGS)
		local added, refusal = DogTrust.feed(record, 5, 1, 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("cooldown")
	end,
	["trust never goes past max"] = function()
		local record = DogTrust.new()
		record.trust = 95
		expect((DogTrust.feed(record, 24, 0, 1, SETTINGS))).toBe(5)
		local _, refusal = DogTrust.room(record, 100, 1, SETTINGS)
		expect(refusal).toBe("full")
	end,
	["trust fades only while away"] = function()
		local record = DogTrust.new()
		record.trust = 50
		DogTrust.decay(record, 60, true, SETTINGS)
		expect(record.trust).toBe(50)
		DogTrust.decay(record, 60, false, SETTINGS)
		expect(record.trust).toBeNear(49.6)
		record.trust = 0.1
		DogTrust.decay(record, 600, false, SETTINGS)
		expect(record.trust).toBe(0)
	end,
	["stages go wary, eats, wags, follows"] = function()
		expect(DogTrust.stage(0, SETTINGS)).toBe("wary")
		expect(DogTrust.stage(20, SETTINGS)).toBe("eats")
		expect(DogTrust.stage(50, SETTINGS)).toBe("wags")
		expect(DogTrust.stage(75, SETTINGS)).toBe("follows")
		expect(DogTrust.atLeast("wags", "eats")).toBeTruthy()
		expect(DogTrust.atLeast("eats", "wags")).toBeFalsy()
	end,
	["hearts fill up to follow"] = function()
		expect(DogTrust.hearts(0, SETTINGS, 4)).toBe(0)
		expect(DogTrust.hearts(20, SETTINGS, 4)).toBe(1)
		expect(DogTrust.hearts(75, SETTINGS, 4)).toBe(4)
		expect(DogTrust.hearts(100, SETTINGS, 4)).toBe(4)
	end,
	["picks the first food the player has"] = function()
		local bag = { Sandwich = 1, RationPack = 2 }
		local function countOf(id: string): number
			return bag[id] or 0
		end
		expect(DogTrust.pickFood({ "Apple", "Sandwich", "RationPack" }, countOf)).toBe("Sandwich")
		expect(DogTrust.pickFood({ "Apple" }, countOf)).toBe(nil)
	end,
}
