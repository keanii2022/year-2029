return {
	PerDay = 3,
	CheckInterval = 2,

	-- One mission of each kind at most per day. weight decides how often a kind makes the list.
	-- Text uses {item}, {place} and {seconds} where the kind fills them in.
	Kinds = {
		find = {
			weight = 3,
			texts = { "Find one {item}", "Bring back one {item}", "Somewhere out there: one {item}" },
			items = { "RationPack", "Bandage", "EnergyDrink", "FlashlightBattery", "Sandwich", "NoodleCup" },
		},
		visit = {
			weight = 3,
			texts = { "Visit the {place}", "Go say hi to the {place}", "Stand in the {place}" },
		},
		deep = {
			weight = 2,
			texts = { "Go deeper than feels smart", "Walk until the signs stop", "Find the far corner" },
			-- Warehouse.depth: 0 at the entrance, 1 at the far corners
			depths = { 0.7, 0.8, 0.9 },
		},
		survive = { weight = 2, texts = { "Survive tonight", "Be here at dawn", "Don't get caught tonight" } },
		hide = {
			weight = 2,
			texts = { "Hide for {seconds} seconds", "Stay hidden for {seconds} seconds" },
			seconds = { 20, 30, 45 },
		},
		haul = { weight = 2, texts = { "Move some furniture. Start a fort", "Drag something heavy around" } },
	},

	-- Rewards: { item, count, weight }. Rare is rolled first.
	Rewards = {
		{ item = "BlasterCells", count = 12, weight = 4 },
		{ item = "Bandage", count = 1, weight = 3 },
		{ item = "Sandwich", count = 1, weight = 2 },
		{ item = "RationPack", count = 1, weight = 2 },
		{ item = "EnergyDrink", count = 1, weight = 2 },
		{ item = "FlashlightBattery", count = 2, weight = 2 },
	},
	RareReward = { item = "EmpCharge", count = 1 },
	RareChance = 0.08,

	-- The visit mission prefers installations at least this deep (falls back to any)
	VisitMinDepth = 0.45,

	MorningTitle = "NEW DAY.",
	MorningLine = "Here's your list.",
	ListTitle = "TODAY",
	DoneLine = "DONE: {text}",
	RewardLine = "+{count} {item}",
	AllDoneLine = "List's done. The warehouse is proud of you.",

	-- Display names for installation kinds (Config.Warehouse.InstallationKinds)
	Places = {
		catwalk_void = "Catwalk Void",
		black_sun = "Black Sun",
		orb_dunes = "Orb Dunes",
		night_lot = "Night Lot",
		playground = "Playground",
		stairs_nowhere = "Stairs to Nowhere",
		soft_play = "Soft Play",
		floating_block = "Floating Block",
		grandmas_room = "Grandma's Room",
		giant_nursery = "Giant Nursery",
		hedge_maze = "Hedge Maze",
		sky_door = "Sky Door",
		kids_corner = "Kids' Corner",
		sky_hatch = "Sky Hatch",
		tile_maze = "Tile Maze",
		cloud_hill = "Cloud Hill",
		fog_lawn = "Fog Lawn",
		basement = "Basement",
		poolroom = "Pool Halls",
		dead_mall = "Dead Mall",
		light_grid = "Light Grid",
		backroom = "Back Rooms",
		green_hall = "Green Hall",
		pastel_houses = "Pastel Houses",
		curtain_room = "Curtain Room",
		grass_store = "Grass Store",
		window_court = "Window Court",
	},
}
