local RobotRooms = require("../src/shared/Logic/RobotRooms")
local expect = require("./expect")

local SETTINGS = { ActivationRadius = 100, DeactivationRadius = 150, MaxLiveChoreBots = 2 }
local ROOMS = {
	{ id = 1, cx = 50, cz = 0 },
	{ id = 2, cx = 120, cz = 0 },
	{ id = 3, cx = 0, cz = 80 },
	{ id = 4, cx = 1000, cz = 0 },
}

local function count(set): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

return {
	["only rooms near a player wake up"] = function()
		local active = RobotRooms.active(ROOMS, { { x = 0, z = 0 } }, {}, SETTINGS)
		expect(active[1]).toBe(true)
		expect(active[3]).toBe(true)
		expect(active[2]).toBe(nil)
		expect(active[4]).toBe(nil)
	end,
	["no players, every room sleeps"] = function()
		expect(count(RobotRooms.active(ROOMS, {}, { [1] = true }, SETTINGS))).toBe(0)
	end,
	["an awake room stays awake out to the deactivation radius"] = function()
		local active = RobotRooms.active(ROOMS, { { x = 0, z = 0 } }, { [2] = true }, SETTINGS)
		expect(active[2]).toBe(true)
	end,
	["the cap keeps awake rooms first, then the closest"] = function()
		local active = RobotRooms.active(ROOMS, { { x = 0, z = 0 } }, { [2] = true }, SETTINGS)
		expect(count(active)).toBe(2)
		expect(active[2]).toBe(true)
		expect(active[1]).toBe(true)
	end,
	["destroyed rooms are skipped"] = function()
		local active = RobotRooms.active(ROOMS, { { x = 0, z = 0 } }, {}, SETTINGS, { [1] = 3 })
		expect(active[1]).toBe(nil)
		expect(active[3]).toBe(true)
	end,
	["room kind picks its chore bot"] = function()
		expect(RobotRooms.botFor("kitchen", { kitchen = "cook" }, "cleaner")).toBe("cook")
		expect(RobotRooms.botFor("garage", { kitchen = "cook" }, "cleaner")).toBe("cleaner")
	end,
	["a group of players gets one hunter, a loner gets their own"] = function()
		local players = {
			{ id = "a", x = 0, z = 0 },
			{ id = "b", x = 10, z = 0 },
			{ id = "c", x = 900, z = 0 },
		}
		local need = RobotRooms.needHunters(players, {}, 100, 8)
		expect(#need).toBe(2)
		expect(need[1]).toBe("a")
		expect(need[2]).toBe("c")
	end,
	["hunters already close or the cap stop new ones"] = function()
		local players = { { id = "a", x = 0, z = 0 }, { id = "c", x = 900, z = 0 } }
		expect(#RobotRooms.needHunters(players, { { x = 50, z = 0 } }, 100, 8)).toBe(1)
		expect(#RobotRooms.needHunters(players, { { x = 50, z = 0 } }, 100, 1)).toBe(0)
	end,
}
