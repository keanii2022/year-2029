-- Seeded warehouse layout. Pure data: the server builds parts from it, other systems ask it
-- where rooms are, how deep a spot is and whether a spot is clear. Local studs: x east, z south,
-- (0, 0) is the floor centre, the entrance is the middle of the south wall.
-- The floor is a grid of square zones split by cross aisles; each zone gets one kind of content
-- (see WarehouseGenZones). Giant pillars stand on every other cross aisle corner.
local NightLights = if script
	then require(script.Parent.WarehouseGenNightLights)
	else require("./WarehouseGenNightLights")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")
local Rooms = if script then require(script.Parent.WarehouseGenRooms) else require("./WarehouseGenRooms")
local Zones = if script then require(script.Parent.WarehouseGenZones) else require("./WarehouseGenZones")
local Clutter = if script
	then require(script.Parent.WarehouseGenClutter)
	else require("./WarehouseGenClutter")

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
export type Zone = { i: number, j: number, kind: string, x0: number, z0: number, x1: number, z1: number }
export type Light = {
	x: number,
	y: number,
	z: number,
	length: number,
	axis: string,
	tone: string,
	state: string,
	cable: number,
}
export type Piece = {
	shape: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	turn: number,
	style: string,
	solid: boolean?,
	collide: boolean,
	label: string?,
	paint: string?,
	lamp: string?,
	lean: number?,
	kit: string?,
	kitOnly: boolean?,
	skipIfKit: string?,
	kitFloor: string?,
	flicker: boolean?,
}
export type Pocket = {
	kind: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	height: number,
	doors: { Rooms.Door }?,
}
export type DeptSign = { x: number, z: number, y: number, text: string }
export type Solid = { x0: number, z0: number, x1: number, z1: number, room: boolean? }
export type Layout = {
	seed: number,
	size: number,
	half: number,
	blockSize: number,
	blocks: number,
	entrance: { x: number, z: number },
	zones: { Zone },
	rooms: { Rooms.Room },
	shelves: { Shelf },
	signs: { Sign },
	junk: { Junk },
	loose: { Loose },
	pillars: { Pillar },
	decals: { Decal },
	spawns: { Spawn },
	lights: { Light },
	pieces: { Piece },
	pockets: { Pocket },
	deptSigns: { DeptSign },
	solidsByBlock: { [number]: { Solid } },
}

