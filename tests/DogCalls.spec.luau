local DogCalls = require("../src/shared/Logic/DogCalls")
local expect = require("./expect")

local SETTINGS = {
	Gap = { 40, 90 },
	EdgeGapScale = 0.6,
	EdgeSeconds = 60,
	QuietRange = 45,
	Weights = {
		dawn = { Bark = 1, Howl = 3, Whine = 1 },
		day = { Bark = 3, Howl = 1, Whine = 2 },
		dusk = { Bark = 1, Howl = 3, Whine = 1 },
		scared = { Bark = 1, Whine = 3 },
	},
	Bounce = { 15, 40 },
	WallPad = 2,
	Muffle = { Near = 30, Far = 220, HighCut = -40, MidCut = -14 },
}

return {
	["dawn and dusk sit at the edges of the day; siren counts as dusk"] = function()
		expect(DogCalls.mood("Day", 10, 300, 60)).toBe("dawn")
		expect(DogCalls.mood("Day", 200, 160, 60)).toBe("day")
		expect(DogCalls.mood("Day", 320, 40, 60)).toBe("dusk")
		expect(DogCalls.mood("Siren", 5, 40, 60)).toBe("dusk")
		expect(DogCalls.mood("Night", 5, 200, 60)).toBe("night")
	end,
	["calls come every 40-90 seconds, sooner at dawn and dusk"] = function()
		expect(DogCalls.gap("day", false, 0, SETTINGS)).toBe(40)
		expect(DogCalls.gap("day", false, 1, SETTINGS)).toBe(90)
		expect(DogCalls.gap("dusk", false, 1, SETTINGS)).toBe(54)
	end,
	["quiet at night unless scared"] = function()
		expect(DogCalls.gap("night", false, 0.5, SETTINGS)).toBe(nil)
		expect(DogCalls.gap("night", true, 0, SETTINGS)).toBe(40)
	end,
	["no far call while someone is right there"] = function()
		expect(DogCalls.shouldCall(nil, SETTINGS)).toBe(true)
		expect(DogCalls.shouldCall(20, SETTINGS)).toBe(false)
		expect(DogCalls.shouldCall(80, SETTINGS)).toBe(true)
	end,
	["the pick follows the mood's weights"] = function()
		expect(DogCalls.pick("day", false, 0, SETTINGS)).toBe("Bark")
		expect(DogCalls.pick("dawn", false, 0.5, SETTINGS)).toBe("Howl")
		expect(DogCalls.pick("day", true, 0.9, SETTINGS)).toBe("Whine")
		expect(DogCalls.pick("day", true, 0.1, SETTINGS)).toBe("Bark")
	end,
	["the bounce lands 15-40 studs out, short of a wall"] = function()
		expect(DogCalls.bounceDistance(nil, 0, SETTINGS)).toBe(15)
		expect(DogCalls.bounceDistance(nil, 1, SETTINGS)).toBe(40)
		expect(DogCalls.bounceDistance(25, 1, SETTINGS)).toBe(23)
		expect(DogCalls.bounceDistance(10, 1, SETTINGS)).toBe(15)
	end,
	["farther away sounds more muffled"] = function()
		local high, mid = DogCalls.muffle(10, SETTINGS)
		expect(high).toBe(0)
		expect(mid).toBe(0)
		high = DogCalls.muffle(125, SETTINGS)
		expect(high).toBe(-20)
		high, mid = DogCalls.muffle(500, SETTINGS)
		expect(high).toBe(-40)
		expect(mid).toBe(-14)
	end,
	["a sound without an id falls back"] = function()
		local sounds = { Howl = "dog_howl", Whine = "dog_whine", Sneeze = "dog_sneeze" }
		local names = DogCalls.soundNames("Howl", sounds, { Howl = "Whine" })
		expect(#names).toBe(2)
		expect(names[2]).toBe("dog_whine")
		expect(#DogCalls.soundNames("Sneeze", sounds, { Howl = "Whine" })).toBe(1)
	end,
}
