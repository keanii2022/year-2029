local LifeSpots = require("../src/shared/Logic/LifeSpots")
local expect = require("./expect")

local SPOT_SETTINGS = { EndGap = 3, AisleStep = 12, AisleOffset = 1.5 }
local CHOOSE =
	{ MinDistance = 25, MaxDistance = 90, HiddenAngle = 50, GlimpseChance = 0.25, GlimpseMinDistance = 50 }

local function rolls(list)
	local n = 0
	return function()
		n += 1
		return list[(n - 1) % #list + 1]
	end
end

local function spot(x, z, kind)
	return { x = x, z = z, kind = kind or "aisle", dx = 0, dz = 1 }
end

local LOOK_NORTH = { x = 0, z = 0, lookX = 0, lookZ = 1 }

return {
	["a rack gives two ends and a spot per bay on each face"] = function()
		local spots = LifeSpots.fromShelves({ { x0 = 0, x1 = 24, z = 10, depth = 5 } }, SPOT_SETTINGS)
		local ends, aisles = 0, 0
		for _, s in spots do
			if s.kind == "end" then
				ends += 1
				expect(s.z).toBe(10)
				expect(s.x == -3 or s.x == 27).toBeTruthy()
			else
				aisles += 1
				expect(s.z == 14 or s.z == 6).toBeTruthy()
				expect(s.dz).toBe(if s.z > 10 then 1 else -1)
			end
		end
		expect(ends).toBe(2)
		expect(aisles).toBe(4)
	end,
	["near keeps only the ring and thins to max"] = function()
		local spots = {}
		for n = 0, 99 do
			table.insert(spots, spot(n, 0))
		end
		local ring = LifeSpots.near(spots, 0, 0, 20, 59, 100)
		expect(#ring).toBe(40)
		local thin = LifeSpots.near(spots, 0, 0, 20, 59, 10)
		expect(#thin).toBe(10)
		for _, s in thin do
			expect(s.x >= 20 and s.x <= 59).toBeTruthy()
		end
	end,
	["never picks a spot too close or too far"] = function()
		local spots = { spot(0, 10), spot(-10, 0), spot(0, -200) }
		expect(LifeSpots.choose(spots, LOOK_NORTH, "any", CHOOSE, rolls({ 0.9, 0.5 }))).toBe(nil)
	end,
	["prefers spots out of sight"] = function()
		local behind, ahead = spot(0, -40), spot(0, 60)
		local picked = LifeSpots.choose({ ahead, behind }, LOOK_NORTH, "any", CHOOSE, rolls({ 0.9, 0.5 }))
		expect(picked).toBe(behind)
	end,
	["a glimpse is far and in view"] = function()
		local behind, nearAhead, farAhead = spot(0, -40), spot(0, 30), spot(0, 70)
		local picked =
			LifeSpots.choose({ behind, nearAhead, farAhead }, LOOK_NORTH, "any", CHOOSE, rolls({ 0.1, 0.5 }))
		expect(picked).toBe(farAhead)
	end,
	["a close spot in view is never used, even with nothing else"] = function()
		local picked = LifeSpots.choose({ spot(0, 30) }, LOOK_NORTH, "any", CHOOSE, rolls({ 0.1, 0.5 }))
		expect(picked).toBe(nil)
	end,
	["kind filters spots"] = function()
		local aisle, rackEnd = spot(0, -40, "aisle"), spot(10, -40, "end")
		expect(LifeSpots.choose({ aisle, rackEnd }, LOOK_NORTH, "end", CHOOSE, rolls({ 0.9, 0.1 }))).toBe(
			rackEnd
		)
	end,
}
