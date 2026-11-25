local DogWary = require("../src/shared/Logic/DogWary")
local expect = require("./expect")

local SETTINGS = {
	WaryDistance = 10,
	CautiousDistance = 5,
	Wary = {
		SlowSpeed = 8,
		ClosingSpeed = 4,
		SprintRange = 25,
		SniffAfter = 3,
		StepAfter = 6,
		FoodDistance = 3,
	},
}

local function react(overrides: { [string]: any }): string
	local input = {
		stage = "wary",
		distance = 20,
		stance = "Walk",
		speed = 0,
		closing = 0,
		holdingFood = false,
		spooked = false,
		calmFor = 0,
	}
	for key, value in overrides do
		input[key] = value
	end
	return DogWary.react(input :: any, SETTINGS)
end

return {
	["at first sight it freezes and watches"] = function()
		expect(react({ speed = 14 })).toBe("watch")
	end,
	["walking straight at it makes it back off"] = function()
		expect(react({ distance = 8, speed = 14, closing = 12 })).toBe("backoff")
	end,
	["sprinting at it or a spook makes it run"] = function()
		expect(react({ stance = "Sprint", distance = 20, speed = 22, closing = 20 })).toBe("run")
		expect(DogWary.isBadMove({ stance = "Sprint", distance = 40, closing = 20 } :: any, SETTINGS)).toBe(
			false
		)
		expect(react({ spooked = true, stance = "Crouch" })).toBe("run")
	end,
	["crouching slowly: stays, then sniffs, then steps closer"] = function()
		expect(react({ stance = "Crouch", speed = 5, calmFor = 1 })).toBe("stay")
		expect(react({ stance = "Crouch", speed = 5, calmFor = 4 })).toBe("sniff")
		expect(react({ stance = "Crouch", speed = 5, calmFor = 7 })).toBe("creep")
	end,
	["crouching alone only brings it so close"] = function()
		expect(react({ stance = "Crouch", distance = 4, calmFor = 7 })).toBe("sniff")
		expect(DogWary.closest("wary", SETTINGS)).toBe(5)
		expect(DogWary.closest("eats", SETTINGS)).toBe(2.5)
	end,
	["food in your hand draws it in while you keep still"] = function()
		expect(react({ holdingFood = true, distance = 12 })).toBe("creep")
		expect(react({ holdingFood = true, distance = 2.5 })).toBe("stay")
		expect(react({ holdingFood = true, distance = 8, speed = 14, closing = 12 })).toBe("backoff")
	end,
	["a dog that eats from you lets you closer before backing off"] = function()
		expect(react({ stage = "eats", distance = 7, speed = 14, closing = 12 })).toBe("watch")
		expect(react({ stage = "wary", distance = 7, speed = 14, closing = 12 })).toBe("backoff")
	end,
}
