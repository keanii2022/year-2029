local Needs = require("../src/shared/Logic/Needs")
local expect = require("./expect")

-- Mirrors Config/Supplies.Needs (that file holds Roblox types Lune can't load)
local config = {
	Max = 100,
	HungerDrain = 0.16,
	HungerSprintMultiplier = 1.5,
	EnergyDrain = 0.03,
	EnergySprintDrain = 1.1,
	EnergyRestRegen = 0.25,
	EnergyRestCap = 35,
	ExhaustedRecover = 10,
	StarveDamage = 0.5,
	LowAt = 30,
}

local uses = {
	Snack = { kind = "Eat", hunger = 15, time = 1, loudness = "quiet" },
	Sandwich = { kind = "Eat", hunger = 30, time = 2, loudness = "quiet" },
	RationPack = { kind = "Eat", hunger = 70, time = 4, loudness = "quiet" },
	PizzaBox = { kind = "Eat", time = 1, loudness = "normal", opens = { { id = "PizzaSlice", count = 4 } } },
	EnergyDrink = { kind = "Drink", energy = 60, time = 1, loudness = "normal" },
	Bandage = { kind = "Heal", health = 35, time = 3, loudness = "quiet" },
}

local walking = { sprinting = false }
local running = { sprinting = true }

local function state(hunger: number, energy: number, exhausted: boolean?): Needs.State
	return { hunger = hunger, energy = energy, exhausted = exhausted == true }
end

return {
	["hunger drains over time and faster while sprinting"] = function()
		local walked = Needs.step(state(50, 100), 10, walking, config)
		local ran = Needs.step(state(50, 100), 10, running, config)
		expect(walked.hunger).toBeNear(48.4)
		expect(ran.hunger).toBeNear(47.6)
	end,
	["sprinting burns energy, resting recovers only up to the cap"] = function()
		expect(Needs.step(state(50, 50), 10, running, config).energy).toBeNear(38.7)
		expect(Needs.step(state(50, 20), 10, walking, config).energy).toBeNear(22.5)
		expect(Needs.step(state(50, 34), 10, walking, config).energy).toBe(35)
		expect(Needs.step(state(50, 80), 10, walking, config).energy).toBeNear(79.7)
		expect(Needs.step(state(50, 35.1), 10, walking, config).energy).toBe(35)
	end,
	["empty energy exhausts until it climbs back"] = function()
		local s = Needs.step(state(50, 1), 1, running, config)
		expect(s.energy).toBe(0)
		expect(s.exhausted).toBeTruthy()
		s = Needs.step(s, 20, running, config)
		expect(s.exhausted).toBeTruthy()
		expect(s.energy).toBeNear(5)
		s = Needs.step(s, 20, walking, config)
		expect(s.exhausted).toBeFalsy()
	end,
	["empty hunger hurts, a fed player doesn't"] = function()
		local _, hurt = Needs.step(state(0, 50), 2, walking, config)
		local _, fine = Needs.step(state(10, 50), 2, walking, config)
		expect(hurt).toBe(1)
		expect(fine).toBe(0)
		local s = Needs.step(state(0.1, 50), 2, walking, config)
		expect(s.hunger).toBe(0)
	end,
	["refills clamp to max and a drink ends exhaustion"] = function()
		local fed = Needs.refill(state(90, 0, true), uses.Sandwich, config)
		expect(fed.hunger).toBe(100)
		expect(fed.exhausted).toBeTruthy()
		local drank = Needs.refill(state(50, 0, true), uses.EnergyDrink, config)
		expect(drank.energy).toBe(60)
		expect(drank.exhausted).toBeFalsy()
	end,
	["status reads ok, low and empty"] = function()
		expect(Needs.status(80, config)).toBe("ok")
		expect(Needs.status(20, config)).toBe("low")
		expect(Needs.status(0, config)).toBe("empty")
	end,
	["eat picks the smallest food that covers the gap, else the biggest"] = function()
		local bag =
			{ { id = "RationPack", count = 1 }, { id = "Snack", count = 2 }, { id = "Sandwich", count = 1 } }
		expect((Needs.pick("Eat", bag, uses, { hunger = 25, energy = 0, health = 0 }))).toBe("Sandwich")
		expect((Needs.pick("Eat", bag, uses, { hunger = 10, energy = 0, health = 0 }))).toBe("Snack")
		expect((Needs.pick("Eat", bag, uses, { hunger = 90, energy = 0, health = 0 }))).toBe("RationPack")
	end,
	["boxes only open when nothing ready is left"] = function()
		local missing = { hunger = 40, energy = 0, health = 0 }
		expect(
			(
				Needs.pick(
					"Eat",
					{ { id = "PizzaBox", count = 1 }, { id = "Snack", count = 1 } },
					uses,
					missing
				)
			)
		).toBe("Snack")
		expect((Needs.pick("Eat", { { id = "PizzaBox", count = 1 } }, uses, missing))).toBe("PizzaBox")
	end,
	["pick refuses when full or out"] = function()
		local bag = { { id = "Bandage", count = 1 } }
		local id, why = Needs.pick("Heal", bag, uses, { hunger = 0, energy = 0, health = 0 })
		expect(id).toBe(nil)
		expect(why).toBe("full")
		id, why = Needs.pick("Drink", bag, uses, { hunger = 0, energy = 50, health = 0 })
		expect(id).toBe(nil)
		expect(why).toBe("none")
		expect((Needs.pick("Heal", bag, uses, { hunger = 0, energy = 0, health = 20 }))).toBe("Bandage")
	end,
	["shopping list counts kinds and items and flags what's short"] = function()
		local list = {
			{ label = "Food", kind = "Eat", want = 3 },
			{ label = "Drinks", kind = "Drink", want = 2 },
			{ label = "Cells", item = "BlasterCells", want = 30 },
		}
		local bag = {
			{ id = "Snack", count = 2 },
			{ id = "PizzaBox", count = 1 },
			{ id = "EnergyDrink", count = 1 },
			{ id = "BlasterCells", count = 40 },
		}
		local rows = Needs.shoppingList(list, bag, uses, state(80, 80), config)
		expect(rows[1].have).toBe(3)
		expect(rows[1].low).toBeFalsy()
		expect(rows[2].have).toBe(1)
		expect(rows[2].low).toBeTruthy()
		expect(rows[3].have).toBe(40)
		expect(rows[3].low).toBeFalsy()
		local hungry = Needs.shoppingList(list, bag, uses, state(10, 80), config)
		expect(hungry[1].low).toBeTruthy()
	end,
}
