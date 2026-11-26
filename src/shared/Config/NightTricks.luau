-- Night tricks: flashlight battery, breath holding, generators, storm, night PA, room sound, lore.
return {
	TickEvery = 0.25, -- seconds between server meter updates
	PromptReach = 8, -- studs for generator, fuel can and journal prompts

	Battery = {
		Max = 100,
		DrainPerSecond = 0.55, -- about three minutes of light per battery
		LowAt = 20, -- flickers below this
		ItemId = "FlashlightBattery", -- a fresh one is swapped in when you switch on with a dead battery
		FlickerSlot = 0.07, -- seconds per flicker step on the client
		FlickerDim = 0.15, -- brightness share during a dip
		Bar = {
			Width = 120,
			Height = 6,
			Color = Color3.fromRGB(225, 220, 190),
			LowColor = Color3.fromRGB(190, 30, 30),
		},
	},

	Breath = {
		Max = 100,
		DrainPerSecond = 14, -- about seven seconds held
		RefillPerSecond = 9,
		MinToStart = 25, -- need this much before you can hold again
	},

	Winded = {
		SprintGain = 1, -- effort per second sprinting
		Rest = 0.6, -- effort lost per second not sprinting
		Max = 12,
		BreatheAbove = 4, -- heavy breathing once you stop with more effort than this
		Volume = 0.5,
	},

	Generators = {
		Count = 6,
		SpotPad = 10,
		SpotGap = 220,
		SpotTries = 60,
		MaxFuel = 100,
		StartFuel = 35,
		BurnPerSecond = 0.4, -- a full tank runs about four minutes, one night
		SputterAt = 15,
		CanFuel = 50, -- one fuel can fills this much
		PullChances = { 0.3, 0.5, 0.75, 1 }, -- chance on the 1st, 2nd... pull; last one repeats
		FixTime = 4, -- hold seconds on the prompt
		PullCooldown = 1.2,
		HumEvery = 7, -- seconds between loud hum events robots can hear
		HumLevel = "loud",
		Light = {
			Count = 4,
			Radius = 22,
			Height = 16,
			Range = 48,
			Brightness = 2.2,
			Color = Color3.fromRGB(255, 226, 170),
			SputterDim = 0.25,
		},
	},

	FuelCans = {
		Count = 10,
		MaxCarry = 2,
		SpotPad = 6,
		SpotGap = 90,
		SpotTries = 40,
	},

	Lore = {
		SpotPad = 6,
		SpotGap = 160,
		SpotTries = 40,
	},

	Storm = {
		RainVolume = 0.35,
		LightningGap = { 25, 70 }, -- seconds between strikes at night
		NearChance = 0.4, -- near strikes are brighter and crack instead of rumble
		ThunderDelay = { 0.4, 2.5 }, -- far thunder comes later
		Flash = {
			Ambient = Color3.fromRGB(120, 130, 160),
			Brightness = 2,
			Hold = 0.07, -- seconds per flash
			Gap = 0.35, -- dark between the two flashes
			MoonlightBoost = 8, -- broken skylights light the floor
		},
		Silhouette = {
			Chance = 0.12, -- per near strike
			Models = { "scout_night", "brute_night", "cleaner_night" },
			MinDistance = 45,
			MaxDistance = 140,
		},
		ShelfNoiseGap = { 30, 80 }, -- the store moving shelves somewhere far off
		ShelfNoiseVolume = 0.25,
	},

	PA = {
		Gap = { 70, 150 }, -- seconds between night announcements
		RightChance = 0.35, -- the aisle line uses a real player's aisle
		RecordedAisle = 32, -- the aisle the canned version of the aisle line names
		AisleVoice = "pa_remain_still", -- spoken without a number; the subtitle has the aisle
		ChimeToLine = 1.2,
		SubtitleTime = 5,
		AisleLine = "Shopper in aisle %d, please remain still.",
		Lines = {
			{
				voice = "pa_closed",
				text = "Attention shoppers. The store is now closed. Please remain where you are.",
			},
			{ voice = "pa_parents", text = "Will the parents of ... please come to the front desk." },
			{
				voice = "pa_thank_you",
				text = "Thank you for staying with us. Thank you for staying. Thank you.",
			},
		},
		GlitchChance = 0.3,
		Volume = 0.8,
	},

	-- SoundService.AmbientReverb per place.
	Reverb = { Aisle = "Hangar", Room = "LivingRoom", Installation = "StoneRoom", Hidden = "PaddedCell" },

	Peek = {
		Slats = 7,
		Gap = 0.035, -- screen share each slat leaves open
		Color = Color3.fromRGB(6, 6, 8),
	},

	Sounds = {
		Flicker = "flashlight_flicker",
		DeadClick = "flashlight_click", -- the light was refused (dead battery, no spare)
		HoldBreath = "hold_breath",
		Release = "breath_release",
		Gasp = "breath_release",
		Heavy = "breath_heavy_loop",
		GeneratorStart = "generator_start",
		GeneratorFail = "generator_pull_fail",
		GeneratorRun = "generator_run_loop",
		GeneratorSputter = "generator_sputter",
		GeneratorDie = "generator_die",
		FuelPour = "fuel_pour",
		Rain = "rain_roof_loop",
		ThunderNear = "thunder_near",
		ThunderFar = "thunder_far",
		Chime = "pa_chime",
		Glitch = "pa_glitch",
		ShelfScrape = "shelf_scrape_far",
		ShelfThud = "shelf_thud_far",
	},

	-- Survivor journals. Original text: what happened in 2029. id is the 2029 Files id (Config.Files).
	Journals = {
		{
			id = "journal_3",
			title = "Journal, page 3",
			text = "The helper bots learned everything from watching us. How we stack, how we sweep, how we smile at the door. Nobody taught them when to stop.",
		},
		{
			id = "journal_9",
			title = "Journal, page 9",
			text = "Corporate closed the store in March. Turned off the music, locked the gates. The bots didn't get the memo. They're still restocking shelves nobody will buy from.",
		},
		{
			id = "journal_14",
			title = "Journal, page 14",
			text = "At night they stop being helpful. Same faces, different job. If one stops outside your hiding spot, don't breathe. I mean it.",
		},
		{
			id = "journal_21",
			title = "Journal, page 21",
			text = "Found a generator that still runs. Light keeps the dark away, not them. They follow the hum like it's the dinner bell.",
		},
		{
			id = "journal_26",
			title = "Journal, page 26",
			text = "The aisles were different this morning. My chalk marks are gone. Somebody moved the shelves while I slept and it wasn't any of us.",
		},
		{
			id = "journal_last",
			title = "Journal, last page",
			text = "The speakers called my aisle tonight. I don't know how it knew. If you're reading this, the exit isn't where the signs say.",
		},
	},
}
