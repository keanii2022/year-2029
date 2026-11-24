local LifeSchedule = require("../src/shared/Logic/LifeSchedule")
local expect = require("./expect")

local function rolls(list)
	local n = 0
	return function()
		n += 1
		return list[(n - 1) % #list + 1]
	end
end

local EVENTS = {
	box = { weight = 3, phases = { Day = true, Night = true } },
	cart = { weight = 1, phases = { Day = true } },
}

return {
	["gap stretches with a lower rate and stops at zero"] = function()
		local range = { Min = 10, Max = 20 }
		expect(LifeSchedule.gap(range, 1, rolls({ 0.5 }))).toBeNear(15)
		expect(LifeSchedule.gap(range, 0.5, rolls({ 0.5 }))).toBeNear(30)
		expect(LifeSchedule.gap(range, 0, rolls({ 0.5 }))).toBe(nil)
		expect(LifeSchedule.gap(range, nil, rolls({ 0.5 }))).toBe(nil)
	end,
	["pick follows weight and phase"] = function()
		expect(LifeSchedule.pick(EVENTS, "Day", rolls({ 0.1 }))).toBe("box")
		expect(LifeSchedule.pick(EVENTS, "Day", rolls({ 0.9 }))).toBe("cart")
		expect(LifeSchedule.pick(EVENTS, "Night", rolls({ 0.9 }))).toBe("box")
		expect(LifeSchedule.pick(EVENTS, "Siren", rolls({ 0.5 }))).toBe(nil)
	end,
	["bag gives every line once before repeating, never twice in a row"] = function()
		local bag = LifeSchedule.newBag()
		local roll = rolls({ 0.7, 0.2, 0.95, 0.4, 0.05 })
		local last
		for _ = 1, 10 do
			local seen = {}
			for _ = 1, 4 do
				local index = LifeSchedule.draw(bag, 4, roll)
				expect(seen[index]).toBe(nil)
				expect(index == last).toBeFalsy()
				seen[index] = true
				last = index
			end
		end
	end,
	["flicker alternates dark and lit and ends lit"] = function()
		local settings = { Blinks = { 2, 5 }, Short = { 0.05, 0.25 }, Dark = { 0.6, 2.5 } }
		for _, r in { 0, 0.3, 0.6, 0.99 } do
			local pattern = LifeSchedule.flicker(settings, rolls({ r, 0.2, 0.8 }))
			expect(#pattern >= 4 and #pattern <= 10).toBeTruthy()
			for n, blink in pattern do
				expect(blink.lit).toBe(n % 2 == 0)
				expect(blink.seconds > 0 and blink.seconds <= 2.5).toBeTruthy()
			end
			expect(pattern[#pattern].lit).toBe(true)
		end
	end,
	["room tone is quiet in a tight aisle and loud in the open"] = function()
		local settings = { Min = 0.1, Max = 0.5, Near = 10, Far = 90 }
		expect(LifeSchedule.roomTone({ 3, 5, 8, 4 }, settings)).toBeNear(0.1)
		expect(LifeSchedule.roomTone({ 120, 200, 90, 95 }, settings)).toBeNear(0.5)
		expect(LifeSchedule.roomTone({ 50, 50 }, settings)).toBeNear(0.3)
		expect(LifeSchedule.roomTone({}, settings)).toBeNear(0.1)
	end,
}
