local InventoryItems = require("../src/shared/Logic/InventoryItems")
local Prizes = require("../src/shared/Logic/Prizes")
local Rng = require("../src/shared/Logic/WarehouseGenRng")
local expect = require("./expect")

local settings = { GiantBonus = 0.15, ScaryBonus = { black_sun = 0.2 } }

local loot = {
	headline = {
		{ item = "Revolver", model = "revolver", count = { 1, 1 }, near = 4, deep = 0 },
		{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 0, deep = 4, minDepth = 0.5 },
	},
	fill = {
		{ item = "BlasterCells", model = "ammo_cell", count = { 20, 40 }, near = 10, deep = 8 },
		{ item = "Bandage", model = "bandage", count = { 2, 4 }, near = 5, deep = 4 },
	},
	rolls = { 1, 4 },
}

local function count(stacks: { any }, id: string): number
	local n = 0
	for _, stack in stacks do
		if stack.id == id then
			n += stack.count
		end
	end
	return n
end

return {
	["scary, giant, deep halls are worth more, capped at 1"] = function()
		expect(Prizes.value(settings, 0.3, "poolroom", false)).toBeNear(0.3)
		expect(Prizes.value(settings, 0.3, "black_sun", false)).toBeNear(0.5)
		expect(Prizes.value(settings, 0.3, "black_sun", true)).toBeNear(0.65)
		expect(Prizes.value(settings, 0.95, "black_sun", true)).toBe(1)
	end,
	["every chest has a headline find, and deep ones pay the rare one"] = function()
		local rng = Rng.new(5)
		local disruptors = 0
		for _ = 1, 50 do
			local near = Prizes.roll(loot, 0.1, rng, InventoryItems, 10)
			expect(count(near, "Revolver")).toBe(1)
			expect(count(near, "Disruptor")).toBe(0)
			local deep = Prizes.roll(loot, 1, rng, InventoryItems, 10)
			disruptors += count(deep, "Disruptor")
		end
		expect(disruptors).toBe(50)
	end,
	["higher value means more fill rolls"] = function()
		local rng = Rng.new(9)
		local low, high = 0, 0
		for _ = 1, 200 do
			low += #Prizes.roll(loot, 0, rng, InventoryItems, 10)
			high += #Prizes.roll(loot, 1, rng, InventoryItems, 10)
		end
		expect(high > low).toBeTruthy()
	end,
	["same seed fills the same chest"] = function()
		local a = Prizes.roll(loot, 0.6, Rng.new(3), InventoryItems, 10)
		local b = Prizes.roll(loot, 0.6, Rng.new(3), InventoryItems, 10)
		expect(#a).toBe(#b)
		for index, stack in a do
			expect(stack.id).toBe(b[index].id)
			expect(stack.count).toBe(b[index].count)
		end
	end,
	["gap follows the phase, nil when the phase has none"] = function()
		local gaps = { Day = { 100, 200 }, Night = { 400, 500 } }
		local rng = Rng.new(1)
		for _ = 1, 20 do
			local day = Prizes.gap(gaps, "Day", rng) :: number
			local night = Prizes.gap(gaps, "Night", rng) :: number
			expect(day >= 100 and day <= 200).toBeTruthy()
			expect(night >= 400 and night <= 500).toBeTruthy()
		end
		expect(Prizes.gap(gaps, "Siren", rng)).toBe(nil)
	end,
	["event pick only from what can happen"] = function()
		local events = { delivery = { weight = 3 }, open = { weight = 2 }, lost = { weight = 1 } }
		local rng = Rng.new(2)
		for _ = 1, 30 do
			expect(Prizes.pickEvent(events, { lost = true }, rng)).toBe("lost")
		end
		expect(Prizes.pickEvent(events, {}, rng)).toBe(nil)
		local seen = {}
		for _ = 1, 200 do
			seen[Prizes.pickEvent(events, { delivery = true, open = true, lost = true }, rng) :: string] =
				true
		end
		expect(seen.delivery and seen.open and seen.lost).toBeTruthy()
	end,
	["line fills in the spot"] = function()
		expect(Prizes.line("a delivery has arrived in aisle {spot}.", "42")).toBe(
			"a delivery has arrived in aisle 42."
		)
		expect(Prizes.line("the {spot} is now open", "Pool Halls")).toBe("the Pool Halls is now open")
		expect(Prizes.line("Lost item at the front desk.", nil)).toBe("Lost item at the front desk.")
	end,
	["clear spot search finds open floor or gives up"] = function()
		local rng = Rng.new(4)
		local x, z = Prizes.clearNear(function(px, _pz)
			return px > 10
		end, 0, 0, 5, 30, 40, rng)
		expect((x :: number) > 10).toBeTruthy()
		expect(z ~= nil).toBeTruthy()
		local nx = Prizes.clearNear(function()
			return false
		end, 0, 0, 5, 30, 10, rng)
		expect(nx).toBe(nil)
	end,
}
