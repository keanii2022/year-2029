local World = require("../src/shared/Logic/NightTricksWorld")
local expect = require("./expect")

local pa = {
	RightChance = 0.5,
	RecordedAisle = 32,
	AisleVoice = "pa_remain_still",
	AisleLine = "Shopper in aisle %d, please remain still.",
	Lines = { { voice = "pa_closed", text = "Closed." }, { voice = "pa_thank_you", text = "Thanks." } },
}

local function rolls(list: { number }): () -> number
	local index = 0
	return function()
		index += 1
		return list[index]
	end
end

return {
	["nearest sign picks the closest"] = function()
		local signs =
			{ { x = 0, z = 0, number = 1 }, { x = 100, z = 0, number = 2 }, { x = 40, z = 40, number = 3 } }
		expect((World.nearestSign(signs, 90, 5) :: any).number).toBe(2)
		expect((World.nearestSign(signs, 30, 30) :: any).number).toBe(3)
		expect(World.nearestSign({}, 0, 0)).toBe(nil)
	end,
	["the aisle line is always spoken, with the aisle in the subtitle"] = function()
		local recorded = World.aisleLine(32, pa)
		expect(recorded.text).toBe("Shopper in aisle 32, please remain still.")
		expect(recorded.voice).toBe("pa_remain_still")
		local other = World.aisleLine(7, pa)
		expect(other.text).toBe("Shopper in aisle 7, please remain still.")
		expect(other.voice).toBe("pa_remain_still")
	end,
	["sometimes the announcer is right"] = function()
		local line = World.announcement(12, rolls({ 0.1 }), pa)
		expect(line.text).toBe("Shopper in aisle 12, please remain still.")
	end,
	["otherwise it picks a canned line or the recorded aisle"] = function()
		expect(World.announcement(12, rolls({ 0.9, 0 }), pa).voice).toBe("pa_closed")
		expect(World.announcement(nil, rolls({ 0.5 }), pa).voice).toBe("pa_thank_you")
		expect(World.announcement(nil, rolls({ 0.99 }), pa).voice).toBe("pa_remain_still")
	end,
	["reverb follows hiding, rooms, installations and aisles"] = function()
		local reverb =
			{ Aisle = "Hangar", Room = "LivingRoom", Installation = "StoneRoom", Hidden = "PaddedCell" }
		expect(World.reverb(true, true, false, reverb)).toBe("PaddedCell")
		expect(World.reverb(true, false, true, reverb)).toBe("PaddedCell")
		expect(World.reverb(false, true, false, reverb)).toBe("LivingRoom")
		expect(World.reverb(false, false, true, reverb)).toBe("StoneRoom")
		expect(World.reverb(false, false, false, reverb)).toBe("Hangar")
	end,
	["between scales a roll into a range"] = function()
		expect(World.between({ 10, 20 }, 0.5)).toBe(15)
	end,
}
