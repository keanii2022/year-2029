local GrabPlace = require("../src/shared/Logic/GrabPlace")
local expect = require("./expect")

local function overlap(overrides: { [string]: any })
	local check = { ownProp = false, character = nil, canCollide = true, transparency = 0, thinnest = 1 }
	for key, value in overrides do
		check[key] = value
	end
	return check :: any
end

return {
	["blocks a solid wall or prop"] = function()
		expect(GrabPlace.blocks(overlap({}), true)).toBeTruthy()
	end,
	["never blocks on the prop itself, mats, ropes or invisible zones"] = function()
		expect(GrabPlace.blocks(overlap({ ownProp = true }), true)).toBeFalsy()
		expect(GrabPlace.blocks(overlap({ thinnest = 0.1 }), true)).toBeFalsy()
		expect(GrabPlace.blocks(overlap({ canCollide = false }), true)).toBeFalsy()
		expect(GrabPlace.blocks(overlap({ transparency = 1 }), true)).toBeFalsy()
	end,
	["other players always block, the carrier only on the strict pass"] = function()
		expect(GrabPlace.blocks(overlap({ character = "other", canCollide = false }), false)).toBeTruthy()
		expect(GrabPlace.blocks(overlap({ character = "carrier" }), true)).toBeTruthy()
		expect(GrabPlace.blocks(overlap({ character = "carrier" }), false)).toBeFalsy()
	end,
	["landing casts pass invisible and non-solid parts"] = function()
		expect(GrabPlace.landsOn(true, 0)).toBeTruthy()
		expect(GrabPlace.landsOn(true, 1)).toBeFalsy()
		expect(GrabPlace.landsOn(false, 0)).toBeFalsy()
	end,
	["overlap box shrinks by the tolerance but never below half"] = function()
		local x, y, z = GrabPlace.overlapSize(4, 2, 0.6, 0.3)
		expect(x).toBeNear(3.4)
		expect(y).toBeNear(1.4)
		expect(z).toBeNear(0.3)
	end,
	["offsets start at the aimed spot and ring outward"] = function()
		local spots = GrabPlace.offsets({ 1, 2 })
		expect(#spots).toBe(17)
		expect(spots[1].x).toBe(0)
		expect(spots[2].x).toBeNear(1)
		expect(math.sqrt(spots[17].x ^ 2 + spots[17].z ^ 2)).toBeNear(2)
	end,
}
