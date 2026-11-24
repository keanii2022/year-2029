local Manifest = require("../src/shared/Logic/Manifest")
local ManifestData = require("../src/shared/Logic/ManifestData")
local expect = require("./expect")

local index = Manifest.index(ManifestData :: any)
local LIMITS = { HingeOpenDegrees = 100, SlideOpenFraction = 0.8, MoverDegrees = 30 }

return {
	["every model has a root part and a real size"] = function()
		local count = 0
		for _, entry in ManifestData.models do
			count += 1
			expect(#entry.parts > 0).toBeTruthy()
			expect(Manifest.rootPart(Manifest.partNames(entry)) ~= nil).toBeTruthy()
			for axis = 1, 3 do
				expect(entry.size[axis] >= 0).toBeTruthy()
			end
			expect(math.max(entry.size[1], entry.size[2], entry.size[3]) > 0.1).toBeTruthy()
		end
		expect(count).toBe(276)
	end,
	["index groups models by art folder in name order"] = function()
		expect(index.models.fridge.group).toBe("furniture")
		local previous = ""
		for _, group in index.groups do
			expect(group.name > previous).toBeTruthy()
			previous = group.name
		end
	end,
	["sounds and images resolve only once uploaded"] = function()
		local fake = Manifest.index({
			models = {},
			sounds = { { name = "bite", assetId = 123 }, { name = "chew" } },
			images = { { name = "static", assetId = 9 } },
		})
		expect(Manifest.soundId(fake, "bite")).toBe("rbxassetid://123")
		expect(Manifest.soundId(fake, "chew")).toBe(nil)
		expect(Manifest.soundId(fake, "missing")).toBe(nil)
		expect(Manifest.imageId(fake, "static")).toBe("rbxassetid://9")
	end,
	["root is Body, then a gun Handle, then a robot Torso"] = function()
		expect(Manifest.rootPart({ "Door", "Body", "Glow" })).toBe("Body")
		expect(Manifest.rootPart({ "Glow", "Handle", "Mag" })).toBe("Handle")
		expect(Manifest.rootPart({ "Head", "Torso" })).toBe("Torso")
	end,
	["robot limbs chain to the part above them"] = function()
		local names =
			{ "Torso", "Head", "Extra", "UpperArm", "Forearm", "LeftUpperArm", "LeftForearm", "LeftHand" }
		expect(Manifest.parentPart("Forearm", names, "Torso")).toBe("UpperArm")
		expect(Manifest.parentPart("LeftForearm", names, "Torso")).toBe("LeftUpperArm")
		expect(Manifest.parentPart("LeftHand", names, "Torso")).toBe("LeftForearm")
		expect(Manifest.parentPart("LeftUpperArm", names, "Torso")).toBe("Torso")
		expect(Manifest.parentPart("Extra", names, "Torso")).toBe("Head")
		expect(Manifest.parentPart("Door", { "Body", "Door" }, "Body")).toBe("Body")
	end,
	["part names map to motions, numbers ignored"] = function()
		expect(Manifest.motion("fridge", "Door2").kind).toBe("hinge")
		expect(Manifest.motion("dresser", "Drawer3").kind).toBe("slide")
		expect(Manifest.motion("wall_clock", "Spin2").kind).toBe("spin")
		expect(Manifest.motion("rat", "Leg4").kind).toBe("joint")
		expect(Manifest.motion("brute", "LeftShin").kind).toBe("joint")
		expect(Manifest.motion("fridge", "Body")).toBe(nil)
		expect(Manifest.motion("fridge", "Glow")).toBe(nil)
		expect(Manifest.motion("crt_tv", "Screen")).toBe(nil)
		expect(Manifest.motion("brute", "Torso")).toBe(nil)
	end,
	["per-model overrides change the axis only"] = function()
		local overrides = { entrance_gate = { Slide = "Y" } }
		expect(Manifest.motion("shower_door", "Slide", overrides).axis).toBe("X")
		local gate = Manifest.motion("entrance_gate", "Slide", overrides)
		expect(gate.axis).toBe("Y")
		expect(gate.kind).toBe("slide")
	end,
	["screens and glow are recognised"] = function()
		expect(Manifest.isScreen("Screen2")).toBeTruthy()
		expect(Manifest.isScreen("ScreenFrame")).toBeFalsy()
		expect(Manifest.isGlow("Glow")).toBeTruthy()
	end,
	["doors swing toward the front, lids lift, bottom flaps drop forward"] = function()
		-- door to the right of its hinge: a negative turn about y carries +x toward +z
		expect(Manifest.turnSign("Y", { 1, 0, 0 }, { 0, 0, 0 })).toBe(-1)
		expect(Manifest.turnSign("Y", { -1, 0, 0 }, { 0, 0, 0 })).toBe(1)
		-- lid reaching forward from a back hinge lifts with a negative turn about x
		expect(Manifest.turnSign("X", { 0, 0, 1 }, { 0, 0, 0 })).toBe(-1)
		-- oven door standing up from a bottom hinge drops forward with a positive turn
		expect(Manifest.turnSign("X", { 0, 1, 0 }, { 0, 0, 0 })).toBe(1)
	end,
	["pose turns hinges by the open angle and slides by part length"] = function()
		local door = { name = "Door", center = { -1, 0, 0 }, size = { 2, 4, 0.2 }, pivot = { 0, 0, 0 } }
		local degrees, studs = Manifest.pose({ kind = "hinge", axis = "Y" }, 1, door, LIMITS)
		expect(degrees).toBe(100)
		expect(studs).toBe(0)
		local drawer = { name = "Drawer1", center = { 0, 0, 0 }, size = { 2, 1, 1.5 }, pivot = { 0, 0, 0 } }
		degrees, studs = Manifest.pose({ kind = "slide", axis = "Z" }, 0.5, drawer, LIMITS)
		expect(degrees).toBe(0)
		expect(studs).toBeNear(0.6)
		degrees = Manifest.pose({ kind = "spin", axis = "Y" }, 0.25, drawer, LIMITS)
		expect(degrees).toBe(90)
	end,
	["the fridge door hinge sits on the fridge's side"] = function()
		local door = Manifest.part(index.models.fridge, "Door")
		expect(door ~= nil).toBeTruthy()
		local body = Manifest.part(index.models.fridge, "Body") :: any
		expect(math.abs((door :: any).pivot[1]) >= body.size[1] / 2 - 0.1).toBeTruthy()
	end,
}
