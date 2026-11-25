local FortLink = require("../src/shared/Logic/FortLink")
local expect = require("./expect")

local function box(x: number, y: number, z: number, hx: number, hy: number, hz: number): FortLink.Box
	return { x = x, y = y, z = z, hx = hx, hy = hy, hz = hz }
end

local CRATE = box(0, 1.5, 0, 1.5, 1.5, 1.5)
local FLOOR = box(0, -0.5, 0, 50, 0.5, 50)

return {
	["gap is the widest separation on any axis"] = function()
		expect(FortLink.gap(CRATE, box(3.2, 1.5, 0, 1.5, 1.5, 1.5))).toBeNear(0.2)
		expect(FortLink.gap(CRATE, box(2, 1.5, 0, 1.5, 1.5, 1.5)) <= 0).toBeTruthy()
	end,
	["a lone piece on the floor is not fortified"] = function()
		expect(FortLink.fortified(CRATE, { { box = FLOOR, placed = false } }, 0.3, 0.5)).toBeFalsy()
	end,
	["a piece touching another placed piece is fortified, even stacked"] = function()
		local beside = { box = box(3.2, 1.5, 0, 1.5, 1.5, 1.5), placed = true }
		local onTop = { box = box(0, 4.5, 0, 1.5, 1.5, 1.5), placed = true }
		expect(FortLink.fortified(CRATE, { beside }, 0.3, 0.5)).toBeTruthy()
		expect(FortLink.fortified(CRATE, { onTop }, 0.3, 0.5)).toBeTruthy()
	end,
	["a piece set against a wall is fortified"] = function()
		local wall = { box = box(1.7, 8, 0, 0.1, 8, 20), placed = false }
		expect(FortLink.fortified(CRATE, { wall }, 0.3, 0.5)).toBeTruthy()
	end,
	["a gap of 0.3 or more doesn't count"] = function()
		local beside = { box = box(3.35, 1.5, 0, 1.5, 1.5, 1.5), placed = true }
		expect(FortLink.fortified(CRATE, { beside }, 0.3, 0.5)).toBeFalsy()
	end,
}
