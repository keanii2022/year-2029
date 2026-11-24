local RobotSenses = require("../src/shared/Logic/RobotSenses")
local expect = require("./expect")

local SENSE = {
	SightAngle = 110,
	NightSightFactor = 1.2,
	CrouchSightFactor = 0.5,
	SprintSightFactor = 1.2,
	FeelRadius = 4,
	FootstepRadius = { Walk = 12, Sprint = 30, Crouch = 0 },
	BeamRange = 60,
	BeamAngle = 12,
}

-- robot at the origin looking down +z
local EYE = { x = 0, z = 0, fx = 0, fz = 1, range = 34 }

return {
	["sees a player in front, inside range and in the room"] = function()
		expect(RobotSenses.canSee(EYE, { x = 0, z = 20, sameRoom = true }, SENSE, false, true)).toBeTruthy()
		expect(RobotSenses.canSee(EYE, { x = 0, z = 40, sameRoom = true }, SENSE, false, true)).toBeFalsy()
	end,
	["by day sight stays in its room"] = function()
		expect(RobotSenses.canSee(EYE, { x = 0, z = 20, sameRoom = false }, SENSE, false, true)).toBeFalsy()
		expect(RobotSenses.canSee(EYE, { x = 0, z = 20, sameRoom = false }, SENSE, false, false)).toBeTruthy()
	end,
	["can't see behind it, but feels you right next to it"] = function()
		expect(RobotSenses.canSee(EYE, { x = 0, z = -10, sameRoom = true }, SENSE, false, true)).toBeFalsy()
		expect(RobotSenses.canSee(EYE, { x = 0, z = -3, sameRoom = true }, SENSE, false, true)).toBeTruthy()
	end,
	["the cone edge is half the sight angle"] = function()
		local inside = { x = math.sin(math.rad(50)) * 20, z = math.cos(math.rad(50)) * 20, sameRoom = true }
		local outside = { x = math.sin(math.rad(60)) * 20, z = math.cos(math.rad(60)) * 20, sameRoom = true }
		expect(RobotSenses.canSee(EYE, inside, SENSE, false, true)).toBeTruthy()
		expect(RobotSenses.canSee(EYE, outside, SENSE, false, true)).toBeFalsy()
	end,
	["crouching halves the range, sprinting stretches it"] = function()
		local at25 = { x = 0, z = 25, sameRoom = true, stance = "Crouch" }
		expect(RobotSenses.canSee(EYE, at25, SENSE, false, true)).toBeFalsy()
		at25.stance = "Walk"
		expect(RobotSenses.canSee(EYE, at25, SENSE, false, true)).toBeTruthy()
		local sprinter = { x = 0, z = 38, stance = "Sprint", sameRoom = true }
		expect(RobotSenses.canSee(EYE, sprinter, SENSE, false, true)).toBeTruthy()
	end,
	["hidden players are invisible even up close"] = function()
		local hider = { x = 0, z = 2, hidden = true, sameRoom = true }
		expect(RobotSenses.canSee(EYE, hider, SENSE, true, false)).toBeFalsy()
	end,
	["night sight reaches further"] = function()
		expect(RobotSenses.canSee(EYE, { x = 0, z = 38 }, SENSE, true, false)).toBeTruthy()
		expect(RobotSenses.canSee(EYE, { x = 0, z = 38 }, SENSE, false, false)).toBeFalsy()
	end,
	["footsteps: sprint is loud, crouch is silent"] = function()
		expect(RobotSenses.hearsSteps(0, 0, { x = 25, z = 0, stance = "Sprint" }, SENSE, false)).toBeTruthy()
		expect(RobotSenses.hearsSteps(0, 0, { x = 25, z = 0, stance = "Walk" }, SENSE, false)).toBeFalsy()
		expect(RobotSenses.hearsSteps(0, 0, { x = 1, z = 0, stance = "Crouch" }, SENSE, false)).toBeFalsy()
		local outside = { x = 5, z = 0, stance = "Walk", sameRoom = false }
		expect(RobotSenses.hearsSteps(0, 0, outside, SENSE, true)).toBeFalsy()
	end,
	["a flashlight pointed at a robot gives you away"] = function()
		expect(RobotSenses.beamHits(0, 0, 1, 0, 40, 2, SENSE)).toBeTruthy()
		expect(RobotSenses.beamHits(0, 0, 1, 0, 40, 20, SENSE)).toBeFalsy()
		expect(RobotSenses.beamHits(0, 0, 1, 0, 80, 0, SENSE)).toBeFalsy()
	end,
	["notice builds faster up close"] = function()
		expect(RobotSenses.noticeRate(30, 30, 1)).toBeNear(1)
		expect(RobotSenses.noticeRate(0, 30, 1)).toBeNear(3)
	end,
	["nearest and loudest pick the right one"] = function()
		local best, d = RobotSenses.nearest(0, 0, { { id = "a", x = 10, z = 0 }, { id = "b", x = 3, z = 4 } })
		expect(best.id).toBe("b")
		expect(d).toBeNear(5)
		local loud = RobotSenses.loudest({
			{ rank = 2, time = 1 },
			{ rank = 3, time = 0 },
			{ rank = 3, time = 2, tag = "newest" },
		})
		expect(loud.tag).toBe("newest")
		expect(RobotSenses.loudest({})).toBe(nil)
	end,
}
