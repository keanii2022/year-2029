-- Fills the open floor of an installation set once its own pieces are down: little furniture
-- groupings, heaps of the human stuff the robots collected, benches where they study it, each
-- under a bare bulb on a long cord. Big overhead, tight underfoot. Groups only go where the set
-- left floor free (no walls, water, hedges or furniture) and keep clear of the doorways.
-- Uses its own random source per room so it never reshuffles the rest of the layout.
local Pieces = if script then require(script.Parent.WarehouseGenPieces) else require("./WarehouseGenPieces")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Fill = {}

-- A keep-out: a box (half sizes hx, hz) grown by r, or a plain circle when hx = hz = 0
type Block = { x: number, z: number, r: number, hx: number, hz: number }
type Frame = { x: number, z: number, quarter: number }

local piece = Pieces.piece

-- Furniture by group, in the group's own frame: +z is its open front. f = the way it faces.
local GROUPS = {
	sitting = {
		{ "rug", 0, 0, 0, 1 },
		{ "couch", 0, -4, 0, 1 },
		{ "armchair", 4.8, -0.5, -1, 0 },
		{ "coffee_table", 0, 0, 0, 1 },
		{ "floor_lamp", -4.8, -4, 0, 1 },
		{ "crt_tv", 0, 4.8, 0, -1 },
	},
	bedroom = {
		{ "bed", 0, -1.5, 0, 1 },
		{ "nightstand", 4, -4, 0, 1 },
		{ "dresser", -4.5, -4, 0, 1 },
		{ "toy_chest", 0, 4.5, 0, -1 },
	},
	kitchen = {
		{ "kitchen_table", 0, 0, 0, 1 },
		{ "kitchen_chair", 0, -2.6, 0, 1 },
		{ "kitchen_chair", 0, 2.6, 0, -1 },
		{ "fridge", -5, -2, 1, 0 },
		{ "counter", 5, -2, -1, 0 },
	},
	office = {
		{ "desk", 0, -1, 0, 1 },
		{ "office_chair", 0, 1.8, 0, -1 },
		{ "filing_cabinet", -4, -1.2, 0, 1 },
		{ "bookshelf", 4.2, -2, -1, 0 },
	},
	-- Where a robot takes things apart to work out what they're for
	study = {
		{ "arm_bench", 0, -3, 0, 1 },
		{ "whiteboard", 0, -6, 0, 1 },
		{ "mannequin", -4.5, 1, 1, 0 },
	},
	-- The robots' hoard: a chest and a heap of the stuff they took off people
	hoard = {
		{ "toy_chest", 0, -3.5, 0, 1 },
	},
}
local GROUP_NAMES = { "sitting", "bedroom", "kitchen", "office", "study", "hoard", "hoard", "study" }

local function rotate(frame: Frame, dx: number, dz: number): (number, number)
	local q = frame.quarter
	if q == 1 then
		return dz, -dx
	elseif q == 2 then
		return -dx, -dz
	elseif q == 3 then
		return -dz, dx
	end
	return dx, dz
end

local function toWorld(frame: Frame, dx: number, dz: number): (number, number)
	local rx, rz = rotate(frame, dx, dz)
	return frame.x + rx, frame.z + rz
end

-- A model robots treat as room furniture: they study it, stash by it, loot spawns in front of it
local function furniture(
	layout: any,
	room: any,
	frame: Frame,
	name: string,
	dx: number,
	dz: number,
	fx: number,
	fz: number
)
	local x, z = toWorld(frame, dx, dz)
	local nx, nz = rotate(frame, fx, fz)
	table.insert(room.items, { name = name, x = x, z = z, nx = nx, nz = nz })
	layout.addSolid({ x0 = x - 2, x1 = x + 2, z0 = z - 2, z1 = z + 2 })
end

local function smallThing(layout: any, rng: Rng.Rng, settings: any, x: number, z: number)
	table.insert(
		layout.loose,
		{ name = rng:pick(settings.HumanStuff), x = x, z = z, turn = rng:range(0, 360) }
	)
end

-- Small finds laid out in a dead straight row, the way something that doesn't understand them would
local function studyRow(layout: any, rng: Rng.Rng, settings: any, frame: Frame)
	for n = -2, 2 do
		local x, z = toWorld(frame, n * 1.5, 0.5)
		smallThing(layout, rng, settings, x, z)
	end
end

local function heap(layout: any, rng: Rng.Rng, settings: any, frame: Frame)
	for n = 1, rng:int(settings.HeapSize[1], settings.HeapSize[2]) do
		local angle = n * 2.4
		local reach = 0.6 + n * 0.28
		local x, z = toWorld(frame, math.cos(angle) * reach, 0.8 + math.sin(angle) * reach)
		smallThing(layout, rng, settings, x, z)
	end
	local x, z = toWorld(frame, 4, -2.5)
	Pieces.junkStack(layout, rng, x, z, rng:int(2, 4), false)
end

