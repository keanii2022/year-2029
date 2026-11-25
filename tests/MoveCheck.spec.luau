local MoveCheck = require("../src/shared/Logic/MoveCheck")
local expect = require("./expect")

local settings = { Slack = 1.5, BurstSeconds = 2, BadlyOver = 30, MaxStrikes = 3, StrikeDecay = 0.5 }

return {
	["normal sprinting never trips"] = function()
		local state = MoveCheck.new(22, settings)
		for _ = 1, 600 do
			expect(MoveCheck.step(state, 22 / 60, 1 / 60, 22, settings)).toBeFalsy()
		end
	end,
	["a lag burst inside the saved-up budget is fine"] = function()
		local state = MoveCheck.new(22, settings)
		expect(MoveCheck.step(state, 40, 1 / 60, 22, settings)).toBeFalsy()
	end,
	["a big jump pulls back at once"] = function()
		local state = MoveCheck.new(22, settings)
		expect(MoveCheck.step(state, 120, 1 / 60, 22, settings)).toBe(true)
	end,
	["steady speeding pulls back after a few strikes"] = function()
		local state = MoveCheck.new(22, settings)
		local pulled = false
		for _ = 1, 600 do
			if MoveCheck.step(state, 60 / 60, 1 / 60, 22, settings) then
				pulled = true
				break
			end
		end
		expect(pulled).toBe(true)
	end,
	["strikes fade while moving normally"] = function()
		local state = MoveCheck.new(22, settings)
		state.credit = 0
		MoveCheck.step(state, 5, 1 / 60, 22, settings)
		expect(state.strikes).toBe(1)
		for _ = 1, 180 do
			MoveCheck.step(state, 0, 1 / 60, 22, settings)
		end
		expect(state.strikes).toBe(0)
	end,
}
