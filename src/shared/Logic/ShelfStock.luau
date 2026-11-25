-- What sits on a rack bay's shelves, and which bays carry their stock right now. A bay's stock is
-- planned from its own seed, so a bay that streams out and back in comes back the same.
-- Positions are bay space: x along the bay, y the surface a prop rests on, z out the front (+z).
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local ShelfStock = {}

export type Slot = { x0: number, x1: number, y: number, clear: number, tier: string }
export type Placement = { name: string, x: number, y: number, z: number, turn: number, tipped: boolean }
export type Point = { x: number, z: number }
type SizeOf = (name: string) -> { number }?

local TRIES = 4 -- picks that don't fit before a shelf counts as full

-- Weights table { name = weight } -> a name; 0 <= roll < 1. Names sorted so it's the same everywhere.
function ShelfStock.pickBay(roll: number, weights: { [string]: number }): string
	local names = {}
	local total = 0
	for name, weight in weights do
		table.insert(names, name)
		total += weight
	end
	table.sort(names)
	local left = roll * total
	for _, name in names do
		left -= weights[name]
		if left < 0 then
			return name
		end
	end
	return names[#names]
end

-- Every level of an empty bay, full width
function ShelfStock.levelSlots(config: any): { Slot }
	local half = config.ShelfWidth / 2
	local slots = {}
	for _, level in config.ShelfLevels do
		table.insert(slots, { x0 = -half, x1 = half, y = level.y, clear = level.clear, tier = level.tier })
	end
	return slots
end

-- The empty pallet slots of a baked bay. gaps: { { x, y } } slot centres; slot: width, clear, depth.
function ShelfStock.gapSlots(
	gaps: { { x: number, y: number } },
	width: number,
	clear: number,
	config: any
): { Slot }
	local slots = {}
	for _, gap in gaps do
		local tier = config.ShelfLevels[1].tier
		local nearest = math.huge
		for _, level in config.ShelfLevels do
			if math.abs(level.y - gap.y) < nearest then
				nearest = math.abs(level.y - gap.y)
				tier = level.tier
			end
		end
		table.insert(
			slots,
			{ x0 = gap.x - width / 2, x1 = gap.x + width / 2, y = gap.y, clear = clear, tier = tier }
		)
	end
	return slots
end

-- Footprint (along, deep) of a w x d box turned by degrees about y
local function footprint(w: number, d: number, degrees: number): (number, number)
	local c, s = math.abs(math.cos(math.rad(degrees))), math.abs(math.sin(math.rad(degrees)))
	return w * c + d * s, w * s + d * c
end

-- Fills one slot left to right: a row along the front, sometimes a second one behind it, boxes
-- stacked, the odd gap where something was taken and the odd thing lying on its side.
local function planSlot(rng: Rng.Rng, slot: Slot, config: any, sizeOf: SizeOf, out: { Placement })
	local weights = config.ShelfTiers[slot.tier]
	local halfDepth = config.ShelfDepth / 2
	local x = slot.x0
	local placed = 0
	local misses = 0
	while misses < TRIES and placed < config.ShelfMaxPerSlot do
		if rng:next() < config.ShelfGapChance then
			x += rng:range(config.ShelfGap[1], config.ShelfGap[2])
		end
		local name = rng:weighted(weights)
		local size = sizeOf(name)
		if not size then
			misses += 1
			continue
		end
		local w, h, d = size[1], size[2], size[3]
		-- Only things taller than wide fall over; a toppled box would just be a box
		local tipped = h > w and rng:next() < config.ShelfFallenChance
		if tipped then
			w, h = h, w
		end
		local turn = rng:range(-config.ShelfTurn, config.ShelfTurn)
		local along, deep = footprint(w, d, turn)
		if h > slot.clear or deep > config.ShelfDepth or x + along > slot.x1 then
			misses += 1
			continue
		end
		local maxStack = if tipped
			then 1
			else math.min(config.ShelfStackable[name] or 1, math.floor(slot.clear / h))
		local stack = rng:int(math.max(1, maxStack - 1), math.max(1, maxStack))
		local rows = { halfDepth - deep / 2 }
		if deep * 2 <= config.ShelfDepth and rng:next() < config.ShelfBackRowChance then
			table.insert(rows, -halfDepth + deep / 2)
		elseif deep * 2 > config.ShelfDepth then
			-- One deep thing: anywhere front to back
			rows[1] = rng:range(-(halfDepth - deep / 2), halfDepth - deep / 2)
		end
		local cx = x + along / 2
		for _, z in rows do
			for level = 0, stack - 1 do
				if placed >= config.ShelfMaxPerSlot then
					break
				end
				table.insert(out, {
					name = name,
					x = cx,
					y = slot.y + level * h,
					z = z,
					turn = turn,
					tipped = tipped,
				})
				placed += 1
			end
		end
		x += along + rng:range(0.05, 0.3)
	end
end

-- The whole bay's stock: its slots, some left bare, and now and then something knocked off into
-- the aisle in front or behind.
function ShelfStock.planBay(seed: number, slots: { Slot }, config: any, sizeOf: SizeOf): { Placement }
	local rng = Rng.new(seed)
	local out = {}
	for _, slot in slots do
		if rng:next() >= config.ShelfBareChance then
			planSlot(rng, slot, config, sizeOf, out)
		end
	end
	if rng:next() < config.ShelfSpillChance then
		local name = rng:weighted(config.ShelfTiers[config.ShelfSpillTier])
		local size = sizeOf(name)
		if size then
			local side = if rng:next() < 0.5 then 1 else -1
			local offset = config.ShelfDepth / 2 + rng:range(config.ShelfSpill[1], config.ShelfSpill[2])
			table.insert(out, {
				name = name,
				x = rng:range(-config.ShelfWidth / 2 + size[1], config.ShelfWidth / 2 - size[1]),
				y = 0,
				z = side * offset,
				turn = rng:range(0, 360),
				tipped = size[2] > size[1],
			})
		end
	end
	return out
end

-- Which bays carry stock: those within radius of any player, nearest first, until the budget of
-- props runs out. A bay already stocked keeps it out to keep (> radius) so walking the edge
-- doesn't flicker it in and out. costOf(index): props that bay would spawn.
function ShelfStock.wanted(
	bays: { Point },
	live: { [number]: boolean },
	players: { Point },
	radius: number,
	keep: number,
	budget: number,
	costOf: (number) -> number
): { [number]: boolean }
	local near = {}
	local distance = {}
	for index, bay in bays do
		local best = math.huge
		for _, player in players do
			local dx, dz = bay.x - player.x, bay.z - player.z
			best = math.min(best, dx * dx + dz * dz)
		end
		local reach = if live[index] then keep else radius
		if best <= reach * reach then
			table.insert(near, index)
			distance[index] = best
		end
	end
	table.sort(near, function(a, b)
		return distance[a] < distance[b]
	end)
	local chosen = {}
	local spent = 0
	for _, index in near do
		local cost = costOf(index)
		if spent + cost > budget then
			break
		end
		spent += cost
		chosen[index] = true
	end
	return chosen
end

return ShelfStock
