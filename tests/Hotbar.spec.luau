local Hotbar = require("../src/shared/Logic/Hotbar")
local expect = require("./expect")

local DEFS: { Hotbar.SlotDef } = {
	{ id = "Hands", label = "HANDS", use = "Grab", always = true },
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
	["always slots first, then one per quick slot, empty ones marked"] = function()
		local slots = Hotbar.slots(DEFS, {}, USES, GUNS, NONE_MISSING, { "", "", "", "" })
		expect(ids(slots)).toBe("Hands,Flashlight,Quick1,Quick2,Quick3,Quick4")
		expect(slots[2].item).toBe("Flashlight")
		expect(slots[3].empty).toBe(true)

		local bag = { { id = "EmpCharge", count = 2 } }
		slots = Hotbar.slots(DEFS, bag, USES, GUNS, NONE_MISSING, { "", "Emp" })
		expect(ids(slots)).toBe("Hands,Flashlight,Quick1,Emp")
		expect(slots[4].count).toBe(2)
		expect(slots[4].item).toBe("EmpCharge")
	end,

	["guns sit where the player put them, labelled"] = function()
		local bag = { { id = "StarterBlaster", count = 1 }, { id = "Rifle", count = 1 } }
		local slots = Hotbar.slots(DEFS, bag, USES, GUNS, NONE_MISSING, { "StarterBlaster", "Rifle" })
		expect(ids(slots)).toBe("Hands,Flashlight,StarterBlaster,Rifle")
		expect(slots[3].label).toBe("BLASTER")
		expect(slots[4].label).toBe("GUN")
		expect(slots[3].use).toBe("Fire")
		expect(slots[3].item).toBe("StarterBlaster")
	end,

	["a slot remembering something you lost shows empty"] = function()
		local slots = Hotbar.slots(DEFS, {}, USES, GUNS, NONE_MISSING, { "Rifle" })
		expect(ids(slots)).toBe("Hands,Flashlight,Quick1")
	end,

	["a kind slot counts every item of that kind and shows the one that would be used"] = function()
		local bag =
			{ { id = "Snack", count = 2 }, { id = "Sandwich", count = 1 }, { id = "JuiceBox", count = 1 } }
		local quick = { "Food", "Drink" }
		local slots = Hotbar.slots(DEFS, bag, USES, GUNS, { hunger = 10, energy = 0, health = 0 }, quick)
		expect(slots[3].count).toBe(3)
		expect(slots[3].item).toBe("Snack")
		slots = Hotbar.slots(DEFS, bag, USES, GUNS, { hunger = 25, energy = 0, health = 0 }, quick)
		expect(slots[3].item).toBe("Sandwich")
	end,

	["a full player still sees food in hand"] = function()
		local slots = Hotbar.slots(
			DEFS,
			{ { id = "Snack", count = 1 } },
			USES,
			GUNS,
			NONE_MISSING,
			{ "Food" }
		)
		expect(slots[3].item).toBe("Snack")
	end,

	["selection skips empty slots and wraps both ways"] = function()
		local bag = { { id = "StarterBlaster", count = 1 }, { id = "EmpCharge", count = 1 } }
		local slots = Hotbar.slots(DEFS, bag, USES, GUNS, NONE_MISSING, { "StarterBlaster", "", "Emp", "" })
		expect(Hotbar.cycle(slots, "Flashlight", 1)).toBe("StarterBlaster")
		expect(Hotbar.cycle(slots, "StarterBlaster", 1)).toBe("Emp")
		expect(Hotbar.cycle(slots, "Emp", 1)).toBe("Hands")
		expect(Hotbar.cycle(slots, "Hands", -1)).toBe("Emp")
		expect(Hotbar.cycle(slots, nil, 1)).toBe("Hands")
		expect(Hotbar.cycle(slots, nil, -1)).toBe("Emp")
		expect(Hotbar.cycle({}, "Emp", 1)).toBe(nil)
	end,

	["number keys pick by position, empty slots pick nothing"] = function()
		local slots = Hotbar.slots(
			DEFS,
			{ { id = "EmpCharge", count = 1 } },
			USES,
			GUNS,
			NONE_MISSING,
			{ "", "Emp" }
		)
		expect(Hotbar.atNumber(slots, 4)).toBe("Emp")
		expect(Hotbar.atNumber(slots, 3)).toBe(nil)
		expect(Hotbar.atNumber(slots, 7)).toBe(nil)
	end,

	["a slot that runs out falls back to the gun, else the first slot"] = function()
		local armed = Hotbar.slots(
			DEFS,
			{ { id = "StarterBlaster", count = 1 } },
			USES,
			GUNS,
			NONE_MISSING,
			{ "", "StarterBlaster" }
		)
		expect(Hotbar.keep(armed, "Food")).toBe("StarterBlaster")
		expect(Hotbar.keep(armed, "Quick1")).toBe("StarterBlaster")
		expect(Hotbar.keep(armed, "Flashlight")).toBe("Flashlight")
		expect(Hotbar.keep(armed, nil)).toBe("StarterBlaster")
		local unarmed = Hotbar.slots(DEFS, {}, USES, GUNS, NONE_MISSING, { "" })
		expect(Hotbar.keep(unarmed, "Emp")).toBe("Hands")
	end,
}
