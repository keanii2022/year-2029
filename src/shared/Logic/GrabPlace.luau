-- Where a carried prop may go down: which parts count as in the way, which ones a landing cast
-- may rest on, how far the landing box may sink into its neighbours, and the nearby spots tried
-- when the aimed one doesn't fit.
local GrabPlace = {}

export type Who = "carrier" | "other" | nil

export type Overlap = {
	ownProp: boolean,
	character: Who,
	canCollide: boolean,
	transparency: number,
	thinnest: number, -- smallest side of the part's size
}

-- Parts thinner than this (mats, decals, tape, sign cables) never stop a placement.
GrabPlace.THIN = 0.2

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

-- Sideways nudges to try, nearest first: no nudge, then eight directions on each ring.
function GrabPlace.offsets(rings: { number }): { { x: number, z: number } }
	local spots = { { x = 0, z = 0 } }
	for _, radius in rings do
		for step = 0, 7 do
			local angle = step * math.pi / 4
			table.insert(spots, { x = math.cos(angle) * radius, z = math.sin(angle) * radius })
		end
	end
	return spots
end

return GrabPlace
