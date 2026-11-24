-- Press to use (E / Square) and the loudness system. What each object does lives in Logic/InteractKinds.
return {
	Reach = 9, -- studs from the player's root to the object's bounding box
	ObjectCooldown = 0.35, -- seconds between uses of one object
	PlayerCooldown = 0.2,

	OpenTime = 0.45, -- hinge and slide tweens
	PressTime = 0.15, -- buttons and levers go down, then back up in the same time
	PopHold = 1.2, -- toast, jack and the vending flap stay out this long
	StaticBurst = 0.35, -- static between TV channels
	BubbleTime = 2.5, -- floating text over a button or phone

	SpinRate = 20, -- spinning part updates per second
	BobPeriod = 6, -- seconds for a lava lamp blob to drift up and back down
	ContinuousEvery = 2, -- seconds between loudness events from a boombox, TV or ringing phone

	-- Lamps and signs that are switched on light up the area around them.
	Light = { Range = 18, Brightness = 1.4, Color = Color3.fromRGB(255, 214, 160) },

	-- Hiding
	HiddenCheckEvery = 0.25,
	HideMoveTolerance = 1, -- a hiding spot that moves further than this (grabbed, pushed) drops you out
	EjectDistance = 2.5, -- studs in front of the spot where you land when found
	RevealHold = 1.5, -- a found spot stays open this long

	-- Sit and search
	CushionItem = "BlasterCells",
	CushionChance = 0.35,
	CushionAmmo = { Min = 2, Max = 6 },
	CushionCooldown = 300, -- seconds before the same couch can pay out again
	CushionFoundLine = "You dig through the cushions... + %d Blaster Cells",
	CushionNothingLine = "You dig through the cushions. Crumbs. Nothing.",
	CushionEmptyLine = "Someone already searched this one.",
	SitSpinTime = 1.2,

	-- Vending machine. Step 9 adds the snack item; until then the machine plays but drops nothing.
	VendingItem = "Snack",
	VendingStock = 3,

	-- Rotary phone
	PhoneRingGap = { Min = 90, Max = 240 },
	PhoneRingFor = 12,
	PhoneTalkTime = 9,

	-- Keani picks the boombox music (original or free library). Paste its rbxassetid:// here.
	BoomboxMusicId = nil :: string?,

	Volume = 0.8,

	-- Voice lines from art/sounds/VOICE_LINES.md, with the words shown in a bubble until they're recorded.
	ButtonLines = {
		{ sound = "button_good_job", text = "Good job!" },
		{ sound = "button_task_complete", text = "Task complete!" },
		{ sound = "button_you_did_it", text = "You did it!" },
	},
	PhoneLine = {
		sound = "phone_message",
		text = "Hello! Thank you for calling. Your call is very important to us. Please stay on the line. We know where you are. Please hold.",
	},
	ScreenLine = "Are you still there?",
	SoldOutLine = "SOLD OUT. Thank you for shopping!",

	-- From art/SOUNDS.md. Quiet sounds reach robots only inside the same room.
	Loudness = {
		Levels = {
			quiet = { players = 20, robots = 0, robotsInRoom = true },
			normal = { players = 45, robots = 25 },
			loud = { players = 120, robots = 80 },
		},
		RecentSeconds = 12, -- Loudness.recent forgets events older than this
		MaxRecent = 300,
		RollOffMinFraction = 0.12, -- full volume inside this share of the hearing range
	},
}
