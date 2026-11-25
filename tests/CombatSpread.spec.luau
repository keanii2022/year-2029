local CombatSpread = require("../src/shared/Logic/CombatSpread")
local expect = require("./expect")

local tuning = { walk = 0.8, airborne = 3, crouchScale = 0.7 }
local smg = { hipSpread = 2, adsSpread = 0.6, bloomPerShot = 0.25, bloomMax = 3.5 }

local function state(overrides: { [string]: any })
	local s = { aim = 0, bloom = 0, moving = false, airborne = false, crouching = false }
	for key, value in overrides do
		s[key] = value
	end
	return s :: any
end

return {
	["cone blends hip to aimed and adds bloom"] = function()
		expect(CombatSpread.cone(smg, state({}), tuning)).toBeNear(2)
		expect(CombatSpread.cone(smg, state({ aim = 1 }), tuning)).toBeNear(0.6)
		expect(CombatSpread.cone(smg, state({ aim = 0.5, bloom = 1 }), tuning)).toBeNear(2.3)
	end,
	["moving, jumping and crouching change the cone"] = function()
		expect(CombatSpread.cone(smg, state({ moving = true }), tuning)).toBeNear(2.8)
		expect(CombatSpread.cone(smg, state({ moving = true, airborne = true }), tuning)).toBeNear(5)
		expect(CombatSpread.cone(smg, state({ crouching = true }), tuning)).toBeNear(1.4)
		expect(CombatSpread.cone(smg, state({ crouching = true, airborne = true }), tuning)).toBeNear(5)
	end,
	["a gun with no spread numbers is dead on"] = function()
		expect(CombatSpread.cone({}, state({}), tuning)).toBe(0)
	end,
	["bloom builds per shot up to its cap"] = function()
		local bloom = 0
		for _ = 1, 3 do
			bloom = CombatSpread.bloomAfterShot(smg, bloom)
		end
		expect(bloom).toBeNear(0.75)
		for _ = 1, 20 do
			bloom = CombatSpread.bloomAfterShot(smg, bloom)
		end
		expect(bloom).toBeNear(1.5)
		expect(CombatSpread.bloomAfterShot({ hipSpread = 4, bloomMax = 4 }, 0)).toBe(0)
	end,
	["bloom recovers over time and stops at zero"] = function()
		expect(CombatSpread.recover(1.5, 0.1, 6)).toBeNear(0.9)
		expect(CombatSpread.recover(0.3, 1, 6)).toBe(0)
	end,
	["offset stays inside the cone"] = function()
		for index = 0, 20 do
			local yaw, pitch = CombatSpread.offset(2.5, index / 20, (index * 7 % 20) / 20)
			expect(math.sqrt(yaw * yaw + pitch * pitch) <= 2.5 + 1e-9).toBeTruthy()
		end
		local yaw, pitch = CombatSpread.offset(2, 1, 0)
		expect(yaw).toBeNear(2)
		expect(pitch).toBeNear(0)
	end,
}
