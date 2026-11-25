local GrabPlace = require("../src/shared/Logic/GrabPlace")
local expect = require("./expect")

local function v(x: number, y: number, z: number): GrabPlace.Vec
	return { X = x, Y = y, Z = z }
end

local function overlap(overrides: { [string]: any })
	local check = { ownProp = false, character = nil, canCollide = true, transparency = 0, thinnest = 1 }
	for key, value in overrides do
		check[key] = value
	end
	return check :: any
end

return {
	["blocks a solid wall or prop"] = function()
		expect(GrabPlace.blocks(overlap({}), true)).toBeTruthy()
	end,
	["never blocks on the prop itself, mats, ropes or invisible zones"] = function()
		expect(GrabPlace.blocks(overlap({ ownProp = true }), true)).toBeFalsy()
		expect(GrabPlace.blocks(overlap({ thinnest = 0.1 }), true)).toBeFalsy()
		expect(GrabPlace.blocks(overlap({ canCollide = false }), true)).toBeFalsy()
		expect(GrabPlace.blocks(overlap({ transparency = 1 }), true)).toBeFalsy()
	end,
	["other players always block, the carrier only on the strict pass"] = function()
		expect(GrabPlace.blocks(overlap({ character = "other", canCollide = false }), false)).toBeTruthy()
		expect(GrabPlace.blocks(overlap({ character = "carrier" }), true)).toBeTruthy()
		expect(GrabPlace.blocks(overlap({ character = "carrier" }), false)).toBeFalsy()
	end,
	["landing casts pass invisible and non-solid parts"] = function()
		expect(GrabPlace.landsOn(true, 0)).toBeTruthy()
		expect(GrabPlace.landsOn(true, 1)).toBeFalsy()
		expect(GrabPlace.landsOn(false, 0)).toBeFalsy()
	end,
	["overlap box shrinks by the tolerance but never below half"] = function()
		local x, y, z = GrabPlace.overlapSize(4, 2, 0.6, 0.3)
		expect(x).toBeNear(3.4)
		expect(y).toBeNear(1.4)
		expect(z).toBeNear(0.3)
	end,
	["extentAlong measures a turned box along any direction"] = function()
		local size = v(4, 2, 6)
		local right, up, look = v(1, 0, 0), v(0, 1, 0), v(0, 0, 1)
		expect(GrabPlace.extentAlong(size, right, up, look, v(0, 1, 0))).toBeNear(1)
		expect(GrabPlace.extentAlong(size, right, up, look, v(0, 0, -1))).toBeNear(3)
		-- a quarter turn swaps which side faces x
		expect(GrabPlace.extentAlong(size, v(0, 0, 1), up, v(-1, 0, 0), v(1, 0, 0))).toBeNear(3)
	end,
	["faceKind tells tops, walls and undersides apart"] = function()
		expect(GrabPlace.faceKind(1)).toBe("top")
		expect(GrabPlace.faceKind(0.1)).toBe("wall")
		expect(GrabPlace.faceKind(-1)).toBe("under")
	end,
	["onFace sits a box on a top and flush against a wall"] = function()
		local x, y, z = GrabPlace.onFace(v(3, 0, 5), v(0, 1, 0), 1.5)
		expect(x).toBeNear(3)
		expect(y).toBeNear(1.5)
		expect(z).toBeNear(5)
		x, y = GrabPlace.onFace(v(10, 2, 0), v(-1, 0, 0), 0.3)
		expect(x).toBeNear(9.7)
		expect(y).toBeNear(2)
	end,
	["pushSteps go out a quarter stud at a time up to the max"] = function()
		local steps = GrabPlace.pushSteps(1.5, 0.25)
		expect(#steps).toBe(6)
		expect(steps[1]).toBeNear(0.25)
		expect(steps[6]).toBeNear(1.5)
	end,
	["faceNormal picks the face the point is furthest outside"] = function()
		-- beside a thin wall panel, the push is out of its face, not along it
		local x, y, z = GrabPlace.faceNormal(3, 0, 2, 10, 4, 0.5)
		expect(x).toBe(0)
		expect(y).toBe(0)
		expect(z).toBe(1)
		x = GrabPlace.faceNormal(-6, 1, 0, 2, 2, 2)
		expect(x).toBe(-1)
		_, y = GrabPlace.faceNormal(0, 5, 0, 2, 2, 2)
		expect(y).toBe(1)
	end,
	["squareTo allows a quarter turn and a few degrees, not more"] = function()
		local flat = { v(1, 0, 0), v(0, 1, 0), v(0, 0, 1) }
		local quarter = { v(0, 0, 1), v(0, 1, 0), v(-1, 0, 0) }
		local function turned(degrees: number)
			local c, s = math.cos(math.rad(degrees)), math.sin(math.rad(degrees))
			return { v(c, 0, -s), v(0, 1, 0), v(s, 0, c) }
		end
		expect(GrabPlace.squareTo(flat, quarter, 5)).toBeTruthy()
		expect(GrabPlace.squareTo(flat, turned(4), 5)).toBeTruthy()
		expect(GrabPlace.squareTo(flat, turned(15), 5)).toBeFalsy()
	end,
	["snapFlush closes a small gap and lines up the ends"] = function()
		-- neighbour 4 x 2, box 2 x 2 sitting 0.5 off its +x face and 0.4 past its end
		local snap = GrabPlace.snapFlush(3.5, 0.4, 1, 1, 2, 1, 0.75)
		expect(snap ~= nil).toBeTruthy()
		local s = snap :: GrabPlace.Snap
		expect(s.axis).toBe("x")
		expect(s.side).toBe(1)
		expect(s.x).toBeNear(3)
		expect(s.z).toBeNear(0)
		expect(s.from).toBeNear(-1)
		expect(s.to).toBeNear(1)
	end,
	["snapFlush pulls a box that sinks in back out to touching"] = function()
		local s = GrabPlace.snapFlush(0, -2.6, 1, 1, 2, 2, 0.75) :: GrabPlace.Snap
		expect(s.axis).toBe("z")
		expect(s.z).toBeNear(-3)
	end,
	["snapFlush leaves far, corner and stacked boxes alone"] = function()
		expect(GrabPlace.snapFlush(4.5, 0, 1, 1, 2, 1, 0.75)).toBe(nil)
		expect(GrabPlace.snapFlush(3.2, 3, 1, 1, 2, 1, 0.75)).toBe(nil)
		expect(GrabPlace.snapFlush(0, 0, 1, 1, 2, 1, 0.75)).toBe(nil)
	end,
}
