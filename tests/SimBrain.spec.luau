local SimBrain = require("../src/shared/Logic/SimBrain")
local expect = require("./expect")

local DAY = { wander = 1, loot = 1, sneak = 1, drag = 1, group = 1 }
local SETTINGS = {
	Moods = {
		calm = { aggro = 0, fightBack = 0.3, avoid = 1, freeze = 0, day = DAY },
		normal = { aggro = 0.2, fightBack = 0.8, avoid = 0.3, freeze = 0.2, day = DAY },
		chaos = { aggro = 1, fightBack = 1, avoid = 0, freeze = 0, day = DAY },
	},
	FleeRange = 40,
	FightRange = 90,
	AvoidRange = 30,
	ActionTime = {},
}

local function rolls(...: number): () -> number
	local list = { ... }
	local index = 0
	return function()
		index = index % #list + 1
		return list[index]
	end
end

local function input(overrides: { [string]: any }): SimBrain.Input
	local base: { [string]: any } = { phase = "Day", mood = "normal", ammo = 30, targetSeen = false }
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

return {
	["it runs from a robot at night"] = function()
		local brain = SimBrain.new()
		local seen = input({ phase = "Night", robot = { id = "bot", distance = 20, chasing = false } })
		expect(SimBrain.decide(brain, seen, SETTINGS, 0, rolls(0.9))).toBe("flee")
		expect(brain.target).toBe("bot")
	end,
	["sometimes it panics and freezes instead"] = function()
		local brain = SimBrain.new()
		local seen = input({ phase = "Night", robot = { id = "bot", distance = 20, chasing = false } })
		expect(SimBrain.decide(brain, seen, SETTINGS, 0, rolls(0.1))).toBe("freeze")
	end,
	["by day it only runs from a robot that is chasing it"] = function()
		local brain = SimBrain.new()
		local calm = input({ robot = { id = "bot", distance = 10, chasing = false } })
		expect(SimBrain.decide(brain, calm, SETTINGS, 0, rolls(0.9))).toBe("group")
		brain = SimBrain.new()
		local chased = input({ robot = { id = "bot", distance = 10, chasing = true } })
		expect(SimBrain.decide(brain, chased, SETTINGS, 0, rolls(0.9))).toBe("flee")
	end,
	["chaos picks a fight with anyone in range"] = function()
		local brain = SimBrain.new()
		local seen = input({ mood = "chaos", enemy = { id = "p1", distance = 50 } })
		expect(SimBrain.decide(brain, seen, SETTINGS, 0, rolls(0.5))).toBe("fight")
		expect(brain.target).toBe("p1")
	end,
	["calm backs away from people close by"] = function()
		local brain = SimBrain.new()
		local seen = input({ mood = "calm", enemy = { id = "p1", distance = 10 } })
		expect(SimBrain.decide(brain, seen, SETTINGS, 0, rolls(0.5))).toBe("avoid")
	end,
	["no ammo means no fights"] = function()
		local brain = SimBrain.new()
		local seen = input({ mood = "chaos", ammo = 0, enemy = { id = "p1", distance = 50 } })
		expect(SimBrain.decide(brain, seen, SETTINGS, 0, rolls(0.5)) ~= "fight").toBeTruthy()
	end,
	["getting shot is answered once, right away"] = function()
		local brain = SimBrain.new()
		SimBrain.decide(brain, input({}), SETTINGS, 0, rolls(0.1))
		local hit = input({ attacker = { id = "p2", distance = 30, at = 1 }, targetSeen = true })
		expect(SimBrain.decide(brain, hit, SETTINGS, 1, rolls(0.5))).toBe("fight")
		expect(brain.target).toBe("p2")
		-- same hit again: it keeps fighting rather than rolling again
		expect(SimBrain.decide(brain, hit, SETTINGS, 1.5, rolls(0.99))).toBe("fight")
	end,
	["a calm bot that gets shot mostly backs off"] = function()
		local brain = SimBrain.new()
		local hit = input({ mood = "calm", attacker = { id = "p2", distance = 30, at = 1 } })
		expect(SimBrain.decide(brain, hit, SETTINGS, 1, rolls(0.9))).toBe("avoid")
	end,
	["a fight ends when the target is out of sight"] = function()
		local brain = SimBrain.new()
		local seen = input({ mood = "chaos", enemy = { id = "p1", distance = 50 }, targetSeen = true })
		SimBrain.decide(brain, seen, SETTINGS, 0, rolls(0.5))
		local lost = input({ mood = "chaos", targetSeen = false })
		expect(SimBrain.decide(brain, lost, SETTINGS, 0.5, rolls(0.5)) ~= "fight").toBeTruthy()
	end,
	["the siren sends everyone to hide"] = function()
		local brain = SimBrain.new()
		SimBrain.decide(brain, input({}), SETTINGS, 0, rolls(0.1))
		expect(SimBrain.decide(brain, input({ phase = "Siren" }), SETTINGS, 1, rolls(0.5))).toBe("hide")
	end,
	["it sticks with an action until its time is up"] = function()
		local brain = SimBrain.new()
		expect(SimBrain.decide(brain, input({}), SETTINGS, 0, rolls(0.1))).toBe("wander")
		expect(SimBrain.decide(brain, input({}), SETTINGS, 1, rolls(0.9))).toBe("wander")
		expect(SimBrain.decide(brain, input({}), SETTINGS, 100, rolls(0.9))).toBe("group")
	end,
	["a lobby bot starts mid-action and keeps at it"] = function()
		local brain = SimBrain.new()
		expect(SimBrain.start(brain, "drag", "Day", SETTINGS, 0, rolls(0.5))).toBe("drag")
		expect(SimBrain.decide(brain, input({}), SETTINGS, 1, rolls(0.1))).toBe("drag")
	end,
	["day actions follow the mood weights"] = function()
		local weights = { wander = 0, loot = 3, sneak = 0, drag = 1, group = 0 }
		expect(SimBrain.pickWeighted(weights, 0)).toBe("loot")
		expect(SimBrain.pickWeighted(weights, 0.74)).toBe("loot")
		expect(SimBrain.pickWeighted(weights, 0.76)).toBe("drag")
		expect(SimBrain.pickWeighted({}, 0.5)).toBe("wander")
	end,
	["gamer names come out of the word lists"] = function()
		local words = { Adjectives = { "Neon" }, Nouns = { "Pickle" } }
		expect(SimBrain.gamerName(words, rolls(0, 0, 0, 0.042))).toBe("NeonPickle42")
		expect(SimBrain.gamerName(words, rolls(0, 0, 0.3, 0))).toBe("neon_pickle")
		expect(SimBrain.gamerName(words, rolls(0, 0, 0.5, 0))).toBe("xXPickleXx")
		expect(#SimBrain.gamerName(words, rolls(0.99, 0.99, 0.99, 0.99)) <= 20).toBeTruthy()
	end,
	["bots go for events by mood and distance, never mid-fight"] = function()
		local eager = { lure = 1 }
		local brain = SimBrain.new()
		expect(SimBrain.answersLure(brain, eager, 1, 100, 900, 0.5)).toBeTruthy()
		expect(SimBrain.answersLure(brain, eager, 1, 1000, 900, 0)).toBeFalsy()
		expect(SimBrain.answersLure(brain, { lure = 0 }, 1, 10, 900, 0.01)).toBeFalsy()
		-- far away pulls less than close by
		expect(SimBrain.answersLure(brain, { lure = 0.5 }, 1, 50, 900, 0.45)).toBeTruthy()
		expect(SimBrain.answersLure(brain, { lure = 0.5 }, 1, 850, 900, 0.45)).toBeFalsy()
		brain.action = "fight"
		expect(SimBrain.answersLure(brain, eager, 1, 10, 900, 0)).toBeFalsy()
	end,
	["a lured bot keeps chasing until a robot or a hit changes its mind"] = function()
		local brain = SimBrain.new()
		brain.phase = "Day" -- it was already up and about when the PA went
		local spot = { 1, 2 }
		local settings = table.clone(SETTINGS)
		settings.ActionTime = { chase = { 30, 30 } }
		expect(SimBrain.lure(brain, spot, settings, 0, rolls(0.5))).toBe("chase")
		expect(brain.target).toBe(spot)
		expect(SimBrain.decide(brain, input({}), settings, 10, rolls(0.9))).toBe("chase")
		local robot = input({ robot = { id = "bot", distance = 20, chasing = true } })
		expect(SimBrain.decide(brain, robot, settings, 11, rolls(0.9))).toBe("flee")
	end,
	["a bot with an unfinished fort goes back to building by day"] = function()
		local settings = table.clone(SETTINGS) :: any
		settings.BuildFocus = 0.8
		local brain = SimBrain.new()
		expect(SimBrain.decide(brain, input({ building = true }), settings, 0, rolls(0.5))).toBe("drag")
		local night = SimBrain.new()
		expect(SimBrain.decide(night, input({ phase = "Night", building = true }), settings, 0, rolls(0.5))).toBe(
			"hide"
		)
	end,
	["it rolls once per raider to defend its fort"] = function()
		local settings = table.clone(SETTINGS) :: any
		settings.Moods = { normal = table.clone(SETTINGS.Moods.normal) }
		settings.Moods.normal.defend = 0.5
		local brain = SimBrain.new()
		local raided = input({ phase = "Night", raider = { id = "raider", distance = 6 } })
		expect(SimBrain.decide(brain, raided, settings, 0, rolls(0.9))).toBe("hide")
		-- same raider, still hiding: no second roll even if it would land
		expect(SimBrain.decide(brain, raided, settings, 1, rolls(0.1))).toBe("hide")
		local other = SimBrain.new()
		expect(SimBrain.decide(other, raided, settings, 0, rolls(0.1))).toBe("fight")
		expect(other.target).toBe("raider")
	end,
}
