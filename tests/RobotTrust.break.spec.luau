-- Trying to break the robot companion's trust rules (and its saved rapport). Tests marked BUG fail
-- on purpose: each names the bug it shows. Leave them failing until the code is fixed.
local RobotTrust = require("../src/shared/Logic/RobotTrust")
local Saves = require("../src/shared/Logic/Saves")
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
local GONE = 180
local CYCLE = 645 -- Day 360 + Siren 45 + Night 240: the one-day hold after a switch

local SAVE_RULES = {
	items = {},
	stats = {},
	cosmetics = {},
	maxPieces = 5,
	isKnownModel = function()
		return false
	end,
}

local function record(trust: number, night: boolean?): RobotTrust.Record
	local made = RobotTrust.new(trust)
	made.survivedNight = night == true
	return made
end

local function candidate(id: any, trust: number, night: boolean?, free: boolean?): RobotTrust.Candidate
	return {
		id = id,
		stage = RobotTrust.stage(record(trust, night), SETTINGS),
		trust = trust,
		free = free ~= false,
	}
end

local function ownerInput(extra: { [string]: any }): RobotTrust.OwnerInput
	local input: any = {
		owner = nil,
		ownerStage = nil,
		ownerTrust = 0,
		ownerGoneFor = 0,
		lockedUntil = 0,
		now = 1000,
		goneSeconds = GONE,
		candidates = {},
	}
	for key, value in extra do
		input[key] = value
	end
	return input
end

