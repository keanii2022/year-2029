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
	InstallationBots = { 1, 3 },
	GiantInstallationBots = { 4, 7 },
	AreaPerBot = 1400,
	BotSpacing = 9, -- robots in a room spawn, study and idle at least this far apart
	-- One per installation stands in a corner facing the wall. Inside LookRange its head turns to
	-- follow you; it wakes after staring StareSeconds, when you come inside WakeRange, or on a sound.
	Watcher = { LookRange = 34, WakeRange = 9, StareSeconds = 4, CornerPad = 3 },

	-- Stiff bodies, heads that move too smoothly. The server says where a head looks (LookAt); each
	-- client turns it there at HeadSpeed degrees a second, slowing over the last HeadEase, with a
	-- ratchet tick every RatchetGap seconds while it still has more than RatchetMinTurn degrees to go.
	Motion = {
		HeadSpeed = 55,
		HeadEase = 25,
		MaxHeadTurn = 150,
		LookRange = 120, -- clients only turn heads this close to the camera
		Ratchet = "cam_servo",
		RatchetPitch = 0.6,
		RatchetVolume = 0.35,
		RatchetGap = 0.8,
		RatchetMinTurn = 6,
		-- the Watcher and scouts also crank their neck once as each turn starts
		NeckCrank = "robot_neck_crank",
		NeckCrankVolume = 0.4,
		-- a still head leans to one side now and then while it studies you
		Tilt = { Every = 7, Hold = 1.8, Degrees = 20 },
		StalledLookRange = 22, -- a hunter frozen by day follows you with its head this close
		-- awake hunters walking about hold dead still, then move in short fast bursts (Speed x walk)
		Burst = { Move = { 0.5, 0.9 }, Still = { 0.9, 2.2 }, Speed = 2.2 },
		-- a studying robot you look straight at (within Angle degrees, Range studs) for Seconds turns its
		-- head to you and stops working until you've looked away for Release seconds
		Watched = { Range = 30, Angle = 10, Seconds = 3, Release = 1 },
	},

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
		AlertVolume = 0.9,
		PackSound = "robot_pack_chatter", -- under the alert, the pack talking to each other
		PackVolume = 0.6,
		AnswerSounds = { "scout_eye_whine", "servo_whirr_1", "brute_groan" },
		AnswerPitch = 0.8,
		AnswerDelay = { 0.3, 1.2 },
		-- Up close at night a chasing hunter bursts past sprint speed (22) for a moment, screeching
		-- first, then cools down. Speed in studs per second, times in seconds.
		Lunge = { Range = 15, Speed = 26, Seconds = 1.5, Cooldown = 4 },
		-- Before a chase it freezes and stares this long (seconds), eyes brighter, hum cut, then goes
		Stare = { 0.6, 1 },
		StareGlow = 2.5, -- eye glow brightness and range, times normal, while it stares
		StareSound = "robot_lens_focus", -- its eye locking on as the stare starts
		StareVolume = 0.6,
		LungeSound = "chase_servo_scream",
		LungePitch = 1.35,
		LungeVolume = 0.9,
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

	-- One robot per installation keeps the stash: it stands at the back facing the crate, working with
	-- its back to the room for Work seconds, then glancing round for Glance. Anyone walking (not
	-- crouched) within HearRange of it makes it turn and look. No robot starts within DoorClear of a
	-- doorway, so stepping in is never an instant chase.
	Guard = { Reach = 3.5, Work = 7, Glance = 2.5, HearRange = 14, DoorClear = 14 },

	-- Nights that learn: each night a server survives adds a little, capped (night 1 is the base).
	-- Every HardEvery-th night is a hard night: HardHunters more per player and the PA glitching all
	-- night. The siren says which.
	Nights = {
		SightStep = 0.04,
		SightMax = 0.24,
		HunterEvery = 2, -- one more hunter per player every this many nights
		HunterMax = 2,
		SpeedStep = 0.25,
		SpeedMax = 1, -- night chase tops out at 21, still under a sprint (22)
		HardEvery = 10,
		HardHunters = 2,
		LearnLine = "Night %d. They're learning.",
		HardLine = "Night %d. Something's wrong with the PA. More of them tonight.",
		LineDelay = 1.5, -- seconds after the siren starts
		LineSeconds = 6,
		HardPa = "pa_glitch",
		HardPaGap = { 12, 30 },
		HardPaVolume = 0.3,
		HardPaPitch = { 0.8, 1.05 },
	},

	-- A hunting robot this close that you can't see: the lights round you flicker and the PA hums and
	-- glitches softly. Level eases up at Rise and down at Fall per second.
	Presence = {
		Range = 40,
		Hum = "distant_hum_loop",
		HumVolume = 0.25,
		Glitch = "pa_glitch",
		GlitchVolume = 0.2,
		GlitchGap = { 6, 14 },
		Rise = 0.8,
		Fall = 0.5,
	},

	-- One hunter a night (one of the first PickFrom to spawn) makes no footsteps and no hum until it lunges
	Silent = { PickFrom = 4 },

	-- Some night hunters spawn perched on top of a rack bay near a player instead of far off, hold still
	-- Perch seconds, then drop into the aisle (DropSeconds) and land hard.
	Racks = {
		DropChance = 0.3,
		Distance = { 16, 34 },
		Along = { -28, -16, 0, 16, 28 }, -- spots along a rack, from level with the player
		Inset = 3, -- lands this far out from the rack face
		Perch = { 1.5, 4 },
		DropSeconds = 0.45,
		LandStill = 0.7,
		Sounds = { "land_thud", "brute_thud" },
		Volume = 1,
		-- ticking up on top of the rack while it waits to drop, by type
		PerchSounds = { crawler = "robot_ceiling_tick" },
		PerchVolume = 0.45,
		PerchGap = { 0.8, 1.8 },
	},

	-- The mimic: at night, now and then, a robot replays a callout someone made Delay seconds ago from
	-- where it stands (Offset studs from the caller), pitched slightly wrong. Checked every CheckEvery
	-- seconds at Chance, then not again for Cooldown.
	Mimic = {
		Delay = { 6, 40 },
		Offset = { 25, 90 },
		Chance = 0.25,
		CheckEvery = 5,
		Cooldown = { 180, 300 },
		Copy = "robot_copy_callout_", -- the robot's own copy of each call (.. index); else Pitch on the original
		Pitch = 0.92,
		Volume = 0.8, -- a touch quieter than a real callout, and further off
		Tail = "walkie_static",
		TailVolume = 0.15,
		-- The lure: it sneaks to cover out of the callers' sight, goes dark and still, calls, and waits.
		-- Cover spots are probed on rings round it; each probe ray (CoverProbe studs) that hits counts.
		CoverRings = { 6, 10, 14, 18 },
		CoverSteps = 12, -- spots per ring
		CoverRange = { 4, 20 },
		CoverMin = 2, -- probe hits needed: beside a rack end or a pillar, more in a corner
		CoverProbe = 5,
		CoverDistanceCost = 0.1,
		FortClearance = 8, -- never hides this close to a piece a player placed
		SneakSeconds = 15, -- not in cover by then: gives up without calling
		WaitSeconds = 30,
		Repeats = { 0, 2 }, -- extra calls while it waits
		RepeatGap = { 8, 12 },
		PounceRange = 10,
		ViewRange = 18,
		ViewAngle = 35, -- degrees either side of where it faces
		-- its head follows one player while it waits (Logic/RobotMimic.track)
		TrackRange = 30,
		HoldSeconds = 3,
		SwitchMargin = 0.25, -- someone this much nearer takes the lock
		HeadSpeedFactor = 0.35, -- a slow deliberate turn, never a snap
		CrankRange = 12, -- the only sound its head makes, and only this close
		CrankVolume = 0.12,
		-- fair tells: a faint glint and the wet breath, heard within TellRange
		LurkEyeColor = Color3.fromRGB(45, 10, 10),
		LurkGlow = { Range = 2, Brightness = 0.25 },
		TellRange = 12,
		RevealGlow = 3, -- the eyes snap this much brighter than normal as it pounces, then settle
		-- the player its head is locked on, once they can see it: a faint red at the screen edges and
		-- the heartbeat up a little (halved with Gentler scares)
		SingledDread = 0.3,
		SingledRise = 0.35, -- per second
		SingledFall = 0.5,
		VignetteColor = Color3.fromRGB(110, 0, 0),
		VignetteAlpha = 0.3,
		VignetteSize = 0.18, -- of the screen, from each edge
	},

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
		Volume = 0.7,
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
	-- beats a walk, none beats a sprint. nightChaseSpeed: hunters at night run close to a sprint, so
	-- stamina decides who gets away.
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
			nightChaseSpeed = 20,
			sightRange = 70,
			agentHeight = 7,
			armor = 150,
		},
		brute = {
			role = "hunter",
			walkSpeed = 8,
			chaseSpeed = 15,
			nightChaseSpeed = 19,
			sightRange = 45,
			agentHeight = 8,
			armor = 300,
		},
		crawler = {
			role = "hunter",
			walkSpeed = 9,
			chaseSpeed = 18,
			nightChaseSpeed = 20,
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
		-- the first uploaded name wins (Logic/RobotSounds)
		Sputter = { "robot_knockdown_sputter", "emp_shutdown" },
		Reboot = { "robot_reboot_gasp", "hydraulic_hiss" },
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
				-- knocking robots down is also a way to find a gun
				{ id = "Smg", count = 1, weight = 2 },
				{ id = "Revolver", count = 1, weight = 2 },
				{ id = "Shotgun", count = 1, weight = 2 },
				{ id = "NailGun", count = 1, weight = 2 },
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
		FeelRadius = 6, -- this close, a robot notices you whatever way it faces (unless you're hidden or crouched)
		FaceRadius = 16, -- standing in its cone this close, it sees you even crouched, busy or not
		FootstepRadius = { Walk = 12, Sprint = 30, Crouch = 0 },
		NoticeSeconds = 1.4, -- by day, how long you can stay in view before it charges (less up close)
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
	DayLeash = 70, -- a day chase gives up this far from home, so running out of the room works
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
		Reach = 60, -- and this close to the robot's room (under DayLeash, so a chase still holds)
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
	StashPerRoom = 8, -- crates one room's shelves hold; the oldest goes when another lands
	MaxGunshots = 24, -- gunshots robots remember at once; each robot checks every one per tick
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
		-- a chore bot noticing you, under Voice.Notice
		ChoreNotice = "robot_broken_welcome",
		ChoreNoticeVolume = 0.55,
		-- its face flips to red: turning hostile, or noticing you at night
		TurnByType = { cleaner = "robot_smile_glitch" },
		TurnVolume = 0.6,
		-- a still robot watching at night (staring, frozen, or a Watcher) breathes while the hum is cut
		Breath = "robot_wet_servo_breath",
		BreathVolume = 0.4,
		-- a loop while it moves, louder and higher the faster it goes (fullSpeed studs per second)
		MoveLoops = { brute = { sound = "robot_floor_scrape_drag", volume = 0.5, fullSpeed = 20 } },
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
			-- 0: loops while it moves and cuts dead when it stops, so it follows the bursts
			crawler = { sound = { "robot_skitter_burst", "crawler_skitter_loop" }, stride = 0 },
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
	-- Per type: added to its idle noises once uploaded, and state cues that take over from StateSounds
	TypeSounds = {
		cook = { Idle = { "robot_order_bell" }, NightIdle = { "robot_order_bell" } },
		carrier = { NightIdle = { "robot_scanner_sweep" }, States = { investigate = "robot_scanner_sweep" } },
	},

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
