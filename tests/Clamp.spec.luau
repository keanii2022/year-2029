local Clamp = require("../src/shared/Logic/Clamp")
local expect = require("./expect")

return {
	["approach moves up without overshooting"] = function()
		expect(Clamp.approach(0, 10, 3)).toBe(3)
		expect(Clamp.approach(9, 10, 3)).toBe(10)
	end,
	["approach moves down without overshooting"] = function()
		expect(Clamp.approach(10, 0, 4)).toBe(6)
		expect(Clamp.approach(1, 0, 4)).toBe(0)
	end,
}
