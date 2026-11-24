-- Seeded warehouse layout. Pure data: the server builds parts from it, other systems ask it
-- where rooms are and how deep a spot is. Local studs: x east, z south, (0, 0) is the floor centre,
-- the entrance is the middle of the south wall.
local Rng = require("./WarehouseGenRng")
local Rooms = require("./WarehouseGenRooms")

local WarehouseGen = {}

export type Shelf = { x0: number, x1: number, z: number, depth: number }
export type Sign = { x: number, z: number, number: number }
export type Box = { sx: number, sy: number, sz: number, x: number, y: number, z: number, turn: number }
export type Junk = { x: number, z: number, boxes: { Box } }
export type Loose = { name: string, x: number, z: number, turn: number }
export type Pillar = { x: number, z: number }
export type Decal = {
	name: string,
	kind: string,
	x: number,
	y: number,
	z: number,
	nx: number,
	nz: number,
	width: number,
	height: number,
}
export type Spawn = { x: number, z: number }
export type Layout = {
	seed: number,
	size: number,
	half: number,
	blockSize: number,
	blocks: number,
	entrance: { x: number, z: number },
	rooms: { Rooms.Room },
	shelves: { Shelf },
	signs: { Sign },
	junk: { Junk },
	loose: { Loose },
	pillars: { Pillar },
	decals: { Decal },
	spawns: { Spawn },
	shelvesByBlock: { [number]: { Shelf } },
}

