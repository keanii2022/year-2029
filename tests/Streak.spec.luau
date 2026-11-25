local Streak = require("../src/shared/Logic/Streak")
local expect = require("./expect")

local texts = { Live = "STREAK {days}", Paused = "STREAK {days} PAUSED" }

return {
	["day numbers roll over at UTC midnight"] = function()
		expect(Streak.dayOf(0)).toBe(0)
		expect(Streak.dayOf(86399)).toBe(0)
		expect(Streak.dayOf(86400)).toBe(1)
	end,
	["a day only counts once"] = function()
		local state = { days = 0, lastDay = 0 }
		expect(Streak.complete(state, 100)).toBe(true)
		expect(Streak.complete(state, 100)).toBe(false)
		expect(state.days).toBe(1)
		expect(Streak.complete(state, 101)).toBe(true)
		expect(state.days).toBe(2)
	end,
	["a missed day pauses instead of wiping"] = function()
		local state = { days = 0, lastDay = 0 }
		Streak.complete(state, 100)
		Streak.complete(state, 101)
		expect(Streak.status(state, 105)).toBe("paused")
		expect(Streak.complete(state, 105)).toBe(true)
		expect(state.days).toBe(3)
		expect(Streak.status(state, 105)).toBe("done")
		expect(Streak.status(state, 106)).toBe("live")
	end,
	["an older day never counts again"] = function()
		local state = { days = 5, lastDay = 200 }
		expect(Streak.complete(state, 150)).toBe(false)
		expect(state.days).toBe(5)
	end,
	["rewards fire once as the count passes their day"] = function()
		local rewards = { { day = 3, tokens = 30 }, { day = 7, tokens = 0 } }
		expect(#Streak.rewardsReached(rewards, 1, 2)).toBe(0)
		expect(Streak.rewardsReached(rewards, 2, 3)[1].day).toBe(3)
		expect(#Streak.rewardsReached(rewards, 3, 4)).toBe(0)
		expect(#Streak.rewardsReached(rewards, 0, 9)).toBe(2)
	end,
	["label shows live, paused or nothing"] = function()
		expect(Streak.label(texts, { days = 0, lastDay = 0 }, 10)).toBe("")
		expect(Streak.label(texts, { days = 4, lastDay = 9 }, 10)).toBe("STREAK 4")
		expect(Streak.label(texts, { days = 4, lastDay = 10 }, 10)).toBe("STREAK 4")
		expect(Streak.label(texts, { days = 4, lastDay = 7 }, 10)).toBe("STREAK 4 PAUSED")
	end,
}
