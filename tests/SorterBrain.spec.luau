local SorterBrain = require("../src/shared/Logic/SorterBrain")
local expect = require("./expect")

local settings = { HuntRange = 45, Leash = 80, Speed = 16, CatchDistance = 3.5, CatchCooldown = 8 }

local function at(x: number, z: number)
	return { X = x, Y = 0, Z = z }
end

local function input(overrides: { [string]: any })
	local base = {
		now = 100,
		dt = 0.2,
		night = true,
		seen = false,
		position = at(0, 0),
		home = at(0, 0),
		target = at(20, 0),
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

return {
	["creeps toward a nearby player at night while unseen"] = function()
		local state = SorterBrain.new()
		local action = SorterBrain.decide(settings, state, input({})) :: any
		expect(action.kind).toBe("move")
		expect(action.x).toBeNear(3.2, 1e-6)
		expect(action.z).toBeNear(0, 1e-6)
		expect(state.mode).toBe("creep")
	end,
	["freezes the moment anyone looks"] = function()
		local state = SorterBrain.new()
		expect(SorterBrain.decide(settings, state, input({ seen = true })).kind).toBe("hold")
	end,
	["never hunts by day"] = function()
		local state = SorterBrain.new()
		expect(SorterBrain.decide(settings, state, input({ night = false })).kind).toBe("hold")
	end,
	["ignores players out of range or past its leash"] = function()
		local state = SorterBrain.new()
		expect(SorterBrain.decide(settings, state, input({ target = at(60, 0) })).kind).toBe("hold")
		local far = input({ position = at(70, 0), target = at(90, 0) })
		expect(SorterBrain.decide(settings, state, far).kind).toBe("home")
	end,
	["grabs when close, then waits out the cooldown"] = function()
		local state = SorterBrain.new()
		expect(SorterBrain.decide(settings, state, input({ target = at(3, 0) })).kind).toBe("catch")
		expect(SorterBrain.decide(settings, state, input({ target = at(3, 0), now = 104 })).kind).toBe("hold")
		expect(SorterBrain.decide(settings, state, input({ target = at(3, 0), now = 109 })).kind).toBe(
			"catch"
		)
	end,
	["goes home by day once nobody looks"] = function()
		local state = SorterBrain.new()
		local away = input({ night = false, position = at(30, 0) })
		expect(SorterBrain.decide(settings, state, away).kind).toBe("home")
		away.seen = true
		expect(SorterBrain.decide(settings, state, away).kind).toBe("hold")
	end,
	["stays down after a shot, and only gets up unseen"] = function()
		local state = SorterBrain.new()
		SorterBrain.knockDown(state, 100, 20)
		expect(SorterBrain.decide(settings, state, input({ now = 110 })).kind).toBe("hold")
		expect(SorterBrain.decide(settings, state, input({ now = 121, seen = true })).kind).toBe("hold")
		expect(SorterBrain.decide(settings, state, input({ now = 122 })).kind).toBe("stand")
		expect(state.mode).toBe("still")
	end,
	["never steps past the stop distance"] = function()
		local x, z = SorterBrain.stepToward(at(0, 0), at(2, 0), 10, 3)
		expect(x).toBe(0)
		expect(z).toBe(0)
	end,
	["groups models into displays by distance"] = function()
		local groups = SorterBrain.groupNear({ at(0, 0), at(100, 0), at(3, 0), at(102, 1) }, 12)
		expect(#groups).toBe(2)
		expect(#groups[1]).toBe(2)
		expect(groups[2][2]).toBe(4)
	end,
}
