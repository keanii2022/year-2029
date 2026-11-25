local QuickSlots = require("../src/shared/Logic/QuickSlots")
local expect = require("./expect")

local DEFS: { QuickSlots.GroupDef } = {
	{ id = "Hands", always = true },
	{ id = "Guns" },
	{ id = "Food", kind = "Eat" },
	{ id = "Emp", items = { "EmpCharge" } },
}
local USES = { Snack = { kind = "Eat" }, Sandwich = { kind = "Eat" } }
local GUNS = { StarterBlaster = {}, Rifle = {} }

return {
	["items map to their group, junk has none"] = function()
		expect(QuickSlots.groupOf("Rifle", DEFS, USES, GUNS)).toBe("Rifle")
		expect(QuickSlots.groupOf("Snack", DEFS, USES, GUNS)).toBe("Food")
		expect(QuickSlots.groupOf("Sandwich", DEFS, USES, GUNS)).toBe("Food")
		expect(QuickSlots.groupOf("EmpCharge", DEFS, USES, GUNS)).toBe("Emp")
		expect(QuickSlots.groupOf("BlasterCells", DEFS, USES, GUNS)).toBe(nil)
	end,

	["carried lists groups with something in the bag"] = function()
		local carried = QuickSlots.carried(
			{ { id = "Snack", count = 2 }, { id = "Rifle", count = 1 }, { id = "BlasterCells", count = 9 } },
			DEFS,
			USES,
			GUNS
		)
		expect(carried.Food).toBe(true)
		expect(carried.Rifle).toBe(true)
		expect(carried.Emp).toBe(nil)
	end,

	["pickups fill empty slots in order, then stop"] = function()
		local quick = QuickSlots.new(2)
		local carried = { Rifle = true, Food = true, Emp = true }
		expect(QuickSlots.autoAssign(quick, "Rifle", carried)).toBe(1)
		expect(QuickSlots.autoAssign(quick, "Food", carried)).toBe(2)
		expect(QuickSlots.autoAssign(quick, "Rifle", carried)).toBe(1)
		expect(QuickSlots.autoAssign(quick, "Emp", carried)).toBe(nil)
		expect(table.concat(quick, ",")).toBe("Rifle,Food")
	end,

	["a lost item goes back to its slot, and a lost item's slot can be taken over"] = function()
		local quick = { "Rifle", "Food" }
		expect(QuickSlots.autoAssign(quick, "Food", { Food = true })).toBe(2)
		expect(QuickSlots.autoAssign(quick, "StarterBlaster", { Food = true, StarterBlaster = true })).toBe(1)
		expect(table.concat(quick, ",")).toBe("StarterBlaster,Food")
		local all = { Food = true, StarterBlaster = true, Rifle = true }
		expect(QuickSlots.autoAssign(quick, "Rifle", all)).toBe(nil)
	end,

	["empty slots win over remembered ones"] = function()
		local quick = { "Rifle", "" }
		expect(QuickSlots.autoAssign(quick, "Emp", { Emp = true })).toBe(2)
	end,

	["put swaps with the slot it came from, else replaces"] = function()
		local quick = { "Rifle", "Food", "" }
		expect(QuickSlots.put(quick, 2, "Rifle")).toBe(true)
		expect(table.concat(quick, ",")).toBe("Food,Rifle,")
		expect(QuickSlots.put(quick, 3, "Emp")).toBe(true)
		expect(QuickSlots.put(quick, 3, "StarterBlaster")).toBe(true)
		expect(table.concat(quick, ",")).toBe("Food,Rifle,StarterBlaster")
		expect(QuickSlots.put(quick, 4, "Emp")).toBe(false)
		expect(QuickSlots.put(quick, 0, "Emp")).toBe(false)
	end,

	["clear sends a slot back to the bag"] = function()
		local quick = { "Rifle", "Food" }
		expect(QuickSlots.clear(quick, 1)).toBe(true)
		expect(QuickSlots.clear(quick, 3)).toBe(false)
		expect(table.concat(quick, ",")).toBe(",Food")
	end,

	["a remembered slot shows empty until you carry it again"] = function()
		local quick = { "Rifle", "Food" }
		expect(QuickSlots.showing(quick, 1, { Food = true })).toBe("")
		expect(QuickSlots.showing(quick, 2, { Food = true })).toBe("Food")
		expect(QuickSlots.showing(quick, 5, { Food = true })).toBe("")
	end,
}
