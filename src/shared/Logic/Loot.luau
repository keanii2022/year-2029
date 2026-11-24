-- World loot: what a pickup holds at a given depth, and where pickups go on the warehouse floor.
-- Seeded through WarehouseGenRng so a restock comes out the same for the same seed.
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")
local WarehouseGen = if script then require(script.Parent.WarehouseGen) else require("./WarehouseGen")

local Loot = {}

export type Entry = {
	item: string,
	model: string,
	count: { number },
	near: number,
	deep: number,
	minDepth: number?,
}
export type Roll = { item: string, model: string, count: number }
export type Spot = { x: number, z: number, depth: number }

-- Weight of an entry at depth 0..1: slides from near to deep, zero below minDepth.
function Loot.weightAt(entry: Entry, depth: number): number
	if depth < (entry.minDepth or 0) then
		return 0
	end
	local d = math.clamp(depth, 0, 1)
	return math.max(0, entry.near + (entry.deep - entry.near) * d)
end

function Loot.roll(entries: { Entry }, depth: number, rng: Rng.Rng): Roll?
	local total = 0
	for _, entry in entries do
		total += Loot.weightAt(entry, depth)
	end
	if total <= 0 then
		return nil
	end
	local pick = rng:next() * total
	for _, entry in entries do
		local weight = Loot.weightAt(entry, depth)
		if weight > 0 then
			pick -= weight
			if pick < 0 then
				return {
					item = entry.item,
					model = entry.model,
					count = rng:int(entry.count[1], entry.count[2]),
				}
			end
		end
	end
	return nil
end

-- Clear floor spots (not in a room, shelf, pillar or wall) scattered over the whole warehouse.
function Loot.floorSpots(
	layout: any,
	warehouseConfig: any,
	rng: Rng.Rng,
	count: number,
	tries: number,
	pad: number
): { Spot }
	local spots = {}
	local edge = layout.half - warehouseConfig.WallThickness - pad
	for _ = 1, count do
		for _ = 1, tries do
			local x, z = rng:range(-edge, edge), rng:range(-edge, edge)
			if WarehouseGen.isClear(layout, warehouseConfig, x, z, pad) then
				table.insert(spots, { x = x, z = z, depth = WarehouseGen.depth(layout, x, z) })
				break
			end
		end
	end
	return spots
end

-- At most one spot per robot room, beside its centre, rolled bonus deeper than where it stands.
function Loot.roomSpots(layout: any, rng: Rng.Rng, chance: number, depthBonus: number): { Spot }
	local spots = {}
	for _, room in layout.rooms do
		if rng:next() < chance then
			local x = room.cx + rng:range(-1, 1) * (room.x1 - room.x0) * 0.25
			local z = room.cz + rng:range(-1, 1) * (room.z1 - room.z0) * 0.25
			local depth = math.min(1, WarehouseGen.depth(layout, x, z) + depthBonus)
			table.insert(spots, { x = x, z = z, depth = depth })
		end
	end
	return spots
end

return Loot
