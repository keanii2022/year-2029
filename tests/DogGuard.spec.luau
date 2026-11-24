local DogGuard = require("../src/shared/Logic/DogGuard")
local expect = require("./expect")

local SPOT = { x = 0, z = 0 }

return {
	["strangers are anyone but the owner"] = function()
		expect(DogGuard.isStranger(2, 1)).toBeTruthy()
		expect(DogGuard.isStranger(1, 1)).toBeFalsy()
		expect(DogGuard.isStranger(nil, 1)).toBeFalsy()
	end,
	["only a stranger inside the radius sets it off"] = function()
		expect(DogGuard.isOffence(2, 1, SPOT, { x = 5, z = 5 }, 14)).toBeTruthy()
		expect(DogGuard.isOffence(1, 1, SPOT, { x = 5, z = 5 }, 14)).toBeFalsy()
		expect(DogGuard.isOffence(2, 1, SPOT, { x = 20, z = 0 }, 14)).toBeFalsy()
	end,
	["it protects the spot, the owner or itself"] = function()
		local owner, dog = { x = 10, z = 0 }, { x = 3, z = 3 }
		expect(DogGuard.protectPoint("guard", SPOT, owner, dog)).toBe(SPOT)
		expect(DogGuard.protectPoint("follow", SPOT, owner, dog)).toBe(owner)
		expect(DogGuard.protectPoint("follow", SPOT, nil, dog)).toBe(dog)
		expect(DogGuard.protectPoint("stay", SPOT, owner, dog)).toBe(dog)
	end,
	["raiders are remembered for a while"] = function()
		local memory = {}
		DogGuard.remember(memory, 7, 20)
		expect(DogGuard.remembers(memory, 7, 10)).toBeTruthy()
		expect(DogGuard.remembers(memory, 7, 25)).toBeFalsy()
		DogGuard.forget(memory, 25)
		expect(memory[7]).toBe(nil)
	end,
	["picks the nearest threat"] = function()
		local id, distance = DogGuard.nearest({ { id = "a", distance = 9 }, { id = "b", distance = 4 } })
		expect(id).toBe("b")
		expect(distance).toBe(4)
		expect((DogGuard.nearest({}))).toBe(nil)
	end,
}
