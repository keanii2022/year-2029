-- Where warehouse life can happen: floor spots beside rack faces ("aisle") and just past rack ends
-- ("end"), plus picking one near a player that is far enough off and mostly out of sight.
-- Coordinates are flat x/z; dx/dz is a unit direction (aisle: away from the rack face, end: across
-- the cross aisle, the way a cart would roll).
local LifeSpots = {}

export type Shelf = { x0: number, x1: number, z: number, depth: number }
export type Spot = { x: number, z: number, kind: string, dx: number, dz: number }
export type Viewer = { x: number, z: number, lookX: number, lookZ: number }

function LifeSpots.fromShelves(
	shelves: { Shelf },
	settings: { EndGap: number, AisleStep: number, AisleOffset: number }
): { Spot }
	local spots = {}
	for index, shelf in shelves do
		local roll = if index % 2 == 0 then 1 else -1
		table.insert(spots, { x = shelf.x0 - settings.EndGap, z = shelf.z, kind = "end", dx = 0, dz = roll })
		table.insert(spots, { x = shelf.x1 + settings.EndGap, z = shelf.z, kind = "end", dx = 0, dz = -roll })
		local out = shelf.depth / 2 + settings.AisleOffset
		local x = shelf.x0 + settings.AisleStep / 2
		while x < shelf.x1 do
			table.insert(spots, { x = x, z = shelf.z + out, kind = "aisle", dx = 0, dz = 1 })
			table.insert(spots, { x = x, z = shelf.z - out, kind = "aisle", dx = 0, dz = -1 })
			x += settings.AisleStep
		end
	end
	return spots
end

-- Spots in the ring min..radius round x/z, thinned evenly to at most max.
function LifeSpots.near(
	spots: { Spot },
	x: number,
	z: number,
	min: number,
	radius: number,
	max: number
): { Spot }
	local ring = {}
	for _, spot in spots do
		local d = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if d >= min and d <= radius then
			table.insert(ring, spot)
		end
	end
	if #ring <= max then
		return ring
	end
	local thinned = {}
	local stride = #ring / max
	for n = 0, max - 1 do
		table.insert(thinned, ring[math.floor(n * stride) + 1])
	end
	return thinned
end

-- Angle in degrees between the flat look direction and the direction to the spot.
local function offAngle(viewer: Viewer, spot: Spot, distance: number): number
	local look = math.sqrt(viewer.lookX ^ 2 + viewer.lookZ ^ 2)
	if look < 1e-6 or distance < 1e-6 then
		return 180
	end
	local dot = ((spot.x - viewer.x) * viewer.lookX + (spot.z - viewer.z) * viewer.lookZ) / (look * distance)
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

-- A spot for an event of `kind` ("aisle", "end" or "any"). Mostly out of sight; with GlimpseChance a
-- far one in view instead. roll() returns 0..1. Nil when nothing fits.
function LifeSpots.choose(
	spots: { Spot },
	viewer: Viewer,
	kind: string,
	settings: {
		MinDistance: number,
		MaxDistance: number,
		HiddenAngle: number,
		GlimpseChance: number,
		GlimpseMinDistance: number,
	},
	roll: () -> number
): Spot?
	local hidden, glimpse = {}, {}
	for _, spot in spots do
		if kind == "any" or spot.kind == kind then
			local d = math.sqrt((spot.x - viewer.x) ^ 2 + (spot.z - viewer.z) ^ 2)
			if d >= settings.MinDistance and d <= settings.MaxDistance then
				if offAngle(viewer, spot, d) > settings.HiddenAngle then
					table.insert(hidden, spot)
				elseif d >= settings.GlimpseMinDistance then
					table.insert(glimpse, spot)
				end
			end
		end
	end
	local wantGlimpse = roll() < settings.GlimpseChance
	local pool = if (wantGlimpse and #glimpse > 0) or #hidden == 0 then glimpse else hidden
	if #pool == 0 then
		return nil
	end
	return pool[math.min(#pool, math.floor(roll() * #pool) + 1)]
end

return LifeSpots
