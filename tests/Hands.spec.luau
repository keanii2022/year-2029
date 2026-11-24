local Hands = require("../src/shared/Logic/Hands")
local expect = require("./expect")

local function pose(x: number, y: number, z: number, pitch: number?): Hands.Pose
	return { x = x, y = y, z = z, pitch = pitch or 0, yaw = 0, roll = 0 }
end

local SETTINGS: Hands.Settings = {
	Rest = pose(0, -2, -1),
	Poses = {
		Eat = { right = pose(0, -0.5, -1) },
		Drink = { right = pose(0.1, -0.5, -1) },
		Heal = { right = pose(0.3, -0.7, -1.2), left = pose(-0.1, -0.8, -1.2) },
		Open = { right = pose(0.3, -0.7, -1.2), left = pose(-0.3, -0.7, -1.2) },
	},
	RaiseTime = 0.2,
	LowerTime = 0.2,
	BiteInterval = 0.5,
	BiteLength = 0.2,
	BitePush = pose(0, 0.2, 0.3, 10),
	ChewBob = 0.02,
	ChewSpeed = 20,
	DrinkTilt = 70,
	DrinkLift = 0.15,
	SipBob = 0.01,
	WrapTurns = 2,
	WrapRadius = 0.2,
	OpenPull = 0.15,
	OpenTwist = 20,
	ReachTime = 0.4,
}

return {
	["raise goes up, holds, then comes back down to rest"] = function()
		expect(Hands.raise(-1, 2, 0.2, 0.2)).toBe(0)
		expect(Hands.raise(0, 2, 0.2, 0.2)).toBe(0)
		expect(Hands.raise(0.1, 2, 0.2, 0.2)).toBeNear(0.5)
		expect(Hands.raise(1, 2, 0.2, 0.2)).toBe(1)
		expect(Hands.raise(2.1, 2, 0.2, 0.2)).toBeNear(0.5)
		expect(Hands.raise(2.5, 2, 0.2, 0.2)).toBe(0)
		expect(Hands.finished(2.1, 2, 0.2)).toBe(false)
		expect(Hands.finished(2.2, 2, 0.2)).toBe(true)
	end,

	["pulse bumps at the start of each interval only"] = function()
		expect(Hands.pulse(0.1, 0.2, 0.5, 0.2)).toBe(0)
		expect(Hands.pulse(0.3, 0.2, 0.5, 0.2)).toBeNear(1)
		expect(Hands.pulse(0.5, 0.2, 0.5, 0.2)).toBe(0)
		expect(Hands.pulse(0.8, 0.2, 0.5, 0.2)).toBeNear(1)
	end,

	["bitesBetween counts each bite once and none after the stop"] = function()
		expect(Hands.bitesBetween(0, 0.19, 0.2, 0.5, 2)).toBe(0)
		expect(Hands.bitesBetween(0.19, 0.2, 0.2, 0.5, 2)).toBe(1)
		expect(Hands.bitesBetween(0.2, 0.6, 0.2, 0.5, 2)).toBe(0)
		expect(Hands.bitesBetween(0.6, 0.71, 0.2, 0.5, 2)).toBe(1)
		expect(Hands.bitesBetween(0, 2, 0.2, 0.5, 2)).toBe(4)
		expect(Hands.bitesBetween(2, 5, 0.2, 0.5, 2)).toBe(0)
	end,

	["hands start and end at rest"] = function()
		for _, kind in { "Eat", "Drink", "Heal", "Open" } do
			local right, left = Hands.pose(kind, 0, 2, SETTINGS)
			expect(right.y).toBeNear(-2)
			expect(left.y).toBeNear(-2)
			right, left = Hands.pose(kind, 2.2, 2, SETTINGS)
			expect(right.y).toBeNear(-2)
			expect(left.y).toBeNear(-2)
		end
	end,

	["eating pushes the food toward the mouth on a bite"] = function()
		local between = Hands.pose("Eat", 0.6, 2, SETTINGS)
		local bite = Hands.pose("Eat", 0.8, 2, SETTINGS)
		expect(bite.z > between.z).toBe(true)
		expect(bite.pitch > between.pitch).toBe(true)
	end,

	["drinking tips the can back further as it goes"] = function()
		local early = Hands.pose("Drink", 0.3, 2, SETTINGS)
		local late = Hands.pose("Drink", 1.5, 2, SETTINGS)
		expect(late.pitch > early.pitch).toBe(true)
		expect(late.pitch).toBeNear(70)
	end,

	["bandaging circles the right hand while the left holds still"] = function()
		local r1, l1 = Hands.pose("Heal", 0.5, 3, SETTINGS)
		local r2, l2 = Hands.pose("Heal", 0.9, 3, SETTINGS)
		expect(math.abs(r1.x - r2.x) + math.abs(r1.y - r2.y) > 0.05).toBe(true)
		expect(l1.x).toBeNear(l2.x)
		expect(l1.y).toBeNear(l2.y)
	end,

	["opening pulls the hands apart"] = function()
		local r1, l1 = Hands.pose("Open", 0.25, 2, SETTINGS)
		local r2, l2 = Hands.pose("Open", 1.5, 2, SETTINGS)
		expect(r2.x - l2.x > r1.x - l1.x).toBe(true)
	end,

	["reach goes out and comes back"] = function()
		expect(Hands.reach(0, 0.4)).toBe(0)
		expect(Hands.reach(0.2, 0.4)).toBeNear(1)
		expect(Hands.reach(0.4, 0.4)).toBe(0)
	end,

	["reachTarget never reaches backward"] = function()
		local start = pose(0, 0, 0)
		local forward = Hands.reachTarget(start, 0, 0, -1, 2)
		expect(forward.z).toBeNear(-2)
		local behind = Hands.reachTarget(start, 0, 0, 1, 2)
		expect(behind.z < 0).toBe(true)
		local none = Hands.reachTarget(start, 0, 0, 0, 2)
		expect(none.z).toBeNear(-2)
	end,
}
