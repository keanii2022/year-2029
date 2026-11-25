local Combat = require("../src/shared/Logic/Combat")
local expect = require("./expect")

local gun = {
	rank = 1,
	ammo = "Cells",
	damage = 20,
	minDamage = 10,
	falloffStart = 40,
	falloffEnd = 140,
	range = 300,
	fireInterval = 0.2,
	mode = "semi",
	magSize = 12,
	reloadTime = 1.6,
}

local function fire(overrides: { [string]: any })
	local check =
		{ alive = true, carrying = false, hasGun = true, ammo = 5, sinceLastShot = 1, minInterval = 0.16 }
	for key, value in overrides do
		check[key] = value
	end
	return Combat.canFire(check :: any)
end

return {
	["damageAt is full up close and slides to the minimum"] = function()
		expect(Combat.damageAt(gun, 5)).toBe(20)
		expect(Combat.damageAt(gun, 40)).toBe(20)
		expect(Combat.damageAt(gun, 90)).toBeNear(15)
		expect(Combat.damageAt(gun, 140)).toBe(10)
		expect(Combat.damageAt(gun, 1000)).toBe(10)
	end,
	["selectedGun only hands back a real gun the player owns"] = function()
		local guns = { Pistol = gun }
		local function owns(id)
			return id == "Pistol"
		end
		expect(Combat.selectedGun(guns :: any, "Pistol", owns)).toBe(gun)
		expect(Combat.selectedGun(guns :: any, "Rifle", function()
			return true
		end)).toBe(nil)
		expect(Combat.selectedGun(guns :: any, "Pistol", function()
			return false
		end)).toBe(nil)
		expect(Combat.selectedGun(guns :: any, 42, owns)).toBe(nil)
		expect(Combat.selectedGun(guns :: any, nil, owns)).toBe(nil)
	end,
	["canFire allows a ready shot"] = function()
		expect(fire({})).toBeTruthy()
	end,
	["canFire refuses with a reason"] = function()
		local _, reason = fire({ alive = false })
		expect(reason).toBe("down")
		_, reason = fire({ carrying = true })
		expect(reason).toBe("hands full")
		_, reason = fire({ cuffed = true })
		expect(reason).toBe("cuffed")
		_, reason = fire({ hasGun = false })
		expect(reason).toBe("no gun")
		_, reason = fire({ reloading = true })
		expect(reason).toBe("reloading")
		_, reason = fire({ ammo = 0 })
		expect(reason).toBe("no ammo")
		_, reason = fire({ sinceLastShot = 0.1 })
		expect(reason).toBe("too fast")
	end,
	["checkShot wants an origin near the head and a unit direction"] = function()
		expect(Combat.checkShot({ originOffset = 1, maxOriginOffset = 6, directionLength = 1 })).toBeTruthy()
		local _, reason = Combat.checkShot({ originOffset = 9, maxOriginOffset = 6, directionLength = 1 })
		expect(reason).toBe("bad origin")
		_, reason = Combat.checkShot({ originOffset = 0 / 0, maxOriginOffset = 6, directionLength = 1 })
		expect(reason).toBe("bad origin")
		_, reason = Combat.checkShot({ originOffset = 1, maxOriginOffset = 6, directionLength = 2 })
		expect(reason).toBe("bad direction")
		_, reason = Combat.checkShot({ originOffset = 1, maxOriginOffset = 6, directionLength = 0 / 0 })
		expect(reason).toBe("bad direction")
	end,
	["lineOfSightClear only blocks on something well before the target"] = function()
		expect(Combat.lineOfSightClear(50, nil, 0.5)).toBeTruthy()
		expect(Combat.lineOfSightClear(50, 49.8, 0.5)).toBeTruthy()
		expect(Combat.lineOfSightClear(50, 20, 0.5)).toBeFalsy()
	end,
	["respawnSecondsLeft counts whole seconds down to zero"] = function()
		expect(Combat.respawnSecondsLeft(10, 4.2)).toBe(6)
		expect(Combat.respawnSecondsLeft(10, 12)).toBe(0)
	end,
}
