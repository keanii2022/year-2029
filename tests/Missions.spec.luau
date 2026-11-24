local Missions = require("../src/shared/Logic/Missions")
local config = require("../src/shared/Config/Missions")
local expect = require("./expect")

-- Repeats a fixed list of rolls so picks are predictable
local function rolls(values: { number }): () -> number
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

local places = {
	{ kind = "poolroom", depth = 0.2 },
	{ kind = "dead_mall", depth = 0.8 },
}

local function facts(overrides: { [string]: any }): Missions.Facts
	local base = {
		count = function()
			return 0
		end,
		place = nil,
		depth = 0,
		hidden = false,
		hauling = false,
	}
	for key, value in overrides do
		(base :: any)[key] = value
	end
	return base :: any
end

local function mission(kind: string, fields: { [string]: any }?): Missions.Mission
	local m: any = { kind = kind, text = kind, reward = { item = "Bandage", count = 1 }, done = false }
	for key, value in fields or {} do
		m[key] = value
	end
	return m
end

return {
	["pick gives PerDay missions with no repeated kind"] = function()
		for seed = 1, 40 do
			local list = Missions.pick(
				config,
				{ places = places, canSurvive = true },
				rolls({ (seed * 0.137) % 1, 0.5, 0.9, 0.01 })
			)
			expect(#list).toBe(config.PerDay)
			local seen = {}
			for _, m in list do
				expect(seen[m.kind]).toBe(nil)
				seen[m.kind] = true
				expect(string.find(m.text, "{", 1, true)).toBe(nil)
				expect(m.reward.count > 0).toBe(true)
			end
		end
	end,
	["pick skips visit with no installations and survive when it can't be survived"] = function()
		for seed = 1, 40 do
			local list = Missions.pick(
				config,
				{ places = {}, canSurvive = false },
				rolls({ (seed * 0.311) % 1, 0.2, 0.7 })
			)
			for _, m in list do
				expect(m.kind ~= "visit" and m.kind ~= "survive").toBe(true)
			end
		end
	end,
	["visit prefers far installations"] = function()
		for _, r in { 0, 0.5, 0.99 } do
			expect((Missions.pickPlace(config, places, rolls({ r })) :: any).kind).toBe("dead_mall")
		end
		local near = { { kind = "poolroom", depth = 0.1 } }
		expect((Missions.pickPlace(config, near, rolls({ 0.5 })) :: any).kind).toBe("poolroom")
		expect(Missions.pickPlace(config, {}, rolls({ 0.5 }))).toBe(nil)
	end,
	["visit text uses the place's display name"] = function()
		local list = Missions.pick(
			config,
			{ places = { { kind = "poolroom", depth = 0.9 } }, canSurvive = true },
			rolls({ 0.5 })
		)
		for _, m in list do
			if m.kind == "visit" then
				expect(string.find(m.text, "Pool Halls", 1, true) ~= nil).toBe(true)
			end
		end
	end,
	["rare reward comes from a low roll"] = function()
		expect(Missions.pickReward(config, rolls({ 0 })).item).toBe(config.RareReward.item)
		expect(Missions.pickReward(config, rolls({ 0.99 })).item ~= config.RareReward.item).toBe(true)
	end,
	["find needs a new one, not one already held"] = function()
		local m = mission("find", { item = "RationPack" })
		local held = 1
		local f = facts({
			count = function()
				return held
			end,
		})
		expect(Missions.check(m, f, 2)).toBe(false)
		expect(Missions.check(m, f, 2)).toBe(false)
		held = 0
		expect(Missions.check(m, f, 2)).toBe(false)
		held = 1
		expect(Missions.check(m, f, 2)).toBe(true)
		expect(Missions.check(m, f, 2)).toBe(false)
		expect(m.done).toBe(true)
	end,
	["visit and deep finish in the right spot"] = function()
		local visit = mission("visit", { place = "poolroom" })
		expect(Missions.check(visit, facts({ place = "dead_mall" }), 2)).toBe(false)
		expect(Missions.check(visit, facts({ place = "poolroom" }), 2)).toBe(true)
		local deep = mission("deep", { depth = 0.8 })
		expect(Missions.check(deep, facts({ depth = 0.5 }), 2)).toBe(false)
		expect(Missions.check(deep, facts({ depth = 0.85 }), 2)).toBe(true)
	end,
	["hide needs seconds in a row"] = function()
		local m = mission("hide", { seconds = 4 })
		expect(Missions.check(m, facts({ hidden = true }), 2)).toBe(false)
		expect(Missions.check(m, facts({ hidden = false }), 2)).toBe(false)
		expect(Missions.check(m, facts({ hidden = true }), 2)).toBe(false)
		expect(Missions.check(m, facts({ hidden = true }), 2)).toBe(true)
	end,
	["haul finishes while carrying"] = function()
		local m = mission("haul")
		expect(Missions.check(m, facts({}), 2)).toBe(false)
		expect(Missions.check(m, facts({ hauling = true }), 2)).toBe(true)
	end,
	["survive only finishes at dawn for survivors"] = function()
		local list = { mission("survive"), mission("haul") }
		expect(Missions.check(list[1], facts({ hauling = true, hidden = true, depth = 1 }), 2)).toBe(false)
		expect(#Missions.dawn(list, false)).toBe(0)
		local finished = Missions.dawn(list, true)
		expect(#finished).toBe(1)
		expect(finished[1].kind).toBe("survive")
		expect(#Missions.dawn(list, true)).toBe(0)
		expect(Missions.allDone(list)).toBe(false)
		list[2].done = true
		expect(Missions.allDone(list)).toBe(true)
		expect(Missions.allDone({})).toBe(false)
	end,
	["snapshot carries text, done and reward line"] = function()
		local rows =
			Missions.snapshot(config, { mission("haul", { reward = { item = "BlasterCells", count = 12 } }) })
		expect(rows[1].text).toBe("haul")
		expect(rows[1].done).toBe(false)
		expect(rows[1].reward).toBe("+12 Blaster Cells")
	end,
}
