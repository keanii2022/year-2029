local Interact = require("../src/shared/Logic/Interact")
local expect = require("./expect")

local function use(overrides: { [string]: any })
	local check = { alive = true, carrying = false, distance = 3, reach = 9, cooling = false }
	for key, value in overrides do
		check[key] = value
	end
	return Interact.canUse(check :: any)
end

local function behaviour(kind: string): any
	return { kind = kind, loudness = "normal" }
end

return {
	["canUse allows a free hand in reach"] = function()
		expect(use({})).toBeTruthy()
	end,
	["canUse refuses dead, carrying, far and spam"] = function()
		local _, reason = use({ alive = false })
		expect(reason).toBe("dead")
		_, reason = use({ carrying = true })
		expect(reason).toBe("hands full")
		_, reason = use({ distance = 9.5 })
		expect(reason).toBe("too far")
		_, reason = use({ cooling = true })
		expect(reason).toBe("busy")
	end,
	["distanceToBox is 0 inside and measures to the nearest face or corner"] = function()
		expect(Interact.distanceToBox(0.5, 0, 0, 1, 1, 1)).toBe(0)
		expect(Interact.distanceToBox(4, 0, 0, 1, 1, 1)).toBe(3)
		expect(Interact.distanceToBox(4, 5, 0, 1, 1, 1)).toBe(5)
	end,
	["resolve picks byPart, one drawer, or the whole object"] = function()
		local desk: any = {
			kind = "open",
			parts = { "Drawer1", "Drawer2" },
			each = true,
			loudness = "normal",
			byPart = { Screen = behaviour("press") },
		}
		local sub, key, parts = Interact.resolve(desk, "Screen")
		expect(sub.kind).toBe("press")
		expect(key).toBe("Screen")
		expect(#parts).toBe(0)
		sub, key, parts = Interact.resolve(desk, "Drawer2")
		expect(sub).toBe(desk)
		expect(key).toBe("Drawer2")
		expect(parts[1]).toBe("Drawer2")
		expect(#parts).toBe(1)
		_, key, parts = Interact.resolve(desk, "Body")
		expect(key).toBe("")
		expect(#parts).toBe(2)
		_, key = Interact.resolve(desk, nil)
		expect(key).toBe("")
	end,
	["stateAttribute names the slot"] = function()
		expect(Interact.stateAttribute("")).toBe("On")
		expect(Interact.stateAttribute("Tap")).toBe("On_Tap")
	end,
	["verb follows the kind and state"] = function()
		expect(Interact.verb(behaviour("open"), false, false)).toBe("Open")
		expect(Interact.verb(behaviour("open"), true, false)).toBe("Close")
		expect(Interact.verb(behaviour("toggle"), true, false)).toBe("Turn off")
		expect(Interact.verb(behaviour("hide"), false, false)).toBe("Hide")
		expect(Interact.verb(behaviour("phone"), true, false)).toBe("Answer")
		expect(Interact.verb(behaviour("open"), false, true)).toBe("Get out")
	end,
	["nextChannel runs through and turns off, or loops without an off"] = function()
		expect(Interact.nextChannel(0, 3, true)).toBe(1)
		expect(Interact.nextChannel(2, 3, true)).toBe(3)
		expect(Interact.nextChannel(3, 3, true)).toBe(0)
		expect(Interact.nextChannel(3, 3, false)).toBe(1)
		expect(Interact.nextChannel(0, 0, true)).toBe(0)
	end,
	["hideAction enters an empty spot, leaves your own, reveals someone else"] = function()
		expect(Interact.hideAction(nil, "a")).toBe("enter")
		expect(Interact.hideAction("a", "a")).toBe("leave")
		expect(Interact.hideAction("b", "a")).toBe("reveal")
	end,
	["cushionFind pays out within the range only under the chance"] = function()
		expect(Interact.cushionFind(0.5, 0.5, 0.35, 2, 6)).toBe(0)
		expect(Interact.cushionFind(0.1, 0, 0.35, 2, 6)).toBe(2)
		expect(Interact.cushionFind(0.1, 0.999, 0.35, 2, 6)).toBe(6)
	end,
	["spinT wraps a full turn and bobT drifts 0 to 1 and back"] = function()
		expect(Interact.spinT(0.5, 1)).toBeNear(0.5)
		expect(Interact.spinT(2.25, 1)).toBeNear(0.25)
		expect(Interact.bobT(0, 6)).toBeNear(0)
		expect(Interact.bobT(3, 6)).toBeNear(1)
		expect(Interact.bobT(6, 6)).toBeNear(0)
	end,
	["pick stays inside the list"] = function()
		local list = { "a", "b", "c" }
		expect(Interact.pick(list, 0)).toBe("a")
		expect(Interact.pick(list, 0.999)).toBe("c")
		expect(Interact.pick({}, 0.5)).toBe(nil)
	end,
}