return {
	-- Cap abuse -----------------------------------------------------------------------------------

	["a hundred gifts of the same item in one day pay once"] = function()
		local r = record(0)
		local total = 0
		for _ = 1, 100 do
			total += RobotTrust.gift(r, "Apple", 1, SETTINGS)
		end
		expect(total).toBe(25)
		expect(r.trust).toBe(25)
	end,
	["gifting every item on the list in one day still stops at the day cap"] = function()
		local r = record(0)
		for _, item in { "Apple", "JuiceBox", "Popcorn", "Chips", "Sandwich", "NoodleCup" } do
			RobotTrust.gift(r, item, 1, SETTINGS)
		end
		expect(r.trust).toBe(50)
		local added, refusal = RobotTrust.gift(r, "Watermelon", 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("day")
		-- refused for the day: the item isn't remembered, so it can be given tomorrow
		expect(RobotTrust.canGift(r, "Watermelon", 1)).toBeTruthy()
	end,
	["the teach place-and-pickup loop stops at five lessons a day"] = function()
		local r = record(0)
		local paid = 0
		for _ = 1, 50 do
			paid += RobotTrust.teach(r, 3, SETTINGS)
		end
		expect(paid).toBe(20)
		local added, refusal = RobotTrust.teach(r, 3, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("lessons")
		expect(RobotTrust.teach(r, 4, SETTINGS)).toBe(4) -- next day the lessons come back
	end,
	["a lesson refused by the day cap doesn't use up a lesson"] = function()
		local r = record(0)
		RobotTrust.gift(r, "Apple", 1, SETTINGS)
		RobotTrust.gift(r, "Chips", 1, SETTINGS)
		local added, refusal = RobotTrust.teach(r, 1, SETTINGS)
		expect(added).toBe(0)
		expect(refusal).toBe("day")
		expect(r.teachCount).toBe(0)
	end,
	["knocking it down yourself and fixing it never pays, however often"] = function()
		local r = record(30)
		for _ = 1, 20 do
			local added, refusal = RobotTrust.repair(r, 1, true, SETTINGS)
			expect(added).toBe(0)
			expect(refusal).toBe("own")
		end
		expect(r.trust).toBe(30)
	end,
	["repairs from someone else stack only up to the day cap"] = function()
		local r = record(0)
		for _ = 1, 30 do
			RobotTrust.repair(r, 1, false, SETTINGS)
		end
		expect(r.trust).toBe(50)
	end,
	["hiding at dawn twice shares the cap with the day's gifts"] = function()
		local r = record(0)
		RobotTrust.hide(r, 2, SETTINGS)
		RobotTrust.hide(r, 2, SETTINGS)
		RobotTrust.gift(r, "Apple", 2, SETTINGS)
		RobotTrust.gift(r, "Chips", 2, SETTINGS)
		expect(r.trust).toBe(50)
		expect(r.dayGain).toBe(50)
	end,
	["a gift at 99 tops out at max and remembers the gift"] = function()
		local r = record(99)
		local added = RobotTrust.gift(r, "Apple", 1, SETTINGS)
		expect(added).toBe(1)
		expect(r.trust).toBe(100)
		local again, refusal = RobotTrust.gift(r, "Chips", 1, SETTINGS)
		expect(again).toBe(0)
		expect(refusal).toBe("full")
	end,

	-- Stage edges ---------------------------------------------------------------------------------

	["exact thresholds land on the higher stage"] = function()
		expect(RobotTrust.stage(record(19.999), SETTINGS)).toBe("curious")
		expect(RobotTrust.stage(record(20), SETTINGS)).toBe("watching")
		expect(RobotTrust.stage(record(45), SETTINGS)).toBe("learning")
		expect(RobotTrust.stage(record(75, true), SETTINGS)).toBe("bonded")
		expect(RobotTrust.stage(record(74.999, true), SETTINGS)).toBe("learning")
	end,
	["a full 100 without a night together is still only learning"] = function()
		expect(RobotTrust.stage(record(100, false), SETTINGS)).toBe("learning")
	end,
	["dropping a stage from each stage lands on the floor below"] = function()
		local bonded = record(90, true)
		expect(RobotTrust.dropStage(bonded, SETTINGS)).toBe("learning")
		expect(bonded.trust).toBe(45)
		expect(bonded.survivedNight).toBe(false)
		expect(RobotTrust.dropStage(bonded, SETTINGS)).toBe("watching")
		expect(bonded.trust).toBe(20)
		expect(RobotTrust.dropStage(bonded, SETTINGS)).toBe("curious")
		expect(bonded.trust).toBe(0)
		expect(RobotTrust.dropStage(bonded, SETTINGS)).toBe("curious")
		expect(bonded.trust).toBe(0)
	end,
	["a 100-trust robot with no night drops from learning, not from bonded"] = function()
		local r = record(100, false)
		expect(RobotTrust.dropStage(r, SETTINGS)).toBe("watching")
		expect(r.trust).toBe(20)
	end,
	["decay to exactly 0 is curious and never goes negative"] = function()
		local r = record(20)
		RobotTrust.decay(r, 20 * 60, false, SETTINGS)
		expect(r.trust).toBe(0)
		expect(RobotTrust.stage(r, SETTINGS)).toBe("curious")
		RobotTrust.decay(r, 600, false, SETTINGS)
		expect(r.trust).toBe(0)
	end,
	["a night survived while only watching carries into bonded later"] = function()
		-- the night flag outlives the stage it was earned at: reaching 75 later bonds on the spot
		local r = record(30, true)
		r.trust = 75
		expect(RobotTrust.stage(r, SETTINGS)).toBe("bonded")
	end,

	-- Decay math ----------------------------------------------------------------------------------

	["decay is a point a minute, split across ticks the same as one big step"] = function()
		local a, b = record(60), record(60)
		for _ = 1, 300 do
			RobotTrust.decay(a, 0.2, false, SETTINGS)
		end
		RobotTrust.decay(b, 60, false, SETTINGS)
		expect(a.trust).toBeNear(b.trust, 1e-6)
		expect(b.trust).toBe(59)
	end,
	["standing near stops decay completely"] = function()
		local r = record(60)
		RobotTrust.decay(r, 1e6, true, SETTINGS)
		expect(r.trust).toBe(60)
	end,
	-- BUG (design clash, Systems/Companion decayAll + mode "build"): a bonded robot builds "whether or
	-- not you're around", but trust decays a point a minute the whole time its owner is off looting.
	-- Ten minutes away (under two days' cycle) drops a fresh bond below 75, so it stops building and,
	-- below bonded, anyone with more trust can take it.
	["BUG: a bonded owner looting for ten minutes while it builds stays bonded"] = function()
		local r = record(80, true)
		for _ = 1, 10 * 60 * 5 do
			RobotTrust.decay(r, 0.2, false, SETTINGS)
		end
		local stage = RobotTrust.stage(r, SETTINGS)
		expect(stage).toBe("bonded")
		expect(RobotTrust.mode({
			owned = true,
			stage = stage,
			phase = "Day",
			down = false,
			homeBound = false,
			ownerHere = true,
			hasWork = true,
		})).toBe("build")
	end,

	-- Ownership races -----------------------------------------------------------------------------

	["two players hitting watching on the same tick: the higher trust wins"] = function()
		local chosen, switched = RobotTrust.chooseOwner(ownerInput({
			candidates = { candidate("a", 25), candidate("b", 33) },
		}))
		expect(chosen).toBe("b")
		expect(switched).toBe(false)
	end,
	["a dead tie goes to whoever is first in the player list"] = function()
		expect(
			(RobotTrust.chooseOwner(ownerInput({ candidates = { candidate("a", 25), candidate("b", 25) } })))
		).toBe("a")
		expect(
			(RobotTrust.chooseOwner(ownerInput({ candidates = { candidate("b", 25), candidate("a", 25) } })))
		).toBe("b")
	end,
	["someone who already owns a robot can't take a second"] = function()
		local chosen = RobotTrust.chooseOwner(ownerInput({
			candidates = { candidate("greedy", 60, false, false), candidate("fair", 21) },
		}))
		expect(chosen).toBe("fair")
	end,
	["a bonded owner away exactly three minutes can be challenged, a hair under cannot"] = function()
		local base = {
			owner = "owner",
			ownerStage = "bonded" :: RobotTrust.Stage,
			ownerTrust = 80,
			candidates = { candidate("owner", 80, true), candidate("thief", 81) },
		}
		local under = table.clone(base) :: any
		under.ownerGoneFor = GONE - 0.001
		expect((RobotTrust.chooseOwner(ownerInput(under)))).toBe("owner")
		local exact = table.clone(base) :: any
		exact.ownerGoneFor = GONE
		local chosen, switched = RobotTrust.chooseOwner(ownerInput(exact))
		expect(chosen).toBe("thief")
		expect(switched).toBe(true)
	end,
	["an equal-trust challenger never wins, even with the owner gone"] = function()
		local chosen = RobotTrust.chooseOwner(ownerInput({
			owner = "owner",
			ownerStage = "bonded",
			ownerTrust = 80,
			ownerGoneFor = 10000,
			candidates = { candidate("thief", 80, true) },
		}))
		expect(chosen).toBe("owner")
	end,
	["the one-day hold after a switch blocks a switch back until it runs out"] = function()
		local now = 1000
		local lockedUntil = now + CYCLE
		local function at(t: number)
			return RobotTrust.chooseOwner(ownerInput({
				owner = "thief",
				ownerStage = "watching",
				ownerTrust = 21,
				ownerGoneFor = 10000,
				lockedUntil = lockedUntil,
				now = t,
				candidates = { candidate("thief", 21), candidate("owner", 70) },
			}))
		end
		expect((at(lockedUntil - 0.001))).toBe("thief")
		local chosen, switched = at(lockedUntil)
		expect(chosen).toBe("owner")
		expect(switched).toBe(true)
	end,
	["an owner knocked back to curious loses it with no hold, so it can bounce straight away"] = function()
		local chosen, switched = RobotTrust.chooseOwner(ownerInput({
			owner = "owner",
			ownerStage = "curious",
			ownerTrust = 10,
			lockedUntil = 1e9,
			candidates = { candidate("owner", 10), candidate("griefer", 20) },
		}))
		expect(chosen).toBe("griefer")
		expect(switched).toBe(false) -- no lock: the hold only follows a switch
	end,
	-- BUG (Systems/Companion updateOwner, ~line 829-875): owners are compared as Player objects. A
	-- bonded owner who rejoins comes back as a new Player with the same record (same trust), so the
	-- "challenger" never has MORE trust than the stale owner and can't win it; the robot sits in
	-- "wait" for LeftHoldSeconds and then wipes the returning player's record (records[UserId] = nil).
	["BUG: a bonded owner who rejoins (new player object, same record) gets their robot back"] = function()
		local oldSelf = { userId = 7, session = 1 }
		local newSelf = { userId = 7, session = 2 }
		local chosen = RobotTrust.chooseOwner(ownerInput({
			owner = oldSelf,
			ownerStage = "bonded",
			ownerTrust = 90,
			ownerGoneFor = 250,
			candidates = { candidate(newSelf, 90, true) },
		}))
		expect(chosen).toBe(newSelf)
	end,
	["a below-bonded owner standing right there loses it to anyone with a point more"] = function()
		local chosen, switched = RobotTrust.chooseOwner(ownerInput({
			owner = "owner",
			ownerStage = "learning",
			ownerTrust = 60,
			ownerGoneFor = 0,
			candidates = { candidate("owner", 60), candidate("thief", 60.5) },
		}))
		expect(chosen).toBe("thief")
		expect(switched).toBe(true)
	end,

	-- Bad input -----------------------------------------------------------------------------------

	["NaN and negative trust in a candidate never win it"] = function()
		local chosen = RobotTrust.chooseOwner(ownerInput({
			candidates = {
				{ id = "nan", stage = "bonded", trust = 0 / 0, free = true },
				{ id = "neg", stage = "watching", trust = -50, free = true },
			},
		}))
		-- NaN can't beat anything; -50 still beats -math.huge, but only because its stage says watching
		expect(chosen).toBe("neg")
	end,
	["a NaN owner distance at night is not kept"] = function()
		expect(RobotTrust.kept(0 / 0, false, 20)).toBe(false)
		expect(RobotTrust.kept(20, false, 20)).toBe(true)
		expect(RobotTrust.kept(nil, true, 20)).toBe(true)
	end,
	["a huge time step decays to zero, not below"] = function()
		local r = record(100, true)
		RobotTrust.decay(r, math.huge, false, SETTINGS)
		expect(r.trust).toBe(0)
	end,
	-- BUG (hardening, Logic/RobotTrust decay): a negative dt adds trust past Max. The server only
	-- passes task.wait's dt today, so it's not reachable, but nothing clamps it.
	["BUG: a negative time step never adds trust"] = function()
		local r = record(90, true)
		RobotTrust.decay(r, -60 * 60, false, SETTINGS)
		expect(r.trust <= 90).toBeTruthy()
	end,
	-- math.max(0, NaN) gives 0 in Luau, so a NaN dt zeroes trust rather than poisoning it
	["a NaN time step leaves trust a real number"] = function()
		local r = record(50)
		RobotTrust.decay(r, 0 / 0, false, SETTINGS)
		expect(r.trust == r.trust).toBeTruthy()
	end,
	["a want rotation with a negative or giant offset still lands on the list"] = function()
		local list = { "Apple", "Chips", "Popcorn" }
		expect(table.find(list, RobotTrust.nextWant(list, nil, -7) :: string) ~= nil).toBeTruthy()
		expect(table.find(list, RobotTrust.nextWant(list, nil, 2 ^ 52) :: string) ~= nil).toBeTruthy()
		expect(RobotTrust.nextWant(list, "NotOnTheList", 1)).toBe("Chips")
		expect(RobotTrust.nextWant({ "Apple" }, "Apple", 0)).toBe("Apple")
		expect(RobotTrust.nextWant({}, "Apple", 0)).toBe(nil)
	end,

	-- Rapport across days and servers -------------------------------------------------------------

	["bonded rapport skips ahead up to a hair under a real day away, not at a day"] = function()
		local saved = 1_700_000_000
		local justUnder = RobotTrust.rapport(4, saved, saved + 86399, SETTINGS)
		expect(justUnder).toBe(4)
		expect(RobotTrust.startTrust(justUnder, SETTINGS)).toBe(20)
		local aDay = RobotTrust.rapport(4, saved, saved + 86400, SETTINGS)
		expect(aDay).toBe(3)
		expect(RobotTrust.startTrust(aDay, SETTINGS)).toBe(0)
	end,
	["a month away bottoms out at curious and never below"] = function()
		expect(RobotTrust.rapport(4, 0, 86400 * 30, SETTINGS)).toBe(1)
		expect(RobotTrust.rapport(0, 0, 0, SETTINGS)).toBe(1)
	end,
	["a save stamped in the future doesn't add stages"] = function()
		expect(RobotTrust.rapport(2, 5000, 0, SETTINGS)).toBe(2)
	end,
	["a version 5 save gets a blank rapport even if it carried junk"] = function()
		local data = Saves.load({ version = 5, rapport = { stage = 4, at = 99 } }, SAVE_RULES)
		expect(data.version).toBe(6)
		expect(data.rapport.stage).toBe(0)
		expect(data.rapport.at).toBe(0)
	end,
	["rapport clean survives NaN, infinity, negatives, fractions, strings and giants"] = function()
		local function clean(raw: any)
			return Saves.cleanRapport(raw)
		end
		expect(clean({ stage = 0 / 0, at = 0 / 0 }).stage).toBe(0)
		expect(clean({ stage = math.huge, at = -math.huge }).stage).toBe(0)
		expect(clean({ stage = -3, at = -10 }).at).toBe(0)
		expect(clean({ stage = 3.9, at = 12.7 }).stage).toBe(3)
		expect(clean({ stage = 3.9, at = 12.7 }).at).toBe(12)
		expect(clean({ stage = 1e300, at = 5 }).stage).toBe(4)
		expect(clean({ stage = "4", at = "now" }).stage).toBe(0)
		expect(clean(nil).stage).toBe(0)
		expect(clean(42).at).toBe(0)
	end,
	["a version 6 save keeps a good rapport through load"] = function()
		local data = Saves.load({ version = 6, rapport = { stage = 4, at = 1_700_000_000 } }, SAVE_RULES)
		expect(data.rapport.stage).toBe(4)
		expect(data.rapport.at).toBe(1_700_000_000)
	end,
}