local function blockIndex(layout: any, x: number, z: number): number
	local i = math.clamp(math.floor((x + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local j = math.clamp(math.floor((z + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	return j * layout.blocks + i + 1
end

local function inAnyRoom(rooms: { Rooms.Room }, x: number, z: number, pad: number): boolean
	for _, room in rooms do
		if Rooms.contains(room, x, z, pad) then
			return true
		end
	end
	return false
end

-- Pieces of [x0, x1] left after cutting out every room whose padded rect crosses the row's band
local function clipRow(rooms: { Rooms.Room }, x0: number, x1: number, z: number, depth: number, pad: number)
	local pieces = { { x0, x1 } }
	for _, room in rooms do
		if room.z0 - pad < z + depth / 2 and z - depth / 2 < room.z1 + pad then
			local cutFrom, cutTo = room.x0 - pad, room.x1 + pad
			local nextPieces = {}
			for _, piece in pieces do
				if cutTo <= piece[1] or cutFrom >= piece[2] then
					table.insert(nextPieces, piece)
				else
					if cutFrom > piece[1] then
						table.insert(nextPieces, { piece[1], cutFrom })
					end
					if cutTo < piece[2] then
						table.insert(nextPieces, { cutTo, piece[2] })
					end
				end
			end
			pieces = nextPieces
		end
	end
	return pieces
end

local function addShelves(
	layout: Layout,
	config: any,
	byBlock: { [number]: { Shelf } },
	bx0: number,
	bz0: number,
	rng: Rng.Rng
)
	local margin, block = config.BlockMargin, config.BlockSize
	local depth = config.ShelfDepth
	local z = bz0 + margin + depth / 2
	local first: Shelf? = nil
	while z + depth / 2 <= bz0 + block - margin do
		for _, piece in
			clipRow(layout.rooms, bx0 + margin, bx0 + block - margin, z, depth, config.RoomClearance)
		do
			if piece[2] - piece[1] >= config.ShelfMinLength then
				local shelf = { x0 = piece[1], x1 = piece[2], z = z, depth = depth }
				table.insert(layout.shelves, shelf)
				local key = blockIndex(layout, (shelf.x0 + shelf.x1) / 2, z)
				byBlock[key] = byBlock[key] or {}
				table.insert(byBlock[key], shelf)
				first = first or shelf
			end
		end
		z += config.ShelfPitch
	end
	if first then
		-- Numbers are random on purpose: the signs don't really help
		table.insert(layout.signs, { x = first.x0 - 3, z = first.z, number = rng:int(1, 99) })
	end
end

local function nearPillar(layout: Layout, config: any, x: number, z: number, pad: number): boolean
	local step = config.BlockSize * config.PillarEvery
	local function offGrid(v: number): number
		local rel = (v + layout.half) % step
		return math.min(rel, step - rel)
	end
	return offGrid(x) < config.PillarSize / 2 + pad and offGrid(z) < config.PillarSize / 2 + pad
end

local function spotFree(layout: Layout, config: any, x: number, z: number, pad: number): boolean
	return not inAnyRoom(layout.rooms, x, z, config.RoomClearance + pad)
		and not nearPillar(layout, config, x, z, pad)
end

local function addJunk(layout: Layout, config: any, rng: Rng.Rng, bx0: number, bz0: number, count: number)
	local inner = config.BlockMargin + 6
	for _ = 1, count do
		for _ = 1, 6 do
			local x = rng:range(bx0 + inner, bx0 + config.BlockSize - inner)
			local z = rng:range(bz0 + inner, bz0 + config.BlockSize - inner)
			if spotFree(layout, config, x, z, 4) then
				local boxes = {}
				local y = 0
				for _ = 1, rng:int(config.JunkBoxes[1], config.JunkBoxes[2]) do
					local sy = rng:range(1.6, 3.2)
					table.insert(boxes, {
						sx = rng:range(2, 4.5),
						sy = sy,
						sz = rng:range(2, 4),
						x = rng:range(-0.6, 0.6),
						y = y + sy / 2,
						z = rng:range(-0.6, 0.6),
						turn = rng:range(-25, 25),
					})
					y += sy
				end
				table.insert(layout.junk, { x = x, z = z, boxes = boxes })
				break
			end
		end
	end
end

local function addLoose(layout: Layout, config: any, rng: Rng.Rng, bx0: number, bz0: number, count: number)
	local inner = config.BlockMargin + 10
	for _ = 1, count do
		for _ = 1, 6 do
			local x = rng:range(bx0 + inner, bx0 + config.BlockSize - inner)
			local z = rng:range(bz0 + inner, bz0 + config.BlockSize - inner)
			if spotFree(layout, config, x, z, 6) then
				table.insert(
					layout.loose,
					{ name = rng:pick(config.LooseFurniture), x = x, z = z, turn = rng:range(0, 360) }
				)
				break
			end
		end
	end
end

local function addPillars(layout: Layout, config: any)
	local pad = config.PillarSize / 2 + config.RoomClearance
	for j = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
		for i = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
			local x = -layout.half + i * config.BlockSize
			local z = -layout.half + j * config.BlockSize
			if not inAnyRoom(layout.rooms, x, z, pad) then
				table.insert(layout.pillars, { x = x, z = z })
			end
		end
	end
end

-- A paintable face: centre (x, z), outward normal, and the face width available
local function decalSurface(layout: Layout, config: any, rng: Rng.Rng)
	local roll = rng:next()
	if roll < 0.5 and #layout.shelves > 0 then
		local shelf = rng:pick(layout.shelves)
		if rng:next() < 0.5 then
			return shelf.x0 - 0.06, shelf.z, -1, 0, shelf.depth
		end
		return shelf.x1 + 0.06, shelf.z, 1, 0, shelf.depth
	elseif roll < 0.75 and #layout.rooms > 0 then
		local room = rng:pick(layout.rooms)
		local wall = rng:pick(room.walls)
		local alongX = wall.x1 - wall.x0 > wall.z1 - wall.z0
		local length = if alongX then wall.x1 - wall.x0 else wall.z1 - wall.z0
		if length < 3 then
			return nil
		end
		if alongX then
			local x = rng:range(wall.x0 + 1.5, wall.x1 - 1.5)
			if wall.z0 == room.z0 then
				return x, room.z0 - 0.06, 0, -1, length
			end
			return x, room.z1 + 0.06, 0, 1, length
		end
		local z = rng:range(wall.z0 + 1.5, wall.z1 - 1.5)
		if wall.x0 == room.x0 then
			return room.x0 - 0.06, z, -1, 0, length
		end
		return room.x1 + 0.06, z, 1, 0, length
	elseif #layout.pillars > 0 then
		local pillar = rng:pick(layout.pillars)
		local faces = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
		local face = rng:pick(faces)
		local out = config.PillarSize / 2 + 0.06
		return pillar.x + face[1] * out, pillar.z + face[2] * out, face[1], face[2], config.PillarSize
	end
	return nil
end

local function addDecals(layout: Layout, config: any, rng: Rng.Rng)
	for _ = 1, config.DecalCount do
		local x, z, nx, nz, faceWidth = decalSurface(layout, config, rng)
		if x then
			local kind = rng:weighted(config.DecalKinds)
			local size = config.DecalSizes[kind]
			local scale = math.min(1, (faceWidth - 0.4) / size[1])
			local height = size[2] * scale
			table.insert(layout.decals, {
				name = rng:pick(config.DecalNames[kind]),
				kind = kind,
				x = x,
				y = rng:range(config.DecalHeight[1], config.DecalHeight[2]) + height / 2,
				z = z,
				nx = nx,
				nz = nz,
				width = size[1] * scale,
				height = height,
			})
		end
	end
end

-- True when a player standing here isn't inside a room, shelf, junk stack or pillar
function WarehouseGen.isClear(layout: Layout, config: any, x: number, z: number, pad: number): boolean
	local edge = layout.half - config.WallThickness - pad
	if math.abs(x) > edge or math.abs(z) > edge then
		return false
	end
	if not spotFree(layout, config, x, z, pad) then
		return false
	end
	for _, shelf in layout.shelvesByBlock[blockIndex(layout, x, z)] or {} do
		if
			x > shelf.x0 - pad
			and x < shelf.x1 + pad
			and z > shelf.z - shelf.depth / 2 - pad
			and z < shelf.z + shelf.depth / 2 + pad
		then
			return false
		end
	end
	return true
end

local function addSpawns(layout: Layout, config: any, rng: Rng.Rng)
	local pad = config.SpawnClearance
	local function nearestGap(x: number, z: number): number
		local best = math.huge
		for _, spawn in layout.spawns do
			best = math.min(best, math.sqrt((spawn.x - x) ^ 2 + (spawn.z - z) ^ 2))
		end
		return best
	end
	local function clearOfJunk(x: number, z: number): boolean
		for _, junk in layout.junk do
			if math.abs(junk.x - x) < pad + 4 and math.abs(junk.z - z) < pad + 4 then
				return false
			end
		end
		for _, item in layout.loose do
			if math.abs(item.x - x) < pad + 6 and math.abs(item.z - z) < pad + 6 then
				return false
			end
		end
		return true
	end

	local rounds = 0
	while #layout.spawns < config.SpawnCount and rounds < config.SpawnCount * 20 do
		rounds += 1
		-- Best of several candidates: the one furthest from everyone already placed
		local bestX, bestZ, bestGap = nil, nil, -1
		local found, tries = 0, 0
		while found < config.SpawnCandidates and tries < config.SpawnCandidates * 20 do
			tries += 1
			local x = rng:range(-layout.half, layout.half)
			local z = rng:range(-layout.half, layout.half)
			if WarehouseGen.isClear(layout, config, x, z, pad) and clearOfJunk(x, z) then
				found += 1
				local gap = nearestGap(x, z)
				if gap > bestGap then
					bestX, bestZ, bestGap = x, z, gap
				end
			end
		end
		if bestX and bestGap >= config.SpawnMinGap then
			table.insert(layout.spawns, { x = bestX, z = bestZ :: number })
		end
	end
end

function WarehouseGen.generate(config: any, seed: number): Layout
	local rng = Rng.new(seed)
	local half = config.Size / 2
	local blocks = math.floor(config.Size / config.BlockSize)
	local layout: any = {
		seed = seed,
		size = config.Size,
		half = half,
		blockSize = config.BlockSize,
		blocks = blocks,
		entrance = { x = 0, z = half },
		rooms = {},
		shelves = {},
		signs = {},
		junk = {},
		loose = {},
		pillars = {},
		decals = {},
		spawns = {},
	}

	local inset = config.WallThickness + config.BlockMargin * 2
	layout.rooms = Rooms.place(
		config,
		rng,
		{ x0 = -half + inset, z0 = -half + inset, x1 = half - inset, z1 = half - inset },
		{ x = 0, z = half, radius = config.BlockSize * 1.5 }
	)

	local byBlock = {}
	for j = 0, blocks - 1 do
		for i = 0, blocks - 1 do
			local bx0, bz0 = -half + i * config.BlockSize, -half + j * config.BlockSize
			local kind = rng:weighted(config.BlockKinds)
			if kind == "aisles" then
				addShelves(layout, config, byBlock, bx0, bz0, rng)
			elseif kind == "open" then
				addJunk(layout, config, rng, bx0, bz0, rng:int(config.OpenJunk[1], config.OpenJunk[2]))
				addLoose(layout, config, rng, bx0, bz0, rng:int(config.OpenLoose[1], config.OpenLoose[2]))
			else
				addJunk(layout, config, rng, bx0, bz0, rng:int(config.EmptyJunk[1], config.EmptyJunk[2]))
			end
		end
	end
	layout.shelvesByBlock = byBlock

	addPillars(layout, config)
	addDecals(layout, config, rng)
	addSpawns(layout, config, rng)
	return layout
end

-- 0 at the entrance, 1 at the far corners. Better loot goes deeper.
function WarehouseGen.depth(layout: Layout, x: number, z: number): number
	local far = math.sqrt(layout.half ^ 2 + layout.size ^ 2)
	local distance = math.sqrt((x - layout.entrance.x) ^ 2 + (z - layout.entrance.z) ^ 2)
	return math.clamp(distance / far, 0, 1)
end

function WarehouseGen.roomAt(layout: Layout, x: number, z: number): Rooms.Room?
	for _, room in layout.rooms do
		if Rooms.contains(room, x, z, 0) then
			return room
		end
	end
	return nil
end

return WarehouseGen
