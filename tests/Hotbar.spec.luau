local Hotbar = require("../src/shared/Logic/Hotbar")
local expect = require("./expect")

local DEFS: { Hotbar.SlotDef } = {
	{ id = "Flashlight", label = "LIGHT", use = "Flashlight", always = true, hold = "Flashlight" },
	{ id = "Guns", label = "GUN", use = "Fire" },
	{ id = "Food", label = "FOOD", use = "Eat", kind = "Eat" },
	{ id = "Drink", label = "DRINK", use = "Drink", kind = "Drink" },
	{ id = "Emp", label = "EMP", use = "Emp", items = { "EmpCharge" } },
}

local USES: any = {
	Snack = { kind = "Eat", hunger = 15, time = 1 },
	Sandwich = { kind = "Eat", hunger = 30, time = 1 },
	JuiceBox = { kind = "Drink", energy = 15, time = 1 },
}

local GUNS: { [string]: Hotbar.Gun } = {
	StarterBlaster = { rank = 1, label = "BLASTER" },
	Rifle = { rank = 3 },
}

local NONE_MISSING = { hunger = 0, energy = 0, health = 0 }

local function ids(slots: { Hotbar.Slot }): string
	local list = {}
	for _, slot in slots do
		table.insert(list, slot.id)
	end
	return table.concat(list, ",")
end

return {
	["only slots you have something for show, flashlight always"] = function()
		local slots = Hotbar.slots(DEFS, {}, USES, GUNS, NONE_MISSING)
		expect(ids(slots)).toBe("Flashlight")
		expect(slots[1].item).toBe("Flashlight")

		slots = Hotbar.slots(DEFS, { { id = "EmpCharge", count = 2 } }, USES, GUNS, NONE_MISSING)
		expect(ids(slots)).toBe("Flashlight,Emp")
		expect(slots[2].count).toBe(2)
		expect(slots[2].item).toBe("EmpCharge")
	end,

	["each gun gets its own slot, best first, labelled"] = function()
		local bag = { { id = "StarterBlaster", count = 1 }, { id = "Rifle", count = 1 } }
		local slots = Hotbar.slots(DEFS, bag, USES, GUNS, NONE_MISSING)
		expect(ids(slots)).toBe("Flashlight,Rifle,StarterBlaster")
		expect(slots[2].label).toBe("GUN")
		expect(slots[3].label).toBe("BLASTER")
		expect(slots[3].use).toBe("Fire")
		expect(slots[3].item).toBe("StarterBlaster")
	end,

	["a kind slot counts every item of that kind and shows the one that would be used"] = function()
		local bag =
			{ { id = "Snack", count = 2 }, { id = "Sandwich", count = 1 }, { id = "JuiceBox", count = 1 } }
		local slots = Hotbar.slots(DEFS, bag, USES, GUNS, { hunger = 10, energy = 0, health = 0 })
		expect(ids(slots)).toBe("Flashlight,Food,Drink")
		expect(slots[2].count).toBe(3)
		expect(slots[2].item).toBe("Snack")
		slots = Hotbar.slots(DEFS, bag, USES, GUNS, { hunger = 25, energy = 0, health = 0 })
		expect(slots[2].item).toBe("Sandwich")
	end,

	["a full player still sees food in hand"] = function()
		local slots = Hotbar.slots(DEFS, { { id = "Snack", count = 1 } }, USES, GUNS, NONE_MISSING)
		expect(slots[2].item).toBe("Snack")
	end,

	["selection wraps both ways and starts from the ends"] = function()
		local slots = Hotbar.slots(
			DEFS,
			{ { id = "StarterBlaster", count = 1 }, { id = "EmpCharge", count = 1 } },
			USES,
			GUNS,
			NONE_MISSING
		)
		expect(Hotbar.cycle(slots, "Flashlight", 1)).toBe("StarterBlaster")
		expect(Hotbar.cycle(slots, "Emp", 1)).toBe("Flashlight")
		expect(Hotbar.cycle(slots, "Flashlight", -1)).toBe("Emp")
		expect(Hotbar.cycle(slots, nil, 1)).toBe("Flashlight")
		expect(Hotbar.cycle(slots, nil, -1)).toBe("Emp")
		expect(Hotbar.cycle({}, "Emp", 1)).toBe(nil)
	end,

	["number keys pick by position"] = function()
		local slots = Hotbar.slots(DEFS, { { id = "EmpCharge", count = 1 } }, USES, GUNS, NONE_MISSING)
		expect(Hotbar.atNumber(slots, 2)).toBe("Emp")
		expect(Hotbar.atNumber(slots, 3)).toBe(nil)
	end,

	["a slot that runs out falls back to the gun, else the first slot"] = function()
		local armed = Hotbar.slots(DEFS, { { id = "StarterBlaster", count = 1 } }, USES, GUNS, NONE_MISSING)
		expect(Hotbar.keep(armed, "Food")).toBe("StarterBlaster")
		expect(Hotbar.keep(armed, "Flashlight")).toBe("Flashlight")
		expect(Hotbar.keep(armed, nil)).toBe("StarterBlaster")
		local unarmed = Hotbar.slots(DEFS, {}, USES, GUNS, NONE_MISSING)
		expect(Hotbar.keep(unarmed, "Emp")).toBe("Flashlight")
	end,
}
