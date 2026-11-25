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
	DragSearchRange = 50,
	DragMaxSize = 9, -- longest side; bigger props stay put
	DragGap = 1.5, -- studs between the bot's back and the prop it drags
	DragSpeed = 9,
	FortRange = 35, -- each bot picks its fort spot this close to where it first spawned
	HideSearchRange = 160,
	SpotsRefresh = 60, -- seconds between rescans for hiding spots
	FlashlightChance = 0.6, -- share of bots that turn a flashlight on at lights out

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
		drag = { 14, 24 },
		group = { 8, 16 },
		hide = { 10, 20 },
		flee = { 2.5, 4 },
		avoid = { 2, 4 },
		fight = { 4, 9 },
		freeze = { 1.5, 3 },
	},

	-- aggro: chance to start a fight with someone in range. fightBack: chance to shoot back once hit.
	-- avoid: chance to back away from someone close. freeze: chance to panic when a robot comes.
	Moods = {
		calm = {
			aggro = 0.02,
			fightBack = 0.35,
			avoid = 0.6,
			freeze = 0.1,
			day = { wander = 3, loot = 4, sneak = 1, drag = 2.5, group = 3 },
		},
		normal = {
			aggro = 0.12,
			fightBack = 0.75,
			avoid = 0.25,
			freeze = 0.2,
			day = { wander = 3, loot = 4, sneak = 2, drag = 1.5, group = 1.5 },
		},
		chaos = {
			aggro = 0.55,
			fightBack = 1,
			avoid = 0,
			freeze = 0.25,
			day = { wander = 3, loot = 2, sneak = 2, drag = 0.5, group = 1 },
		},
	},
	DefaultMood = "normal",

	-- Fill lobby: a public server already running when you drop in. Bots is the Large-warehouse
	-- range, scaled down by area on smaller ones. Groups are 1 to 3; Openings is what each group is
	-- busy with when it appears (drag is fort building). The rest of a group starts on "group".
	Lobby = {
		Bots = { 20, 26 },
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
