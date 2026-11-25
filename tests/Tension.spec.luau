local Tension = require("../src/shared/Logic/Tension")
local expect = require("./expect")

return {
	["no noise, no zone"] = function()
		expect(Tension.loudestZone({}, 80)).toBe(nil)
		expect(Tension.loudestZone({ { x = 1, z = 1, weight = 0 } }, 80)).toBe(nil)
	end,
	["many quiet sounds can beat one loud one"] = function()
		local spot = Tension.loudestZone({
			{ x = 500, z = 500, weight = 3 },
			{ x = 10, z = 10, weight = 1 },
			{ x = 20, z = 30, weight = 1 },
			{ x = 30, z = 20, weight = 2 },
		}, 80) :: any
		expect(spot.x).toBeNear(22.5)
		expect(spot.z).toBeNear(20)
	end,
	["the spot is the weighted middle of its zone"] = function()
		local spot = Tension.loudestZone({
			{ x = 0, z = 0, weight = 1 },
			{ x = 40, z = 0, weight = 3 },
		}, 80) :: any
		expect(spot.x).toBeNear(30)
		expect(spot.z).toBeNear(0)
	end,
}
