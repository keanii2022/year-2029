-- Aisle 40, the Smile Aisle, and the store's small secrets. Server SmileAisle builds and runs them;
-- client SmileAisle plays the aisle's own PA lines and the sign that reads 41. Where things go is
-- planned in Logic/WarehouseGenSmileAisle from Config.Warehouse.SmileAisle.
-- Secrets are never in the normal UI: no hints, no prompts until something is actually there to use.
-- All writing is original: no real stores, brands or people.
return {
	Propaganda = {
		"SMILE. IT'S MANDATORY.",
		"A HAPPY SHOPPER IS A SAFE SHOPPER",
		"WE CAN SEE YOU SMILING",
		"FROWNING IS SHOPLIFTING",
	},
	-- Every PosterImageEvery-th poster is one of the store's printed ones (Config.Warehouse decals)
	PosterImages = { "smile_on_camera", "smile_on_camera_defaced" },
	PosterImageEvery = 4,
	PosterSize = Vector3.new(3, 4.5, 0.05),
	Banners = { "SMILE!", "SMILING IS MANDATORY", "SAY CHEESE", "HAPPY HELPERS, HAPPY SHOPPERS" },
	-- Survivor paint over every few posters and banners
	Spray = { "DON'T SMILE BACK", "IT'S NOT A SMILE", "DON'T SMILE BACK", "THEY COUNT TEETH" },
	SprayColor = Color3.fromRGB(170, 18, 18),
	PosterColor = Color3.fromRGB(222, 210, 172),
	PosterInk = Color3.fromRGB(150, 62, 72),
	SmileyYellow = Color3.fromRGB(228, 194, 72),
	SmileyInk = Color3.fromRGB(30, 26, 22),
	TearBlue = Color3.fromRGB(90, 150, 210),
	StickerSize = 0.7,
	NeonSign = {
		Text = "SMILE :)",
		Size = Vector3.new(7, 1.8, 0.3),
		Y = 14,
		Color = Color3.fromRGB(255, 120, 170),
		Light = { Range = 16, Brightness = 1.2 },
	},
	Greeter = { Model = "greeter", WavePose = 0.3 }, -- frozen mid-wave

	Booth = {
		Size = Vector3.new(3.5, 8, 2.5),
		Color = Color3.fromRGB(214, 196, 188),
		ScreenColor = Color3.fromRGB(12, 16, 14),
		TextColor = Color3.fromRGB(150, 230, 170),
		AcceptColor = Color3.fromRGB(120, 255, 150),
		RejectColor = Color3.fromRGB(255, 110, 110),
		Idle = "SMILE FOR THE HELPERS",
		Scanning = "HOLD STILL. SCANNING...",
		Reject = "NO SMILE DETECTED. TRY HARDER.",
		Progress = "SMILE LEVEL {n}/{total}",
		Accepted = "SMILE ACCEPTED. WELCOME BACK, MANAGER.",
		Mark = "STAND HERE :)",
		MarkRadius = 2.2,
		RejectAfter = 4, -- seconds on the mark without bowing before it turns you down
		Every = 0.1,
		Bows = { Bows = 3, DownMin = 0.15, DownMax = 1.5, GapMax = 2.5 }, -- Logic/SmileCheck
	},
	-- The one hint in the aisle: a crying smiley sticker low on the rack beside the booth, three red
	-- tally marks under it
	HintMarks = "I I I",

	Office = {
		OpenSeconds = 45, -- then the panel slides shut once nobody stands in the doorway
		SlideSeconds = 1.6,
		DoorHeight = 7.5,
		Wall = 1,
		Ceiling = 10,
		WallColor = Color3.fromRGB(58, 98, 96), -- the rack uprights' teal, so it reads as more racking
		InsideColor = Color3.fromRGB(120, 108, 92),
		CarpetColor = Color3.fromRGB(70, 58, 52),
		Lamp = { Color = Color3.fromRGB(255, 196, 130), Range = 14, Brightness = 0.9 },
		Spill = { Range = 18, Brightness = 1.4 }, -- warm light out through the open panel
		NameTag = { Top = "HELLO, MY NAME IS", Role = "NIGHT MANAGER" },
		Drawing = "ME AND DAD",
		Tape = { Prompt = "Play", Object = "Tape recorder", File = "secret_office", Voice = "dad_last_tape" },
		Lanyard = {
			Prompt = "Take",
			Object = "Lanyard",
			Stat = "NightManager",
			Again = "You're already wearing his.",
		},
		Release = { Prompt = "Open", Object = "Door release" },
		PromptReach = 6,
	},

	Sounds = {
		Beep = "vending_beep",
		Accepted = "computer_chime",
		Reject = "pa_glitch",
		Slide = "shelf_scrape_far",
		Tape = "tape_insert",
		Ring = "phone_ring",
		Pickup = "phone_handset",
		Crackle = "neon_crackle",
		Chime = "pa_chime",
	},
	Volume = { Booth = 0.6, Slide = 0.8, Ring = 0.7, Small = 0.5, Chime = 0.5 },
	RollOff = { Min = 8, Max = 80 },

	-- Lines only aisle 40 hears, by day, while you're standing in it
	PaGap = { 25, 55 },
	PaFirst = { 6, 14 }, -- the first one after you walk in comes sooner
	PaSubtitleSeconds = 6,
	PaLines = {
		{
			voice = "pa_aisle40_counting",
			text = "Shoppers in aisle 40: please smile for the helpers. The helpers are counting.",
		},
		{
			voice = "pa_aisle40_happy",
			text = "A happy shopper is a safe shopper. Are you happy, shopper in aisle 40?",
		},
		{
			voice = "pa_aisle40_frowning",
			text = "Frowning has been detected in aisle 40. Frowning is shoplifting.",
		},
		{ voice = "pa_aisle40_wider", text = "Wider, please. A little wider. Thank you, aisle 40." },
		{
			voice = "pa_aisle40_manager",
			text = "Would the night manager please return to aisle 40. Your shift is not over.",
		},
	},

	-- The phone on the office's aisle wall rings only at night, only while someone is in aisle 40.
	-- The robots copy the night manager's voice; this one has learned a little too much.
	Phone = {
		Model = "rotary_phone",
		Gap = { 30, 70 },
		RingSeconds = 12,
		Prompt = "Answer",
		Object = "Phone",
		Reach = 7,
		File = "secret_phone",
		Line = {
			voice = "dad_phone_bud",
			text = "Hey bud. I'm in the office, behind the smiles. The booth can't tell a smile from a bow. Three little bows. ...Smile for the helpers, bud.",
			style = "dad",
		},
		SubtitleSeconds = 9,
	},
	TapeLine = {
		voice = "dad_last_tape",
		text = "Last tape. They learned my voice from these. If a helper says I'll come find you, that's not me. I'd say stay put. Stay put, bud. I'm coming.",
		style = "dad",
	},
	TapeSubtitleSeconds = 10,

	-- Just inside the doors: a lost and found box with the ghost kid's raincoat in it
	LostFound = {
		Prompt = "Look inside",
		Object = "Lost & Found",
		File = "secret_lost_found",
		Label = "LOST & FOUND",
		Sticker = "LOST CHILD",
		Reach = 7,
		BoxColor = Color3.fromRGB(150, 116, 78),
		CoatColor = Color3.fromRGB(232, 196, 40),
	},

	-- The aisle 40 sign reads 41 while you're not looking at it (Logic/SmileCheck.stepSign)
	Sign = { HiddenFor = 3, Chance = 0.35, SeenFor = 0.35, Range = 70, Every = 0.2 },
}
