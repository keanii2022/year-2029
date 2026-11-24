-- Haunts and life: the lost kid, private scares, critters, mannequins, the greeter, security cams
-- and survivor story spots. Distances in studs, times in seconds.
return {
	-- Director: who gets a private scare and when
	DirectorEvery = 2,
	AloneRadius = 80, -- no other living player this close counts as alone
	ChancePerMinute = 0.35, -- for one player alone at night; scaled by PhaseWeight
	PhaseWeight = { Day = 0.1, Siren = 0.4, Night = 1 },
	MinGap = 75, -- never two scares on one player closer than this
	GuaranteeAfter = 100, -- alone at night this long without a scare forces a visual one

	-- Each private scare the server can send. weight picks between ready ones; cooldown is per player;
	-- nightBudget caps it per server per night; visual ones count toward the guarantee.
	Scares = {
		kid_peek = { weight = 2, cooldown = 600, phases = { Night = true }, nightBudget = 1, visual = true },
		mannequin_behind = {
			weight = 3,
			cooldown = 300,
			phases = { Siren = true, Night = true },
			visual = true,
		},
		ball_roll = { weight = 3, cooldown = 360, phases = { Night = true }, visual = true },
		flock_burst = { weight = 2, cooldown = 240, visual = true },
		giggle = { weight = 3, cooldown = 180, phases = { Night = true }, hiddenOk = true },
	},

	-- Client side of the private scares
	Kid = {
		Distance = { Min = 24, Max = 40 },
		BeamEdge = 4, -- degrees past the flashlight cone edge, so it stands just outside the light
		ViewEdge = 30, -- degrees off centre when the flashlight is off
		Hold = 4, -- seconds it stands there if you don't come closer
		VanishDistance = 14,
		TiltAfter = 0.8,
		TiltDegrees = 55,
		FadeTime = 0.35,
		ToyStays = 60, -- the stuffed robot it leaves behind
	},
	MannequinBehind = { Distance = 9, SeenFor = 1, Timeout = 25, TooClose = 4, ReachDegrees = 80 },
	Ball = { Distance = 32, StopShort = 3, RollTime = 5, Stays = 20 },
	Flock = { Count = 6, Distance = 12, Rise = 30, FlyTime = 1.4 },
	GiggleBehind = 6,

	Sounds = {
		Giggle = { "kid_giggle", "kid_humming", "kid_come_find_me" },
		KidAppear = "kid_giggle",
		Greeter = "announcer_welcome",
		PigeonBurst = "pigeon_flutter", -- not in the sound pack yet: silent until one is uploaded
		RatScatter = "rat_squeak", -- same
	},
	Volume = 0.6,

	-- Everyone-sees life, checked on the server
	LifeEvery = 0.5,
	CamEvery = 0.25,
	ViewHalfAngle = 70, -- a player "sees" anything inside this cone from where they face
	ViewRange = 120,

	Pigeons = {
		Flocks = 30,
		PerFlock = { 5, 8 },
		Spread = 5,
		SprintNear = 26,
		WalkNear = 7,
		SprintSpeed = 18, -- root speed over this counts as sprinting
		FlyTime = 1.6,
		FlyHeight = 35,
		FlyAway = 40,
		ReturnAfter = 120, -- the flock comes back when nobody is near
	},
	Rats = {
		Nests = 30,
		PerNest = { 3, 5 },
		Spread = 3,
		Near = 8,
		BeamRange = 60, -- matches the flashlight beam
		BeamHalfAngle = 22.5,
		FleeDistance = { 14, 24 },
		FleeTime = 0.8,
		ReturnAfter = 60,
	},
	Moths = {
		Lamps = 30,
		PerLamp = 3,
		Height = 7,
		Radius = { 1.2, 2.4 },
		Speed = { 1.5, 3 }, -- radians per second
	},
	Mannequins = {
		CheckEvery = 4,
		Chance = { Day = 0.15, Siren = 0.4, Night = 0.7 },
		NearPlayer = 90, -- only bother when someone is close enough to notice
		FaceTurn = 0.5, -- chance the new pose also turns it to face the nearest player
		-- Joint turns in steps of Config.Models.MoverDegrees; positive swings a limb forward and up
		Poses = {
			stand = {},
			reach = { UpperArm = 3, Forearm = 1 },
			point = { LeftUpperArm = 2.8, Head = 1 },
			crouch = { Thigh = 3, LeftThigh = 3, Shin = -3, LeftShin = -3 },
			lookback = { Head = 3 },
			hug = { UpperArm = 2, LeftUpperArm = 2, Forearm = 2, LeftForearm = 2, Head = -1 },
		},
	},
	Greeter = {
		Every = 25,
		Hear = 70,
		-- Worse each night: slower, lower and more broken
		SpeedDropPerNight = 0.05,
		MinSpeed = 0.6,
		DistortionPerNight = 0.12,
		MaxDistortion = 0.75,
	},
	Cams = {
		Count = 40,
		Height = 16,
		Range = 70,
		TurnSpeed = 30, -- degrees per second
		Color = Color3.fromRGB(255, 40, 40),
	},

	-- Story spots. Groups are laid out around a spot, offsets in studs facing +z.
	StorySpots = {
		camp = {
			count = 12,
			items = {
				{ name = "survivor_tent", dx = 0, dz = 0, turn = 0 },
				{ name = "sleeping_bag", dx = -6, dz = 3, turn = 80 },
				{ name = "sleeping_bag", dx = 6, dz = 4, turn = -100 },
				{ name = "candles", dx = 0, dz = 7, turn = 0 },
				{ name = "notes_wall", dx = 9, dz = -3, turn = -60 },
			},
		},
		drawings = { count = 10, items = { { name = "drawing_wall", dx = 0, dz = 0, turn = 0 } } },
		leak = {
			count = 25,
			items = {
				{ name = "leak_bucket", dx = 0, dz = 0, turn = 0 },
				{ name = "puddle", dx = 2.5, dz = 1.5, turn = 30 },
			},
		},
		skylight = {
			count = 15,
			items = {
				{ name = "puddle", dx = 0, dz = 0, turn = 0 },
				{ name = "weeds", dx = -2, dz = 2, turn = 40 },
				{ name = "weeds", dx = 2.5, dz = -1.5, turn = 200 },
			},
		},
		weeds = {
			count = 40,
			items = {
				{ name = "weeds", dx = 0, dz = 0, turn = 0 },
				{ name = "vines", dx = 2, dz = 1, turn = 90 },
			},
		},
	},
	SpotPad = 10, -- clearance around a story spot from shelves, rooms and junk
	SpotGap = 60, -- story spots and critter groups keep this far apart
	SpotTries = 40, -- random tries per wanted spot

	CandleLight = { Range = 12, Brightness = 1.2, Color = Color3.fromRGB(255, 170, 90) },
	Moonlight = { Height = 55, Range = 60, Angle = 40, Brightness = 2, Color = Color3.fromRGB(160, 180, 255) },

	-- Client loops: wave, fold, twitch, moth circles, cam turning, candle flicker, pigeon pecks
	LoopRange = 160,
	WavePeriod = 1.6,
	FoldPeriod = 4,
	TwitchGap = { 3, 9 },
	FlapRate = 14,
}
