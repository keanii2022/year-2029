-- The store rearranges itself overnight: which loose things the robots "restock" at dawn and where
-- they end up. Flat x/z coordinates; roll() returns 0..1; isClear(x, z) says a floor spot is free of
-- racks, walls and rooms (WarehouseGen.isClear).
local Rearrange = {}

export type Point = { x: number, z: number }
export type Item = {
	x: number,
	z: number,
	kind: string, -- "junk", "furniture" or "cart"
	placed: boolean?, -- a player put it down: part of a fort
	carried: boolean?,
	fixed: boolean?, -- locker, container, in an installation, or not the server's to move
	y: number?, -- junk only: centre height and half its footprint, to find boxes under others
	half: number?,
	covered: boolean?, -- junk with another box resting on it
}

local function shuffled<T>(list: { T }, roll: () -> number): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.floor(roll() * i) + 1
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

function Rearrange.nearPlayer(x: number, z: number, players: { Point }, keepAway: number): boolean
	for _, player in players do
		if (player.x - x) ^ 2 + (player.z - z) ^ 2 < keepAway * keepAway then
			return true
		end
	end
	return false
end

function Rearrange.movable(item: Item, players: { Point }, keepAway: number): boolean
	return not item.placed
		and not item.carried
		and not item.fixed
		and not item.covered
		and not Rearrange.nearPlayer(item.x, item.z, players, keepAway)
end

-- Junk boxes sit in stacks; pulling out a lower one would leave the ones above floating (they're
-- anchored), so any box with another box's centre over its footprint is marked covered.
function Rearrange.markCovered(items: { Item }, cell: number)
	local buckets: { [string]: { Item } } = {}
	local function key(x: number, z: number): string
		return `{math.floor(x / cell)}_{math.floor(z / cell)}`
	end
	for _, item in items do
		if item.kind == "junk" then
			local k = key(item.x, item.z)
			buckets[k] = buckets[k] or {}
			table.insert(buckets[k], item)
		end
	end
	for _, item in items do
		if item.kind == "junk" and item.y and item.half then
			local cx, cz = math.floor(item.x / cell), math.floor(item.z / cell)
			for dx = -1, 1 do
				for dz = -1, 1 do
					for _, other in buckets[`{cx + dx}_{cz + dz}`] or {} do
						if
							other ~= item
							and (other.y or 0) > item.y
							and math.abs(other.x - item.x) < item.half
							and math.abs(other.z - item.z) < item.half
						then
							item.covered = true
						end
					end
				end
			end
		end
	end
end

-- A share of each kind's movable items (rounded down, at most Max), as indices into items
function Rearrange.choose(
	items: { Item },
	players: { Point },
	settings: { KeepAway: number, Share: { [string]: number }, Max: { [string]: number } },
	roll: () -> number
): { number }
	local byKind: { [string]: { number } } = {}
	for index, item in items do
		if Rearrange.movable(item, players, settings.KeepAway) then
			byKind[item.kind] = byKind[item.kind] or {}
			table.insert(byKind[item.kind], index)
		end
	end
	local chosen = {}
	for kind, indices in byKind do
		local count = math.min(math.floor(#indices * (settings.Share[kind] or 0)), settings.Max[kind] or 0)
		local order = shuffled(indices, roll)
		for n = 1, count do
			table.insert(chosen, order[n])
		end
	end
	table.sort(chosen)
	return chosen
end

local function crowded(x: number, z: number, taken: { Point }, gap: number): boolean
	for _, point in taken do
		if (point.x - x) ^ 2 + (point.z - z) ^ 2 < gap * gap then
			return true
		end
	end
	return false
end

-- A clear spot a short shove away, away from players and from anything already moved there (taken
-- gets the new spot). Nil after Tries misses.
function Rearrange.spotNear(
	x: number,
	z: number,
	players: { Point },
	taken: { Point },
	settings: {
		MinShift: number,
		MaxShift: number,
		Tries: number,
		KeepAway: number,
		Gap: number,
	},
	roll: () -> number,
	isClear: (x: number, z: number) -> boolean
): Point?
	for _ = 1, settings.Tries do
		local angle = roll() * math.pi * 2
		local distance = settings.MinShift + roll() * (settings.MaxShift - settings.MinShift)
		local nx, nz = x + math.cos(angle) * distance, z + math.sin(angle) * distance
		if
			not Rearrange.nearPlayer(nx, nz, players, settings.KeepAway)
			and not crowded(nx, nz, taken, settings.Gap)
			and isClear(nx, nz)
		then
			local spot = { x = nx, z = nz }
			table.insert(taken, spot)
			return spot
		end
	end
	return nil
end

-- A cart rolls to an aisle spot a different aisle over (z at least AisleGap off) within CartRange
function Rearrange.cartSpot(
	x: number,
	z: number,
	spots: { Point },
	players: { Point },
	taken: { Point },
	settings: {
		CartRange: number,
		AisleGap: number,
		Tries: number,
		KeepAway: number,
		Gap: number,
	},
	roll: () -> number,
	isClear: (x: number, z: number) -> boolean
): Point?
	local pool = {}
	for _, spot in spots do
		local far = (spot.x - x) ^ 2 + (spot.z - z) ^ 2
		if far <= settings.CartRange * settings.CartRange and math.abs(spot.z - z) >= settings.AisleGap then
			table.insert(pool, spot)
		end
	end
	for _ = 1, math.min(settings.Tries, #pool) do
		local spot = pool[math.floor(roll() * #pool) + 1]
		if
			not Rearrange.nearPlayer(spot.x, spot.z, players, settings.KeepAway)
			and not crowded(spot.x, spot.z, taken, settings.Gap)
			and isClear(spot.x, spot.z)
		then
			local chosen = { x = spot.x, z = spot.z }
			table.insert(taken, chosen)
			return chosen
		end
	end
	return nil
end

-- Up to count pairs of sign indices (1..n) whose texts swap; no sign is in two pairs
function Rearrange.swaps(n: number, count: number, roll: () -> number): { { number } }
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	order = shuffled(order, roll)
	local swapped = {}
	for p = 1, math.min(count, math.floor(n / 2)) do
		table.insert(swapped, { order[p * 2 - 1], order[p * 2] })
	end
	return swapped
end

-- Where the next distant drag comes from: a random direction off one random player
function Rearrange.dragSpot(
	players: { Point },
	distance: { Min: number, Max: number },
	roll: () -> number
): Point?
	if #players == 0 then
		return nil
	end
	local player = players[math.floor(roll() * #players) + 1]
	local angle = roll() * math.pi * 2
	local far = distance.Min + roll() * (distance.Max - distance.Min)
	return { x = player.x + math.cos(angle) * far, z = player.z + math.sin(angle) * far }
end

return Rearrange
