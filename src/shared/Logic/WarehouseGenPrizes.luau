-- Prize chest spots in an installation set: the open floor furthest from the hall's way in, so
-- reaching one means walking past the robots. Spots a set asks for itself (room.prizeHints, e.g. the
-- end of a catwalk) come first. Never in walls, water, void, doorways or furniture.
-- Writes room.prizes = { { x, z, y, turn, plinth } }. Own random source, so the rest of the layout
-- comes out the same as before.
local Fill = if script then require(script.Parent.WarehouseGenFill) else require("./WarehouseGenFill")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Prizes = {}

export type Spot = { x: number, z: number, y: number, turn: number, plinth: boolean }

-- Things Fill lets furniture sit on but a chest shouldn't: holes in the floor and kit models, whose
-- layout piece is a 1x1 stand-in for something much bigger
local function extraBlockers(layout: any, from: number, kitClearance: number): { Fill.Block }
	local list = {}
	for index = from, #layout.pieces do
		local spec = layout.pieces[index]
		local bottom = spec.y - spec.sy / 2
		if bottom < 3 and spec.style == "void" then
			table.insert(list, { x = spec.x, z = spec.z, r = 0, hx = spec.sx / 2, hz = spec.sz / 2 })
		elseif bottom < 3 and spec.kit then
			table.insert(list, { x = spec.x, z = spec.z, r = kitClearance, hx = 0, hz = 0 })
		end
	end
	return list
end

local function facing(x: number, z: number, tx: number, tz: number): number
	return math.deg(math.atan2(tx - x, tz - z))
end

local function nearest(points: { { number } }, x: number, z: number): number
	local best = math.huge
	for _, point in points do
		best = math.min(best, math.sqrt((point[1] - x) ^ 2 + (point[2] - z) ^ 2))
	end
	return best
end

local function farFromAll(spots: { Spot }, x: number, z: number, gap: number): boolean
	for _, spot in spots do
		if (spot.x - x) ^ 2 + (spot.z - z) ^ 2 < gap * gap then
			return false
		end
	end
	return true
end

-- How many chests a set gets: one, more for bigger floors, the most for a giant hall
function Prizes.count(settings: any, room: any): number
	if room.giant then
		return settings.Count[2]
	end
	local area = (room.x1 - room.x0) * (room.z1 - room.z0)
	return math.clamp(1 + math.floor(area / settings.AreaPerExtra), settings.Count[1], settings.Count[2])
end

-- doorways: the set's own doors; entrances: the hall doors players walk in through, as { x, z }
function Prizes.place(
	layout: any,
	config: any,
	room: any,
	from: number,
	doorways: { { number } },
	entrances: { { number } }
): { Spot }
	local settings = config.PrizeSpots
	local rng = Rng.new(layout.seed + room.id * 104729)
	local want = Prizes.count(settings, room)
	local list = Fill.blockers(layout, room, from)
	for _, block in extraBlockers(layout, from, settings.KitClearance) do
		table.insert(list, block)
	end
	for _, door in doorways do
		table.insert(list, { x = door[1], z = door[2], r = settings.DoorClearance, hx = 0, hz = 0 })
	end

	local spots: { Spot } = {}
	for _, hint in room.prizeHints or {} do
		if #spots < want then
			table.insert(spots, {
				x = hint.x,
				z = hint.z,
				y = hint.y or 0,
				turn = hint.turn or 0,
				plinth = hint.plinth == true,
			})
		end
	end

	local function search(radius: number, pad: number, gap: number)
		local candidates = {}
		local step = settings.GridStep
		local x = room.x0 + pad
		while x <= room.x1 - pad do
			local z = room.z0 + pad
			while z <= room.z1 - pad do
				local jx, jz = x + rng:range(-1, 1) * step * 0.3, z + rng:range(-1, 1) * step * 0.3
				if Fill.free(list, jx, jz, radius) then
					table.insert(candidates, { x = jx, z = jz, score = nearest(entrances, jx, jz) })
				end
				z += step
			end
			x += step
		end
		table.sort(candidates, function(a, b)
			return a.score > b.score
		end)
		for _, candidate in candidates do
			if #spots >= want then
				break
			end
			if farFromAll(spots, candidate.x, candidate.z, gap) then
				table.insert(spots, {
					x = candidate.x,
					z = candidate.z,
					y = 0,
					turn = facing(candidate.x, candidate.z, room.cx, room.cz),
					plinth = true,
				})
			end
		end
	end
	search(settings.Radius, settings.WallPad, settings.MinGap)
	-- A small, crowded set still gets its chest: try right up against the walls too
	if #spots < settings.Count[1] then
		search(settings.Radius, 2, settings.MinGap)
	end
	room.prizes = spots
	return spots
end

return Prizes
