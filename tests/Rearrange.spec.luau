local Rearrange = require("../src/shared/Logic/Rearrange")
local expect = require("./expect")

local function rolls(list)
	local n = 0
	return function()
		n += 1
		return list[(n - 1) % #list + 1]
	end
end

local function always()
	return true
end

local CHOOSE = {
	KeepAway = 40,
	Share = { junk = 0.5, furniture = 0.5, cart = 1 },
	Max = { junk = 10, furniture = 1, cart = 5 },
}
local SHIFT = { MinShift = 6, MaxShift = 24, Tries = 8, KeepAway = 40, Gap = 3 }
local CART = { CartRange = 100, AisleGap = 10, Tries = 8, KeepAway = 40, Gap = 3 }

return {
	["forts, carried things, lockers and anything near a player stay put"] = function()
		local players = { { x = 0, z = 0 } }
		expect(Rearrange.movable({ x = 100, z = 0, kind = "junk" }, players, 40)).toBeTruthy()
		expect(Rearrange.movable({ x = 100, z = 0, kind = "junk", placed = true }, players, 40)).toBeFalsy()
		expect(Rearrange.movable({ x = 100, z = 0, kind = "junk", carried = true }, players, 40)).toBeFalsy()
		expect(Rearrange.movable({ x = 100, z = 0, kind = "furniture", fixed = true }, players, 40)).toBeFalsy()
		expect(Rearrange.movable({ x = 30, z = 0, kind = "junk" }, players, 40)).toBeFalsy()
	end,

	["a box with another resting on it is covered, the top one isn't"] = function()
		local bottom = { x = 10, z = 10, kind = "junk", y = 1, half = 1.5 }
		local top = { x = 10.5, z = 10, kind = "junk", y = 3, half = 1.5 }
		local alone = { x = 40, z = 40, kind = "junk", y = 1, half = 1.5 }
		Rearrange.markCovered({ bottom, top, alone }, 8)
		expect(bottom.covered).toBe(true)
		expect(top.covered).toBe(nil)
		expect(alone.covered).toBe(nil)
	end,

	["choose takes a rounded-down share per kind, capped by Max"] = function()
		local items = {}
		for i = 1, 6 do
			table.insert(items, { x = 100 + i, z = 0, kind = "junk" })
		end
		for i = 1, 4 do
			table.insert(items, { x = 200 + i, z = 0, kind = "furniture" })
		end
		table.insert(items, { x = 300, z = 0, kind = "junk", placed = true })
		local chosen = Rearrange.choose(items, {}, CHOOSE, rolls({ 0.3, 0.7, 0.1 }))
		local junk, furniture = 0, 0
		for _, index in chosen do
			local item = items[index]
			expect(item.placed).toBe(nil)
			if item.kind == "junk" then
				junk += 1
			else
				furniture += 1
			end
		end
		expect(junk).toBe(3)
		expect(furniture).toBe(1)
	end,

	["spotNear finds a clear spot in range and remembers it"] = function()
		local taken = {}
		local spot = Rearrange.spotNear(0, 0, {}, taken, SHIFT, rolls({ 0.25, 0.5 }), always)
		expect(spot).toBeTruthy()
		local d = math.sqrt(spot.x ^ 2 + spot.z ^ 2)
		expect(d >= 6 and d <= 24).toBeTruthy()
		expect(#taken).toBe(1)
	end,

	["spotNear gives up when nothing is clear or it would land by a player"] = function()
		local never = function()
			return false
		end
		expect(Rearrange.spotNear(0, 0, {}, {}, SHIFT, rolls({ 0.5 }), never)).toBe(nil)
		expect(Rearrange.spotNear(0, 0, { { x = 0, z = 0 } }, {}, SHIFT, rolls({ 0.5 }), always)).toBe(nil)
	end,

	["spotNear won't stack two things on the same spot"] = function()
		local taken = { { x = 15, z = 0 } }
		expect(Rearrange.spotNear(0, 0, {}, taken, SHIFT, rolls({ 0, 0.5 }), always)).toBe(nil)
	end,

	["a cart rolls to another aisle within range"] = function()
		local spots = { { x = 5, z = 2 }, { x = 20, z = 30 }, { x = 500, z = 40 } }
		local spot = Rearrange.cartSpot(0, 0, spots, {}, {}, CART, rolls({ 0.5 }), always)
		expect(spot).toBeTruthy()
		expect(spot.x).toBe(20)
		expect(spot.z).toBe(30)
	end,

	["swaps pair signs without reusing one"] = function()
		local swapped = Rearrange.swaps(5, 4, rolls({ 0.9, 0.1, 0.5, 0.3 }))
		expect(#swapped).toBe(2)
		local seen = {}
		for _, pair in swapped do
			for _, index in pair do
				expect(seen[index]).toBe(nil)
				seen[index] = true
			end
		end
	end,

	["drag spots are the right distance from a player"] = function()
		local spot = Rearrange.dragSpot(
			{ { x = 10, z = 10 } },
			{ Min = 60, Max = 110 },
			rolls({ 0, 0.3, 0.5 })
		)
		local d = math.sqrt((spot.x - 10) ^ 2 + (spot.z - 10) ^ 2)
		expect(d).toBeNear(85, 0.01)
		expect(Rearrange.dragSpot({}, { Min = 60, Max = 110 }, rolls({ 0.5 }))).toBe(nil)
	end,
}
