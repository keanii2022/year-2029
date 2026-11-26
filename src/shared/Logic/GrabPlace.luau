-- Where a carried prop may go down: which parts count as in the way, which ones a landing cast
-- may rest on, how far the landing box may sink into its neighbours, where a box sits against
-- the face under the crosshair, which way a blocked spot is pushed out, and how it snaps flush
-- to a neighbour. Vectors are anything with X / Y / Z (a Vector3 in game, a table in tests).
local GrabPlace = {}

export type Who = "carrier" | "other" | nil

export type Overlap = {
	ownProp: boolean,
	character: Who,
	canCollide: boolean,
	transparency: number,
	thinnest: number, -- smallest side of the part's size
}

export type Vec = { X: number, Y: number, Z: number }

-- A flush snap in the neighbour's flat frame: the new centre, which face it sits against
-- ("x" or "z", side +1 / -1), the shared edge's span along the other axis, and how far it moved
-- to close the gap.
export type Snap = {
	x: number,
	z: number,
	axis: "x" | "z",
	side: number,
	from: number,
	to: number,
	gap: number,
}

-- Parts thinner than this (mats, decals, tape, sign cables) never stop a placement.
GrabPlace.THIN = 0.2

local function dot(a: Vec, b: Vec): number
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

-- Whether an overlapping part keeps the prop out. Other players always do; the carrier only on
-- the strict pass, so a prop that only clips its own carrier still goes down.
function GrabPlace.blocks(overlap: Overlap, carrierBlocks: boolean): boolean
	if overlap.ownProp then
		return false
	end
	if overlap.character == "other" then
		return true
	end
	if overlap.character == "carrier" then
		return carrierBlocks
	end
	return overlap.canCollide and overlap.transparency < 1 and overlap.thinnest >= GrabPlace.THIN
end

-- Whether a downward cast may rest on this part. Invisible volumes (zones, triggers) are passed.
function GrabPlace.landsOn(canCollide: boolean, transparency: number): boolean
	return canCollide and transparency < 1
end

-- The box used for the overlap test: tolerance studs off every side, so props may touch and sink
-- a little into bumpy meshes, never below half the real size.
function GrabPlace.overlapSize(
	sx: number,
	sy: number,
	sz: number,
	tolerance: number
): (number, number, number)
	local function shrink(side: number): number
		return math.max(side - 2 * tolerance, side / 2)
	end
	return shrink(sx), shrink(sy), shrink(sz)
end

-- How far a turned box reaches from its centre along a unit direction. right / up / look are the
-- box's own unit axes and size its sides along them.
function GrabPlace.extentAlong(size: Vec, right: Vec, up: Vec, look: Vec, direction: Vec): number
	return (
		math.abs(dot(right, direction)) * size.X
		+ math.abs(dot(up, direction)) * size.Y
		+ math.abs(dot(look, direction)) * size.Z
	) / 2
end

-- What a crosshair hit is good for: a floor or top to sit on, a wall to back against, or an
-- underside (ceiling, shelf bottom) that a box can't go against.
function GrabPlace.faceKind(normalY: number): "top" | "wall" | "under"
	if normalY > 0.7 then
		return "top"
	end
	if normalY < -0.7 then
		return "under"
	end
	return "wall"
end

-- Centre of a box set against the face it's aimed at: stepped out from the hit point along the
-- face normal by its own reach that way, so it sits on a top and its back is flush with a wall.
function GrabPlace.onFace(hit: Vec, normal: Vec, reachAlongNormal: number): (number, number, number)
	return hit.X + normal.X * reachAlongNormal,
		hit.Y + normal.Y * reachAlongNormal,
		hit.Z + normal.Z * reachAlongNormal
end

-- Distances to try pushing a blocked spot out along the blocking face, nearest first.
function GrabPlace.pushSteps(maxPush: number, step: number): { number }
	local steps = {}
	for index = 1, math.floor(maxPush / step + 1e-6) do
		table.insert(steps, index * step)
	end
	return steps
end

