local LifeMoments = require("../src/shared/Logic/LifeMoments")
local expect = require("./expect")

local POINTS = {
	{ x = 50, z = 0 },
	{ x = 5, z = 0 },
	{ x = 0, z = 20 },
	{ x = 200, z = 0 },
	{ x = 0, z = -10 },
}

return {
	["nearest keeps the ring, nearest first, capped"] = function()
		local picked = LifeMoments.nearest(POINTS, 0, 0, 0, 60, 10)
		expect(#picked).toBe(4)
		expect(picked[1]).toBe(2)
		expect(picked[2]).toBe(5)
		expect(picked[3]).toBe(3)
		expect(picked[4]).toBe(1)
		local capped = LifeMoments.nearest(POINTS, 0, 0, 0, 60, 2)
		expect(#capped).toBe(2)
		expect(capped[2]).toBe(5)
	end,
	["nearest skips anything too close"] = function()
		local picked = LifeMoments.nearest(POINTS, 0, 0, 8, 60, 10)
		expect(#picked).toBe(3)
		expect(picked[1]).toBe(5)
		expect(#LifeMoments.nearest({}, 0, 0, 0, 60, 3)).toBe(0)
	end,
	["sway stays inside the angle and moves over time"] = function()
		local settings = { Angle = 2, Period = 7 }
		local limit = math.rad(2) + 1e-9
		local first = LifeMoments.sway(0, 0.3, settings)
		local changed = false
		for step = 0, 200 do
			local tilt, roll = LifeMoments.sway(step * 0.1, 0.3, settings)
			expect(math.abs(tilt) <= limit).toBeTruthy()
			expect(math.abs(roll) <= limit * 0.4 + 1e-9).toBeTruthy()
			if math.abs(tilt - first) > 0.01 then
				changed = true
			end
		end
		expect(changed).toBeTruthy()
	end,
	["sway seeds put signs out of step"] = function()
		local settings = { Angle = 2, Period = 7 }
		local a = LifeMoments.sway(3, 0.1, settings)
		local b = LifeMoments.sway(3, 0.6, settings)
		expect(math.abs(a - b) > 0.01).toBeTruthy()
	end,
	["glimpse needs a long clear sightline and stays short of the end"] = function()
		local settings = { Near = 60, Far = 100, Margin = 4 }
		expect(LifeMoments.glimpseDistance(40, settings)).toBe(nil)
		expect(LifeMoments.glimpseDistance(63, settings)).toBe(nil)
		expect(LifeMoments.glimpseDistance(80, settings)).toBeNear(76)
		expect(LifeMoments.glimpseDistance(104, settings)).toBeNear(100)
		expect(LifeMoments.glimpseDistance(500, settings)).toBeNear(100)
	end,
}
