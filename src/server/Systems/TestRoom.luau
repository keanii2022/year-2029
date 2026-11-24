-- Greybox test room built from code: concrete floor, walls, shelving rows, box cover,
-- a metal floor patch (for footstep tests later) and crates to jump on. Stand-in until
-- the real warehouse exists.
local TestRoom = {}

local ROOM_SIZE = 160
local WALL_HEIGHT = 24
local WALL_THICKNESS = 2

local CONCRETE = Color3.fromRGB(92, 92, 90)
local WALL = Color3.fromRGB(118, 116, 110)
local SHELF_STEEL = Color3.fromRGB(52, 66, 82)
local SHELF_DECK = Color3.fromRGB(70, 72, 74)
local CARDBOARD = Color3.fromRGB(150, 118, 78)
local CRATE = Color3.fromRGB(104, 84, 60)
local PLATE = Color3.fromRGB(130, 132, 134)

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildShell(parent: Instance)
	block(
		parent,
		"Floor",
		Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
		CFrame.new(0, -0.5, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	local half = ROOM_SIZE / 2 + WALL_THICKNESS / 2
	local long = Vector3.new(ROOM_SIZE + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS)
	local short = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE)
	local y = WALL_HEIGHT / 2
	block(parent, "WallNorth", long, CFrame.new(0, y, -half), WALL, Enum.Material.Concrete)
	block(parent, "WallSouth", long, CFrame.new(0, y, half), WALL, Enum.Material.Concrete)
	block(parent, "WallEast", short, CFrame.new(half, y, 0), WALL, Enum.Material.Concrete)
	block(parent, "WallWest", short, CFrame.new(-half, y, 0), WALL, Enum.Material.Concrete)
end

local function buildShelf(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Shelf"
	local length, depth, height = 12, 3, 10
	for _, x in { -length / 2 + 0.2, length / 2 - 0.2 } do
		for _, z in { -depth / 2 + 0.2, depth / 2 - 0.2 } do
			block(
				model,
				"Upright",
				Vector3.new(0.4, height, 0.4),
				origin * CFrame.new(x, height / 2, z),
				SHELF_STEEL,
				Enum.Material.Metal
			)
		end
	end
	for _, y in { 0.6, 3.8, 7 } do
		block(
			model,
			"Deck",
			Vector3.new(length, 0.3, depth),
			origin * CFrame.new(0, y, 0),
			SHELF_DECK,
			Enum.Material.Metal
		)
	end
	block(
		model,
		"Box",
		Vector3.new(2.5, 2, 2.4),
		origin * CFrame.new(-3, 4.95, 0),
		CARDBOARD,
		Enum.Material.Cardboard
	)
	block(
		model,
		"Box",
		Vector3.new(2, 1.6, 2),
		origin * CFrame.new(2.5, 1.55, 0.2),
		CARDBOARD,
		Enum.Material.Cardboard
	)
	model.Parent = parent
end

local function buildShelving(parent: Instance)
	for _, z in { -40, -16, 16, 40 } do
		for _, x in { -46, -34, 34, 46 } do
			buildShelf(parent, CFrame.new(x, 0, z))
		end
	end
end

local function buildCover(parent: Instance)
	local boxes = {
		{ Vector3.new(4, 3, 4), Vector3.new(-8, 1.5, -6), 10 },
		{ Vector3.new(4, 3, 4), Vector3.new(-4, 1.5, -7), -5 },
		{ Vector3.new(3, 2.5, 3), Vector3.new(-6, 4.25, -6.5), 25 },
		{ Vector3.new(5, 3.5, 3), Vector3.new(10, 1.75, 8), 0 },
		{ Vector3.new(3, 3, 3), Vector3.new(14, 1.5, 4), 40 },
		{ Vector3.new(4, 4, 4), Vector3.new(-14, 2, 20), 15 },
		{ Vector3.new(3, 2, 3), Vector3.new(6, 1, -24), -20 },
	}
	for _, spec in boxes do
		local size, position, turn = spec[1] :: Vector3, spec[2] :: Vector3, spec[3] :: number
		block(
			parent,
			"Box",
			size,
			CFrame.new(position) * CFrame.Angles(0, math.rad(turn), 0),
			CARDBOARD,
			Enum.Material.Cardboard
		)
	end

	-- Stepped crates: 2.5 then 4 studs, to feel out jump height.
	block(
		parent,
		"CrateLow",
		Vector3.new(5, 2.5, 5),
		CFrame.new(0, 1.25, 30),
		CRATE,
		Enum.Material.WoodPlanks
	)
	block(parent, "CrateHigh", Vector3.new(5, 4, 5), CFrame.new(5, 2, 30), CRATE, Enum.Material.WoodPlanks)

	block(
		parent,
		"MetalPlate",
		Vector3.new(20, 0.2, 20),
		CFrame.new(0, 0.1, -55),
		PLATE,
		Enum.Material.DiamondPlate
	)
end

local function buildSpawns(parent: Instance)
	for index, position in
		{ Vector3.new(-60, 0, 60), Vector3.new(60, 0, 60), Vector3.new(-60, 0, -60), Vector3.new(60, 0, -60) }
	do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `Spawn{index}`
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0))
		spawn.Color = CONCRETE
		spawn.Material = Enum.Material.Concrete
		spawn.Parent = parent
	end
end

function TestRoom.Init()
	local room = Instance.new("Folder")
	room.Name = "TestRoom"
	buildShell(room)
	buildShelving(room)
	buildCover(room)
	buildSpawns(room)
	room.Parent = workspace
end

return TestRoom
