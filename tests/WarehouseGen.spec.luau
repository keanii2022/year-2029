local Rng = require("../src/shared/Logic/WarehouseGenRng")
local Rooms = require("../src/shared/Logic/WarehouseGenRooms")
local WarehouseGen = require("../src/shared/Logic/WarehouseGen")
local expect = require("./expect")

-- Mirrors the layout numbers in Config/Warehouse (that file holds Roblox types Lune can't load)
local config = {
	Size = 8000,
	WallThickness = 8,
	BlockSize = 200,
	BlockMargin = 12,
	BlockKinds = { aisles = 40, open = 35, empty = 25 },
	ShelfDepth = 5,
	ShelfPitch = 30,
	ShelfMinLength = 20,
	RoomCount = 90,
	RoomMinSize = 28,
	RoomMaxSize = 44,
	RoomWallThickness = 1,
	RoomGap = 30,
	RoomClearance = 8,
	RoomDoorWidth = 7,
	RoomSlotSpacing = 7,
	RoomItems = { 4, 7 },
	RoomKinds = { kitchen = 3, living = 4, bedroom = 3 },
	RoomFurniture = {
		kitchen = { "fridge", "stove", "counter" },
		living = { "couch", "armchair" },
		bedroom = { "bed", "nightstand", "dresser", "wardrobe" },
	},
	RoomRug = "rug",
	RoomLamp = "floor_lamp",
	OpenJunk = { 2, 4 },
	OpenLoose = { 0, 2 },
	EmptyJunk = { 0, 1 },
	JunkBoxes = { 1, 4 },
	LooseFurniture = { "armchair", "couch", "locker" },
	PillarEvery = 2,
	PillarSize = 8,
	DecalCount = 1400,
	DecalKinds = { spray = 40, oil = 35, claw = 10, poster = 15 },
	DecalNames = {
		spray = { "run", "hide", "lights_lie" },
		oil = { "oil_handprint", "oil_splat" },
		claw = { "claw_marks" },
		poster = { "lost_dog" },
	},
	DecalSizes = { spray = { 7, 3.5 }, oil = { 3, 3 }, claw = { 3, 3 }, poster = { 3, 4.5 } },
	DecalHeight = { 2.5, 8 },
	SpawnCount = 40,
	SpawnMinGap = 600,
	SpawnCandidates = 24,
	SpawnClearance = 6,
}

local layout = WarehouseGen.generate(config, 2029)

local function sameValue(a: any, b: any, path: string)
	if type(a) ~= "table" or type(b) ~= "table" then
		if a ~= b then
			error(`differs at {path}: {a} vs {b}`)
		end
		return
	end
	for key, value in a do
		sameValue(value, b[key], `{path}.{key}`)
	end
	for key in b do
		if a[key] == nil then
			error(`extra key at {path}.{key}`)
		end
	end
end

local function shelfRect(shelf: WarehouseGen.Shelf)
	return { x0 = shelf.x0, x1 = shelf.x1, z0 = shelf.z - shelf.depth / 2, z1 = shelf.z + shelf.depth / 2 }
end

return {
	["rng is repeatable and stays in range"] = function()
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 500 do
			local value = a:next()
			expect(value).toBe(b:next())
			expect(value >= 0 and value < 1).toBeTruthy()
		end
		local c = Rng.new(8)
		expect(Rng.new(7):next() == c:next()).toBeFalsy()
	end,
	["rng int covers both ends"] = function()
		local rng = Rng.new(3)
		local seen = {}
		for _ = 1, 400 do
			local value = rng:int(1, 4)
			expect(value >= 1 and value <= 4).toBeTruthy()
			seen[value] = true
		end
		expect(seen[1] and seen[4]).toBeTruthy()
	end,
	["same seed builds the same warehouse"] = function()
		sameValue(layout, WarehouseGen.generate(config, 2029), "layout")
	end,
	["different seeds build different warehouses"] = function()
		local other = WarehouseGen.generate(config, 77)
		expect(other.rooms[1].x0 == layout.rooms[1].x0 and other.rooms[1].z0 == layout.rooms[1].z0).toBeFalsy()
	end,
	["fills the floor"] = function()
		expect(#layout.rooms >= 60).toBeTruthy()
		expect(#layout.shelves > 1000).toBeTruthy()
		expect(#layout.junk > 500).toBeTruthy()
		expect(#layout.pillars > 300).toBeTruthy()
		expect(#layout.decals >= 1300).toBeTruthy()
		expect(#layout.signs > 300).toBeTruthy()
	end,
	["rooms stay apart and inside the walls"] = function()
		local edge = layout.half - config.WallThickness
		for i, room in layout.rooms do
			expect(room.x0 > -edge and room.x1 < edge and room.z0 > -edge and room.z1 < edge).toBeTruthy()
			for j = i + 1, #layout.rooms do
				expect(Rooms.overlaps(room, layout.rooms[j], config.RoomGap - 1)).toBeFalsy()
			end
		end
	end,
	["rooms are placed off-grid"] = function()
		local xs = {}
		for _, room in layout.rooms do
			xs[room.x0 % config.BlockSize] = true
		end
		local distinct = 0
		for _ in xs do
			distinct += 1
		end
		expect(distinct > 30).toBeTruthy()
	end,
	["shelving never runs into a room"] = function()
		for _, shelf in layout.shelves do
			expect(shelf.x1 - shelf.x0 >= config.ShelfMinLength).toBeTruthy()
			for _, room in layout.rooms do
				expect(Rooms.overlaps(shelfRect(shelf), room, config.RoomClearance - 0.01)).toBeFalsy()
			end
		end
	end,
	["junk, loose furniture and pillars stay out of rooms"] = function()
		for _, room in layout.rooms do
			for _, junk in layout.junk do
				expect(Rooms.contains(room, junk.x, junk.z, config.RoomClearance)).toBeFalsy()
			end
			for _, item in layout.loose do
				expect(Rooms.contains(room, item.x, item.z, config.RoomClearance)).toBeFalsy()
			end
			for _, pillar in layout.pillars do
				expect(Rooms.contains(room, pillar.x, pillar.z, config.PillarSize / 2)).toBeFalsy()
			end
		end
	end,
	["every room has doorways, a rug, a lamp and furniture inside"] = function()
		for _, room in layout.rooms do
			expect(#room.doors >= 1 and #room.doors <= 2).toBeTruthy()
			local names = {}
			for _, item in room.items do
				names[item.name] = true
				expect(Rooms.contains(room, item.x, item.z, 0.01)).toBeTruthy()
				expect(item.name ~= "").toBeTruthy()
			end
			expect(names.rug and names.floor_lamp).toBeTruthy()
			expect(#room.items >= 3).toBeTruthy()
		end
	end,
	["doorways leave a gap in the walls"] = function()
		for _, room in layout.rooms do
			local wallLength = 0
			for _, wall in room.walls do
				wallLength += math.max(wall.x1 - wall.x0, wall.z1 - wall.z0)
			end
			local perimeter = 2 * (room.x1 - room.x0) + 2 * (room.z1 - room.z0) - 4 * config.RoomWallThickness
			expect(wallLength).toBeNear(perimeter - #room.doors * config.RoomDoorWidth, 0.01)
		end
	end,
	["spawns are spread out and standing in the clear"] = function()
		expect(#layout.spawns).toBe(config.SpawnCount)
		for i, spawn in layout.spawns do
			expect(WarehouseGen.isClear(layout, config, spawn.x, spawn.z, config.SpawnClearance)).toBeTruthy()
			for j = i + 1, #layout.spawns do
				local other = layout.spawns[j]
				local gap = math.sqrt((spawn.x - other.x) ^ 2 + (spawn.z - other.z) ^ 2)
				expect(gap >= config.SpawnMinGap).toBeTruthy()
			end
		end
	end,
	["decals sit on a face and fit it"] = function()
		for _, decal in layout.decals do
			expect(math.abs(decal.nx) + math.abs(decal.nz)).toBe(1)
			expect(decal.width <= config.DecalSizes[decal.kind][1] + 1e-6).toBeTruthy()
			expect(decal.y - decal.height / 2 >= config.DecalHeight[1] - 1e-6).toBeTruthy()
		end
	end,
	["depth grows from the entrance"] = function()
		expect(WarehouseGen.depth(layout, layout.entrance.x, layout.entrance.z)).toBe(0)
		expect(WarehouseGen.depth(layout, -layout.half, -layout.half)).toBeNear(1)
		expect(WarehouseGen.depth(layout, 0, 0) < WarehouseGen.depth(layout, 0, -3000)).toBeTruthy()
	end,
	["roomAt finds the room around a point"] = function()
		local room = layout.rooms[1]
		expect(WarehouseGen.roomAt(layout, room.cx, room.cz)).toBe(room)
		expect(WarehouseGen.roomAt(layout, layout.entrance.x, layout.entrance.z - 1)).toBe(nil)
	end,
}
