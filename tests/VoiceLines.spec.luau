local VoiceLines = require("../src/shared/Logic/VoiceLines")
local expect = require("./expect")

local CUES = {
	{ distance = 28, sound = "ghost_kid_near_1" },
	{ distance = 18, sound = "ghost_kid_near_2" },
	{ distance = 7, sound = "ghost_kid_close" },
}
local LINES = {
	Notice = "robot_notice",
	Resume = "robot_resume",
	Error = "robot_error",
	ErrorStates = { "stalled", "disabled" },
	CalmStates = { "study", "errand", "return" },
	ChatterStates = { "study", "errand", "return", "sweep", "investigate" },
}

return {
	["callouts step both ways and wrap round"] = function()
		expect(VoiceLines.stepCallout(0, 1, 7)).toBe(1)
		expect(VoiceLines.stepCallout(6, 1, 7)).toBe(0)
		expect(VoiceLines.stepCallout(0, -1, 7)).toBe(6)
	end,
	["the stick picks the callout it points at on the wheel"] = function()
		expect(VoiceLines.calloutAt(0, 1, 7, 0.5)).toBe(0)
		expect(VoiceLines.calloutAt(1, 0.2, 7, 0.5)).toBe(2)
		expect(VoiceLines.calloutAt(-0.1, -1, 7, 0.5)).toBe(4)
		expect(VoiceLines.calloutAt(-1, 0.4, 7, 0.5)).toBe(6)
		expect(VoiceLines.calloutAt(0.2, 0.2, 7, 0.5)).toBe(nil)
	end,
	["only whole callout numbers in range are accepted"] = function()
		expect(VoiceLines.validCallout(0, 7)).toBe(true)
		expect(VoiceLines.validCallout(6, 7)).toBe(true)
		expect(VoiceLines.validCallout(7, 7)).toBe(false)
		expect(VoiceLines.validCallout(-1, 7)).toBe(false)
		expect(VoiceLines.validCallout(1.5, 7)).toBe(false)
		expect(VoiceLines.validCallout("1", 7)).toBe(false)
	end,
	["kid lines play in order as the player walks closer"] = function()
		expect(VoiceLines.kidCue(CUES, 35, 0)).toBe(nil)
		expect(VoiceLines.kidCue(CUES, 27, 0)).toBe(1)
		expect(VoiceLines.kidCue(CUES, 27, 1)).toBe(nil)
		expect(VoiceLines.kidCue(CUES, 17, 1)).toBe(2)
		expect(VoiceLines.kidCue(CUES, 6, 2)).toBe(3)
		expect(VoiceLines.kidCue(CUES, 3, 3)).toBe(nil)
	end,
	["running straight at the kid skips to the closest line"] = function()
		expect(VoiceLines.kidCue(CUES, 6, 0)).toBe(3)
		expect(VoiceLines.kidCue(CUES, 15, 0)).toBe(2)
	end,
	["robots notice, go back to work and error out loud"] = function()
		expect(VoiceLines.robotStateLine("study", "suspicious", LINES)).toBe("robot_notice")
		expect(VoiceLines.robotStateLine("errand", "suspicious", LINES)).toBe("robot_notice")
		expect(VoiceLines.robotStateLine("suspicious", "study", LINES)).toBe("robot_resume")
		expect(VoiceLines.robotStateLine("suspicious", "return", LINES)).toBe("robot_resume")
		expect(VoiceLines.robotStateLine("chase", "stalled", LINES)).toBe("robot_error")
		expect(VoiceLines.robotStateLine("stalled", "disabled", LINES)).toBe(nil)
		expect(VoiceLines.robotStateLine("chase", "return", LINES)).toBe(nil)
		expect(VoiceLines.robotStateLine("suspicious", "chase", LINES)).toBe(nil)
		expect(VoiceLines.robotStateLine("sweep", "chase", LINES)).toBe("robot_notice")
		expect(VoiceLines.robotStateLine("investigate", "chase", LINES)).toBe("robot_notice")
		expect(VoiceLines.robotStateLine("study", "chase", LINES)).toBe("robot_notice")
		expect(VoiceLines.robotStateLine("chase", "chase", LINES)).toBe(nil)
		expect(VoiceLines.robotStateLine(nil, "study", LINES)).toBe(nil)
	end,
	["calm and patrolling robots chatter, chasing ones don't"] = function()
		expect(VoiceLines.chatters("study", LINES)).toBe(true)
		expect(VoiceLines.chatters("sweep", LINES)).toBe(true)
		expect(VoiceLines.chatters("chase", LINES)).toBe(false)
		expect(VoiceLines.chatters("disabled", LINES)).toBe(false)
		expect(VoiceLines.chatters(nil, LINES)).toBe(false)
	end,
}
