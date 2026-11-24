local SavesBlueprint = require("../src/shared/Logic/SavesBlueprint")
local expect = require("./expect")

local function known(name)
	return name == "crate" or name == "shelf"
end

local function piece(model, x, z)
	return { model = model, x = x, y = 0, z = z, rx = 0, ry = 90, rz = 0 }
end

return {
	["capture keeps nearby known props, nearest first"] = function()
		local blueprint = SavesBlueprint.capture(
			{ piece("crate", 10, 0), piece("crate", 2, 0), piece("ghost", 1, 0), piece("shelf", 50, 0) },
			30,
			10,
			known
		)
		assert(blueprint, "expected a blueprint")
		expect(#blueprint.pieces).toBe(2)
		expect(blueprint.pieces[1].x).toBe(2)
	end,
	["capture caps the piece count"] = function()
		local list = {}
		for index = 1, 20 do
			table.insert(list, piece("crate", index, 0))
		end
		local blueprint = SavesBlueprint.capture(list, 30, 5, known)
		assert(blueprint, "expected a blueprint")
		expect(#blueprint.pieces).toBe(5)
		expect(blueprint.pieces[5].x).toBe(5)
	end,
	["capture with nothing near is nil"] = function()
		expect(SavesBlueprint.capture({ piece("shelf", 99, 0) }, 30, 5, known)).toBe(nil)
	end,
	["capture rounds and drops broken numbers"] = function()
		local bad = piece("crate", 0 / 0, 0)
		local blueprint = SavesBlueprint.capture({ bad, piece("crate", 1.0333, 0) }, 30, 5, known)
		assert(blueprint, "expected a blueprint")
		expect(#blueprint.pieces).toBe(1)
		expect(blueprint.pieces[1].x).toBeNear(1.05, 1e-9)
	end,
	["sanitize trims to max pieces and rejects junk"] = function()
		expect(SavesBlueprint.sanitize("nope", 5, known)).toBe(nil)
		expect(SavesBlueprint.sanitize({ pieces = { "x" } }, 5, known)).toBe(nil)
		local list = {}
		for index = 1, 8 do
			table.insert(list, piece("crate", index, 0))
		end
		local blueprint = SavesBlueprint.sanitize({ pieces = list }, 5, known)
		assert(blueprint, "expected a blueprint")
		expect(#blueprint.pieces).toBe(5)
	end,
	["yaw snaps to quarter turns"] = function()
		expect(SavesBlueprint.snapYaw(44)).toBe(0)
		expect(SavesBlueprint.snapYaw(46)).toBe(90)
		expect(SavesBlueprint.snapYaw(-91)).toBe(270)
	end,
	["lay out is daytime only"] = function()
		local ok, reason = SavesBlueprint.canLayOut(nil, { job = "a", day = 1, at = 0 }, "Night", 600)
		expect(ok).toBe(false)
		expect(reason).toBe("day only")
		expect(SavesBlueprint.canLayOut(nil, { job = "a", day = 1, at = 0 }, "Day", 600)).toBe(true)
	end,
	["same server needs a new day"] = function()
		local last = { job = "a", day = 2, at = 0 }
		expect(SavesBlueprint.canLayOut(last, { job = "a", day = 2, at = 9999 }, "Day", 600)).toBe(false)
		expect(SavesBlueprint.canLayOut(last, { job = "a", day = 3, at = 10 }, "Day", 600)).toBe(true)
	end,
	["another server needs a full cycle of real time"] = function()
		local last = { job = "a", day = 5, at = 1000 }
		expect(SavesBlueprint.canLayOut(last, { job = "b", day = 9, at = 1300 }, "Day", 600)).toBe(false)
		expect(SavesBlueprint.canLayOut(last, { job = "b", day = 1, at = 1600 }, "Day", 600)).toBe(true)
	end,
	["a dropped prop snaps to the nearest empty matching slot"] = function()
		local slots = {
			{ model = "crate", x = 0, y = 0, z = 0, filled = false },
			{ model = "crate", x = 2, y = 0, z = 0, filled = false },
			{ model = "shelf", x = 1.5, y = 0, z = 0, filled = false },
		}
		expect(SavesBlueprint.matchSlot(slots, "crate", 1.6, 0, 0, 3)).toBe(2)
		slots[2].filled = true
		expect(SavesBlueprint.matchSlot(slots, "crate", 1.6, 0, 0, 3)).toBe(1)
		expect(SavesBlueprint.matchSlot(slots, "crate", 9, 0, 0, 3)).toBe(nil)
		expect(SavesBlueprint.remaining(slots)).toBe(2)
	end,
}
