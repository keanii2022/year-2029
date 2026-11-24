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
	},
	WhineInterval = { 10, 18 },
	GrowlCooldown = 3,
	BarkInterval = 1.2,

	-- Trust hearts over its head, only seen by each player for their own trust
	Hearts = { Count = 4, Color = Color3.fromRGB(196, 72, 72), Distance = 40 },

	TickRate = 5,
	AnimRate = 15,
}
