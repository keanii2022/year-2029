local GrabPry = require("../src/shared/Logic/GrabPry")
local expect = require("./expect")

local function finish(overrides: { [string]: any })
	local check = {
		started = true,
		samePiece = true,
		elapsed = 3,
		duration = 3,
		grace = 0.25,
		distance = 5,
		reach = 12,
	}
	for key, value in overrides do
		check[key] = value
	end
	return GrabPry.canFinish(check :: any)
end

return {
	["needsPry only for pieces someone else placed"] = function()
		expect(GrabPry.needsPry(nil, 1)).toBeFalsy()
		expect(GrabPry.needsPry(1, 1)).toBeFalsy()
		expect(GrabPry.needsPry(2, 1)).toBeTruthy()
	end,
	["progress runs from 0 to 1 and clamps"] = function()
		expect(GrabPry.progress(0, 3)).toBe(0)
		expect(GrabPry.progress(1.5, 3)).toBe(0.5)
		expect(GrabPry.progress(5, 3)).toBe(1)
		expect(GrabPry.progress(-1, 3)).toBe(0)
		expect(GrabPry.progress(0, 0)).toBe(1)
	end,
	["due fires first time and then every interval"] = function()
		expect(GrabPry.due(nil, 10, 1)).toBeTruthy()
		expect(GrabPry.due(10, 10.5, 1)).toBeFalsy()
		expect(GrabPry.due(10, 11, 1)).toBeTruthy()
	end,
	["canFinish allows a full pry in reach"] = function()
		expect(finish({})).toBeTruthy()
		expect(finish({ elapsed = 2.8 })).toBeTruthy()
	end,
	["canFinish refuses early, far or missing pries"] = function()
		local ok, reason = finish({ elapsed = 2 })
		expect(ok).toBeFalsy()
		expect(reason).toBe("too soon")
		ok, reason = finish({ distance = 13 })
		expect(reason).toBe("too far")
		ok, reason = finish({ started = false })
		expect(reason).toBe("not prying")
		ok, reason = finish({ samePiece = false })
		expect(reason).toBe("not prying")
	end,
}
