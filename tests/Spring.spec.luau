local Spring = require("../src/shared/Logic/Spring")
local expect = require("./expect")

local function run(spring: Spring.Spring, seconds: number, dt: number): number
	local peak = 0
	for _ = 1, math.floor(seconds / dt) do
		peak = math.max(peak, Spring.step(spring, dt))
	end
	return peak
end

return {
	["a kick swings out about its peak and settles back"] = function()
		local spring = Spring.new()
		Spring.kick(spring, 1)
		local peak = run(spring, 1, 1 / 240)
		expect(peak).toBeNear(1, 0.05)
		expect(spring.position).toBeNear(0, 0.01)
	end,
	["kicks pile up instead of restarting"] = function()
		local single = Spring.new()
		Spring.kick(single, 1)
		local stacked = Spring.new()
		Spring.kick(stacked, 1)
		Spring.step(stacked, 1 / 60)
		Spring.kick(stacked, 1)
		expect(run(stacked, 0.5, 1 / 60) > run(single, 0.5, 1 / 60)).toBeTruthy()
	end,
	["a long frame is capped so it can't blow up"] = function()
		local spring = Spring.new()
		Spring.kick(spring, 1)
		for _ = 1, 30 do
			Spring.step(spring, 2)
		end
		expect(math.abs(spring.position) < 1).toBeTruthy()
	end,
	["reset swings back from a resting position"] = function()
		local spring = Spring.new()
		Spring.reset(spring, -1.1)
		expect(spring.velocity).toBe(0)
		run(spring, 1, 1 / 60)
		expect(spring.position).toBeNear(0, 0.01)
	end,
	["it chases a moved target"] = function()
		local spring = Spring.new()
		spring.target = 3
		run(spring, 1, 1 / 60)
		expect(spring.position).toBeNear(3, 0.05)
	end,
}
