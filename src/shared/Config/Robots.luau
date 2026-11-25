return {
	Enabled = true,

	-- Ticks per second for robot brains. Movement and limbs run smoother, on their own rates.
	TickRate = 5,
	AnimRate = 15,

	-- Only rooms this close to a player get a live robot; the rest sleep.
	ActivationRadius = 320,
	DeactivationRadius = 400, -- a live room keeps its robot until every player is this far
	ActivationInterval = 2,
	MaxLiveChoreBots = 40, -- robots, across every live installation

	-- How many robots live in an installation (min, max), and the giant 2x2 ones
	-- The count scales with the hall's floor area (one per AreaPerBot square studs), kept in range.
	InstallationBots = { 3, 5 },
	GiantInstallationBots = { 5, 9 },
	AreaPerBot = 2400,
	BotSpacing = 9, -- robots in a room spawn, study and idle at least this far apart
	-- One per installation stands in a corner facing the wall. Inside LookRange its head turns to
	-- follow you; it wakes after staring StareSeconds, when you come inside WakeRange, or on a sound.
	Watcher = { LookRange = 34, WakeRange = 9, StareSeconds = 4, MaxHeadTurn = 150, CornerPad = 3 },

	-- Night hunters spawn out of sight near players and stall where they stand at lights on.
	MaxHunters = 16,
	HunterNearRadius = 260, -- a player with no hunter this close gets one
	HunterSpawnDistance = { 200, 260 }, -- far enough that you hear and see them coming
	HunterGrace = 25, -- seconds of quiet after lights out before any hunter spawns
	HunterDespawnRadius = 450,

	-- Prowlers: a few hunters that never stall. They roam the aisles by day too, red-eyed, loud
	-- enough to hear through the racks, dragging things about. Same hunt as at night, day eyes.
	Prowl = {
		Max = 6,
		NearRadius = 220, -- a player with no prowler this close gets one
		SpawnDistance = { 140, 200 },
		Grace = 40, -- seconds into the day before the first one turns up
		SightFactor = 0.7, -- by day they see less far than at night
		Types = { "scout", "brute", "crawler" },
		IdleSounds = { "drag", "scrape", "servo_whirr_2", "hydraulic_hiss" },
		IdleSoundGap = { 5, 12 },
	},

	-- Hunting as a pack (night, and prowlers by day). One that spots you lets out an alert; the
	-- nearest awake robots answer and run in from the sides. Lose them and they check where they
	-- saw you, then a few spots round it (a nearby hiding spot first, some of the time).
	Hunt = {
		CallRadius = 110,
		MaxResponders = 3,
		CallCooldown = 10,
		ShareEvery = 2, -- while it still sees you, it keeps telling the others where you are
		FlankOffset = 14,
		NightLoseSeconds = 7, -- a night chase holds on this long without seeing you (day: Sense.LoseSeconds)
		Searches = 2,
		SearchRadius = 22,
		SearchFindChance = 0.45,
		AlertSound = "spot_alert",
		AlertPitch = 0.75,
		AlertVolume = 1.4,
		AnswerSounds = { "scout_eye_whine", "servo_whirr_1", "brute_groan" },
		AnswerPitch = 0.8,
		AnswerDelay = { 0.3, 1.2 },
		-- Up close at night a chasing hunter bursts past sprint speed (22) for a moment, screeching
		-- first, then cools down. Speed in studs per second, times in seconds.
		Lunge = { Range = 15, Speed = 24, Seconds = 1.5, Cooldown = 4 },
		LungeSound = "chase_servo_scream",
		LungePitch = 1.35,
		LungeVolume = 1.3,
		RollOff = { 20, 220 },
	},

	-- Getting caught. By day it hurts and throws you down, then takes your best item home; by night it
	-- takes you down. The screen flashes, the camera jolts and you hear it land.
	Catch = {
		DayDamage = 35,
		Shove = 38, -- studs per second, away from the robot
		Lift = 16,
		DownSeconds = 1.6, -- flat on the floor before you get up
		ShakeSeconds = 0.7,
		ShakeAngle = 4, -- degrees
		Sounds = { "impact_metal", "land_thud" },
		Volume = 0.9,
	},

	-- One robot per installation stands just inside a doorway facing out. Anyone walking (not
	-- crouched) inside the room within HearRange makes it turn and look.
	Guard = { Inset = 5, HearRange = 32 },

	-- At night a red glow round the eyes, so you see them hunting from far off in the dark
	EyeGlow = { Range = 7, Brightness = 2.5 },

	-- Client side dread: a heartbeat and a drained, reddened screen as hunting robots close in, and
	-- strip lights near a hunting robot stutter and buzz.
	Dread = {
		ChaseRange = 90,
		HuntRange = 60,
		HuntWeight = 0.45,
		Heartbeat = "heartbeat_loop",
		HeartbeatVolume = 0.9,
		HeartbeatPitch = { 0.85, 1.35 },
		Rise = 1.5, -- per second, how fast dread climbs toward its target
		Fall = 0.35, -- and fades after
		Saturation = -0.45,
		Contrast = 0.12,
		Tint = Color3.fromRGB(255, 205, 200),
		FlickerRadius = 28,
		Buzz = "neon_crackle",
		BuzzChance = 0.02, -- per stuttering strip, each time it cuts out
	},

	-- Far off in the dark, robots at work: crashes, scrapes and groans from a random direction. At
	-- the siren, the warehouse waking up all round you.
	Ambience = {
		NightGap = { 16, 38 },
		SirenGap = { 3, 7 },
		Distance = { 70, 130 },
		Night = { "stack_crash", "prop_metal_clang", "scrape", "drag", "brute_groan", "chase_servo_scream" },
		Siren = { "hydraulic_hiss", "servo_whirr_1", "servo_whirr_2", "brute_groan", "scanner_ping" },
		Pitch = { 0.6, 0.85 },
		Volume = 1,
		RollOff = { 20, 200 },
	},
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

	-- Per type. Speeds in studs per second (players walk 14, sprint 22, crouch 7). Every chase
	-- beats a walk, none beats a sprint.
	-- armor: gun damage that knocks it down (starter pistol hits for 22, a close shotgun blast ~96).
	Types = {
		cleaner = {
			role = "chore",
			walkSpeed = 7,
			chaseSpeed = 15,
			sightRange = 34,
			agentHeight = 7,
			armor = 130,
		},
		carrier = {
			role = "chore",
			walkSpeed = 7,
			chaseSpeed = 15,
			sightRange = 34,
			agentHeight = 7,
			armor = 130,
		},
		cook = {
			role = "chore",
			walkSpeed = 7,
			chaseSpeed = 15,
			sightRange = 34,
			agentHeight = 7,
			armor = 130,
		},
		scout = {
			role = "hunter",
			walkSpeed = 9,
			chaseSpeed = 17,
			sightRange = 70,
			agentHeight = 7,
			armor = 150,
		},
		brute = {
			role = "hunter",
			walkSpeed = 8,
			chaseSpeed = 15,
			sightRange = 45,
			agentHeight = 8,
			armor = 300,
		},
		crawler = {
			role = "hunter",
			walkSpeed = 9,
			chaseSpeed = 18,
			sightRange = 40,
			agentHeight = 3.5,
			armor = 110,
		},
	},

	-- Getting shot: a desperate answer, never a kill. Each hit sparks, clanks and staggers it; enough
	-- damage (Types.armor) inside HitMemory knocks it down. It lies still DownSeconds, reboots, and
	-- hunts whoever shot it for GrudgeSeconds, a little faster than usual.
	Shot = {
		HitMemory = 12,
		StaggerSeconds = 0.35,
		Knockback = 0.8, -- studs it jerks back per hit
		DownSeconds = 15,
		DownTilt = 75, -- degrees it falls back while powered off
		GrudgeSeconds = 45,
		GrudgeRange = 160,
		AngrySpeed = 1.15,
		Clank = "impact_metal",
		ClankVolume = 1,
		Sputter = "emp_shutdown",
		Reboot = "hydraulic_hiss",
		-- Knocking one down spills salvage once per robot per day (so it can't be farmed): a few
		-- rolls from Common, plus one Rare pick at RareChance (brutes always get the rare pick).
		Salvage = {
			Rolls = { 2, 3 },
			Common = {
				{ id = "BlasterCells", count = 12, weight = 4 },
				{ id = "FlashlightBattery", count = 1, weight = 3 },
				{ id = "Shells", count = 4, weight = 2 },
				{ id = "Bandage", count = 1, weight = 2 },
				{ id = "EnergyDrink", count = 1, weight = 1 },
			},
			RareChance = 0.35,
			Rare = {
				{ id = "EmpCharge", count = 1, weight = 4 },
				{ id = "Medkit", count = 1, weight = 3 },
				{ id = "Disruptor", count = 1, weight = 1 },
				{ id = "Handcuffs", count = 1, weight = 1 },
			},
			AlwaysRare = { brute = true },
		},
	},

	-- Senses
	Sense = {
		SightAngle = 140, -- full cone width, degrees
		NightSightFactor = 1.2,
		CrouchSightFactor = 0.5, -- crouching shrinks how far a robot can spot you
		SprintSightFactor = 1.2,
		FeelRadius = 9, -- this close, a robot notices you whatever way it faces (unless you're hidden or crouched)
		FaceRadius = 16, -- standing in its cone this close, it sees you even crouched, busy or not
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
		ChestHeight = 3, -- a second sight ray, so a hanging prop in front of its eyes doesn't blind it
	},

	-- Chasing and catching
	CatchRange = 4,
	DayLeash = 120, -- a day chase gives up this far from home
	CaughtGraceSeconds = 8, -- after a day catch the robot ignores that player for a bit
	ArriveRange = 3,
	StudySeconds = { 4, 9 },
	StudyReach = 3.5, -- stands this far in front of the furniture it studies
	-- what it does at each thing in its room: look it over, poke and sort at it (carriers haul a box
	-- over first), or scan around
	StudyPoses = { "study", "restock", "restock", "scan" },

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
		TapeColor = Color3.fromRGB(196, 170, 120),
		-- Carriers: lift the box, slide it onto the shelf in front, then tidy the shelf
		ShelveLift = 0.8,
		ShelveSlide = 1.6,
		ShelfReach = 3.5, -- studs in front of the robot
		ShelfHeight = 4.5, -- studs off the floor
		BoxStays = 45, -- seconds a shelved box stays before it's tidied away
		-- Cleaners: a broom of plain blocks, swept side to side with the body, kicking up dust
		BroomColor = Color3.fromRGB(120, 86, 52),
		BristleColor = Color3.fromRGB(196, 168, 96),
		SweepYaw = 0.3, -- radians the body turns each way while sweeping
		RestockYaw = 0.12, -- the cook shifts its weight between reaches
		DustColor = Color3.fromRGB(180, 172, 160),
		DustPuff = 5, -- particles at each end of a sweep
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
	-- Eyes say what it's thinking, with a small "?" or "!" popping over its head (seen only up close)
	SuspiciousEyeColor = Color3.fromRGB(255, 170, 30),
	ChaseEyeColor = Color3.fromRGB(255, 25, 20),
	Mark = { Range = 60, Seconds = 1.6, Size = 2.2, Height = 2 },
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

	-- Sounds (names from the manifest), heard out to SoundRollOff[2] studs (NightRollOff at night)
	Sounds = {
		Hum = "hum_loop",
		HumVolume = 0.35,
		NightHumVolume = 0.7,
		CueVolume = 0.9,
		Grab = "grab_clank",
		Notice = "spot_alert", -- with Voice.Notice when it spots you
		NoticeByType = { scout = "scout_eye_whine", brute = "brute_groan" },
		-- while it hunts you: the distorted jingle and a servo whine that climbs the longer it runs
		ChaseLoop = "jingle_distorted",
		ChaseLoopVolume = 0.55,
		ChaseWhine = "servo_whirr_1",
		ChaseWhineVolume = 0.6,
		ChaseWhinePitch = { 0.8, 1.5 },
		ChaseWhineRiseSeconds = 8,
		-- footsteps: one sound per Stride studs walked, so they speed up with the robot
		Steps = {
			cleaner = { sound = "heavy_step", stride = 4 },
			carrier = { sound = "heavy_step", stride = 4 },
			cook = { sound = "heavy_step", stride = 4 },
			scout = { sound = "scout_step", stride = 2.5 },
			brute = { sound = "brute_thud", stride = 5 },
			crawler = { sound = "crawler_skitter_loop", stride = 0 }, -- 0: loops while it moves
		},
		StepVolume = 0.35,
		NightStepVolume = 1,
	},
	SoundRollOff = { 6, 70 },
	NightRollOff = { 10, 140 },
	StateSounds = {
		chase = "chase_servo_scream",
		suspicious = { "curious_beep_1", "curious_beep_2", "curious_beep_3" },
		investigate = { "curious_beep_1", "curious_beep_2", "scanner_ping" },
		sweep = "scanner_ping",
		stalled = "error_stall",
	},
	CaughtDayLine = "A ROBOT GRABBED YOU. It took your %s back to its room. Sneak in and steal it back.",
	CaughtNightLine = "A ROBOT GOT YOU IN THE DARK.",
	CaughtDayHurtLine = "A ROBOT THREW YOU DOWN. Stay out of reach.",
	IdleSounds = { "oil_drip", "hydraulic_hiss", "fumble" },
	NightIdleSounds = { "scanner_ping", "servo_whirr_2", "hydraulic_hiss", "curious_beep_3" },
	IdleSoundGap = { 8, 20 },
	NightIdleSoundGap = { 4, 10 },
	IdleStates = { "study", "stalled", "return", "sweep", "investigate" },

	-- Keani's robot voice, layered over the mechanical sounds above. One line at a time per robot.
	Voice = {
		Chatter = "robot_chatter",
		ChatterEvery = { 10, 25 }, -- seconds, per robot, while calm and a player is in range
		ChatterRange = 45,
		Task = "robot_task", -- once per errand, when you walk up on one at work
		TaskRange = 15,
		Notice = "robot_notice", -- it looks at you (turns suspicious)
		Resume = "robot_resume", -- back to work after being suspicious
		Error = "robot_error",
		ErrorStates = { "stalled", "disabled" },
		CalmStates = { "study", "errand", "return" },
		ChatterStates = { "study", "errand", "return", "sweep", "investigate" }, -- night patrols mutter too
		Volume = 0.85,
		RollOff = { 6, 55 },
	},
}
