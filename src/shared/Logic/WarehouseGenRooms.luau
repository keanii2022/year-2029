-- Rooms: walled rectangles with doorways cut in. Robot rooms are the installation sets
-- (WarehouseGenInstallations). Coordinates are warehouse-local studs.
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
function WarehouseGenRooms.overlaps(a: any, b: any, pad: number): boolean
	return a.x0 - pad < b.x1 and b.x0 < a.x1 + pad and a.z0 - pad < b.z1 and b.z0 < a.z1 + pad
end

function WarehouseGenRooms.contains(room: any, x: number, z: number, pad: number): boolean
	return x > room.x0 - pad and x < room.x1 + pad and z > room.z0 - pad and z < room.z1 + pad
end

-- Length of a side and the coordinate it starts from
local function sideSpan(room: any, side: string): (number, number)
	if side == "north" or side == "south" then
		return room.x1 - room.x0, room.x0
	end
	return room.z1 - room.z0, room.z0
end

local function doorsOn(room: any, side: string): { Door }
	local found = {}
	for _, door in room.doors do
		if door.side == side then
			table.insert(found, door)
		end
	end
	return found
end

-- Wall strips with the doorway gaps cut out. North/south run the full width; west/east fit between.
function WarehouseGenRooms.walls(room: any, thickness: number, doorWidth: number): { Wall }
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

-- One or two doorways on random sides, kept clear of the corners
function WarehouseGenRooms.doors(room: any, rng: Rng.Rng, doorWidth: number, thickness: number, count: number)
	local doors = {}
	local sides = rng:shuffle(SIDES)
	for i = 1, count do
		local length = sideSpan(room, sides[i])
		local edge = doorWidth / 2 + thickness + 2
		table.insert(doors, { side = sides[i], at = math.floor(rng:range(edge, length - edge)) })
	end
	return doors
end

return WarehouseGenRooms
