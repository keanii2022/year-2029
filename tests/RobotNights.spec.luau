local RobotNights = require("../src/shared/Logic/RobotNights")
local expect = require("./expect")

local NIGHTS = {
	SightStep = 0.04,
	SightMax = 0.24,
	HunterEvery = 2,
	HunterMax = 2,
	SpeedStep = 0.25,
	SpeedMax = 1,
	HardEvery = 10,
	HardHunters = 2,
	LearnLine = "Night %d. They're learning.",
	HardLine = "Night %d. Hard.",
}

return {
	["night one is the base"] = function()
		local threat = RobotNights.threat(1, NIGHTS)
		expect(threat.sight).toBe(1)
		expect(threat.hunters).toBe(1)
		expect(threat.speed).toBe(0)
		expect(threat.hard).toBe(false)
		expect(RobotNights.sirenLine(threat, NIGHTS)).toBe(nil)
	end,
	["each night adds a little"] = function()
		local threat = RobotNights.threat(4, NIGHTS)
		expect(threat.sight).toBeNear(1.12)
		expect(threat.hunters).toBe(2)
		expect(threat.speed).toBeNear(0.75)
		expect(RobotNights.sirenLine(threat, NIGHTS)).toBe("Night 4. They're learning.")
	end,
	["it stops getting harder at the caps"] = function()
		local threat = RobotNights.threat(31, NIGHTS)
		expect(threat.sight).toBeNear(1.24)
		expect(threat.hunters).toBe(3)
		expect(threat.speed).toBe(1)
	end,
	["every tenth night is a hard night with extra hunters"] = function()
		local threat = RobotNights.threat(10, NIGHTS)
		expect(threat.hard).toBe(true)
		expect(threat.hunters).toBe(5)
		expect(RobotNights.sirenLine(threat, NIGHTS)).toBe("Night 10. Hard.")
		expect(RobotNights.threat(11, NIGHTS).hard).toBe(false)
	end,
	["hunters run near a sprint at night, never past it"] = function()
		local scout = { chaseSpeed = 17, nightChaseSpeed = 20 }
		expect(RobotNights.chaseSpeed(scout, false, 1)).toBe(17)
		expect(RobotNights.chaseSpeed(scout, true, 1)).toBe(21)
		expect(RobotNights.chaseSpeed({ chaseSpeed = 15 }, true, 1)).toBe(15)
		expect(RobotNights.chaseSpeed(scout, true, NIGHTS.SpeedMax) < 22).toBeTruthy()
	end,
}
