return {
	Enabled = true,

	Model = "dog",
	BowlModel = "dog_bowl",
	Tag = "Dog",
	-- Warm tan for the grey stand-in so the dog stands out from the grey warehouse before upload
	GreyboxColor = Color3.fromRGB(164, 122, 82),

	-- A fresh dog turns up each morning in a room this deep into the warehouse (0 entrance, 1 far corner),
	-- unless the last one still has someone it trusts.
	SpawnDepth = { 0.15, 0.6 },
	RoomPad = 4,
	WanderRadius = 14,
	WanderPause = { 4, 9 },

	-- Trust is 0-100 per player. Caps per visit and per day make it take a couple of days.
	Trust = {
		Max = 100,
		VisitCap = 24, -- most one visit can add
		VisitGap = 90, -- seconds without feeding before the next feeding starts a new visit
		DayCap = 40, -- most one in-game day can add
		FeedCooldown = 3,
		DecayPerMinute = 0.4, -- only while the player is away from the dog
		NearDistance = 40,
		Stages = { Eats = 20, Wags = 45, Follows = 75 },
	},

	-- What the dog will take, cheapest first; the server feeds the first one the player has.
	Foods = { "Apple", "Snack", "PizzaSlice", "Sandwich", "Lunchbox", "RationPack" },
	FoodGain = { Apple = 8, Snack = 10, PizzaSlice = 12, Sandwich = 16, Lunchbox = 20, RationPack = 24 },
	EatSeconds = 4,

	-- Feeding and command prompts on the dog. A wary dog keeps WaryDistance away, so the feed reach is longer.
	FeedReach = 14,
	FeedHold = 0.6,
	CommandReach = 10,

	-- How close it lets each stage come, and how it moves (studs, studs per second)
	NoticeRange = 45,
	WaryDistance = 10,
	CautiousDistance = 5,
	CloseDistance = 3.5,
	FollowDistance = 6,
	NightFollowDistance = 3.5,
	CatchUpDistance = 70, -- a following dog this far behind slips back to its owner
	GuardSlack = 3,
	WalkSpeed = 7,
	RunSpeed = 17,
	StraightLineRange = 10,
	PathRecompute = 1.5,

	-- Guarding and biting
	GuardRadius = 14, -- props and loot piles this close to the guard spot are its to protect
	GuardScanInterval = 1,
	ProtectRadius = 12, -- robots this close to its owner or guard spot get bitten
	ChaseRadius = 25, -- how far from what it protects it will chase a raider
	RaiderMemory = 20,
	AlarmSeconds = 4,
	BiteRange = 3.5,
	BiteCooldown = 2.5,
	BiteDamage = 18,
	RobotStunSeconds = 3,
	RobotRebiteSeconds = 8, -- one robot can't be stun-locked forever

	-- Sounds (silent until uploaded) and how often they repeat
	Sounds = {
		Whine = "dog_whine",
		Growl = "dog_growl",
		Bark = "dog_bark",
		Bite = "dog_bite",
		Yelp = "dog_yelp",
		Eat = "dog_eat",
		Howl = "dog_howl",
		WhineLow = "dog_whine_low",
		Sneeze = "dog_sneeze",
	},
	-- Until a sound has an id, play this one instead (nil = stay silent)
	SoundFallbacks = { Howl = "Whine", WhineLow = "Whine" },
	-- the close-up whine only plays while someone is within NoticeRange; far off it's Calls below
	WhineInterval = { 10, 18 },
	GrowlCooldown = 3,
	BarkInterval = 1.2,

	-- Trust hearts over its head, only seen by each player for their own trust
	Hearts = { Count = 4, Color = Color3.fromRGB(196, 72, 72), Distance = 40 },

	-- Wary but willing (Logic/DogWary): how a stray reads the way you move before it trusts you
	Wary = {
		SlowSpeed = 8, -- crouch speed is 7; at or under this counts as slow
		ClosingSpeed = 4, -- coming at it this fast counts as walking straight at it
		SprintRange = 25, -- sprinting at it from this close spooks it
		SniffAfter = 3, -- seconds crouched and slow before it stretches out to sniff
		StepAfter = 6, -- then one step closer
		StepDistance = 1.5,
		CreepSpeed = 2.5,
		FoodDistance = 3, -- food in your hand lets it creep this close
		SpookRadius = 30, -- shots and loud crashes this close make it bolt
		ChaseRadius = 25, -- a robot chasing someone this close does too
		SpookSeconds = 6, -- won't settle again for this long
		FlinchSeconds = 0.4,
		TellSeconds = 1.6,
		-- the little tell for each trust stage it reaches
		Tells = { eats = "sneeze", wags = "tilt", follows = "sit" },
	},

	-- Far-off calls from an untamed dog (Logic/DogCalls), heard across the warehouse but hard to pin down
	Calls = {
		Gap = { 40, 90 },
		EdgeGapScale = 0.6,
		EdgeSeconds = 60,
		QuietRange = 45,
		NightRecheck = 15, -- quiet at night: look again this often in case something scares it
		Weights = {
			dawn = { Bark = 1, Howl = 3, Whine = 1 },
			day = { Bark = 3, Howl = 1, Whine = 2 },
			dusk = { Bark = 1, Howl = 3, Whine = 1 },
			scared = { Bark = 1, Whine = 3 },
		},
		Bounce = { 15, 40 },
		WallPad = 2,
		BounceTries = 4,
		Volume = 0.55,
		RollOff = { 12, 320 },
		Muffle = { Near = 30, Far = 220, HighCut = -40, MidCut = -14 },
		Reverb = { DecayTime = 3.2, Density = 1, Diffusion = 1, DryLevel = -4, WetLevel = -3 },
		Echo = { Delay = 0.32, Feedback = 0.35, DryLevel = 0, WetLevel = -10 },
	},

	-- Now and then a radio rumor hints at the zone a stray dog is in (once a day at most)
	Rumor = {
		Chance = 0.35,
		Delay = { 60, 240 }, -- seconds into the day
		Lines = {
			"*crackle* ...swear I heard a dog somewhere around the {spot}...",
			"*crackle* ...something's whining near the {spot}. not a robot...",
		},
		Vague = "*crackle* ...there's a dog in here somewhere. heard it barking...",
		-- {spot} for a dog out on the floor, by zone kind; installations use Config.Missions.Places
		Zones = { racking = "racks", showroom = "showroom", neighborhood = "houses", hall = "big hall" },
	},

	-- Rapport saved between sessions: the highest stage reached, a stage lost per real day away.
	-- A new dog starts at this much trust for rapport 1, 2, 3, so it warms up faster.
	RapportStart = { 10, 22, 35 },

	TickRate = 5,
	AnimRate = 15,
}