-- A bare bulb on a cord from the ceiling: the group's own pool of light, day and night
local function bulb(layout: any, settings: any, x: number, z: number, ceiling: number)
	local y = math.min(settings.BulbHeight, ceiling - 2)
	piece(layout, {
		x = x,
		y = y,
		z = z,
		sx = 0.6,
		sy = 0.6,
		sz = 0.6,
		style = "lamp_bulb",
		collide = false,
		lamp = settings.BulbTone,
	})
	local cord = ceiling - y - 0.3
	if cord > 0.5 then
		piece(layout, {
			x = x,
			y = y + 0.3 + cord / 2,
			z = z,
			sx = 0.08,
			sy = cord,
			sz = 0.08,
			style = "cable",
			collide = false,
		})
	end
end

-- Low, solid things the set already put down: anything a group would end up inside
local function blockers(layout: any, room: any, from: number): { Block }
	local list = {}
	for index = from, #layout.pieces do
		local spec = layout.pieces[index]
		local bottom = spec.y - spec.sy / 2
		local blocks = spec.solid or spec.collide or spec.style == "water"
		local floorSheet = spec.sy <= 0.3 and spec.y < 0.6
		if blocks and not floorSheet and bottom < 3 then
			local reach = if spec.turn % 90 == 0 then nil else math.sqrt(spec.sx ^ 2 + spec.sz ^ 2) / 2
			local wide = if spec.turn % 180 == 0 then spec.sx else spec.sz
			local deep = if spec.turn % 180 == 0 then spec.sz else spec.sx
			table.insert(list, {
				x = spec.x,
				z = spec.z,
				r = 0,
				hx = reach or wide / 2,
				hz = reach or deep / 2,
			})
		end
	end
	for _, thing in room.items do
		table.insert(list, { x = thing.x, z = thing.z, r = 3, hx = 0, hz = 0 })
	end
	for _, thing in layout.loose do
		if thing.x > room.x0 and thing.x < room.x1 and thing.z > room.z0 and thing.z < room.z1 then
			table.insert(list, { x = thing.x, z = thing.z, r = 3, hx = 0, hz = 0 })
		end
	end
	return list
end

local function overlaps(block: Block, x: number, z: number, radius: number): boolean
	local dx = math.max(math.abs(x - block.x) - block.hx, 0)
	local dz = math.max(math.abs(z - block.z) - block.hz, 0)
	return dx * dx + dz * dz < (radius + block.r) ^ 2
end

local function free(list: { Block }, x: number, z: number, radius: number): boolean
	for _, block in list do
		if overlaps(block, x, z, radius) then
			return false
		end
	end
	return true
end

-- doorways: { {x, z} } of the set's own doors, kept clear so the way in is never plugged
function Fill.room(
	layout: any,
	config: any,
	room: any,
	from: number,
	ceiling: number,
	doorways: { { number } }
)
	local settings = config.InstallationFill
	if settings.Skip[room.kind] then
		return
	end
	local rng = Rng.new(layout.seed + room.id * 7919)
	local list = blockers(layout, room, from)
	for _, door in doorways do
		table.insert(list, { x = door[1], z = door[2], r = settings.DoorClearance, hx = 0, hz = 0 })
	end
	local area = (room.x1 - room.x0) * (room.z1 - room.z0)
	local want = math.clamp(math.floor(area / settings.AreaPerGroup), settings.Groups[1], settings.Groups[2])
	local radius = settings.GroupRadius
	local pad = radius + 1
	if room.x1 - room.x0 < pad * 2 or room.z1 - room.z0 < pad * 2 then
		return
	end
	local placed, tries = 0, 0
	while placed < want and tries < want * settings.TriesPerGroup do
		tries += 1
		local x = rng:range(room.x0 + pad, room.x1 - pad)
		local z = rng:range(room.z0 + pad, room.z1 - pad)
		if free(list, x, z, radius) then
			placed += 1
			local frame: Frame = { x = x, z = z, quarter = rng:int(0, 3) }
			local kind = GROUP_NAMES[(placed + room.id) % #GROUP_NAMES + 1]
			for _, entry in GROUPS[kind] do
				furniture(layout, room, frame, entry[1], entry[2], entry[3], entry[4], entry[5])
			end
			if kind == "study" then
				studyRow(layout, rng, settings, frame)
			elseif kind == "hoard" then
				heap(layout, rng, settings, frame)
			end
			if rng:next() < settings.CarryLightChance then
				local lx, lz = toWorld(frame, -radius + 1, radius - 1)
				table.insert(layout.loose, {
					name = rng:pick(config.NightLights.CarryLights),
					x = lx,
					z = lz,
					turn = rng:range(0, 360),
				})
			end
			bulb(layout, settings, x, z, ceiling)
			-- Groups sit close but never touch: tight underfoot, still room to walk between
			table.insert(list, { x = x, z = z, r = radius + settings.GroupGap, hx = 0, hz = 0 })
		end
	end
end

return Fill
