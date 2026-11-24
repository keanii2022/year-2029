return {
	-- true keeps players spawning in the step 1 test room; false drops them into the warehouse
	UseTestRoom = false,

	-- 0 = a new layout every server; any other number always builds the same warehouse
	Seed = 0,

	-- World centre of the floor. South edge (the entrance) sits at z = -2000, clear of the test room
	-- at the origin and the showroom at (2000, 0, 0).
	Origin = Vector3.new(0, 0, -6000),

	-- Studs. 8000 at walk speed 14 is about 9.5 minutes wall to wall.
	Size = 8000,
	CeilingHeight = 600,
	WallThickness = 8,

	-- The floor is cut into square blocks; borders between blocks are the wide cross aisles
	BlockSize = 200,
	BlockMargin = 12, -- half the cross aisle width
	BlockKinds = { aisles = 40, open = 35, empty = 25 },

	-- Shelving rows run east-west inside an aisle block
	ShelfDepth = 5,
	ShelfHeight = 18,
	ShelfPitch = 30, -- row to row, so the walking aisle is ShelfPitch - ShelfDepth wide
	ShelfMinLength = 20, -- shorter leftovers after cutting around rooms are dropped
	ShelfBay = 80, -- studs between uprights
	ShelfDecks = { 0.6, 6.5, 12.5 },
	ShelfStockRuns = 1, -- long runs of boxed stock per row

	-- Robot rooms: little homes built from old furniture, scattered off-grid
	RoomCount = 90,
	RoomMinSize = 28,
	RoomMaxSize = 44,
	RoomWallHeight = 12,
	RoomWallThickness = 1,
	RoomGap = 30, -- between rooms
	RoomClearance = 8, -- shelving and junk keep this far from room walls
	RoomDoorWidth = 7,
	RoomSlotSpacing = 7, -- furniture spots along the inside walls
	RoomItems = { 4, 7 },
	RoomKinds = {
		kitchen = 3,
		living = 4,
		bedroom = 3,
		kids = 2,
		office = 3,
		bathroom = 2,
		arcade = 1,
		store = 2,
	},
	RoomFurniture = {
		kitchen = { "fridge", "stove", "counter", "sink_cabinet", "pantry", "kitchen_table", "kitchen_chair" },
		living = { "couch", "armchair", "coffee_table", "tv_stand", "crt_tv", "bookshelf", "record_player" },
		bedroom = { "bed", "nightstand", "dresser", "wardrobe", "bookshelf" },
		kids = { "kid_bed", "bunk_bed", "toy_chest", "play_table", "jack_in_the_box", "stuffed_robot" },
		office = { "desk", "office_chair", "filing_cabinet", "whiteboard", "bookshelf" },
		bathroom = { "bathtub", "toilet", "sink_cabinet", "shower_door" },
		arcade = { "arcade_cabinet", "vending_machine", "boombox", "disco_ball", "arcade_cabinet" },
		store = { "mannequin", "shirt_folder", "mannequin", "counter", "dresser" },
	},
	RoomRug = "rug",
	RoomLamp = "floor_lamp",

	-- Open blocks: junk stacks and loose furniture from the old world
	OpenJunk = { 2, 4 },
	OpenLoose = { 0, 2 },
	EmptyJunk = { 0, 1 },
	JunkBoxes = { 1, 4 },
	LooseFurniture = {
		"armchair",
		"couch",
		"filing_cabinet",
		"office_chair",
		"kitchen_chair",
		"dresser",
		"bookshelf",
		"toy_chest",
		"locker",
		"crt_tv",
		"mannequin",
		"robot_pile",
		"sleeping_bag",
		"survivor_tent",
		"leak_bucket",
	},
	-- Placed but never grabbable
	FixedModels = { rug = true, survivor_tent = true, robot_pile = true },

	-- Giant pillars on the cross aisle corners, every PillarEvery blocks
	PillarEvery = 2,
	PillarSize = 8,

	-- Survivor spray paint (red), robot oil, claw gouges and old printed posters
	DecalCount = 1400,
	DecalKinds = { spray = 40, oil = 35, claw = 10, poster = 15 },
	DecalNames = {
		spray = {
			"run",
			"hide",
			"lights_lie",
			"question_mark",
			"dont_sleep",
			"fog_found_you",
			"no_way_out",
			"not_safe",
			"stay_quiet",
			"they_hear_you",
			"tally",
			"arrow",
		},
		oil = { "oil_handprint", "oil_handprints_sliding", "oil_drag_mark", "oil_splat" },
		claw = { "claw_marks" },
		poster = {
			"dont_panic",
			"dont_panic_defaced",
			"helper_of_the_month",
			"helper_of_the_month_defaced",
			"hug_your_toaster",
			"lost_dog",
			"mega_sale",
			"sleep_2",
			"smile_on_camera",
			"smile_on_camera_defaced",
			"think_less",
			"think_less_defaced",
		},
	},
	DecalSizes = { spray = { 7, 3.5 }, oil = { 3, 3 }, claw = { 3, 3 }, poster = { 3, 4.5 } },
	DecalHeight = { 2.5, 8 },
	-- Shown in red marker text until the scrawl images are uploaded
	SprayText = {
		question_mark = "EXIT?",
		dont_sleep = "DON'T SLEEP",
		tally = "IIII IIII II",
		arrow = ">>>",
	},

	-- Players start alone: spawns are spread out and kept apart
	SpawnCount = 40,
	SpawnMinGap = 600,
	SpawnCandidates = 24,
	SpawnClearance = 6,

	-- Hazy air that swallows the roof and the far walls. Step 6 may retune this Atmosphere.
	Haze = {
		Density = 0.42,
		Offset = 0.2,
		Color = Color3.fromRGB(150, 146, 136),
		Decay = Color3.fromRGB(92, 88, 80),
		Glare = 0,
		Haze = 2.6,
	},

	-- Old, faded colors
	FloorColor = Color3.fromRGB(88, 87, 84),
	WallColor = Color3.fromRGB(104, 102, 96),
	CeilingColor = Color3.fromRGB(60, 60, 62),
	PillarColor = Color3.fromRGB(112, 110, 104),
	ShelfSteel = Color3.fromRGB(58, 70, 84),
	ShelfDeck = Color3.fromRGB(74, 76, 78),
	Cardboard = Color3.fromRGB(146, 118, 82),
	RoomWallColor = Color3.fromRGB(128, 118, 104),
	SprayColor = Color3.fromRGB(170, 18, 18),
	OilColor = Color3.fromRGB(10, 10, 12),
	PosterColor = Color3.fromRGB(196, 186, 160),

	-- Build in square chunks so streaming can load and drop them; yield between chunks
	ChunkSize = 800,
}
