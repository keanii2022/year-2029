local HauntDirector = require("../src/shared/Logic/HauntDirector")
local expect = require("./expect")

local SETTINGS = {
	ChancePerMinute = 0.5,
	PhaseWeight = { Day = 0.1, Siren = 0.4, Night = 1 },
	MinGap = 60,
	GuaranteeAfter = 100,
	Scares = {
		kid_peek = { weight = 1, cooldown = 600, phases = { Night = true }, nightBudget = 1, visual = true },
		giggle = { weight = 1, cooldown = 100, hiddenOk = true },
	},
}

local function moment(overrides)
	local m = { now = 1000, dt = 2, phase = "Night", alone = true, hidden = false, roll = 0, pick = 0 }
	for key, value in overrides or {} do
		m[key] = value
	end
	return m
end

return {
	["alone means nobody inside the radius"] = function()
		local me = { X = 0, Y = 0, Z = 0 }
		expect(HauntDirector.isAlone(me, { { X = 81, Y = 0, Z = 0 } }, 80)).toBeTruthy()
		expect(HauntDirector.isAlone(me, { { X = 50, Y = 0, Z = 40 } }, 80)).toBeFalsy()
		expect(HauntDirector.isAlone(me, {}, 80)).toBeTruthy()
	end,
	["players with company never get scared and lose their alone timer"] = function()
		local player = HauntDirector.newPlayer()
		player.aloneSince = 0
		local pick =
			HauntDirector.decide(SETTINGS, moment({ alone = false }), player, HauntDirector.newServer())
		expect(pick).toBe(nil)
		expect(player.aloneSince).toBe(nil)
	end,
	["a lucky roll scares, an unlucky one waits"] = function()
		local server = HauntDirector.newServer()
		local player = HauntDirector.newPlayer()
		expect(HauntDirector.decide(SETTINGS, moment({ roll = 0.99 }), player, server)).toBe(nil)
		expect(HauntDirector.decide(SETTINGS, moment({ roll = 0 }), player, server)).toBeTruthy()
	end,
	["night weighs ten times the day"] = function()
		expect(HauntDirector.chance(SETTINGS, "Night", 60)).toBeNear(0.5)
		expect(HauntDirector.chance(SETTINGS, "Day", 60)).toBeNear(0.05)
		expect(HauntDirector.chance(SETTINGS, "Unknown", 60)).toBe(0)
	end,
	["the gap between scares holds even on a lucky roll"] = function()
		local server = HauntDirector.newServer()
		local player = HauntDirector.newPlayer()
		HauntDirector.record(player, server, "giggle", 990)
		expect(HauntDirector.decide(SETTINGS, moment({ now = 1000 }), player, server)).toBe(nil)
	end,
	["the night budget keeps the kid rare across the server"] = function()
		local server = HauntDirector.newServer()
		HauntDirector.record(HauntDirector.newPlayer(), server, "kid_peek", 0)
		local other = HauntDirector.newPlayer()
		expect(HauntDirector.decide(SETTINGS, moment({ pick = 0 }), other, server)).toBe("giggle")
		HauntDirector.newNight(server)
		local fresh = HauntDirector.newPlayer()
		expect(HauntDirector.decide(SETTINGS, moment({ pick = 0.99 }), fresh, server)).toBe("kid_peek")
	end,
	["per player cooldowns stop repeats"] = function()
		local server = HauntDirector.newServer()
		local player = HauntDirector.newPlayer()
		HauntDirector.record(player, server, "giggle", 900)
		HauntDirector.newNight(server)
		-- the giggle at 900 is still cooling down at 970, so only the kid is left
		expect(HauntDirector.decide(SETTINGS, moment({ now = 970, pick = 0 }), player, server)).toBe(
			"kid_peek"
		)
	end,
	["the kid only comes at night"] = function()
		local server = HauntDirector.newServer()
		for _ = 1, 5 do
			local pick = HauntDirector.decide(
				SETTINGS,
				moment({ phase = "Day", pick = 0 }),
				HauntDirector.newPlayer(),
				server
			)
			expect(pick).toBe("giggle")
		end
	end,
	["hidden players only get scares that keep them hidden"] = function()
		local pick = HauntDirector.decide(
			SETTINGS,
			moment({ hidden = true, pick = 0 }),
			HauntDirector.newPlayer(),
			HauntDirector.newServer()
		)
		expect(pick).toBe("giggle")
	end,
	["alone at night long enough forces a visual scare"] = function()
		local server = HauntDirector.newServer()
		local player = HauntDirector.newPlayer()
		expect(HauntDirector.decide(SETTINGS, moment({ now = 0, roll = 0.99 }), player, server)).toBe(nil)
		expect(HauntDirector.decide(SETTINGS, moment({ now = 99, roll = 0.99 }), player, server)).toBe(nil)
		local forced =
			HauntDirector.decide(SETTINGS, moment({ now = 100, roll = 0.99, pick = 0.99 }), player, server)
		expect(forced).toBe("kid_peek")
	end,
	["no guarantee in the day or while hiding"] = function()
		local player = HauntDirector.newPlayer()
		player.aloneSince = 0
		expect(HauntDirector.overdue(SETTINGS, moment({ phase = "Day", now = 500 }), player)).toBeFalsy()
		expect(HauntDirector.overdue(SETTINGS, moment({ hidden = true, now = 500 }), player)).toBeFalsy()
		expect(HauntDirector.overdue(SETTINGS, moment({ now = 500 }), player)).toBeTruthy()
	end,
}
