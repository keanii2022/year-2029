local CombatReload = require("../src/shared/Logic/CombatReload")
local expect = require("./expect")

local function reload(overrides: { [string]: any })
	local check = {
		alive = true,
		carrying = false,
		hasGun = true,
		reloading = false,
		mag = 3,
		magSize = 12,
		bag = 30,
	}
	for key, value in overrides do
		check[key] = value
	end
	return CombatReload.canReload(check :: any)
end

return {
	["loaded never holds more than the bag"] = function()
		expect(CombatReload.loaded(12, 30)).toBe(12)
		expect(CombatReload.loaded(12, 5)).toBe(5)
		expect(CombatReload.loaded(4, 0)).toBe(0)
		expect(CombatReload.loaded(-1, 10)).toBe(0)
	end,
	["refill fills to the mag size or what the bag has"] = function()
		expect(CombatReload.refill(12, 30)).toBe(12)
		expect(CombatReload.refill(12, 7)).toBe(7)
		expect(CombatReload.refill(12, 0)).toBe(0)
	end,
	["reserve is the bag minus the mag"] = function()
		expect(CombatReload.reserve(12, 30)).toBe(18)
		expect(CombatReload.reserve(12, 5)).toBe(0)
		expect(CombatReload.reserve(0, 9)).toBe(9)
	end,
	["canReload allows a part-empty mag with spare cells"] = function()
		expect(reload({})).toBeTruthy()
		expect(reload({ mag = 0, bag = 1 })).toBeTruthy()
	end,
	["canReload refuses with a reason"] = function()
		local _, reason = reload({ alive = false })
		expect(reason).toBe("down")
		_, reason = reload({ carrying = true })
		expect(reason).toBe("hands full")
		_, reason = reload({ cuffed = true })
		expect(reason).toBe("cuffed")
		_, reason = reload({ hasGun = false })
		expect(reason).toBe("no gun")
		_, reason = reload({ reloading = true })
		expect(reason).toBe("reloading")
		_, reason = reload({ mag = 12 })
		expect(reason).toBe("full")
		_, reason = reload({ mag = 5, bag = 5 })
		expect(reason).toBe("no cells")
		_, reason = reload({ mag = 0, bag = 0 })
		expect(reason).toBe("no cells")
	end,
	["isDone waits the reload time, eased by the slack"] = function()
		expect(CombatReload.isDone(10, 11, 1.6, 1)).toBeFalsy()
		expect(CombatReload.isDone(10, 11.7, 1.6, 1)).toBeTruthy()
		expect(CombatReload.isDone(10, 11.3, 1.6, 0.8)).toBeTruthy()
		expect(CombatReload.isDone(10, 11.2, 1.6, 0.8)).toBeFalsy()
	end,
	["shouldAutoReload only on an empty mag with cells left"] = function()
		expect(CombatReload.shouldAutoReload(0, 10)).toBeTruthy()
		expect(CombatReload.shouldAutoReload(3, 10)).toBeFalsy()
		expect(CombatReload.shouldAutoReload(0, 0)).toBeFalsy()
		expect(CombatReload.shouldAutoReload(5, 0)).toBeFalsy()
	end,
	["motion dips, holds and rises back"] = function()
		expect(CombatReload.motion(0, 1.6, 0.25, 0.2)).toBe(0)
		expect(CombatReload.motion(0.2, 1.6, 0.25, 0.2)).toBeNear(0.5)
		expect(CombatReload.motion(0.8, 1.6, 0.25, 0.2)).toBe(1)
		expect(CombatReload.motion(1.6, 1.6, 0.25, 0.2)).toBe(0)
		expect(CombatReload.motion(1.6 - 0.16, 1.6, 0.25, 0.2)).toBeNear(0.5)
	end,
}
