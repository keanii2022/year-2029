local settings = {
	-- true keeps players spawning in the step 1 test room; false drops them into the warehouse
	UseTestRoom = false,

	-- 0 = a new layout every server; any other number always builds the same warehouse
	Seed = 0,

	-- World centre of the floor. South edge (the entrance) sits at z = -2000, clear of the test room
	-- at the origin and the showroom at (2000, 0, 0).
	Origin = Vector3.new(0, 0, -6000),

	-- Studs. 3200 at walk speed 14 is a bit under 4 minutes wall to wall: big, but packed.
	Size = 3200,
	CeilingHeight = 70,
	WallThickness = 8,

	-- The floor is a grid of square zones; the borders between zones are the cross aisles
	BlockSize = 160,
	BlockMargin = 12, -- half the cross aisle width
	ZoneKinds = {
		racking = 28,
		showroom = 16,
		stockroom = 10,
		junkyard = 10,
		installation = 22,
		neighborhood = 5,
		hall = 7,
		empty = 2,
	},
	-- These never sit right next to the same kind, so the floor stays a surprise
	ZoneSpread = {
		showroom = true,
		stockroom = true,
		junkyard = true,
		installation = true,
		neighborhood = true,
		hall = true,
		empty = true,
	},
	RackRunChance = 0.4, -- racking with racking both left and above only stays this often
	MegaChance = 0.18, -- an installation that swallows 2 by 2 zones
	MegaInstallationKinds = {
		cloud_hill = 3,
		light_grid = 3,
		fog_lawn = 2,
		pastel_houses = 2,
		window_court = 2,
		sky_hatch = 1,
	},
	MegaHeight = 66,
	InstallationRepeatGap = 4, -- zones between two installations of the same kind, so you never see a repeat
	-- Big overhead, tight underfoot: a clutter island on most open spots this far apart
	ClutterSpacing = 36,
	ClutterChance = 0.8,
	ClutterClearance = 7,
	ClutterKinds = {
		pallets = 4,
		wreck = 2,
		heap = 3,
		boxes = 3,
		carts = 2,
		drums = 2,
		spill = 2,
		checkout = 1,
	},
	ClutterSkipZones = {
		racking = true,
		showroom = true,
		installation = true,
		neighborhood = true,
		hall = true,
	},
	FloorStoryChance = 0.35,
	AirSpacing = 56, -- signs, banners, dangling lights and cables over the cross aisles
	AirHeight = { 22, 48 },
	BannerLines = { "SALE", "EVERYTHING MUST GO", "OPEN 24/7", "THANK YOU", "WE MISS YOU", "SMILE" },
	NeighborhoodRoad = 12,
	NeighborhoodHouses = { "house_ranch", "house_twostory", "house_garage", "house_tiny" },
	NeighborhoodSunY = 62,

	-- Racking: tall racks packed close, so the aisles are narrow and you can't see over them
	RackDepth = 5,
	RackPitch = 14, -- row to row; the walking aisle is RackPitch - RackDepth wide
	RackHeight = 26,
	RackBay = 24, -- studs between uprights
	RackDecks = { 0.4, 6.5, 13, 19.5 },
	RackStock = { 2, 3 }, -- runs of boxed stock per deck
	TapeChance = 0.12,
	AisleSignGap = 3, -- aisle number signs hang with their top this far above the racks
	RackWreckChance = 0.03, -- kit only: a collapsed or toppled bay now and then

	-- Strip lights on cables, cold over racking, warm over the store departments
	LightLength = 10,
	LightGap = 36,
	RackLightY = 34,
	ShowroomLightY = 30,
	LightDead = 0.22,
	LightFlicker = 0.1,
	LightEvery = 2, -- every Nth working strip actually casts light, the rest only glow
	EmergencyEvery = 12, -- every Nth working strip stays on at night as a small red pool of light
	ExitSignChance = 0.35,

	-- Store departments: a floor under a hanging sign on long cables, furniture staged in little sets
	DeptSignY = 26,
	PartitionHeight = 8,
	ShowroomFloors = { "wood", "carpet_blue", "carpet_red", "tile_cream", "wood_dark" },
	ShowroomKitFloors = {
		wood = "floor_wood",
		wood_dark = "floor_wood",
		carpet_blue = "floor_carpet_blue",
		carpet_red = "floor_carpet",
		tile_cream = "floor_checker",
	},
	StockKit = {
		"pallet_boxes",
		"pallet_tower",
		"pallet_wrapped",
		"crate_stack",
		"box_pile_big",
		"pallet_sacks",
	},
	Departments = {
		{ name = "SLEEP", furniture = { "bed", "nightstand", "dresser", "wardrobe", "floor_lamp" } },
		{ name = "SIT", furniture = { "couch", "armchair", "coffee_table", "tv_stand", "crt_tv" } },
		{ name = "COOK", furniture = { "fridge", "stove", "counter", "kitchen_table", "kitchen_chair" } },
		{
			name = "WORK",
			furniture = { "desk", "office_chair", "filing_cabinet", "bookshelf", "whiteboard" },
		},
		{
			name = "PLAY",
			furniture = { "kid_bed", "toy_chest", "play_table", "bunk_bed", "jack_in_the_box" },
		},
		{ name = "BATH", furniture = { "bathtub", "toilet", "sink_cabinet", "shower_door" } },
	},

	-- Stock rooms: pallet stacks in tight rows
	StackPitch = 8,

	-- Pillar halls: giant round pillars
	HallPillar = 12,

	-- Installations: a pitch dark hall up to the roof with a lit dreamcore set inside, where a robot
	-- lives. One of each set, weighted; tall sets reach InstallationTallHeight.
	InstallationKinds = {
		catwalk_void = 3,
		black_sun = 2,
		orb_dunes = 2,
		night_lot = 3,
		playground = 3,
		stairs_nowhere = 2,
		soft_play = 3,
		floating_block = 2,
		grandmas_room = 3,
		giant_nursery = 2,
		hedge_maze = 3,
		sky_door = 3,
		kids_corner = 3,
		sky_hatch = 2,
		tile_maze = 3,
		cloud_hill = 2,
		fog_lawn = 3,
		basement = 3,
		poolroom = 3,
		dead_mall = 3,
		light_grid = 2,
		backroom = 3,
		green_hall = 3,
		pastel_houses = 2,
		curtain_room = 3,
		grass_store = 3,
		window_court = 2,
	},
	InstallationTallHeight = 50,
	HallDoorWidth = 10,
	WeirdDetails = { 3, 5 }, -- extra wrong things scattered through each set
	-- The set's light leaking out of each hall doorway: a ceiling glow `reach` studs outside it
	-- (lamp tone spill_<set tone>) and a faint frame round the opening, frameHeight tall
	InstallationSpill = { reach = 5, height = 12, frame = 0.4, frameHeight = 12, fallback = "warm" },
	InstallationSpillLight = { brightness = 0.9, range = 22, transparency = 0.45 },
	InstallationStash = "loot_crate", -- the container robots guard in every set
	InstallationStashReach = 3.5, -- studs out from the furniture it sits by
	StoreNames = { "GLOMO", "SNAKZ", "TOYVA", "BEDLO", "HAPPI", "ZOOMR", "NUBBY", "SOFTO" },

	-- Racks, junk and spawns keep this far from robot rooms (the installation sets)
	RoomClearance = 8,
	RoomRug = "rug",

	-- Furniture heaps in the junkyard zones
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
	-- Placed but never grabbable: the building itself, lights, signs, installation walls and floors,
	-- the cul-de-sac houses. Everything else placed as a prop can be grabbed, up to MaxGrabSize.
	FixedModels = {
		rug = true,
		survivor_tent = true,
		robot_pile = true,
		-- shell, pillars, racks
		wall_lower = true,
		wall_upper = true,
		dock_door = true,
		giant_pillar = true,
		giant_pillar_base = true,
		rack_end = true,
		rack_bay_full = true,
		rack_bay_bulk = true,
		rack_bay_sparse = true,
		rack_bay_furniture = true,
		rack_collapsed = true,
		rack_toppled_beam = true,
		catwalk = true,
		-- lights and signs
		aisle_sign = true,
		aisle_sign_hanging = true,
		dept_sign = true,
		sale_banner = true,
		ceiling_fan = true,
		disco_ball = true,
		sodium_lamp = true,
		streetlamp = true,
		porch_light = true,
		sun_panel = true,
		black_sun = true,
		giant_cloud = true,
		star_decal = true,
		-- installation walls, floors and fixtures
		shutter_front = true,
		padded_wall = true,
		hedge_wall = true,
		picket_fence = true,
		moon_window = true,
		sky_hatch = true,
		picture_frame = true,
		curtains = true,
		door_frame_lone = true,
		doorway_blue = true,
		stairs_nowhere = true,
		stairs_to_wall = true,
		checkout_lane = true,
		checkout_lane_lit = true,
		cart_corral = true,
		mall_kiosk = true,
		monolith = true,
		swing_set = true,
		slide = true,
		welcome_mat = true,
		-- cul-de-sac houses
		house_ranch = true,
		house_twostory = true,
		house_garage = true,
		house_tiny = true,
	},
	MaxGrabSize = 16, -- longest side in studs; anything bigger stays put
	-- Clutter boxes built from primitives that count as props: pallet stacks and wrapped stacks
	MovableStyles = { stack = true, wrap = true },

	-- Giant pillars on the cross aisle corners, every PillarEvery blocks, vanishing up into the haze
	PillarEvery = 2,
	PillarSize = 24,

	-- Survivor spray paint (red), robot oil, claw gouges and old printed posters
	DecalCount = 900,
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
	SpawnMinGap = 260,
	SpawnCandidates = 24,
	SpawnClearance = 6,

	-- Hazy air that swallows the roof and the far walls. Step 6 may retune this Atmosphere.
	Haze = {
		Density = 0.5,
		Offset = 0,
		Color = Color3.fromRGB(128, 130, 132),
		Decay = Color3.fromRGB(70, 72, 76),
		Glare = 0,
		Haze = 3,
	},

	-- Old, faded colors
	FloorColor = Color3.fromRGB(52, 53, 54),
	WallColor = Color3.fromRGB(86, 88, 90),
	CeilingColor = Color3.fromRGB(34, 35, 38),
	TrussColor = Color3.fromRGB(58, 60, 62),
	TrussGap = 40,
	PillarColor = Color3.fromRGB(118, 114, 106),
	RackUpright = Color3.fromRGB(62, 110, 108),
	RackBeam = Color3.fromRGB(150, 78, 40),
	RackDeck = Color3.fromRGB(70, 72, 74),
	Cardboard = Color3.fromRGB(140, 112, 78),
	RoomWallColor = Color3.fromRGB(128, 118, 104),
	SprayColor = Color3.fromRGB(170, 18, 18),
	OilColor = Color3.fromRGB(10, 10, 12),
	PosterColor = Color3.fromRGB(196, 186, 160),
	CableColor = Color3.fromRGB(28, 28, 30),

	-- Light strips: glow color and the light they cast when they work
	-- Lights inside installations, by name: Color, Brightness, Range. They stay on day and night.
	LampTones = {
		sun = { color = Color3.fromRGB(255, 244, 214), brightness = 2.5, range = 40 },
		panel = { color = Color3.fromRGB(236, 244, 255), brightness = 1.6, range = 26 },
		panel_warm = { color = Color3.fromRGB(255, 226, 180), brightness = 1.4, range = 26 },
		warm = { color = Color3.fromRGB(255, 200, 140), brightness = 1.5, range = 18 },
		blue = { color = Color3.fromRGB(110, 170, 255), brightness = 2.5, range = 22 },
		sky = { color = Color3.fromRGB(190, 220, 255), brightness = 1.6, range = 50 },
		haze = { color = Color3.fromRGB(190, 210, 255), brightness = 2, range = 60 },
		dim = { color = Color3.fromRGB(230, 220, 200), brightness = 0.8, range = 24 },
		tv = { color = Color3.fromRGB(140, 180, 255), brightness = 1.4, range = 14 },
		glare = { color = Color3.fromRGB(255, 250, 236), brightness = 3, range = 50 },
		yellow = { color = Color3.fromRGB(255, 244, 190), brightness = 1.3, range = 24 },
		dusk_sun = { color = Color3.fromRGB(255, 190, 130), brightness = 3, range = 70 },
		moon = { color = Color3.fromRGB(200, 214, 255), brightness = 1.2, range = 24 },
		exit = { color = Color3.fromRGB(60, 255, 120), brightness = 0.8, range = 10 },
		red_rim = { color = Color3.fromRGB(255, 60, 60), brightness = 3, range = 60 },
		blue_rim = { color = Color3.fromRGB(60, 120, 255), brightness = 3, range = 60 },
		sodium = { color = Color3.fromRGB(255, 150, 60), brightness = 2.4, range = 40 },
		disco = { color = Color3.fromRGB(255, 220, 255), brightness = 1.5, range = 30 },
		seam = { color = Color3.fromRGB(150, 200, 255), brightness = 2, range = 40 },
		street = { color = Color3.fromRGB(255, 200, 130), brightness = 2, range = 36 },
		fake_sun = { color = Color3.fromRGB(230, 240, 255), brightness = 4, range = 60 },
	},

	LightTones = {
		cold = {
			glow = Color3.fromRGB(214, 232, 240),
			light = Color3.fromRGB(200, 222, 236),
			brightness = 1.6,
			range = 34,
		},
		warm = {
			glow = Color3.fromRGB(255, 226, 180),
			light = Color3.fromRGB(255, 214, 160),
			brightness = 1.3,
			range = 30,
		},
	},

	-- Looks for the primitive pieces the layout asks for
	Styles = {
		wet = {
			color = Color3.fromRGB(26, 28, 30),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.35,
		},
		tape = { color = Color3.fromRGB(230, 190, 30), material = Enum.Material.SmoothPlastic },
		partition = { color = Color3.fromRGB(196, 190, 176), material = Enum.Material.Plaster },
		stack = { color = Color3.fromRGB(132, 104, 72), material = Enum.Material.Cardboard },
		wrap = { color = Color3.fromRGB(196, 200, 204), material = Enum.Material.Glass, transparency = 0.25 },
		pillar = { color = Color3.fromRGB(150, 138, 112), material = Enum.Material.Concrete },
		wood = { color = Color3.fromRGB(150, 110, 72), material = Enum.Material.WoodPlanks },
		wood_dark = { color = Color3.fromRGB(96, 70, 50), material = Enum.Material.WoodPlanks },
		carpet_blue = { color = Color3.fromRGB(54, 66, 92), material = Enum.Material.Carpet },
		carpet_red = { color = Color3.fromRGB(110, 46, 44), material = Enum.Material.Carpet },
		carpet_grey = { color = Color3.fromRGB(112, 114, 112), material = Enum.Material.Carpet },
		carpet_dark = { color = Color3.fromRGB(44, 44, 50), material = Enum.Material.Carpet },
		tile_cream = { color = Color3.fromRGB(214, 204, 180), material = Enum.Material.CeramicTiles },
		tile_white = { color = Color3.fromRGB(226, 228, 230), material = Enum.Material.CeramicTiles },
		water = {
			color = Color3.fromRGB(80, 170, 180),
			material = Enum.Material.Glass,
			transparency = 0.45,
			reflectance = 0.25,
		},
		grass = { color = Color3.fromRGB(70, 128, 58), material = Enum.Material.Grass },
		paving = { color = Color3.fromRGB(150, 146, 140), material = Enum.Material.Pavement },
		rail = { color = Color3.fromRGB(170, 172, 176), material = Enum.Material.Metal },
		panel_lavender = { color = Color3.fromRGB(226, 180, 255), material = Enum.Material.Neon },
		panel = { color = Color3.fromRGB(240, 244, 236), material = Enum.Material.Neon },
		sun = { color = Color3.fromRGB(255, 246, 214), material = Enum.Material.Neon },
		partition_cloth = { color = Color3.fromRGB(110, 116, 120), material = Enum.Material.Fabric },
		office_wall = { color = Color3.fromRGB(150, 150, 120), material = Enum.Material.Plaster },
		drop_ceiling = { color = Color3.fromRGB(206, 204, 194), material = Enum.Material.Plaster },
		plaster_cream = { color = Color3.fromRGB(222, 212, 184), material = Enum.Material.Plaster },
		plaster_white = { color = Color3.fromRGB(236, 236, 232), material = Enum.Material.Plaster },
		plaster_grey = { color = Color3.fromRGB(140, 140, 142), material = Enum.Material.Plaster },
		night_ceiling = { color = Color3.fromRGB(22, 24, 34), material = Enum.Material.SmoothPlastic },
		sky = { color = Color3.fromRGB(120, 176, 226), material = Enum.Material.SmoothPlastic },
		hill = { color = Color3.fromRGB(120, 176, 226), material = Enum.Material.SmoothPlastic },
		window_lit = { color = Color3.fromRGB(255, 232, 170), material = Enum.Material.Neon },
		window_dark = {
			color = Color3.fromRGB(30, 34, 40),
			material = Enum.Material.Glass,
			reflectance = 0.2,
		},
		door_frame = { color = Color3.fromRGB(160, 120, 80), material = Enum.Material.Wood },
		door_dark = { color = Color3.fromRGB(60, 50, 44), material = Enum.Material.Wood },
		check_red = {
			color = Color3.fromRGB(200, 40, 40),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.15,
		},
		check_blue = {
			color = Color3.fromRGB(30, 90, 190),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.15,
		},
		check_yellow = {
			color = Color3.fromRGB(240, 200, 40),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.15,
		},
		check_green = {
			color = Color3.fromRGB(40, 150, 70),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.15,
		},
		check_white = {
			color = Color3.fromRGB(236, 232, 220),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.15,
		},
		pastel_pink = { color = Color3.fromRGB(232, 150, 170), material = Enum.Material.Plaster },
		pastel_yellow = { color = Color3.fromRGB(240, 214, 140), material = Enum.Material.Plaster },
		pastel_peach = { color = Color3.fromRGB(240, 180, 150), material = Enum.Material.Plaster },
		roof = { color = Color3.fromRGB(90, 84, 110), material = Enum.Material.RoofShingles },
		picket = { color = Color3.fromRGB(240, 238, 230), material = Enum.Material.Wood },
		grate = {
			color = Color3.fromRGB(120, 122, 124),
			material = Enum.Material.DiamondPlate,
			transparency = 0.35,
		},
		dark_wall = { color = Color3.fromRGB(14, 14, 16), material = Enum.Material.SmoothPlastic },
		dark_floor = { color = Color3.fromRGB(20, 20, 22), material = Enum.Material.Concrete },
		void = { color = Color3.fromRGB(2, 2, 3), material = Enum.Material.SmoothPlastic },
		lamp_bulb = { color = Color3.fromRGB(255, 244, 220), material = Enum.Material.Neon, transparency = 1 },
		silhouette = { color = Color3.fromRGB(8, 8, 10), material = Enum.Material.SmoothPlastic },
		wall_blush = { color = Color3.fromRGB(214, 182, 178), material = Enum.Material.Plaster },
		marble_dark = {
			color = Color3.fromRGB(40, 36, 38),
			material = Enum.Material.Marble,
			reflectance = 0.12,
		},
		marble_cream = {
			color = Color3.fromRGB(226, 214, 204),
			material = Enum.Material.Marble,
			reflectance = 0.12,
		},
		frame = { color = Color3.fromRGB(40, 34, 30), material = Enum.Material.Wood },
		art_grey = { color = Color3.fromRGB(150, 150, 146), material = Enum.Material.SmoothPlastic },
		exit_green = { color = Color3.fromRGB(30, 170, 80), material = Enum.Material.Neon },
		wall_pink = { color = Color3.fromRGB(226, 80, 120), material = Enum.Material.Plaster },
		wall_blue = { color = Color3.fromRGB(40, 70, 130), material = Enum.Material.Plaster },
		wall_yellow = { color = Color3.fromRGB(236, 196, 50), material = Enum.Material.Plaster },
		carpet_party = { color = Color3.fromRGB(40, 36, 70), material = Enum.Material.Carpet },
		neon_pink = { color = Color3.fromRGB(255, 80, 170), material = Enum.Material.Neon },
		neon_green = { color = Color3.fromRGB(90, 255, 120), material = Enum.Material.Neon },
		neon_blue = { color = Color3.fromRGB(80, 160, 255), material = Enum.Material.Neon },
		neon_yellow = { color = Color3.fromRGB(255, 230, 80), material = Enum.Material.Neon },
		cubby_red = { color = Color3.fromRGB(200, 50, 40), material = Enum.Material.Plastic },
		cubby_blue = { color = Color3.fromRGB(40, 80, 190), material = Enum.Material.Plastic },
		cubby_yellow = { color = Color3.fromRGB(240, 200, 40), material = Enum.Material.Plastic },
		exit_glow = { color = Color3.fromRGB(255, 248, 230), material = Enum.Material.Neon },
		hatch_wood = { color = Color3.fromRGB(150, 116, 80), material = Enum.Material.WoodPlanks },
		ladder = { color = Color3.fromRGB(190, 194, 200), material = Enum.Material.Metal },
		water_turq = {
			color = Color3.fromRGB(60, 210, 190),
			material = Enum.Material.Glass,
			transparency = 0.35,
			reflectance = 0.2,
		},
		water_dark = {
			color = Color3.fromRGB(20, 50, 52),
			material = Enum.Material.Glass,
			transparency = 0.2,
			reflectance = 0.35,
		},
		sky_deep = { color = Color3.fromRGB(30, 80, 200), material = Enum.Material.SmoothPlastic },
		cloud = { color = Color3.fromRGB(250, 250, 252), material = Enum.Material.SmoothPlastic },
		haze_wall = { color = Color3.fromRGB(150, 180, 230), material = Enum.Material.SmoothPlastic },
		haze_ray = {
			color = Color3.fromRGB(220, 236, 255),
			material = Enum.Material.Neon,
			transparency = 0.88,
		},
		haze_layer = {
			color = Color3.fromRGB(170, 200, 240),
			material = Enum.Material.SmoothPlastic,
			transparency = 0.92,
		},
		siding = { color = Color3.fromRGB(214, 176, 120), material = Enum.Material.WoodPlanks },
		banister = { color = Color3.fromRGB(170, 120, 70), material = Enum.Material.Wood },
		door_white = { color = Color3.fromRGB(232, 232, 228), material = Enum.Material.SmoothPlastic },
		appliance = { color = Color3.fromRGB(236, 238, 240), material = Enum.Material.SmoothPlastic },
		panel_blue = { color = Color3.fromRGB(120, 180, 255), material = Enum.Material.Neon },
		carpet_beige = { color = Color3.fromRGB(196, 186, 168), material = Enum.Material.Carpet },
		tile_dark = { color = Color3.fromRGB(40, 60, 62), material = Enum.Material.CeramicTiles },
		tv_glow = { color = Color3.fromRGB(150, 190, 255), material = Enum.Material.Neon },
		wall_mono_yellow = { color = Color3.fromRGB(214, 200, 120), material = Enum.Material.Plaster },
		ceiling_yellow = { color = Color3.fromRGB(200, 190, 140), material = Enum.Material.Plaster },
		carpet_olive = { color = Color3.fromRGB(130, 128, 90), material = Enum.Material.Carpet },
		panel_yellow = { color = Color3.fromRGB(255, 250, 210), material = Enum.Material.Neon },
		carpet_blue_bright = { color = Color3.fromRGB(70, 100, 190), material = Enum.Material.Carpet },
		lime = {
			color = Color3.fromRGB(160, 210, 40),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.15,
		},
		door_blue = { color = Color3.fromRGB(50, 90, 200), material = Enum.Material.SmoothPlastic },
		chair_orange = { color = Color3.fromRGB(240, 100, 30), material = Enum.Material.SmoothPlastic },
		chair_grey = { color = Color3.fromRGB(120, 122, 124), material = Enum.Material.SmoothPlastic },
		dusk = { color = Color3.fromRGB(160, 110, 200), material = Enum.Material.SmoothPlastic },
		stucco_pink = { color = Color3.fromRGB(226, 120, 140), material = Enum.Material.Plaster },
		stucco_yellow = { color = Color3.fromRGB(236, 206, 140), material = Enum.Material.Plaster },
		stucco_peach = { color = Color3.fromRGB(236, 160, 130), material = Enum.Material.Plaster },
		window_black = {
			color = Color3.fromRGB(10, 10, 14),
			material = Enum.Material.Glass,
			reflectance = 0.3,
		},
		window_teal = { color = Color3.fromRGB(140, 230, 210), material = Enum.Material.Neon },
		carpet_green = { color = Color3.fromRGB(50, 80, 50), material = Enum.Material.Carpet },
		curtain_blue = { color = Color3.fromRGB(110, 160, 220), material = Enum.Material.Fabric },
		bench_pink = { color = Color3.fromRGB(220, 150, 170), material = Enum.Material.Leather },
		moon = { color = Color3.fromRGB(240, 240, 226), material = Enum.Material.Neon },
		cream_wall = { color = Color3.fromRGB(230, 210, 160), material = Enum.Material.Plaster },
		wood_shelf = { color = Color3.fromRGB(170, 124, 80), material = Enum.Material.WoodPlanks },
		pillar_cream = { color = Color3.fromRGB(232, 214, 160), material = Enum.Material.Plaster },
		panel_warm = { color = Color3.fromRGB(255, 236, 196), material = Enum.Material.Neon },
		night_sky = { color = Color3.fromRGB(20, 30, 70), material = Enum.Material.SmoothPlastic },
		bench_stone = { color = Color3.fromRGB(170, 166, 160), material = Enum.Material.Concrete },
		plastic_white = { color = Color3.fromRGB(236, 234, 228), material = Enum.Material.Plastic },
		plastic_black = { color = Color3.fromRGB(24, 24, 26), material = Enum.Material.Plastic },
		balloon_red = {
			color = Color3.fromRGB(220, 30, 40),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.2,
		},
		plaster_patch = { color = Color3.fromRGB(200, 196, 186), material = Enum.Material.Plaster },
		oil = {
			color = Color3.fromRGB(10, 10, 12),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.2,
		},
		phone_beige = { color = Color3.fromRGB(214, 200, 170), material = Enum.Material.Plastic },
		asphalt = { color = Color3.fromRGB(46, 46, 50), material = Enum.Material.Asphalt },
		mailbox = { color = Color3.fromRGB(70, 74, 80), material = Enum.Material.Metal },
		car_body = {
			color = Color3.fromRGB(120, 140, 160),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.2,
		},
		sand = { color = Color3.fromRGB(214, 192, 150), material = Enum.Material.Sand },
		sand_dark = { color = Color3.fromRGB(170, 148, 110), material = Enum.Material.Sand },
		chrome = { color = Color3.fromRGB(220, 224, 230), material = Enum.Material.Foil, reflectance = 0.6 },
		paint_white = { color = Color3.fromRGB(230, 228, 220), material = Enum.Material.SmoothPlastic },
		sodium = { color = Color3.fromRGB(255, 160, 60), material = Enum.Material.Neon },
		mulch = { color = Color3.fromRGB(110, 70, 44), material = Enum.Material.Pebble },
		rubber = { color = Color3.fromRGB(30, 30, 32), material = Enum.Material.Rubber },
		slide_red = { color = Color3.fromRGB(210, 50, 40), material = Enum.Material.SmoothPlastic },
		concrete_step = { color = Color3.fromRGB(170, 166, 158), material = Enum.Material.Concrete },
		pad_red = { color = Color3.fromRGB(210, 60, 60), material = Enum.Material.Leather },
		pad_blue = { color = Color3.fromRGB(50, 100, 210), material = Enum.Material.Leather },
		pad_yellow = { color = Color3.fromRGB(240, 200, 50), material = Enum.Material.Leather },
		pad_green = { color = Color3.fromRGB(60, 170, 80), material = Enum.Material.Leather },
		monolith = { color = Color3.fromRGB(26, 26, 30), material = Enum.Material.Slate },
		wall_floral = { color = Color3.fromRGB(200, 170, 150), material = Enum.Material.Fabric },
		wall_nursery = { color = Color3.fromRGB(170, 200, 220), material = Enum.Material.Plaster },
		horse_cream = { color = Color3.fromRGB(236, 220, 190), material = Enum.Material.SmoothPlastic },
		hedge = { color = Color3.fromRGB(46, 100, 44), material = Enum.Material.LeafyGrass },
		rack_beam = { color = Color3.fromRGB(150, 78, 40), material = Enum.Material.Metal },
		rack_upright = { color = Color3.fromRGB(62, 110, 108), material = Enum.Material.Metal },
		cart_wire = {
			color = Color3.fromRGB(150, 156, 160),
			material = Enum.Material.DiamondPlate,
			transparency = 0.4,
		},
		drum = { color = Color3.fromRGB(40, 70, 90), material = Enum.Material.CorrodedMetal },
		barrier = { color = Color3.fromRGB(230, 120, 30), material = Enum.Material.Plastic },
		counter_grey = { color = Color3.fromRGB(150, 150, 146), material = Enum.Material.SmoothPlastic },
		banner = { color = Color3.fromRGB(170, 60, 50), material = Enum.Material.Fabric },
		cable = { color = Color3.fromRGB(28, 28, 30), material = Enum.Material.Metal },
		store_band = { color = Color3.fromRGB(30, 30, 34), material = Enum.Material.SmoothPlastic },
	},

	-- Build in square chunks so streaming can load and drop them; yield between chunks
	ChunkSize = 320,
}

-- Every lamp tone gets a dim spill_ twin (the doorway pool) and a faint neon frame style
local spill = settings.InstallationSpillLight
for name, tone in table.clone(settings.LampTones) do
	settings.LampTones[`spill_{name}`] =
		{ color = tone.color, brightness = spill.brightness, range = spill.range }
	settings.Styles[`spill_{name}`] =
		{ color = tone.color, material = Enum.Material.Neon, transparency = spill.transparency }
end

return settings
