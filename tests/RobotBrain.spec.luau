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
		expect(brain.state).toBe("investigate")
		expect(brain.focus.x).toBe(9)
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
	["by day only a chase sees outside the room"] = function()
		local brain = RobotBrain.new("chore", "Day", 0)
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeFalsy()
		expect(RobotBrain.seesOutsideRoom(brain, "Night")).toBeTruthy()
		brain.state = "chase"
		expect(RobotBrain.seesOutsideRoom(brain, "Day")).toBeTruthy()
	end,
}
