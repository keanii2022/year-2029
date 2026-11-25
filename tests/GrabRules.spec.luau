local GrabRules = require("../src/shared/Logic/GrabRules")
local expect = require("./expect")

local function grab(overrides: { [string]: any })
	local check = { alive = true, alreadyCarrying = false, carriedByOther = false, distance = 5, reach = 12 }
	for key, value in overrides do
		check[key] = value
	end
	return GrabRules.canGrab(check :: any)
end

local function place(overrides: { [string]: any })
	local check = {
		groundFound = true,
		distance = 6,
		reach = 18,
		heightAboveFeet = 0,
		maxHeightAboveFeet = 12,
		blocked = false,
	}
	for key, value in overrides do
		check[key] = value
	end
	return GrabRules.canPlace(check :: any)
end

return {
	["canGrab allows a free prop in reach"] = function()
		expect(grab({})).toBeTruthy()
	end,
	["canGrab refuses one carrier at a time and far props"] = function()
		local ok, reason = grab({ carriedByOther = true })
		expect(ok).toBeFalsy()
		expect(reason).toBe("taken")
		ok, reason = grab({ distance = 13 })
		expect(ok).toBeFalsy()
		expect(reason).toBe("too far")
		ok, reason = grab({ alreadyCarrying = true })
		expect(reason).toBe("hands full")
		ok, reason = grab({ alive = false })
		expect(reason).toBe("dead")
	end,
	["canPlace allows a clear spot on the ground"] = function()
		expect(place({})).toBeTruthy()
	end,
	["canPlace allows stacking up to the height limit"] = function()
		expect(place({ heightAboveFeet = 12 })).toBeTruthy()
		local ok, reason = place({ heightAboveFeet = 12.5 })
		expect(ok).toBeFalsy()
		expect(reason).toBe("too high")
	end,
	["canPlace refuses blocked, far and groundless spots"] = function()
		local _, reason = place({ blocked = true })
		expect(reason).toBe("blocked")
		_, reason = place({ distance = 19 })
		expect(reason).toBe("too far")
		_, reason = place({ playerInWay = true, blocked = true })
		expect(reason).toBe("player")
		_, reason = place({ groundFound = false })
		expect(reason).toBe("no ground")
		_, reason = place({ sightBlocked = true, blocked = true })
		expect(reason).toBe("through wall")
	end,
	["movable keeps fixed structure and oversized pieces in place"] = function()
		local fixed = { wall_lower = true }
		expect(GrabRules.movable("pallet_boxes", 6, fixed, 16)).toBeTruthy()
		expect(GrabRules.movable("couch", 16, fixed, 16)).toBeTruthy()
		expect(GrabRules.movable("wall_lower", 4, fixed, 16)).toBeFalsy()
		expect(GrabRules.movable("giant_chair", 16.5, fixed, 16)).toBeFalsy()
	end,
}
