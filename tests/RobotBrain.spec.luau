local RobotBrain = require("../src/shared/Logic/RobotBrain")
local expect = require("./expect")

local SETTINGS = {
	Sense = {
		NoticeSeconds = 1.2,
		NightNoticeSeconds = 0.35,
		AlertDecay = 0.6,
		SuspiciousSeconds = 4,
		LoseSeconds = 4,
		InvestigateSeconds = 5,
	},
	CatchRange = 4,
	DayLeash = 120,
	ArriveRange = 3,
	PickupRange = 5,
	Chores = { GiveUpSeconds = 30 },
	Hunt = { NightLoseSeconds = 7, Searches = 2 },
}

local function input(overrides: { [string]: any }?)
	local base = {
		phase = "Day",
		dt = 0.2,
		atHome = true,
		homeDistance = 0,
		carrying = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function seenAt(distance: number)
	return { id = "p1", x = 0, z = distance, distance = distance, range = 34 }
end

-- Runs ticks of dt until the brain leaves `state` or maxTicks pass; returns the last intent and time.
local function runWhile(brain, state, makeInput, now, maxTicks)
	local intent
	for _ = 1, maxTicks do
		now += 0.2
		intent = RobotBrain.update(brain, makeInput(), SETTINGS, now)
		if brain.state ~= state then
			break
		end
	end
	return intent, now
end

local function errand(chore: string?)
	return { x = 50, z = 0, face = { x = 50, z = 3 }, chore = chore or "carry", workSeconds = 10 }
end

local function sentOut(chore: string?)
	local brain = RobotBrain.new("chore", "Day", 0)
	expect(RobotBrain.sendOnErrand(brain, errand(chore), "Day", 1)).toBeTruthy()
	return brain
end

return {
	["a chore bot studies quietly when nothing is around"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		local intent = RobotBrain.update(brain, input(), SETTINGS, 0.2)
		expect(brain.state).toBe("study")
		expect(intent.goal).toBe("study")
	end,
	["a glimpse makes it suspicious before it charges"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		RobotBrain.update(brain, input({ seen = seenAt(30) }), SETTINGS, 0.2)
		expect(brain.state).toBe("suspicious")
		local _, now = runWhile(brain, "suspicious", function()
			return input({ seen = seenAt(30) })
		end, 0.2, 20)
		expect(brain.state).toBe("chase")
		expect(now > 0.8).toBeTruthy()
	end,
	["stepping out of view lets it calm down and go back to studying"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		RobotBrain.update(brain, input({ seen = seenAt(30) }), SETTINGS, 0.2)
		local intent = runWhile(brain, "suspicious", function()
			return input()
		end, 0.2, 40)
		expect(brain.state).toBe("study")
		expect(intent.goal).toBe("study")
	end,
	["a noise in the room makes it look that way"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		local intent = RobotBrain.update(brain, input({ heard = { x = 5, z = 6 } }), SETTINGS, 0.2)
		expect(brain.state).toBe("suspicious")
		expect(intent.face.x).toBe(5)
		expect(intent.goal).toBe(nil)
	end,
	["a day catch takes the item and walks home"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		brain.state = "chase"
		brain.lastSeenAt = 0
		local intent = RobotBrain.update(brain, input({ seen = seenAt(2), atHome = false }), SETTINGS, 0.2)
		expect(intent.catch).toBe("p1")
		expect(brain.state).toBe("return")
	end,
	["a day chase gives up after losing you for a few seconds"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		brain.state = "chase"
		brain.lastSeenAt = 0
		local intent = RobotBrain.update(brain, input({ atHome = false }), SETTINGS, 3)
		expect(brain.state).toBe("chase")
		expect(intent.speed).toBe("chase")
		intent = RobotBrain.update(brain, input({ atHome = false }), SETTINGS, 4.5)
		expect(brain.state).toBe("return")
		expect(intent.goal).toBe("home")
	end,
	["a day chase is leashed to home"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		brain.state = "chase"
		brain.lastSeenAt = 0
		RobotBrain.update(
			brain,
			input({ seen = seenAt(20), atHome = false, homeDistance = 200 }),
			SETTINGS,
			0.2
		)
		expect(brain.state).toBe("return")
	end,
	["hunters stall by day and wake at the siren"] = function()
		local brain = RobotBrain.new("hunter", "Day", 0)
		local intent = RobotBrain.update(brain, input({ seen = seenAt(2) }), SETTINGS, 0.2)
		expect(brain.state).toBe("stalled")
		expect(intent.pose).toBe("stall")
		expect(intent.catch).toBe(nil)
		intent = RobotBrain.update(brain, input({ phase = "Siren" }), SETTINGS, 0.4)
		expect(intent.pose).toBe("wake")
		RobotBrain.update(brain, input({ phase = "Night" }), SETTINGS, 0.6)
		expect(brain.state).toBe("sweep")
	end,
	["at night it sweeps, then goes to check a sound"] = function()
		local brain = RobotBrain.new("chore", "Night", 0)
		local intent = RobotBrain.update(brain, input({ phase = "Night" }), SETTINGS, 0.2)
		expect(intent.goal).toBe("wander")
		intent = RobotBrain.update(
			brain,
			input({ phase = "Night", heard = { x = 40, z = 0 }, focusDistance = 40 }),
			SETTINGS,
			0.4
		)
		expect(brain.state).toBe("investigate")
		expect(intent.goal).toBe("focus")
	end,
	["arriving at a sound it pokes the hiding spots once, then sweeps on"] = function()
		local brain = RobotBrain.new("hunter", "Night", 0)
		brain.state = "investigate"
		brain.focus = { x = 0, z = 0 }
		local intent = RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 1)
		expect(intent.reveal).toBe(true)
		intent = RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 2)
		expect(intent.reveal).toBe(nil)
		RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 6.5)
		expect(brain.state).toBe("sweep")
	end,
	["at night it notices fast and a catch takes you down"] = function()
		local brain = RobotBrain.new("hunter", "Night", 0)
		local _, now = runWhile(brain, "sweep", function()
			return input({ phase = "Night", seen = seenAt(20) })
		end, 0, 10)
		expect(brain.state).toBe("chase")
		expect(now <= 0.6).toBeTruthy()
		local intent =
			RobotBrain.update(brain, input({ phase = "Night", seen = seenAt(3) }), SETTINGS, now + 0.2)
		expect(intent.catch).toBe("p1")
		expect(brain.state).toBe("sweep")
	end,
	["losing you at night means searching where you were"] = function()
		local brain = RobotBrain.new("hunter", "Night", 0)
		brain.state = "chase"
		brain.lastSeenAt = 0
		brain.focus = { x = 9, z = 9 }
		RobotBrain.update(brain, input({ phase = "Night", focusDistance = 30 }), SETTINGS, 5)
		expect(brain.state).toBe("chase") -- a night chase holds on longer than a day one
		local intent = RobotBrain.update(brain, input({ phase = "Night", focusDistance = 30 }), SETTINGS, 8)
		expect(brain.state).toBe("investigate")
		expect(brain.focus.x).toBe(9)
		expect(intent.speed).toBe("chase")
		expect(brain.searchesLeft).toBe(2)
	end,
	["after scanning the last sighting it asks for more spots, then gives up"] = function()
		local brain = RobotBrain.new("hunter", "Night", 0)
		brain.state = "investigate"
		brain.focus = { x = 0, z = 0 }
		brain.searchesLeft = 1
		RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 1)
		local intent = RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 6.5)
		expect(intent.search).toBe(true)
		expect(brain.state).toBe("investigate")
		expect(brain.searchesLeft).toBe(0)
		RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 7)
		RobotBrain.update(brain, input({ phase = "Night", focusDistance = 1 }), SETTINGS, 12.5)
		expect(brain.state).toBe("sweep")
		expect(brain.rushing).toBe(false)
	end,
	["a sweeping robot answers a call at a run; a hauling one doesn't"] = function()
		local brain = RobotBrain.new("hunter", "Night", 0)
		expect(RobotBrain.answerCall(brain, { x = 30, z = 4 }, 2, 1)).toBe(true)
		expect(brain.state).toBe("investigate")
		local intent = RobotBrain.update(brain, input({ phase = "Night", focusDistance = 30 }), SETTINGS, 1.2)
		expect(intent.speed).toBe("chase")
		expect(intent.goal).toBe("focus")
		local hauling = RobotBrain.new("chore", "Night", 0)
		hauling.state = "carry"
		expect(RobotBrain.answerCall(hauling, { x = 30, z = 4 }, 2, 1)).toBe(false)
	end,
	["a prowler hunts by day with day eyes"] = function()
		local brain = RobotBrain.new("prowler", "Day", 0)
		expect(brain.state).toBe("sweep")
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBe(true)
		local intent = RobotBrain.update(brain, input(), SETTINGS, 0.2)
		expect(intent.goal).toBe("wander")
		local _, now = runWhile(brain, "sweep", function()
			return input({ seen = seenAt(20) })
		end, 0, 20)
		expect(brain.state).toBe("chase")
		expect(now > 0.6).toBeTruthy() -- slower to notice than at night
		RobotBrain.disable(brain, now + 1)
		RobotBrain.update(brain, input(), SETTINGS, now + 0.5)
		RobotBrain.update(brain, input(), SETTINGS, now + 1.5)
		expect(brain.state).toBe("sweep")
	end,
	["it picks up loose stuff and hauls it home"] = function()
		local brain = RobotBrain.new("chore", "Night", 0)
		local loose = { id = "crate", distance = 20 }
		local intent = RobotBrain.update(brain, input({ phase = "Night", loose = loose }), SETTINGS, 0.2)
		expect(intent.goal).toBe("loose")
		intent = RobotBrain.update(
			brain,
			input({ phase = "Night", loose = { id = "crate", distance = 2 } }),
			SETTINGS,
			0.4
		)
		expect(intent.pickup).toBe("crate")
		expect(brain.state).toBe("carry")
		intent = RobotBrain.update(
			brain,
			input({ phase = "Night", carrying = true, atHome = false }),
			SETTINGS,
			0.6
		)
		expect(intent.goal).toBe("home")
		intent = RobotBrain.update(
			brain,
			input({ phase = "Night", carrying = true, atHome = true }),
			SETTINGS,
			0.8
		)
		expect(intent.drop).toBe(true)
		expect(brain.state).toBe("sweep")
	end,
	["spotting a player while hauling drops the load and chases"] = function()
		local brain = RobotBrain.new("chore", "Night", 0)
		brain.state = "carry"
		brain.alert = 0.99
		local intent = RobotBrain.update(
			brain,
			input({ phase = "Night", carrying = true, seen = seenAt(20) }),
			SETTINGS,
			0.2
		)
		expect(brain.state).toBe("chase")
		expect(intent.drop).toBe(true)
	end,
	["lights on sends chore bots home, still carrying their haul"] = function()
		local brain = RobotBrain.new("chore", "Night", 0)
		RobotBrain.phaseChanged(brain, "Day", 1)
		expect(brain.state).toBe("return")
		brain.state = "carry"
		RobotBrain.phaseChanged(brain, "Day", 2)
		expect(brain.state).toBe("carry")
		RobotBrain.phaseChanged(brain, "Night", 3)
		expect(brain.state).toBe("carry")
	end,
	["an EMP shuts it down until it wears off"] = function()
		local brain = RobotBrain.new("chore", "Night", 0)
		RobotBrain.disable(brain, 8)
		local intent = RobotBrain.update(brain, input({ phase = "Night", seen = seenAt(1) }), SETTINGS, 1)
		expect(brain.state).toBe("disabled")
		expect(intent.catch).toBe(nil)
		expect(intent.goal).toBe(nil)
		RobotBrain.update(brain, input({ phase = "Night" }), SETTINGS, 8.2)
		expect(brain.state).toBe("sweep")
	end,
	["getting shot sends it straight after the shooter"] = function()
		local brain = RobotBrain.new("hunter", "Night", 0)
		RobotBrain.provoke(brain, seenAt(30), 1)
		expect(brain.state).toBe("chase")
		expect(brain.targetId).toBe("p1")
		local down = RobotBrain.new("hunter", "Night", 0)
		RobotBrain.disable(down, 10)
		RobotBrain.provoke(down, seenAt(30), 1)
		expect(down.state == "chase").toBeFalsy()
	end,
	["by day only a chase sees outside the room"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeFalsy()
		expect(RobotBrain.seesOutsideRoom(brain, "Night")).toBeTruthy()
		brain.state = "chase"
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeTruthy()
	end,
	["a calm chore bot walks out on an errand carrying a box"] = function()
		local brain = sentOut("carry")
		local intent = RobotBrain.update(
			brain,
			input({ atHome = false, homeDistance = 10, errandDistance = 40 }),
			SETTINGS,
			1.2
		)
		expect(brain.state).toBe("errand")
		expect(intent.goal).toBe("errand")
		expect(intent.speed).toBe("walk")
		expect(intent.pose).toBe("carry")
	end,
	["at the spot it works, then walks home"] = function()
		local brain = sentOut("sweep")
		local at = input({ atHome = false, homeDistance = 50, errandDistance = 1 })
		local intent = RobotBrain.update(brain, at, SETTINGS, 2)
		expect(intent.pose).toBe("sweep")
		expect(intent.goal).toBe(nil)
		expect(intent.face.z).toBe(3)
		intent = RobotBrain.update(brain, at, SETTINGS, 11)
		expect(intent.pose).toBe("sweep")
		intent = RobotBrain.update(brain, at, SETTINGS, 12.5)
		expect(brain.state).toBe("return")
		expect(intent.goal).toBe("home")
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeTruthy()
		RobotBrain.update(brain, input(), SETTINGS, 20)
		expect(brain.state).toBe("study")
		expect(brain.errand).toBe(nil)
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeFalsy()
	end,
	["only a calm chore bot by day takes an errand"] = function()
		local hunter = RobotBrain.new("hunter", "Day", 0)
		expect(RobotBrain.sendOnErrand(hunter, errand(), "Day", 1)).toBeFalsy()
		local brain = RobotBrain.new("chore", "Day", 0)
		expect(RobotBrain.sendOnErrand(brain, errand(), "Siren", 1)).toBeFalsy()
		expect(RobotBrain.sendOnErrand(brain, errand(), "Night", 1)).toBeFalsy()
		brain.state = "chase"
		expect(RobotBrain.sendOnErrand(brain, errand(), "Day", 1)).toBeFalsy()
		local stunned = RobotBrain.new("chore", "Day", 0)
		RobotBrain.disable(stunned, 5)
		expect(RobotBrain.sendOnErrand(stunned, errand(), "Day", 1)).toBeFalsy()
	end,
	["out on an errand it sees players outside its room and still charges"] = function()
		local brain = sentOut()
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeTruthy()
		local out = function()
			return input({ atHome = false, homeDistance = 30, errandDistance = 20, seen = seenAt(10) })
		end
		runWhile(brain, "errand", out, 1, 5)
		expect(brain.state).toBe("suspicious")
		runWhile(brain, "suspicious", out, 2, 20)
		expect(brain.state).toBe("chase")
	end,
	["an errand it can't reach gives up and heads home"] = function()
		local brain = sentOut()
		local far = input({ atHome = false, homeDistance = 5, errandDistance = 40 })
		RobotBrain.update(brain, far, SETTINGS, 20)
		expect(brain.state).toBe("errand")
		local intent = RobotBrain.update(brain, far, SETTINGS, 32)
		expect(brain.state).toBe("return")
		expect(intent.goal).toBe("home")
	end,
	["the siren sends errand bots home and night turns them into sweepers"] = function()
		local brain = sentOut()
		RobotBrain.phaseChanged(brain, "Siren", 5)
		expect(brain.state).toBe("return")
		local other = sentOut()
		local intent = RobotBrain.update(
			other,
			input({ phase = "Siren", atHome = false, homeDistance = 30, errandDistance = 20 }),
			SETTINGS,
			5
		)
		expect(other.state).toBe("return")
		expect(intent.goal).toBe("home")
		RobotBrain.phaseChanged(other, "Night", 6)
		expect(other.state).toBe("sweep")
		expect(other.errand).toBe(nil)
	end,
}
