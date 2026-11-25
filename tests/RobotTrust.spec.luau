local RobotTrust = require("../src/shared/Logic/RobotTrust")
local expect = require("./expect")

local SETTINGS = {
	Max = 100,
	DayCap = 50,
	DecayPerMinute = 1.0,
	Stages = { Watching = 20, Learning = 45, Bonded = 75 },
	Gift = 25,
	Teach = 4,
	TeachPerDay = 5,
	Repair = 8,
	Hide = 12,
	RapportDaySeconds = 86400,
}

local function owned(stage: string, extra: { [string]: any }?): any
	local input = {
		owned = true,
		stage = stage,
		phase = "Day",
		down = false,
		homeBound = false,
		ownerHere = true,
		hasWork = false,
	}
	for key, value in extra or {} do
		input[key] = value
	end
	return input
end

return {
	["a gift is big but only once per item per day"] = function()
		local record = RobotTrust.new()
		expect((RobotTrust.gift(record, "Apple", 1, SETTINGS))).toBe(25)
		local added, refusal = RobotTrust.gift(record, "Apple", 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("given")
		expect(RobotTrust.canGift(record, "Apple", 1)).toBeFalsy()
		expect(RobotTrust.canGift(record, "Apple", 2)).toBeTruthy()
		expect((RobotTrust.gift(record, "Apple", 2, SETTINGS))).toBe(25)
	end,
	["every source shares one daily cap"] = function()
		local record = RobotTrust.new()
		RobotTrust.gift(record, "Apple", 1, SETTINGS)
		RobotTrust.gift(record, "Chips", 1, SETTINGS)
		local added, refusal = RobotTrust.teach(record, 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("day")
		expect(record.trust).toBe(50)
		expect((RobotTrust.teach(record, 2, SETTINGS))).toBe(4)
	end,
	["a refused gift is not remembered as given"] = function()
		local record = RobotTrust.new()
		record.day, record.dayGain = 1, 50
		RobotTrust.gift(record, "Apple", 1, SETTINGS)
		expect(RobotTrust.canGift(record, "Apple", 1)).toBeTruthy()
	end,
	["teaching is small and capped at five a day"] = function()
		local record = RobotTrust.new()
		for _ = 1, 5 do
			expect((RobotTrust.teach(record, 1, SETTINGS))).toBe(4)
		end
		local added, refusal = RobotTrust.teach(record, 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("lessons")
		expect((RobotTrust.teach(record, 2, SETTINGS))).toBe(4)
	end,
	["repairing pays nothing if you knocked it down yourself"] = function()
		local record = RobotTrust.new()
		local added, refusal = RobotTrust.repair(record, 1, true, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("own")
		expect((RobotTrust.repair(record, 1, false, SETTINGS))).toBe(8)
		expect((RobotTrust.hide(record, 1, SETTINGS))).toBe(12)
	end,
	["trust never passes max"] = function()
		local record = RobotTrust.new(95)
		expect((RobotTrust.gift(record, "Apple", 1, SETTINGS))).toBe(5)
		local _, refusal = RobotTrust.hide(record, 1, SETTINGS)
		expect(refusal).toBe("full")
	end,
	["bonded needs the points and a night survived together"] = function()
		local record = RobotTrust.new(80)
		expect(RobotTrust.stage(record, SETTINGS)).toBe("learning")
		record.survivedNight = true
		expect(RobotTrust.stage(record, SETTINGS)).toBe("bonded")
		expect(RobotTrust.stage(RobotTrust.new(0), SETTINGS)).toBe("curious")
		expect(RobotTrust.stage(RobotTrust.new(20), SETTINGS)).toBe("watching")
		expect(RobotTrust.stage(RobotTrust.new(45), SETTINGS)).toBe("learning")
		expect(RobotTrust.atLeast("learning", "watching")).toBeTruthy()
		expect(RobotTrust.atLeast("watching", "learning")).toBeFalsy()
	end,
	["it takes about two days to bond"] = function()
		local record = RobotTrust.new()
		RobotTrust.gift(record, "Apple", 1, SETTINGS)
		RobotTrust.gift(record, "Chips", 1, SETTINGS)
		expect(RobotTrust.stage(record, SETTINGS)).toBe("learning")
		record.survivedNight = true
		RobotTrust.hide(record, 2, SETTINGS)
		RobotTrust.gift(record, "Popcorn", 2, SETTINGS)
		expect(RobotTrust.stage(record, SETTINGS)).toBe("bonded")
	end,
	["trust fades a point a minute only while away"] = function()
		local record = RobotTrust.new(50)
		RobotTrust.decay(record, 60, true, SETTINGS)
		expect(record.trust).toBe(50)
		RobotTrust.decay(record, 60, false, SETTINGS)
		expect(record.trust).toBeNear(49)
		RobotTrust.decay(record, 6000, false, SETTINGS)
		expect(record.trust).toBe(0)
	end,
	["shooting it costs a whole stage"] = function()
		local record = RobotTrust.new(90)
		record.survivedNight = true
		expect(RobotTrust.dropStage(record, SETTINGS)).toBe("learning")
		expect(record.trust).toBe(45)
		expect(record.survivedNight).toBe(false)
		expect(RobotTrust.dropStage(record, SETTINGS)).toBe("watching")
		expect(RobotTrust.dropStage(record, SETTINGS)).toBe("curious")
		expect(record.trust).toBe(0)
		expect(RobotTrust.dropStage(record, SETTINGS)).toBe("curious")
	end,
	["it stays yours at night when close or hidden"] = function()
		expect(RobotTrust.kept(12, false, 20)).toBeTruthy()
		expect(RobotTrust.kept(30, false, 20)).toBeFalsy()
		expect(RobotTrust.kept(nil, true, 20)).toBeTruthy()
		expect(RobotTrust.kept(nil, false, 20)).toBeFalsy()
	end,
	["the first player to reach watching owns it"] = function()
		local owner, switched = RobotTrust.chooseOwner({
			owner = nil,
			ownerStage = nil,
			ownerTrust = 0,
			ownerGoneFor = 0,
			lockedUntil = 0,
			now = 100,
			goneSeconds = 180,
			candidates = {
				{ id = "a", stage = "curious", trust = 15, free = true },
				{ id = "b", stage = "watching", trust = 22, free = true },
				{ id = "c", stage = "learning", trust = 50, free = false }, -- already has a robot
			},
		})
		expect(owner).toBe("b")
		expect(switched).toBe(false)
	end,
	["a bonded owner who is around keeps it"] = function()
		local input = {
			owner = "a",
			ownerStage = "bonded",
			ownerTrust = 80,
			ownerGoneFor = 60,
			lockedUntil = 0,
			now = 100,
			goneSeconds = 180,
			candidates = { { id = "b", stage = "bonded", trust = 90, free = true } },
		}
		expect((RobotTrust.chooseOwner(input))).toBe("a")
		input.ownerGoneFor = 200
		local owner, switched = RobotTrust.chooseOwner(input)
		expect(owner).toBe("b")
		expect(switched).toBe(true)
	end,
	["below bonded someone with more trust wins it, but not during the lock"] = function()
		local input = {
			owner = "a",
			ownerStage = "learning",
			ownerTrust = 50,
			ownerGoneFor = 0,
			lockedUntil = 500,
			now = 100,
			goneSeconds = 180,
			candidates = { { id = "b", stage = "learning", trust = 60, free = true } },
		}
		expect((RobotTrust.chooseOwner(input))).toBe("a")
		input.now = 600
		expect((RobotTrust.chooseOwner(input))).toBe("b")
		input.candidates[1].trust = 40
		expect((RobotTrust.chooseOwner(input))).toBe("a")
	end,
	["an owner whose trust falls back to curious loses it"] = function()
		local owner = RobotTrust.chooseOwner({
			owner = "a",
			ownerStage = "curious",
			ownerTrust = 10,
			ownerGoneFor = 0,
			lockedUntil = 1000,
			now = 100,
			goneSeconds = 180,
			candidates = {},
		})
		expect(owner).toBe(nil)
	end,
	["modes follow the stage and the time of day"] = function()
		expect(RobotTrust.mode(owned("watching"))).toBe("trail")
		expect(RobotTrust.mode(owned("watching", { phase = "Siren" }))).toBe("follow")
		expect(RobotTrust.mode(owned("learning"))).toBe("beside")
		expect(RobotTrust.mode(owned("bonded"))).toBe("follow")
		expect(RobotTrust.mode(owned("bonded", { hasWork = true }))).toBe("build")
		expect(RobotTrust.mode(owned("bonded", { hasWork = true, phase = "Siren" }))).toBe("follow")
		expect(RobotTrust.mode(owned("bonded", { phase = "Night" }))).toBe("night")
		expect(RobotTrust.mode(owned("bonded", { ownerHere = false }))).toBe("wait")
		expect(RobotTrust.mode(owned("bonded", { down = true }))).toBe("down")
		expect(RobotTrust.mode(owned("bonded", { homeBound = true }))).toBe("home")
		expect(RobotTrust.mode(owned("curious", { owned = false }))).toBe("doorway")
		expect(RobotTrust.mode(owned("curious", { owned = false, phase = "Night" }))).toBe("pack")
	end,
	["approach stops short of the target"] = function()
		local spot = RobotTrust.approach({ x = 30, z = 0 }, { x = 0, z = 0 }, 15, 2) :: any
		expect(spot.x).toBeNear(15)
		expect(spot.z).toBeNear(0)
		expect(RobotTrust.approach({ x = 16, z = 0 }, { x = 0, z = 0 }, 15, 2)).toBe(nil)
	end,
	["beside is off the right shoulder"] = function()
		local spot = RobotTrust.beside({ x = 0, z = 0 }, { x = 0, z = -1 }, 4)
		expect(spot.x).toBeNear(4)
		expect(spot.z).toBeNear(0)
	end,
	["saved rapport drops a stage per real day away and bonded skips ahead"] = function()
		local day = SETTINGS.RapportDaySeconds
		expect(RobotTrust.rapport(4, 0, day * 0.5, SETTINGS)).toBe(4)
		expect(RobotTrust.rapport(4, 0, day * 1.5, SETTINGS)).toBe(3)
		expect(RobotTrust.rapport(4, 0, day * 10, SETTINGS)).toBe(1)
		expect(RobotTrust.startTrust(4, SETTINGS)).toBe(20)
		expect(RobotTrust.startTrust(3, SETTINGS)).toBe(0)
	end,
	["wanted items rotate"] = function()
		local list = { "Apple", "Chips", "Popcorn" }
		expect(RobotTrust.nextWant(list, "Apple", 0)).toBe("Chips")
		expect(RobotTrust.nextWant(list, "Popcorn", 0)).toBe("Apple")
		expect(RobotTrust.nextWant(list, nil, 4)).toBe("Chips")
		expect(RobotTrust.nextWant({}, nil, 0)).toBe(nil)
	end,
}
