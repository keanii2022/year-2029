local Config = require("../src/shared/Config/Containers")
local Container = require("../src/shared/Logic/Container")
local InteractKinds = require("../src/shared/Logic/InteractKinds")
local InventoryItems = require("../src/shared/Logic/InventoryItems")
local Rng = require("../src/shared/Logic/WarehouseGenRng")
local expect = require("./expect")

local entries = {
	{ item = "BlasterCells", model = "ammo_cell", count = { 8, 20 }, near = 22, deep = 16 },
	{ item = "Snack", model = "snack_bar", count = { 1, 2 }, near = 18, deep = 6 },
	{ item = "Apple", model = "apple", count = { 1, 2 }, near = 10, deep = 3 },
	{ item = "EmpCharge", model = "emp_charge", count = { 1, 1 }, near = 0, deep = 0.6, minDepth = 0.75 },
}

local function check(ok: boolean, label: string)
	expect(if ok then label else `{label} (bad)`).toBe(label)
end

local function goodMove()
	return { alive = true, viewing = true, open = true, distance = 4, reach = 12 }
end

return {
	["every storage kind is a real usable object that opens or hides"] = function()
		for modelName, rule in Config.Kinds do
			local behaviour = InteractKinds.get(modelName)
			check(behaviour ~= nil, modelName)
			local opens = behaviour.kind == "open" or behaviour.kind == "hide"
			for _, sub in behaviour.byPart or {} do
				opens = opens or sub.kind == "open"
			end
			check(opens, modelName)
			check(rule.slots >= 1 and rule.slots == math.floor(rule.slots), modelName)
			check(Config.Titles[modelName] ~= nil, modelName)
			for _, item in rule.only or {} do
				check(InventoryItems[item] ~= nil, `{modelName}.{item}`)
			end
		end
	end,

	["holds items only when the used part opens or hides"] = function()
		expect(Container.ruleFor(Config.Kinds, "dresser", "open")).toBe(Config.Kinds.dresser)
		expect(Container.ruleFor(Config.Kinds, "wardrobe", "hide")).toBe(Config.Kinds.wardrobe)
		expect(Container.ruleFor(Config.Kinds, "tv_stand", "toggle")).toBe(nil)
		expect(Container.ruleFor(Config.Kinds, "toilet", "open")).toBe(nil)
		expect(Container.ruleFor(Config.Kinds, nil, "open")).toBe(nil)
	end,

	["starting loot stays in the allowed items and fits the slots"] = function()
		local rule = { slots = 2, lootChance = 1, lootRolls = 6, only = { "Snack", "Apple" } }
		local rng = Rng.new(7)
		for _ = 1, 50 do
			local stacks = Container.startingLoot(rule, entries, 0.5, rng, InventoryItems)
			check(#stacks >= 1 and #stacks <= 2, "slots")
			for _, stack in stacks do
				check(stack.id == "Snack" or stack.id == "Apple", stack.id)
			end
		end
	end,

	["no loot chance means empty, and the same seed gives the same loot"] = function()
		local empty = Container.startingLoot(
			{ slots = 4, lootChance = 0, lootRolls = 3 },
			entries,
			0.5,
			Rng.new(1),
			InventoryItems
		)
		expect(#empty).toBe(0)
		local rule = { slots = 6, lootChance = 1, lootRolls = 3 }
		local a = Container.startingLoot(rule, entries, 0.3, Rng.new(42), InventoryItems)
		local b = Container.startingLoot(rule, entries, 0.3, Rng.new(42), InventoryItems)
		expect(#a).toBe(#b)
		for index, stack in a do
			expect(stack.id).toBe(b[index].id)
			expect(stack.count).toBe(b[index].count)
		end
	end,

	["some containers start with loot and some start empty"] = function()
		local rng = Rng.new(2029)
		local full, empty = 0, 0
		for _ = 1, 200 do
			local stacks = Container.startingLoot(Config.Kinds.dresser, entries, 0.4, rng, InventoryItems)
			if #stacks > 0 then
				full += 1
			else
				empty += 1
			end
		end
		check(full > 20 and empty > 20, `{full} full, {empty} empty`)
	end,

	["open while any part is open or someone hides inside"] = function()
		expect(Container.isOpen(nil)).toBe(false)
		expect(Container.isOpen({})).toBe(false)
		expect(Container.isOpen({ Drawer2 = true })).toBe(true)
		expect(Container.isOpen({ Hide = true })).toBe(true)
	end,

	["moves need a live viewer close to an open container"] = function()
		expect((Container.canMove(goodMove()))).toBe(true)
		for field, value in { alive = false, viewing = false, open = false, distance = 20 } do
			local move = goodMove()
			move[field] = value
			check(not Container.canMove(move), field)
		end
	end,

	["move counts are whole and never more than there is"] = function()
		expect(Container.moveCount(nil, 5)).toBe(5)
		expect(Container.moveCount(2.7, 5)).toBe(2)
		expect(Container.moveCount(99, 5)).toBe(5)
		expect(Container.moveCount(-3, 5)).toBe(1)
		expect(Container.moveCount(0 / 0, 5)).toBe(5)
		expect(Container.moveCount(3, 0)).toBe(0)
	end,
}
