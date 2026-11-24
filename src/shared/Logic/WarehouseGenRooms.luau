-- Robot rooms: scattered off-grid rectangles with walls, one or two doorways, a rug, a lamp and
-- furniture backed against the inside walls. Coordinates are warehouse-local studs (x, z).
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local WarehouseGenRooms = {}

export type Item = { name: string, x: number, z: number, nx: number, nz: number }
export type Wall = { x0: number, z0: number, x1: number, z1: number }
export type Door = { side: string, at: number }
export type Room = {
	id: number,
	kind: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	cx: number,
	cz: number,
	doors: { Door },
	walls: { Wall },
	items: { Item },
}

local SIDES = { "north", "south", "west", "east" }
-- Inward normal per side
local INWARD = {
	north = { 0, 1 },
	south = { 0, -1 },
	west = { 1, 0 },
	east = { -1, 0 },
}

function WarehouseGenRooms.overlaps(a: any, b: any, pad: number): boolean
	return a.x0 - pad < b.x1 and b.x0 < a.x1 + pad and a.z0 - pad < b.z1 and b.z0 < a.z1 + pad
end

function WarehouseGenRooms.contains(room: any, x: number, z: number, pad: number): boolean
	return x > room.x0 - pad and x < room.x1 + pad and z > room.z0 - pad and z < room.z1 + pad
end

-- Length of a side and the coordinate it starts from
local function sideSpan(room: Room, side: string): (number, number)
	if side == "north" or side == "south" then
		return room.x1 - room.x0, room.x0
	end
	return room.z1 - room.z0, room.z0
end

local function doorsOn(room: Room, side: string): { Door }
	local found = {}
	for _, door in room.doors do
		if door.side == side then
			table.insert(found, door)
		end
	end
	return found
end

-- Wall strips with the doorway gaps cut out. North/south run the full width; west/east fit between.
local function buildWalls(room: Room, thickness: number, doorWidth: number): { Wall }
	local walls = {}
	for _, side in SIDES do
		local length, start = sideSpan(room, side)
		local from, to = start, start + length
		if side == "west" or side == "east" then
			from, to = from + thickness, to - thickness
		end
		local cuts = {}
		for _, door in doorsOn(room, side) do
			table.insert(cuts, { start + door.at - doorWidth / 2, start + door.at + doorWidth / 2 })
		end
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local pieces = {}
		local cursor = from
		for _, cut in cuts do
			if cut[1] > cursor then
				table.insert(pieces, { cursor, cut[1] })
			end
			cursor = math.max(cursor, cut[2])
		end
		if to > cursor then
			table.insert(pieces, { cursor, to })
		end
		for _, piece in pieces do
			if side == "north" then
				table.insert(walls, { x0 = piece[1], x1 = piece[2], z0 = room.z0, z1 = room.z0 + thickness })
			elseif side == "south" then
				table.insert(walls, { x0 = piece[1], x1 = piece[2], z0 = room.z1 - thickness, z1 = room.z1 })
			elseif side == "west" then
				table.insert(walls, { x0 = room.x0, x1 = room.x0 + thickness, z0 = piece[1], z1 = piece[2] })
			else
				table.insert(walls, { x0 = room.x1 - thickness, x1 = room.x1, z0 = piece[1], z1 = piece[2] })
			end
		end
	end
	return walls
end

-- Spots on the inside face of each wall, clear of the doorways
local function wallSlots(room: Room, config: any): { Item }
	local spacing = config.RoomSlotSpacing
	local thickness = config.RoomWallThickness
	local slots = {}
	for _, side in SIDES do
		local length, start = sideSpan(room, side)
		local normal = INWARD[side]
		local along = thickness + spacing / 2
		while along <= length - thickness - spacing / 2 do
			local blocked = false
			for _, door in doorsOn(room, side) do
				if math.abs(along - door.at) < config.RoomDoorWidth / 2 + spacing / 2 then
					blocked = true
				end
			end
			if not blocked then
				local x, z
				if side == "north" then
					x, z = start + along, room.z0 + thickness
				elseif side == "south" then
					x, z = start + along, room.z1 - thickness
				elseif side == "west" then
					x, z = room.x0 + thickness, start + along
				else
					x, z = room.x1 - thickness, start + along
				end
				table.insert(slots, { name = "", x = x, z = z, nx = normal[1], nz = normal[2] })
			end
			along += spacing
		end
	end
	return slots
end

local function furnish(room: Room, config: any, rng: Rng.Rng)
	local slots = rng:shuffle(wallSlots(room, config))
	local items: { Item } = {}
	table.insert(items, { name = config.RoomRug, x = room.cx, z = room.cz, nx = 0, nz = 1 })
	if #slots == 0 then
		return items
	end
	local lamp = slots[1]
	lamp.name = config.RoomLamp
	table.insert(items, lamp)

	local pool = rng:shuffle(config.RoomFurniture[room.kind])
	local count = math.min(rng:int(config.RoomItems[1], config.RoomItems[2]), #slots - 1)
	for i = 1, count do
		local slot = slots[i + 1]
		slot.name = pool[(i - 1) % #pool + 1]
		table.insert(items, slot)
	end
	return items
end

-- Rooms scattered inside bounds (a rect), kept RoomGap apart and away from keepOut ({ x, z, radius })
function WarehouseGenRooms.place(
	config: any,
	rng: Rng.Rng,
	bounds: Wall,
	keepOut: { x: number, z: number, radius: number }
): { Room }
	local rooms: { Room } = {}
	local attempts = 0
	while #rooms < config.RoomCount and attempts < config.RoomCount * 30 do
		attempts += 1
		local width = math.floor(rng:range(config.RoomMinSize, config.RoomMaxSize))
		local depth = math.floor(rng:range(config.RoomMinSize, config.RoomMaxSize))
		local x0 = math.floor(rng:range(bounds.x0, bounds.x1 - width))
		local z0 = math.floor(rng:range(bounds.z0, bounds.z1 - depth))
		local room: any = { x0 = x0, z0 = z0, x1 = x0 + width, z1 = z0 + depth }
		room.cx, room.cz = x0 + width / 2, z0 + depth / 2

		local clear = math.sqrt((room.cx - keepOut.x) ^ 2 + (room.cz - keepOut.z) ^ 2) > keepOut.radius
		if clear then
			for _, other in rooms do
				if WarehouseGenRooms.overlaps(room, other, config.RoomGap) then
					clear = false
					break
				end
			end
		end
		if clear then
			room.id = #rooms + 1
			room.kind = rng:weighted(config.RoomKinds)
			room.doors = {}
			local sides = rng:shuffle(SIDES)
			for i = 1, rng:int(1, 2) do
				local length = sideSpan(room, sides[i])
				local edge = config.RoomDoorWidth / 2 + config.RoomWallThickness + 2
				table.insert(room.doors, { side = sides[i], at = math.floor(rng:range(edge, length - edge)) })
			end
			room.walls = buildWalls(room, config.RoomWallThickness, config.RoomDoorWidth)
			room.items = furnish(room, config, rng)
			table.insert(rooms, room)
		end
	end
	return rooms
end

return WarehouseGenRooms
