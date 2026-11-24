local HauntLife = require("../src/shared/Logic/HauntLife")
local expect = require("./expect")

local function v(x, y, z)
	return { X = x, Y = y, Z = z }
end

local PIGEONS = { near = 7, sprintNear = 26, sprintSpeed = 18 }
local RATS = { near = 8, beamRange = 60, beamHalfAngle = 22.5 }

local function watcher(position, speed, flashlight, look)
	return { position = position, look = look or v(0, 0, 1), speed = speed, flashlight = flashlight }
end

return {
	["pigeons burst for a sprinter but not a walker at the same distance"] = function()
		local flock = v(0, 0, 20)
		expect(HauntLife.spookedBy(flock, { watcher(v(0, 0, 0), 14, false) }, PIGEONS)).toBe(nil)
		expect(HauntLife.spookedBy(flock, { watcher(v(0, 0, 0), 22, false) }, PIGEONS)).toBe(1)
		expect(HauntLife.spookedBy(flock, { watcher(v(0, 0, 15), 0, false) }, PIGEONS)).toBe(1)
	end,
	["rats scatter when a lit beam points at them"] = function()
		local nest = v(0, 0, 40)
		expect(HauntLife.spookedBy(nest, { watcher(v(0, 0, 0), 0, false) }, RATS)).toBe(nil)
		expect(HauntLife.spookedBy(nest, { watcher(v(0, 0, 0), 0, true) }, RATS)).toBe(1)
		expect(HauntLife.spookedBy(nest, { watcher(v(0, 0, 0), 0, true, v(0, 0, -1)) }, RATS)).toBe(nil)
	end,
	["mannequins move only with someone near and nobody looking"] = function()
		local spot = v(0, 0, 0)
		local away = { { eye = v(0, 0, 20), look = v(0, 0, 1) } }
		local toward = { { eye = v(0, 0, 20), look = v(0, 0, -1) } }
		local far = { { eye = v(0, 0, 500), look = v(0, 0, 1) } }
		expect(HauntLife.mannequinMayMove(spot, away, 70, 120, 90)).toBeTruthy()
		expect(HauntLife.mannequinMayMove(spot, toward, 70, 120, 90)).toBeFalsy()
		expect(HauntLife.mannequinMayMove(spot, far, 70, 120, 90)).toBeFalsy()
		expect(HauntLife.mannequinMayMove(spot, {}, 70, 120, 90)).toBeFalsy()
	end,
	["the next pose is never the current one"] = function()
		local poses = { stand = {}, reach = {}, crouch = {} }
		for _, roll in { 0, 0.4, 0.99 } do
			local pose = HauntLife.nextPose(poses, "reach", roll)
			expect(pose ~= "reach" and poses[pose] ~= nil).toBeTruthy()
		end
		expect(HauntLife.nextPose({ stand = {} }, "stand", 0.5)).toBe("stand")
	end,
	["the greeter gets slower and more broken each night, then bottoms out"] = function()
		local voice =
			{ SpeedDropPerNight = 0.05, MinSpeed = 0.6, DistortionPerNight = 0.12, MaxDistortion = 0.75 }
		local speed1, broken1 = HauntLife.greeterVoice(voice, 1)
		expect(speed1).toBe(1)
		expect(broken1).toBe(0)
		local speed3, broken3 = HauntLife.greeterVoice(voice, 3)
		expect(speed3).toBeNear(0.9)
		expect(broken3).toBeNear(0.24)
		local speed40, broken40 = HauntLife.greeterVoice(voice, 40)
		expect(speed40).toBe(0.6)
		expect(broken40).toBe(0.75)
	end,
	["a critter group stays within its spread"] = function()
		local seed = 1
		local function next()
			seed = (seed * 16807) % 2147483647
			return seed / 2147483647
		end
		local points = HauntLife.scatter(8, 5, next)
		expect(#points).toBe(8)
		for _, point in points do
			expect(math.sqrt(point.x ^ 2 + point.z ^ 2) <= 5 + 1e-9).toBeTruthy()
		end
	end,
}
