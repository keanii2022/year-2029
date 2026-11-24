local function fail(message: string)
	error(message, 3)
end

local function expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {tostring(expected)}, got {tostring(actual)}`)
			end
		end,
		toBeNear = function(expected: number, tolerance: number?)
			if math.abs(actual - expected) > (tolerance or 1e-6) then
				fail(`expected ~{expected}, got {actual}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected truthy, got {tostring(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected falsy, got {tostring(actual)}`)
			end
		end,
	}
end

return expect
