-- Simulated players for filling a fake lobby. Only exist when the admin panel spawns them.
return {
	Max = 30,
	Tag = "SimPlayer", -- CollectionService tag on every bot model; Robots and Combat look for it
	FolderName = "SimPlayers",
	RespawnDelay = 10, -- seconds a downed bot lies there before it comes back at a spawn

	-- Ticking: the steer loop runs MoveRate times a second for every bot; each bot's brain decides
	-- ThinkRate times a second, staggered so they never all think on the same frame.
	MoveRate = 10,
	ThinkRate = 3,
	PathsPerSecond = 6, -- path computes shared by all bots; without a token a bot walks straight
	PathReuseDistance = 6, -- keep the old path while the goal moved less than this
	PathMaxAge = 8,
	WaypointReach = 3,
	ArriveRange = 5,
	StuckSeconds = 2.5, -- barely moved this long while walking: jump and find a new path

	-- Senses (studs)
	SightRange = 110,
	RobotSightRange = 70,
	FleeRange = 40,
	FightRange = 90,
	AvoidRange = 30,
	HitMemory = 6, -- seconds a hit keeps the shooter on its mind
	FleeDistance = 35,

	-- Lights-on actions
	WanderRange = 70,
	GroupRange = 140,
	GroupCloseness = 7,
	LootSearchRange = 90,
	LootTime = { 1.5, 3.5 },
	LootItemChance = 0.7, -- chance a finished loot pause actually puts the pile's item in its bag
	FortRange = 35, -- each bot picks its fort spot this close to where it first spawned
	BuildFocus = 0.8, -- chance a bot whose crew fort still has gaps goes back to building by day
	HideSearchRange = 160,
	SpotsRefresh = 60, -- seconds between rescans for hiding spots
	FlashlightChance = 0.6, -- share of bots that turn a flashlight on at lights out
	LureArrive = 20, -- a bot heading for an event slows to a mill-about this close to the spot

	-- Shooting: degrees of aim error, plus more per stud of distance
	Aim = {
		Spread = 2.5,
		SpreadPerStud = 0.035,
		BurstShots = { 2, 5 },
		BurstPause = { 0.7, 1.6 },
		ShotGap = { 0.25, 0.45 }, -- never faster than the gun's own fireInterval
		StrafeEvery = { 1.2, 2.5 },
		StrafeDistance = 8,
	},

	-- Seconds per action { min, max }
	ActionTime = {
		wander = { 6, 14 },
		loot = { 10, 18 },
		sneak = { 10, 18 },
		drag = { 60, 120 }, -- fort building
		group = { 8, 16 },
		hide = { 10, 20 },
		flee = { 2.5, 4 },
		avoid = { 2, 4 },
		fight = { 4, 9 },
		freeze = { 1.5, 3 },
		chase = { 35, 60 }, -- long enough to get there and hang around for the crate
	},

	-- aggro: chance to start a fight with someone in range. fightBack: chance to shoot back once hit.
	-- avoid: chance to back away from someone close. freeze: chance to panic when a robot comes.
	-- lure: chance to go for a PA event or bait drop close by (scaled by Config.Director.BotPull).
	-- defend: chance to open fire on someone coming into its fort. raid: chance a fort builder goes
	-- after pieces of someone else's fort (prying them out) when picking what to haul next.
	Moods = {
		calm = {
			aggro = 0.02,
			fightBack = 0.35,
			avoid = 0.6,
			freeze = 0.1,
			lure = 0.35,
			defend = 0.15,
			raid = 0,
			day = { wander = 3, loot = 4, sneak = 1, drag = 2.5, group = 3 },
		},
		normal = {
			aggro = 0.12,
			fightBack = 0.75,
			avoid = 0.25,
			freeze = 0.2,
			lure = 0.55,
			defend = 0.5,
			raid = 0.15,
			day = { wander = 3, loot = 4, sneak = 2, drag = 1.5, group = 1.5 },
		},
		chaos = {
			aggro = 0.55,
			fightBack = 1,
			avoid = 0,
			freeze = 0.25,
			lure = 0.75,
			defend = 0.9,
			raid = 0.5,
			day = { wander = 3, loot = 2, sneak = 2, drag = 0.5, group = 1 },
		},
	},
	DefaultMood = "normal",

	-- Fill lobby: a public server already running when you drop in. Bots is the range on a BotsAt-stud
	-- warehouse (Standard), scaled by area on other sizes and capped at Max. Groups are 1 to 3; Openings is what each group is
	-- busy with when it appears (drag is fort building). The rest of a group starts on "group".
	Lobby = {
		Bots = { 15, 20 },
		BotsAt = 2080,
		Mood = "normal",
		SoloShare = 0.45,
		TrioShare = 0.2,
		Openings = { loot = 3, drag = 2, sneak = 1.5 },
	},

	-- Roblox's stock R15 animations; used when the rig doesn't carry its own Animate ids
	Animations = {
		idle = "rbxassetid://507766388",
		walk = "rbxassetid://507777826",
		run = "rbxassetid://507767714",
	},
	RunAbove = 17, -- studs per second where walking turns into running
	CarryAnimation = "rbxassetid://507768375", -- stock R15 arms-out hold, played while hauling a piece

	-- Fort building (Logic/FortPlan, Systems/SimForts). A crew of bots shares one plan and hauls
	-- pieces one at a time; Plan is the FortPlan.Limits for every crew fort.
	Forts = {
		CrewSize = 3,
		JoinRange = 60, -- a bot starting to build joins an unfinished crew fort this close
		SiteProbe = 30, -- how far the wall probes reach from a fort spot
		SiteTries = 5, -- spots tried around the wanted one before giving up for now
		SiteRetry = 20, -- seconds a bot that found no room waits before trying again
		SearchRange = 70, -- pieces this close to the fort get hauled in
		MinSide = 1.5, -- longest side of the smallest piece worth hauling
		MaxSide = 12, -- and of the biggest one a bot can carry
		CountPieces = 24, -- most pieces counted when sizing a new fort
		StandGap = 2.5, -- studs between the bot and the inner face of the piece it sets down
		PlaceRange = 1.5, -- this close to its standing spot it sets the piece down
		PickRetry = 3, -- seconds before a bot that found nothing to haul looks again
		FetchTimeout = 40, -- seconds to reach a piece before giving up on it
		CarryTimeout = 45, -- seconds to get a carried piece to its slot before setting it down anywhere
		CarryGap = 1, -- studs between the bot's chest and the piece it carries
		CarryDrop = 2, -- the carried piece's bottom sits this far below the bot's middle
		PickupTime = { 1.2, 2.5 },
		PlaceTime = { 1.8, 3.2 }, -- squaring it up against its neighbour
		RestTime = { 1.5, 4 }, -- looks over its work before going for the next piece
		PlaceTries = 3, -- refused set-downs at one slot before planning around whatever's there
		Nudges = { 0, 0.25, 0.5 }, -- studs outward a refused slot is tried again at
		HideMinPieces = 3, -- a fort with this many pieces up is where its crew hides at night
		DefendPad = 6, -- someone this close to the fort's inside counts as raiding it
		DefendRange = 40, -- bots this close to their fort defend it
		OwnerBase = 1000000, -- bot pieces carry PlacedBy = -(OwnerBase + crew id), never a real UserId
		PlaceSounds = { "prop_wood_knock", "land_thud", "prop_cardboard_thump" },
		Plan = {
			Reach = 14,
			Room = 4,
			Margin = 6,
			Door = 4,
			Width = { 8, 16 },
			Depth = { 6, 12 },
			Overhang = 1.5,
			Fit = 0.2,
			MinPiece = 1.5,
			MinWallHeight = 2.5,
			StackBelow = 4,
			MaxHeight = 8,
		},
	},

	Names = {
		Adjectives = {
			"Neon",
			"Rusty",
			"Sleepy",
			"Turbo",
			"Silent",
			"Crispy",
			"Cosmic",
			"Lucky",
			"Grumpy",
			"Pixel",
			"Frosty",
			"Sneaky",
			"Salty",
			"Mega",
			"Tiny",
			"Feral",
			"Glitchy",
			"Spicy",
			"Chill",
			"Soggy",
		},
		Nouns = {
			"Pickle",
			"Toaster",
			"Ferret",
			"Waffle",
			"Goblin",
			"Noodle",
			"Gecko",
			"Muffin",
			"Raccoon",
			"Biscuit",
			"Cactus",
			"Potato",
			"Badger",
			"Taco",
			"Moth",
			"Sprocket",
			"Yeti",
			"Nugget",
			"Pigeon",
			"Walrus",
		},
	},

	SkinTones = {
		Color3.fromRGB(255, 220, 190),
		Color3.fromRGB(234, 184, 146),
		Color3.fromRGB(198, 140, 100),
		Color3.fromRGB(141, 92, 62),
		Color3.fromRGB(92, 58, 38),
		Color3.fromRGB(250, 200, 80),
	},
	ClothesColors = {
		Color3.fromRGB(40, 40, 44),
		Color3.fromRGB(70, 90, 140),
		Color3.fromRGB(150, 40, 40),
		Color3.fromRGB(60, 110, 70),
		Color3.fromRGB(200, 200, 205),
		Color3.fromRGB(90, 70, 120),
		Color3.fromRGB(210, 130, 40),
		Color3.fromRGB(30, 60, 80),
	},
}
