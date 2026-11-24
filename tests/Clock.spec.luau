local Clock = require("../src/shared/Logic/Clock")
local expect = require("./expect")

local LENGTHS = { Day = 360, Siren = 60, Night = 240 }

return {
	["phases loop day, siren, night"] = function()
		expect(Clock.next("Day")).toBe("Siren")
		expect(Clock.next("Siren")).toBe("Night")
		expect(Clock.next("Night")).toBe("Day")
	end,
	["only night counts as night"] = function()
		expect(Clock.isNight("Night")).toBeTruthy()
		expect(Clock.isNight("Siren")).toBeFalsy()
		expect(Clock.isNight("Day")).toBeFalsy()
	end,
	["short cycle switch picks the short lengths"] = function()
		local short = { Day = 40, Siren = 15, Night = 30 }
		expect(Clock.lengths({ Lengths = LENGTHS, ShortCycle = false, ShortLengths = short })).toBe(LENGTHS)
		expect(Clock.lengths({ Lengths = LENGTHS, ShortCycle = true, ShortLengths = short })).toBe(short)
	end,
	["zero length phase is refused"] = function()
		local bad = { Day = 10, Siren = 0, Night = 10 }
		local ok = pcall(Clock.lengths, { Lengths = bad, ShortCycle = false, ShortLengths = bad })
		expect(ok).toBeFalsy()
	end,
	["starts on day one in daylight"] = function()
		local state = Clock.start(100, LENGTHS)
		expect(state.phase).toBe("Day")
		expect(state.endsAt).toBe(460)
		expect(state.day).toBe(1)
	end,
	["nothing happens before the phase ends"] = function()
		local state, transitions = Clock.advance(Clock.start(0, LENGTHS), 359.9, LENGTHS)
		expect(state.phase).toBe("Day")
		expect(#transitions).toBe(0)
	end,
	["day ends into the siren"] = function()
		local state, transitions = Clock.advance(Clock.start(0, LENGTHS), 360, LENGTHS)
		expect(state.phase).toBe("Siren")
		expect(state.endsAt).toBe(420)
		expect(#transitions).toBe(1)
		expect(transitions[1].from).toBe("Day")
		expect(transitions[1].to).toBe("Siren")
		expect(transitions[1].startedAt).toBe(360)
	end,
	["morning bumps the day counter"] = function()
		local state = { phase = "Night" :: Clock.Phase, endsAt = 660, day = 1 }
		local after, transitions = Clock.advance(state, 661, LENGTHS)
		expect(after.phase).toBe("Day")
		expect(after.day).toBe(2)
		expect(after.endsAt).toBe(1020)
		expect(transitions[1].day).toBe(2)
	end,
	["a long hitch lists every phase crossed in order"] = function()
		local state, transitions = Clock.advance(Clock.start(0, LENGTHS), 700, LENGTHS)
		expect(#transitions).toBe(3)
		expect(transitions[1].to).toBe("Siren")
		expect(transitions[2].to).toBe("Night")
		expect(transitions[3].to).toBe("Day")
		expect(state.phase).toBe("Day")
		expect(state.day).toBe(2)
		expect(state.endsAt).toBe(1020)
	end,
	["time left never goes negative"] = function()
		expect(Clock.timeLeft(100, 40)).toBe(60)
		expect(Clock.timeLeft(100, 140)).toBe(0)
	end,
}