local function blockIndex(layout: any, x: number, z: number): number
	local i = math.clamp(math.floor((x + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local j = math.clamp(math.floor((z + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	return j * layout.blocks + i + 1
end

-- Every block a rect touches gets it, so a spot check only has to look in its own block
local function addSolid(layout: any, solid: Solid)
	local i0 = math.clamp(math.floor((solid.x0 + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local i1 = math.clamp(math.floor((solid.x1 + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local j0 = math.clamp(math.floor((solid.z0 + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local j1 = math.clamp(math.floor((solid.z1 + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	for j = j0, j1 do
		for i = i0, i1 do
			local key = j * layout.blocks + i + 1
			layout.solidsByBlock[key] = layout.solidsByBlock[key] or {}
			table.insert(layout.solidsByBlock[key], solid)
		end
	end
end

-- Plans every zone before anything is built, so nothing clumps: the special kinds never sit right
-- next to the same kind, long runs of racking get broken up, and now and then an installation
-- swallows a 2 by 2 block of zones and becomes something enormous.
local function planZones(layout: any, config: any, rng: Rng.Rng): { [number]: any }
	local blocks = layout.blocks
	local plan = {} -- The block you walk in through is always a store department
	local entranceI = math.floor((layout.entrance.x + layout.half) / config.BlockSize)
	plan[(blocks - 1) * blocks + entranceI + 1] =
		{ kind = "showroom", i0 = entranceI, j0 = blocks - 1, i1 = entranceI, j1 = blocks - 1, owner = true } -- An installation set nobody has used within InstallationRepeatGap zones, so a repeat is never
	-- in sight
	local function pickSet(i: number, j: number, weights: any?): string
		local gap = config.InstallationRepeatGap
		local set
		for _ = 1, 10 do
			set = rng:weighted(weights or config.InstallationKinds)
			local repeated = false
			for nj = math.max(0, j - gap), math.min(blocks - 1, j + gap) do
				for ni = math.max(0, i - gap), math.min(blocks - 1, i + gap) do
					local other = plan[nj * blocks + ni + 1]
					if other and other.set == set then
						repeated = true
					end
				end
			end
			if not repeated then
				break
			end
		end
		return set
	end

	-- True when a block already planned on any side (outside the given giant, if any) is this kind
	local function besideSame(i: number, j: number, kind: string, own: any?): boolean
		for _, step in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
			local ni, nj = i + step[1], j + step[2]
			if ni >= 0 and nj >= 0 and ni < blocks and nj < blocks then
				local other = plan[nj * blocks + ni + 1]
				local mine = own and ni >= own.i0 and ni <= own.i1 and nj >= own.j0 and nj <= own.j1
				if other and other.kind == kind and not mine then
					return true
				end
			end
		end
		return false
	end
	for j = 0, blocks - 1 do
		for i = 0, blocks - 1 do
			local key = j * blocks + i + 1
			if not plan[key] then
				local left = if i > 0 then plan[key - 1] else nil
				local up = if j > 0 then plan[key - blocks] else nil
				local kind
				do
					for _ = 1, 8 do
						kind = rng:weighted(config.ZoneKinds)
						local ok = if config.ZoneSpread[kind]
							then not besideSame(i, j, kind)
							elseif
								kind == "racking"
								and left
								and up
								and left.kind == kind
								and up.kind == kind
							then rng:next() < config.RackRunChance
							else true
						if ok then
							break
						end
					end
				end
				local entry: any = { kind = kind, i0 = i, j0 = j, i1 = i, j1 = j, owner = true }
				local canGrow = i + 1 < blocks
					and j + 1 < blocks
					and not plan[key + 1]
					and not plan[key + blocks]
					and not plan[key + blocks + 1]
				local giant = { i0 = i, j0 = j, i1 = i + 1, j1 = j + 1 }
				local roomAround = canGrow
					and not besideSame(i + 1, j, kind, giant)
					and not besideSame(i, j + 1, kind, giant)
					and not besideSame(i + 1, j + 1, kind, giant)
				if kind == "installation" and roomAround and rng:next() < config.MegaChance then
					entry.i1, entry.j1 = i + 1, j + 1
					entry.set = pickSet(i, j, config.MegaInstallationKinds)
					for _, other in { key + 1, key + blocks, key + blocks + 1 } do
						plan[other] = {
							kind = kind,
							i0 = i,
							j0 = j,
							i1 = i + 1,
							j1 = j + 1,
							owner = false,
							set = entry.set,
						}
					end
				end
				if kind == "installation" and not entry.set then
					entry.set = pickSet(i, j)
				end
				plan[key] = entry
			end
		end
	end
	return plan
end

local function addPillars(layout: Layout, config: any, plan: { [number]: any })
	local half = config.PillarSize / 2
	for j = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
		for i = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
			-- No pillar in the middle of a merged giant installation
			local inside = plan[j * layout.blocks + i + 1]
			if inside and inside.i0 < i and inside.j0 < j then
				continue
			end
			local x = -layout.half + i * config.BlockSize
			local z = -layout.half + j * config.BlockSize
			table.insert(layout.pillars, { x = x, z = z })
			addSolid(layout, { x0 = x - half, x1 = x + half, z0 = z - half, z1 = z + half })
		end
	end
end

-- A paintable face: centre (x, z), outward normal, and the face width available
local function decalSurface(layout: Layout, config: any, rng: Rng.Rng)
	local roll = rng:next()
	if roll < 0.45 and #layout.shelves > 0 then
		local shelf = rng:pick(layout.shelves)
		if rng:next() < 0.5 then
			return shelf.x0 - 0.06, shelf.z, -1, 0, shelf.depth
		end
		return shelf.x1 + 0.06, shelf.z, 1, 0, shelf.depth
	elseif roll < 0.65 and #layout.rooms > 0 then
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
	elseif roll < 0.8 and #layout.pockets > 0 then
		local pocket = rng:pick(layout.pockets)
		local face = rng:int(1, 4)
		if face == 1 then
			return rng:range(pocket.x0 + 2, pocket.x1 - 2), pocket.z0 - 0.06, 0, -1, pocket.x1 - pocket.x0
		elseif face == 2 then
			return rng:range(pocket.x0 + 2, pocket.x1 - 2), pocket.z1 + 0.06, 0, 1, pocket.x1 - pocket.x0
		elseif face == 3 then
			return pocket.x0 - 0.06, rng:range(pocket.z0 + 2, pocket.z1 - 2), -1, 0, pocket.z1 - pocket.z0
		end
		return pocket.x1 + 0.06, rng:range(pocket.z0 + 2, pocket.z1 - 2), 1, 0, pocket.z1 - pocket.z0
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

-- True when a player standing here isn't inside a wall, rack, junk stack, pillar or room
function WarehouseGen.isClear(layout: Layout, config: any, x: number, z: number, pad: number): boolean
	local edge = layout.half - config.WallThickness - pad
	if math.abs(x) > edge or math.abs(z) > edge then
		return false
	end
	for _, solid in layout.solidsByBlock[blockIndex(layout, x, z)] or {} do
		local grow = if solid.room then pad + config.RoomClearance else pad
		if x > solid.x0 - grow and x < solid.x1 + grow and z > solid.z0 - grow and z < solid.z1 + grow then
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
			if WarehouseGen.isClear(layout, config, x, z, pad) then
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
		zones = {},
		rooms = {},
		shelves = {},
		signs = {},
		junk = {},
		loose = {},
		pillars = {},
		decals = {},
		spawns = {},
		lights = {},
		pieces = {},
		pockets = {},
		deptSigns = {},
		solidsByBlock = {},
	}
	layout.addSolid = function(solid: Solid)
		addSolid(layout, solid)
	end

	local plan = planZones(layout, config, rng)
	addPillars(layout, config, plan)
	local margin = config.BlockMargin
	local size = config.BlockSize
	for key = 1, blocks * blocks do
		local entry = plan[key]
		local i, j = (key - 1) % blocks, (key - 1) // blocks
		local rect = {
			x0 = -half + entry.i0 * size + margin,
			z0 = -half + entry.j0 * size + margin,
			x1 = -half + (entry.i1 + 1) * size - margin,
			z1 = -half + (entry.j1 + 1) * size - margin,
		}
		-- The outermost ring keeps clear of the outer wall
		if entry.i0 == 0 then
			rect.x0 += config.WallThickness
		end
		if entry.j0 == 0 then
			rect.z0 += config.WallThickness
		end
		if entry.i1 == blocks - 1 then
			rect.x1 -= config.WallThickness
		end
		if entry.j1 == blocks - 1 then
			rect.z1 -= config.WallThickness
		end
		if entry.owner then
			Zones[entry.kind](layout, config, rng, rect, entry.set)
		end
		table.insert(
			layout.zones,
			{ i = i, j = j, kind = entry.kind, x0 = rect.x0, z0 = rect.z0, x1 = rect.x1, z1 = rect.z1 }
		)
	end
	Clutter.fill(layout, config, rng, WarehouseGen.zoneAt, WarehouseGen.isClear)
	NightLights.fill(layout, config, WarehouseGen.isClear)
	addDecals(layout, config, rng)
	addSpawns(layout, config, rng)
	layout.addSolid = nil
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

function WarehouseGen.zoneAt(layout: Layout, x: number, z: number): Zone?
	local i = math.floor((x + layout.half) / layout.blockSize)
	local j = math.floor((z + layout.half) / layout.blockSize)
	if i < 0 or j < 0 or i >= layout.blocks or j >= layout.blocks then
		return nil
	end
	return layout.zones[j * layout.blocks + i + 1]
end

function WarehouseGen.pocketAt(layout: Layout, x: number, z: number): Pocket?
	for _, pocket in layout.pockets do
		if x > pocket.x0 and x < pocket.x1 and z > pocket.z0 and z < pocket.z1 then
			return pocket
		end
	end
	return nil
end

return WarehouseGen
