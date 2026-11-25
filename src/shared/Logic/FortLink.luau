-- Which placed pieces count as fortified: touching another placed piece on any side, or set
-- against a wall (anything solid and fixed beside it, not just the floor under it). Fortified
-- pieces hold: robots leave them alone and prying one out takes longer. Boxes are world-aligned
-- bounds: centre x / y / z and half sides hx / hy / hz. No Roblox here.
local FortLink = {}

export type Box = { x: number, y: number, z: number, hx: number, hy: number, hz: number }
export type Neighbour = { box: Box, placed: boolean }

-- The widest gap between two boxes along any one axis; zero or less when they touch or overlap.
function FortLink.gap(a: Box, b: Box): number
	local gx = math.abs(a.x - b.x) - a.hx - b.hx
	local gy = math.abs(a.y - b.y) - a.hy - b.hy
	local gz = math.abs(a.z - b.z) - a.hz - b.hz
	return math.max(gx, gy, gz)
end

-- How much two boxes share in height. A floor under a piece shares none, a wall beside it a lot.
function FortLink.sharedHeight(a: Box, b: Box): number
	return math.min(a.y + a.hy, b.y + b.hy) - math.max(a.y - a.hy, b.y - b.hy)
end

-- A placed piece is fortified when another placed piece is within maxGap anywhere (beside, on
-- top, underneath) or a fixed neighbour is within maxGap beside it, sharing more than minSide of
-- its height.
function FortLink.fortified(piece: Box, neighbours: { Neighbour }, maxGap: number, minSide: number): boolean
	for _, neighbour in neighbours do
		if FortLink.gap(piece, neighbour.box) < maxGap then
			if neighbour.placed or FortLink.sharedHeight(piece, neighbour.box) > minSide then
				return true
			end
		end
	end
	return false
end

return FortLink
