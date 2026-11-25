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

	-- Rows the TODAY list has room for: PerDay plus the lore mission, or the whole first-day chain
	MaxRows = 4,
	-- Arrow targets that move (nearest prop, nearest room) are only resent past this many studs
	TargetResend = 12,
	-- The faint screen-edge arrow toward a live mission's target; hides once you're ArrowHideNear away
	-- (No Color3 in this file: Lune tests load it)
	Arrow = { Size = 34, Inset = 0.4, Transparency = 0.6 },
	ArrowHideNear = 10,

	-- The mission that points at the day's lore piece (Config.Files.Daily), added to every normal list
	Lore = {
		texts = {
			"Find today's lost recording",
			"Something was left out for you",
			"Find what's humming in the dark",
		},
	},

	-- Brand-new players get this chain instead of a random list until they finish it, one step live
	-- at a time. Survive finishes at the first dawn they're alive for, even if they joined at night.
	FirstDay = {
		Title = "FIRST DAY",
		Steps = {
			{
				kind = "haul",
				text = "Drag something heavy. Start a fort",
				reward = { item = "Bandage", count = 1 },
			},
			{
				kind = "loot",
				text = "Take one thing from the nearest robot room",
				reward = { item = "BlasterCells", count = 12 },
			},
			{
				kind = "bank",
				text = "Put something in your locker",
				reward = { item = "FlashlightBattery", count = 2 },
			},
			{ kind = "survive", text = "Survive the night", reward = { item = "RationPack", count = 1 } },
		},
		DoneLine = "First day done. Now you're one of us.",
	},

	-- Daily streak: finishing the whole list counts the day (UTC). Missed days pause it.
	-- Day 7 unlocks a cosmetic through the StreakDays stat (Config.Saves.Cosmetics).
	Streak = {
		Rewards = { { day = 3, tokens = 30 } },
		Live = "STREAK {days}",
		Paused = "STREAK {days} PAUSED",
		CountedLine = "Daily streak: {days} days",
		RewardLine = "{days}-day streak: +{tokens} Tokens",
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
