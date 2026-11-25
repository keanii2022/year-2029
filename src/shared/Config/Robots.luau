return {
	Enabled = true,

	-- Ticks per second for robot brains. Movement and limbs run smoother, on their own rates.
	TickRate = 5,
	AnimRate = 15,

	-- Only rooms this close to a player get a live robot; the rest sleep.
	ActivationRadius = 320,
	DeactivationRadius = 400, -- a live room keeps its robot until every player is this far
	ActivationInterval = 2,
	MaxLiveChoreBots = 16,

	-- Night hunters spawn out of sight near players and stall where they stand at lights on.
	MaxHunters = 8,
	HunterNearRadius = 260, -- a player with no hunter this close gets one
	HunterSpawnDistance = { 200, 260 }, -- far enough that you hear and see them coming
	HunterGrace = 25, -- seconds of quiet after lights out before any hunter spawns
	HunterDespawnRadius = 450,
	ChoreDespawnRadius = 400, -- a chore bot out sweeping this far from everyone goes back to sleep

	-- Which chore bot lives in which kind of room
	RoomBots = {
		sky_door = "carrier",
		kids_corner = "cleaner",
		sky_hatch = "carrier",
		tile_maze = "cleaner",
		cloud_hill = "carrier",
		fog_lawn = "cleaner",
		basement = "cook",
		poolroom = "cleaner",
		dead_mall = "carrier",
		light_grid = "cleaner",
		backroom = "carrier",
		green_hall = "cleaner",
		pastel_houses = "cook",
		curtain_room = "cook",
		grass_store = "carrier",
		window_court = "cleaner",
	},
	HunterTypes = { "scout", "brute", "crawler" },
	NightSuffix = "_night", -- night model name = day name .. suffix

	-- Per type. Speeds in studs per second (players walk 14, sprint 22, crouch 7).
	Types = {
		cleaner = { role = "chore", walkSpeed = 7, chaseSpeed = 13, sightRange = 34, agentHeight = 7 },
		carrier = { role = "chore", walkSpeed = 7, chaseSpeed = 13, sightRange = 34, agentHeight = 7 },
		cook = { role = "chore", walkSpeed = 7, chaseSpeed = 13, sightRange = 34, agentHeight = 7 },
		scout = { role = "hunter", walkSpeed = 9, chaseSpeed = 16, sightRange = 70, agentHeight = 7 },
		brute = { role = "hunter", walkSpeed = 8, chaseSpeed = 15, sightRange = 45, agentHeight = 8 },
		crawler = { role = "hunter", walkSpeed = 9, chaseSpeed = 17, sightRange = 40, agentHeight = 3.5 },
	},

	-- Senses
	Sense = {
		SightAngle = 140, -- full cone width, degrees
		NightSightFactor = 1.2,
		CrouchSightFactor = 0.5, -- crouching shrinks how far a robot can spot you
		SprintSightFactor = 1.2,
		FeelRadius = 9, -- this close, a robot notices you whatever way it faces (unless you're hidden or crouched)
		FootstepRadius = { Walk = 12, Sprint = 30, Crouch = 0 },
		NoticeSeconds = 0.8, -- by day, how long you can stay in view before it charges (less up close)
		NightNoticeSeconds = 0.35,
		AlertDecay = 0.6, -- alert lost per second out of view
		SuspiciousSeconds = 4,
		LoseSeconds = 4, -- chase gives up after this long without seeing you
		InvestigateSeconds = 5,
		BeamRange = 60, -- a flashlight pointed at a robot at night within this range gives you away
		BeamAngle = 12, -- degrees off the beam's centre that still counts as pointing at it
		EyeHeight = 6,
	},

	-- Chasing and catching
	CatchRange = 4,
	DayLeash = 120, -- a day chase gives up this far from home
	CaughtGraceSeconds = 8, -- after a day catch the robot ignores that player for a bit
	ArriveRange = 3,
	StudySeconds = { 4, 9 },
	StudyReach = 3.5, -- stands this far in front of the furniture it studies

	-- Day errands: calm chore bots walk out of their rooms to work in the aisles near players, then
	-- walk home. Life hands out the spots every few seconds; never by night.
	Chores = {
		PerPlayer = 2, -- robots out (going, working or heading home) near each player
		MaxErrands = 8, -- out at once across the whole server
		CallRadius = 160, -- only live robots this close to a player get sent
		MinDistance = 20, -- the spot is this far from the player, so you see it working
		MaxDistance = 75,
		Reach = 85, -- and this close to the robot's room (under DayLeash, so a chase still holds)
		WorkSeconds = { 12, 22 },
		GiveUpSeconds = 30, -- couldn't reach the spot: head home
		SightRange = 24, -- a short cone while out, so walking past one isn't instant trouble
		ChoreFor = { carrier = "carry", cleaner = "sweep", cook = "restock" },
		BoxModel = "box_loose",
		BoxSize = Vector3.new(2.4, 1.8, 2.4), -- stand-in until the model is uploaded
		BoxColor = Color3.fromRGB(170, 130, 85),
	},

	-- Night sweeping and hauling
	SweepRadius = 70, -- wander points are picked this close to the nearest player
	SweepMinStep = 20,
	LooseSearchRadius = 45,
	LooseSearchEvery = 1.5,
	PickupRange = 5,
	MaxHaulSize = 14, -- longest side of a prop a robot will carry
	RevealRange = 10,
	RevealChance = 0.4,
	HoldingBreathRevealFactor = 0.25, -- step 12: holding your breath while hidden

	-- Pathfinding: kept cheap on a giant map
	PathRecompute = 1.5,
	PathsPerSecond = 6,
	StraightLineRange = 18, -- in the same room, closer than this, walk straight
	StuckSeconds = 2,
	AgentRadius = 2.5,

	-- Looks
	EyePart = "Extra",
	DayEyeColor = Color3.fromRGB(150, 220, 235),
	NightEyeColor = Color3.fromRGB(255, 40, 30),
	ScannerColor = Color3.fromRGB(255, 70, 60),
	ScannerRange = 40,
	ScannerAngle = 40,
	ScannerBrightness = 3,
	StallLine = "ERROR. NEEDS MORE TRAINING.",
	StallLineEvery = { 6, 14 },
	StallLineRange = 30,
	TwitchEvery = { 1.5, 5 },

	-- Stolen items sit on a shelf in the robot's room
	StashColor = Color3.fromRGB(70, 64, 58),
	StashPickupRange = 8,
	StashPickupHold = 0.8,
	StashHeight = 3.5,

	-- Robot-only gear. Step 9 adds the item definitions; until then these ids are refused.
	EmpItemId = "EmpCharge",
	DisruptorItemId = "Disruptor",
	EmpThrowRange = 45,
	EmpFlightTime = 0.6,
	EmpFuse = 1,
	EmpRadius = 22,
	EmpSeconds = 8,
	DisruptorRange = 60,
	DisruptorCooldown = 45,
	GearUseInterval = 0.5, -- server-side spam guard per player
	DestroyReward = { { id = "EmpCharge", count = 2 } },
	WreckModel = "robot_pile",
	OilColor = Color3.fromRGB(12, 12, 14),

	-- Keys for the gear (no shared Input action for these yet)
	EmpKeys = { Enum.KeyCode.G, Enum.KeyCode.DPadDown },
	DisruptorKeys = { Enum.KeyCode.V, Enum.KeyCode.DPadRight },

	-- Sounds (names from the manifest), heard out to SoundRollOff[2] studs
	Sounds = { Hum = "hum_loop", HumVolume = 0.35, CueVolume = 0.9, Grab = "grab_clank" },
	SoundRollOff = { 6, 70 },
	StateSounds = {
		chase = "chase_servo_scream",
		suspicious = { "curious_beep_1", "curious_beep_2", "curious_beep_3" },
		investigate = { "curious_beep_1", "curious_beep_2", "scanner_ping" },
		sweep = "scanner_ping",
		stalled = "error_stall",
	},
	CaughtDayLine = "A ROBOT GRABBED YOU. It took your %s back to its room. Sneak in and steal it back.",
	CaughtNightLine = "A ROBOT GOT YOU IN THE DARK.",
}
