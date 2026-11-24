local Inventory = require("../src/shared/Logic/Inventory")
local InventoryItems = require("../src/shared/Logic/InventoryItems")
local expect = require("./expect")

local items = {
	Gun = { id = "Gun", name = "Gun", value = 20, stackSize = 1 },
	Cells = { id = "Cells", name = "Cells", value = 1, stackSize = 10 },
	Watch = { id = "Watch", name = "Watch", value = 50, stackSize = 1 },
}

return {
	["add fills existing stacks before new slots"] = function()
		local bag = {}
		expect(Inventory.add(bag, items, "Cells", 7, 5)).toBe(7)
		expect(Inventory.add(bag, items, "Cells", 7, 5)).toBe(7)
		expect(#bag).toBe(2)
		expect(bag[1].count).toBe(10)
		expect(bag[2].count).toBe(4)
	end,
	["add stops when slots run out and reports what fit"] = function()
		local bag = {}
		expect(Inventory.add(bag, items, "Cells", 25, 2)).toBe(20)
		expect(Inventory.add(bag, items, "Gun", 1, 2)).toBe(0)
		expect(Inventory.count(bag, "Cells")).toBe(20)
	end,
	["add refuses unknown items"] = function()
		expect(pcall(Inventory.add, {}, items, "Nope", 1, 5)).toBeFalsy()
	end,
	["remove takes from the newest stack and drops empty slots"] = function()
		local bag = {}
		Inventory.add(bag, items, "Cells", 14, 5)
		expect(Inventory.remove(bag, "Cells", 6)).toBe(6)
		expect(#bag).toBe(1)
		expect(bag[1].count).toBe(8)
		expect(Inventory.remove(bag, "Cells", 50)).toBe(8)
		expect(#bag).toBe(0)
	end,
	["totals merge stacks in first-carried order"] = function()
		local bag = {}
		Inventory.add(bag, items, "Gun", 1, 5)
		Inventory.add(bag, items, "Cells", 15, 5)
		local totals = Inventory.totals(bag)
		expect(#totals).toBe(2)
		expect(totals[1].id).toBe("Gun")
		expect(totals[2].count).toBe(15)
	end,
	["bestItem picks the most valuable single item"] = function()
		local bag = {}
		expect(Inventory.bestItem(bag, items)).toBe(nil)
		Inventory.add(bag, items, "Cells", 30, 5)
		Inventory.add(bag, items, "Watch", 1, 5)
		Inventory.add(bag, items, "Gun", 1, 5)
		expect(Inventory.bestItem(bag, items)).toBe("Watch")
	end,
	["takeAll empties the bag into a pile"] = function()
		local bag = {}
		Inventory.add(bag, items, "Gun", 1, 5)
		Inventory.add(bag, items, "Cells", 12, 5)
		local pile = Inventory.takeAll(bag)
		expect(#bag).toBe(0)
		expect(#pile).toBe(2)
		expect(pile[2].count).toBe(12)
	end,
	["moveAll leaves what does not fit in the pile"] = function()
		local pile = { { id = "Gun", count = 1 }, { id = "Cells", count = 25 } }
		local bag = {}
		Inventory.add(bag, items, "Watch", 1, 3)
		expect(Inventory.moveAll(pile, bag, items, 3)).toBe(20)
		expect(#pile).toBe(2)
		expect(pile[2].count).toBe(5)
		expect(Inventory.moveAll(pile, bag, items, 10)).toBe(6)
		expect(#pile).toBe(0)
	end,
	["real item definitions are complete"] = function()
		for id, def in InventoryItems do
			expect(def.id).toBe(id)
			expect(type(def.name)).toBe("string")
			expect(def.stackSize >= 1).toBeTruthy()
			expect(def.value >= 0).toBeTruthy()
		end
	end,
}
