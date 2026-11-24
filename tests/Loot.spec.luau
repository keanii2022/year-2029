local Loot = require("../src/shared/Logic/Loot")
local Rng = require("../src/shared/Logic/WarehouseGenRng")
local WarehouseGen = require("../src/shared/Logic/WarehouseGen")
local expect = require("./expect")

local config = require("./WarehouseConfig")

local layout = WarehouseGen.generate(config, 2029)

local entries = {
	{ item = "BlasterCells", model = "ammo_cell", count = { 8, 20 }, near = 22, deep = 16 },
	{ item = "Snack", model = "snack_bar", count = { 1, 2 }, near = 18, deep = 6 },
	{ item = "Bandage", model = "bandage", count = { 1, 2 }, near = 4, deep = 9 },
	{ item = "RationPack", model = "ration_pack", count = { 1, 1 }, near = 0, deep = 4, minDepth = 0.4 },
	{ item = "EmpCharge", model = "emp_charge", count = { 1, 1 }, near = 0, deep = 0.6, minDepth = 0.75 },
}

local function tally(depth: number, rolls: number, seed: number): { [string]: number }
	local rng = Rng.new(seed)
	local counts = {}
	for _ = 1, rolls do
		local roll = Loot.roll(entries, depth, rng)
		if roll then
			counts[roll.item] = (counts[roll.item] or 0) + 1
		end
	end
	return counts
end

return {
	["weight slides from near to deep and is zero below minDepth"] = function()
		expect(Loot.weightAt(entries[2], 0)).toBe(18)
		expect(Loot.weightAt(entries[2], 1)).toBe(6)
		expect(Loot.weightAt(entries[2], 0.5)).toBe(12)
		expect(Loot.weightAt(entries[5], 0.74)).toBe(0)
		expect(Loot.weightAt(entries[5], 1) > 0).toBeTruthy()
	end,
	["same seed rolls the same loot"] = function()
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 50 do
			local ra, rb = Loot.roll(entries, 0.6, a), Loot.roll(entries, 0.6, b)
			expect(ra and ra.item).toBe(rb and rb.item)
			expect(ra and ra.count).toBe(rb and rb.count)
		end
	end,
	["counts stay inside the entry range"] = function()
		local rng = Rng.new(3)
		for _ = 1, 200 do
			local roll = Loot.roll(entries, 0.3, rng)
			if roll and roll.item == "BlasterCells" then
				expect(roll.count >= 8 and roll.count <= 20).toBeTruthy()
			end
		end
	end,
	["super rare gear never shows up shallow"] = function()
		local shallow = tally(0.5, 3000, 11)
		expect(shallow.EmpCharge).toBe(nil)
		expect(shallow.RationPack ~= nil).toBeTruthy()
		expect(tally(0.2, 3000, 11).RationPack).toBe(nil)
	end,
	["deeper is better: more bandages, fewer snacks, rare gear appears"] = function()
		local near, deep = tally(0, 4000, 5), tally(1, 4000, 5)
		expect((deep.Bandage or 0) > (near.Bandage or 0)).toBeTruthy()
		expect((deep.Snack or 0) < (near.Snack or 0)).toBeTruthy()
		expect((deep.EmpCharge or 0) > 0).toBeTruthy()
	end,
	["nothing to roll gives nil"] = function()
		expect(Loot.roll({ entries[5] }, 0.1, Rng.new(1))).toBe(nil)
	end,
	["floor spots are clear, inside the walls and seeded"] = function()
		local spots = Loot.floorSpots(layout, config, Rng.new(9), 300, 6, 2)
		expect(#spots > 250).toBeTruthy()
		for _, spot in spots do
			expect(WarehouseGen.isClear(layout, config, spot.x, spot.z, 2)).toBeTruthy()
			expect(spot.depth >= 0 and spot.depth <= 1).toBeTruthy()
		end
		local again = Loot.floorSpots(layout, config, Rng.new(9), 300, 6, 2)
		expect(again[17].x).toBe(spots[17].x)
	end,
	["room spots sit inside their room and roll deeper"] = function()
		local spots = Loot.roomSpots(layout, Rng.new(4), 1, 0.15)
		expect(#spots).toBe(#layout.rooms)
		for _, spot in spots do
			expect(WarehouseGen.roomAt(layout, spot.x, spot.z) ~= nil).toBeTruthy()
			expect(spot.depth >= WarehouseGen.depth(layout, spot.x, spot.z)).toBeTruthy()
		end
	end,
}