-- Where to try next when a spot is blocked and pushing off the blocker didn't free it: back
-- toward the placer and a little to either side, nearest first. Each is { back, side } in studs.
function GrabPlace.searchOffsets(maxBack: number, maxSide: number, step: number): { { number } }
	local offsets = {}
	local backSteps = math.floor(maxBack / step + 1e-6)
	local sideSteps = math.floor(maxSide / step + 1e-6)
	for b = 0, backSteps do
		for s = -sideSteps, sideSteps do
			if b ~= 0 or s ~= 0 then
				table.insert(offsets, { b * step, s * step })
			end
		end
	end
	table.sort(offsets, function(a, c)
		local da, dc = a[1] * a[1] + a[2] * a[2], c[1] * c[1] + c[2] * c[2]
		if da ~= dc then
			return da < dc
		end
		return a[1] > c[1] -- at equal distance, stepping back beats stepping sideways
	end)
	return offsets
end

-- The face of a box a point sits furthest outside of, as a unit normal in the box's own space.
-- x / y / z is the point and hx / hy / hz the half sides, both in the box's space.
function GrabPlace.faceNormal(
	x: number,
	y: number,
	z: number,
	hx: number,
	hy: number,
	hz: number
): (number, number, number)
	local outX, outY, outZ = math.abs(x) - hx, math.abs(y) - hy, math.abs(z) - hz
	if outX >= outY and outX >= outZ then
		return if x >= 0 then 1 else -1, 0, 0
	elseif outY >= outZ then
		return 0, if y >= 0 then 1 else -1, 0
	end
	return 0, 0, if z >= 0 then 1 else -1
end

-- Whether every axis of one box lines up with an axis of the other within maxDegrees, so the two
-- face the same way (or a quarter turn apart, which is the same thing for a box).
function GrabPlace.squareTo(axes: { Vec }, otherAxes: { Vec }, maxDegrees: number): boolean
	local limit = math.cos(math.rad(maxDegrees))
	for _, axis in axes do
		local best = 0
		for _, other in otherAxes do
			best = math.max(best, math.abs(dot(axis, other)))
		end
		if best < limit then
			return false
		end
	end
	return true
end

-- Snaps a box flush against a neighbour. Everything is in the neighbour's flat frame: the
-- neighbour is centred on the origin with half sides nx / nz, the box at x / z with half sides
-- hx / hz. A face gap (or sink) under range closes to touching; then, along that face, ends
-- within range line up. nil when no face is that close.
function GrabPlace.snapFlush(
	x: number,
	z: number,
	hx: number,
	hz: number,
	nx: number,
	nz: number,
	range: number
): Snap?
	local best: Snap? = nil
	for _, axis in { "x", "z" } do
		local along, half, otherHalf = x, hx, nx
		local across, acrossHalf, acrossOther = z, hz, nz
		if axis == "z" then
			along, half, otherHalf = z, hz, nz
			across, acrossHalf, acrossOther = x, hx, nx
		end
		local gap = math.abs(along) - half - otherHalf
		local overlap = math.min(across + acrossHalf, acrossOther)
			- math.max(across - acrossHalf, -acrossOther)
		if math.abs(gap) < range and overlap > 0 and (not best or math.abs(gap) < best.gap) then
			local side = if along >= 0 then 1 else -1
			local lowEnds = (across - acrossHalf) + acrossOther
			local highEnds = (across + acrossHalf) - acrossOther
			if math.abs(lowEnds) < range and math.abs(lowEnds) <= math.abs(highEnds) then
				across -= lowEnds
			elseif math.abs(highEnds) < range then
				across -= highEnds
			end
			local flush = side * (half + otherHalf)
			best = {
				x = if axis == "x" then flush else across,
				z = if axis == "x" then across else flush,
				axis = axis :: any,
				side = side,
				from = math.max(across - acrossHalf, -acrossOther),
				to = math.min(across + acrossHalf, acrossOther),
				gap = math.abs(gap),
			}
		end
	end
	return best
end

return GrabPlace
