local Scores = require("../src/shared/Logic/Scores")
local expect = require("./expect")

local defs = {
	{ key = "NightsSurvived", label = "Nights survived" },
	{ key = "LongestLife", label = "Longest life", minutes = true },
}

local cosmetics = {
	Hat = { { id = "Cap", label = "Cap", unlock = { stat = "NightsSurvived", at = 2 } } },
	Colour = {
		{ id = "Grey", label = "Grey" },
		{ id = "Red", label = "Red", unlock = { stat = "NightsSurvived", at = 5 } },
	},
}

return {
	["add only takes known stats and whole positive amounts"] = function()
		local stats = {}
		expect(Scores.add(stats, defs, "NightsSurvived", 1)).toBe(1)
		expect(Scores.add(stats, defs, "NightsSurvived", 2.9)).toBe(3)
		expect(Scores.add(stats, defs, "NightsSurvived", -5)).toBe(nil)
		expect(Scores.add(stats, defs, "NightsSurvived", 0 / 0)).toBe(nil)
		expect(Scores.add(stats, defs, "Made up", 1)).toBe(nil)
		expect(stats.NightsSurvived).toBe(3)
	end,
	["longest life only goes up"] = function()
		local stats = { LongestLife = 100 }
		expect(Scores.recordLife(stats, 50)).toBe(false)
		expect(Scores.recordLife(stats, 250.5)).toBe(true)
		expect(stats.LongestLife).toBe(250)
	end,
	["a night counts only for a life that started before it"] = function()
		expect(Scores.survivedNight(10, 20)).toBe(true)
		expect(Scores.survivedNight(30, 20)).toBe(false)
		expect(Scores.survivedNight(10, nil)).toBe(false)
		expect(Scores.survivedNight(nil, 20)).toBe(false)
	end,
	["equipping needs the unlock"] = function()
		expect(Scores.canEquip(cosmetics, "Hat", "Cap", { NightsSurvived = 1 })).toBe(false)
		expect(Scores.canEquip(cosmetics, "Hat", "Cap", { NightsSurvived = 2 })).toBe(true)
		expect(Scores.canEquip(cosmetics, "Hat", nil, {})).toBe(true)
		expect(Scores.canEquip(cosmetics, "Shoes", nil, {})).toBe(false)
		expect(Scores.canEquip(cosmetics, "Hat", "Crown", { NightsSurvived = 99 })).toBe(false)
	end,
	["wearing falls back to free options and drops relocked picks"] = function()
		local worn = Scores.wearing(cosmetics, { Hat = "Cap", Colour = "Red" }, { NightsSurvived = 2 })
		expect(worn.Hat).toBe("Cap")
		expect(worn.Colour).toBe(nil)
		local fresh = Scores.wearing(cosmetics, {}, {})
		expect(fresh.Colour).toBe("Grey")
		expect(fresh.Hat).toBe(nil)
	end,
	["new unlocks are reported once"] = function()
		local labels = Scores.newUnlocks(cosmetics, { NightsSurvived = 1 }, { NightsSurvived = 5 })
		expect(#labels).toBe(2)
		expect(labels[1]).toBe("Cap")
		expect(#Scores.newUnlocks(cosmetics, { NightsSurvived = 5 }, { NightsSurvived = 6 })).toBe(0)
	end,
	["unlock hints read like progress"] = function()
		expect(Scores.unlockHint({ stat = "NightsSurvived", at = 5 }, defs, { NightsSurvived = 3 })).toBe(
			"Nights survived 3/5"
		)
		expect(Scores.unlockHint({ stat = "LongestLife", at = 1200 }, defs, { LongestLife = 5000 })).toBe(
			"Longest life 20 min/20 min"
		)
	end,
	["raise only keeps the best"] = function()
		local stats = { BestHaul = 5 }
		local haulDefs = { { key = "BestHaul", label = "Best haul" } }
		expect(Scores.raise(stats, haulDefs, "BestHaul", 3)).toBe(false)
		expect(Scores.raise(stats, haulDefs, "BestHaul", 8.6)).toBe(true)
		expect(stats.BestHaul).toBe(8)
		expect(Scores.raise(stats, haulDefs, "Nope", 99)).toBe(false)
		expect(Scores.raise(stats, haulDefs, "BestHaul", 0 / 0)).toBe(false)
	end,
	["weeks start on Monday UTC"] = function()
		local day = 86400
		expect(Scores.weekOf(0)).toBe(0) -- Thursday 1 Jan 1970
		expect(Scores.weekOf(4 * day - 1)).toBe(0) -- Sunday night
		expect(Scores.weekOf(4 * day)).toBe(1) -- Monday
		expect(Scores.weekOf(11 * day - 1)).toBe(1)
		expect(Scores.weekOf(11 * day)).toBe(2)
	end,
	["the weekly record resets with the week"] = function()
		local weekly = { week = 10, nights = 4 }
		expect(Scores.recordWeekLife(weekly, 10, 3)).toBe(false)
		expect(Scores.recordWeekLife(weekly, 10, 5)).toBe(true)
		expect(Scores.weekValue(weekly, 10)).toBe(5)
		expect(Scores.weekValue(weekly, 11)).toBe(0)
		expect(Scores.recordWeekLife(weekly, 11, 1)).toBe(true)
		expect(weekly.week).toBe(11)
		expect(weekly.nights).toBe(1)
	end,
	["weekly boards put the week in the store key"] = function()
		expect(Scores.boardKey("LongestLifeWeek", true, 2970)).toBe("LongestLifeWeek_W2970")
		expect(Scores.boardKey("BestHaul", false, 2970)).toBe("BestHaul")
	end,
}
