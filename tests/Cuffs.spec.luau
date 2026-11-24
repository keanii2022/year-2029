local Cuffs = require("../src/shared/Logic/Cuffs")
local expect = require("./expect")

local settings = {
	Range = 6,
	BehindDot = 0.35,
	LowHealthFraction = 0.35,
	TargetCooldown = 180,
	Duration = 20,
	MinDuration = 5,
	MashSeconds = 0.25,
	MashMinInterval = 0.08,
}

-- Target at the origin facing +z; the default cuffer stands 3 studs behind.
local function check(overrides: { [string]: any })
	local base = {
		cufferPosition = { x = 0, z = -3 },
		targetPosition = { x = 0, z = 0 },
		targetFacing = { x = 0, z = 1 },
		targetHealth = 100,
		targetMaxHealth = 100,
		targetAlive = true,
		targetCuffed = false,
		cufferCuffed = false,
		hasCuffs = true,
		sinceTargetLastCuffed = nil,
	}
	for key, value in overrides do
		base[key] = value
	end
	return Cuffs.canCuff(base :: any, settings)
end

return {
	["behindness is 1 behind, 0 beside, -1 in front"] = function()
		local facing = { x = 0, z = 1 }
		local origin = { x = 0, z = 0 }
		expect(Cuffs.behindness({ x = 0, z = -4 }, origin, facing)).toBeNear(1)
		expect(Cuffs.behindness({ x = 4, z = 0 }, origin, facing)).toBeNear(0)
		expect(Cuffs.behindness({ x = 0, z = 4 }, origin, facing)).toBeNear(-1)
		expect(Cuffs.behindness(origin, origin, facing)).toBe(0)
	end,
	["can cuff a healthy player from behind"] = function()
		expect(check({})).toBe(true)
	end,
	["can't cuff a healthy player from the front or side"] = function()
		local ok, reason = check({ cufferPosition = { x = 0, z = 3 } })
		expect(ok).toBe(false)
		expect(reason).toBe("not behind")
		expect(check({ cufferPosition = { x = 3, z = 0 } })).toBe(false)
	end,
	["low health can be cuffed from any side"] = function()
		expect(check({ cufferPosition = { x = 0, z = 3 }, targetHealth = 35 })).toBe(true)
		expect(check({ cufferPosition = { x = 0, z = 3 }, targetHealth = 36 })).toBe(false)
	end,
	["range is measured flat"] = function()
		expect(check({ cufferPosition = { x = 0, z = -6 } })).toBe(true)
		local ok, reason = check({ cufferPosition = { x = 0, z = -6.1 } })
		expect(ok).toBe(false)
		expect(reason).toBe("too far")
	end,
	["the same target is protected for the cooldown"] = function()
		local ok, reason = check({ sinceTargetLastCuffed = 179 })
		expect(ok).toBe(false)
		expect(reason).toBe("cooldown")
		expect(check({ sinceTargetLastCuffed = 180 })).toBe(true)
	end,
	["needs cuffs, a live uncuffed target, and a free cuffer"] = function()
		expect(check({ hasCuffs = false })).toBe(false)
		expect(check({ targetAlive = false })).toBe(false)
		expect(check({ targetCuffed = true })).toBe(false)
		expect(check({ cufferCuffed = true })).toBe(false)
	end,
	["cuffs last the full duration without mashing"] = function()
		local hold = Cuffs.start(100, settings)
		expect(Cuffs.isOver(hold, 119.9)).toBe(false)
		expect(Cuffs.isOver(hold, 120)).toBe(true)
	end,
	["mashing takes time off but never below the minimum"] = function()
		local hold = Cuffs.start(0, settings)
		expect(Cuffs.mash(hold, 1, settings)).toBe(true)
		expect(hold.endsAt).toBeNear(19.75)
		for i = 1, 200 do
			Cuffs.mash(hold, 1 + i * 0.1, settings)
		end
		expect(hold.endsAt).toBe(5)
	end,
	["presses faster than the limit don't count"] = function()
		local hold = Cuffs.start(0, settings)
		expect(Cuffs.mash(hold, 1, settings)).toBe(true)
		expect(Cuffs.mash(hold, 1.05, settings)).toBe(false)
		expect(hold.endsAt).toBeNear(19.75)
		expect(Cuffs.mash(hold, 1.1, settings)).toBe(true)
	end,
	["transfer moves everything that fits"] = function()
		local from, to = 5, 0
		local moved = Cuffs.transfer(function(n)
			local taken = math.min(n, from)
			from -= taken
			return taken
		end, function(n)
			to += n
			return n
		end, function(n)
			from += n
		end, 5)
		expect(moved).toBe(5)
		expect(from).toBe(0)
		expect(to).toBe(5)
	end,
	["transfer gives back what didn't fit"] = function()
		local from, to = 5, 0
		local moved = Cuffs.transfer(function(n)
			from -= n
			return n
		end, function(n)
			local fit = math.min(n, 2)
			to += fit
			return fit
		end, function(n)
			from += n
		end, 5)
		expect(moved).toBe(2)
		expect(from).toBe(3)
		expect(to).toBe(2)
	end,
	["transfer of nothing adds nothing"] = function()
		local added = false
		expect(Cuffs.transfer(function()
			return 0
		end, function(n)
			added = true
			return n
		end, function() end, 3)).toBe(0)
		expect(added).toBe(false)
	end,
}
