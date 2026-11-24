local HauntPlacement = require("../src/shared/Logic/HauntPlacement")
local expect = require("./expect")

local function counter()
	local seed = 7
	return function()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
end

local function always()
	return true
end

return {
	["spots are clear, inside the floor and kept apart"] = function()
		local taken = {}
		local spots = HauntPlacement.spots(20, 1000, 50, 40, function(x)
			return x > 0
		end, taken, counter())
		expect(#spots).toBe(20)
		expect(#taken).toBe(20)
		for i, a in spots do
			expect(a.x > 0 and a.x <= 1000 and math.abs(a.z) <= 1000).toBeTruthy()
			for j, b in spots do
				if i ~= j then
					expect(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 50).toBeTruthy()
				end
			end
		end
	end,
	["spots keep away from earlier groups"] = function()
		local taken = { { x = 0, z = 0, turn = 0 } }
		for _, spot in HauntPlacement.spots(5, 100, 60, 40, always, taken, counter()) do
			expect(math.sqrt(spot.x ^ 2 + spot.z ^ 2) >= 60).toBeTruthy()
		end
	end,
	["gives up quietly when nothing is clear"] = function()
		local spots = HauntPlacement.spots(5, 100, 10, 10, function()
			return false
		end, {}, counter())
		expect(#spots).toBe(0)
	end,
	["a group turns with its spot"] = function()
		local items =
			{ { name = "tent", dx = 0, dz = 0, turn = 0 }, { name = "candles", dx = 0, dz = 7, turn = 10 } }
		local facingNorth = HauntPlacement.arrange(items, { x = 100, z = 50, turn = 0 })
		expect(facingNorth[2].x).toBeNear(100)
		expect(facingNorth[2].z).toBeNear(57)
		expect(facingNorth[2].turn).toBe(10)
		local facingEast = HauntPlacement.arrange(items, { x = 100, z = 50, turn = 90 })
		expect(facingEast[1].x).toBeNear(100)
		expect(facingEast[2].x).toBeNear(107)
		expect(facingEast[2].z).toBeNear(50)
		expect(facingEast[2].turn).toBe(100)
	end,
	["every nth spreads picks over the whole list"] = function()
		local list = {}
		for i = 1, 100 do
			list[i] = i
		end
		local picked = HauntPlacement.everyNth(list, 4)
		expect(#picked).toBe(4)
		expect(picked[1]).toBe(1)
		expect(picked[4]).toBe(76)
		expect(#HauntPlacement.everyNth(list, 0)).toBe(0)
		expect(#HauntPlacement.everyNth({ 1, 2 }, 5)).toBe(2)
	end,
}
