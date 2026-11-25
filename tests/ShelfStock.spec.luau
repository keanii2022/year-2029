local ManifestData = require("../src/shared/Logic/ManifestData")
local ShelfStock = require("../src/shared/Logic/ShelfStock")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local sizes = {}
for _, entry in (ManifestData :: any).models do
	sizes[entry.name] = entry.size
end
local function sizeOf(name: string): { number }?
	return sizes[name]
end

local BAYS = 200
local DECK_HALF_WIDTH = 5.7
local DECK_HALF_DEPTH = 2.05

local function plans(): { { ShelfStock.Placement } }
	local list = {}
	local slots = ShelfStock.levelSlots(config)
	for seed = 1, BAYS do
		table.insert(list, ShelfStock.planBay(seed, slots, config, sizeOf))
	end
	return list
end

-- Turned (and maybe tipped) size of a placement: along, high, deep
local function footprint(spot: ShelfStock.Placement): (number, number, number)
	local size = sizes[spot.name]
	local w, h, d = size[1], size[2], size[3]
	if spot.tipped then
		w, h = h, w
	end
	local c, s = math.abs(math.cos(math.rad(spot.turn))), math.abs(math.sin(math.rad(spot.turn)))
	return w * c + d * s, h, w * s + d * c
end

local function levelUnder(y: number): any?
	local found = nil
	for _, level in config.ShelfLevels do
		if level.y <= y + 1e-6 then
			found = level
		end
	end
	return found
end

return {
	["every tier item is in the manifest and fits its shelf"] = function()
		for tier, weights in config.ShelfTiers do
			local clear = math.huge
			for _, level in config.ShelfLevels do
				if level.tier == tier then
					clear = math.min(clear, level.clear)
				end
			end
			for name in weights do
				local size = sizes[name]
				expect(size ~= nil).toBeTruthy()
				expect(size[2] <= clear and size[1] <= config.ShelfWidth and size[3] <= config.ShelfDepth).toBeTruthy()
			end
		end
	end,

	["shelves are packed but not endless"] = function()
		local total = 0
		for _, plan in plans() do
			total += #plan
			expect(#plan <= config.ShelfMaxPerSlot * #config.ShelfLevels + 1).toBeTruthy()
		end
		local average = total / BAYS
		expect(average >= 18 and average <= 50).toBeTruthy()
	end,

	["stock stays on the decks and under the next one"] = function()
		for _, plan in plans() do
			for _, spot in plan do
				local along, high, deep = footprint(spot)
				local spilled = math.abs(spot.z) > DECK_HALF_DEPTH
				if spilled then
					expect(spot.y).toBe(0)
					continue
				end
				expect(math.abs(spot.x) + along / 2 <= DECK_HALF_WIDTH).toBeTruthy()
				expect(math.abs(spot.z) + deep / 2 <= DECK_HALF_DEPTH).toBeTruthy()
				local level = levelUnder(spot.y)
				expect(level ~= nil).toBeTruthy()
				expect(spot.y + high <= level.y + level.clear + 1e-6).toBeTruthy()
			end
		end
	end,

	["big stuff low, small stuff high"] = function()
		local volume = { floor = { 0, 0 }, high = { 0, 0 } }
		for _, plan in plans() do
			for _, spot in plan do
				local level = levelUnder(spot.y)
				local bucket = volume[level.tier]
				if bucket and math.abs(spot.z) <= DECK_HALF_DEPTH then
					local size = sizes[spot.name]
					bucket[1] += size[1] * size[2] * size[3]
					bucket[2] += 1
				end
			end
		end
		expect(volume.floor[1] / volume.floor[2] > 2 * volume.high[1] / volume.high[2]).toBeTruthy()
	end,

	["some things fallen, some knocked into the aisle, boxes stacked"] = function()
		local fallen, spilled, stacked = 0, 0, 0
		for _, plan in plans() do
			for _, spot in plan do
				if spot.tipped then
					fallen += 1
				end
				if math.abs(spot.z) > DECK_HALF_DEPTH then
					spilled += 1
				end
				local level = levelUnder(spot.y)
				if spot.y > level.y + 0.5 then
					stacked += 1
				end
			end
		end
		expect(fallen > 0 and spilled > 0 and stacked > 0).toBeTruthy()
		expect(spilled < BAYS / 2).toBeTruthy()
	end,

	["the same seed stocks a bay the same way"] = function()
		local slots = ShelfStock.levelSlots(config)
		local a = ShelfStock.planBay(77, slots, config, sizeOf)
		local b = ShelfStock.planBay(77, slots, config, sizeOf)
		expect(#a).toBe(#b)
		for i, spot in a do
			expect(spot.name).toBe(b[i].name)
			expect(spot.x).toBe(b[i].x)
			expect(spot.y).toBe(b[i].y)
		end
	end,

	["baked bay gaps get the tier of their level"] = function()
		local slots = ShelfStock.gapSlots({ { x = 2.8, y = 0 }, { x = -2.8, y = 22 } }, 5.4, 4.6, config)
		expect(slots[1].tier).toBe("floor")
		expect(slots[2].tier).toBe("high")
		expect(slots[1].x0).toBeNear(0.1)
		expect(slots[2].x1).toBeNear(-0.1)
	end,

	["most bays are the empty frame"] = function()
		local empty = 0
		for i = 0, 999 do
			if ShelfStock.pickBay(i / 1000, config.RackBays) == "rack_bay_empty" then
				empty += 1
			end
		end
		expect(empty >= 600 and empty <= 850).toBeTruthy()
	end,

	["only nearby bays stream in, nearest first, inside the budget"] = function()
		local bays = {}
		for i = 1, 20 do
			table.insert(bays, { x = i * 10, z = 0 })
		end
		local function ten()
			return 10
		end
		local players = { { x = 0, z = 0 } }
		local chosen = ShelfStock.wanted(bays, {}, players, 135, 165, 1000, ten)
		expect(chosen[13]).toBe(true)
		expect(chosen[14]).toBe(nil)
		local tight = ShelfStock.wanted(bays, {}, players, 135, 165, 35, ten)
		expect(tight[3]).toBe(true)
		expect(tight[4]).toBe(nil)
		-- A stocked bay stays stocked a little past the radius
		local kept = ShelfStock.wanted(bays, { [15] = true }, players, 135, 165, 1000, ten)
		expect(kept[15]).toBe(true)
		expect(kept[14]).toBe(nil)
		expect(ShelfStock.wanted(bays, {}, {}, 135, 165, 1000, ten)[1]).toBe(nil)
	end,
}
