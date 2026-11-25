-- Robot companions (Systems/Companion, Logic/RobotTrust, Logic/BuildPlan): a few chore robots each
-- morning turn curious, and a player who earns one's trust gets a robot that follows, guards and
-- in the end builds their fort. Trust is 0-100 per player, shown through body language, never a meter.
return {
	Enabled = true,

	CuriousPerServer = 2, -- unowned curious robots tagged each morning
	RepickEvery = 10, -- seconds between tries to fill the curious count while rooms wake up
	-- Blue-white instead of red, so a curious robot reads as different from across the aisle
	EyeColor = Color3.fromRGB(205, 232, 255),

	-- Items a curious robot can ask for, in rotation. Each must exist in Logic/InventoryItems; the
	-- ghost it holds up is the item's world model from Config.Supplies.Loot.
	Wants = {
		"Apple",
		"JuiceBox",
		"Popcorn",
		"Chips",
		"Sandwich",
		"NoodleCup",
		"Watermelon",
		"Lunchbox",
		"FlashlightBattery",
		"Bandage",
		"Snack",
		"EnergyDrink",
	},
	GhostColor = Color3.fromRGB(205, 232, 255),
	GhostTransparency = 0.45,
	GhostScale = 1.6,

	Trust = {
		Max = 100,
		DayCap = 50, -- most one in-game day can add, from every source together
		DecayPerMinute = 1.0, -- only while that player is further than NearDistance
		NearDistance = 40,
		Stages = { Watching = 20, Learning = 45, Bonded = 75 }, -- Bonded also needs a night survived
		Gift = 25, -- the item it wants: once per item per day
		Teach = 4, -- a piece you placed near it that stays put and counts as fortified
		TeachPerDay = 5,
		Repair = 8, -- standing it back up; nothing for the one who knocked it down
		Hide = 12, -- it ended the night with you or inside your fort
		RapportDaySeconds = 86400, -- saved rapport drops one stage per this many real seconds away
		BondedGraceSeconds = 900, -- a bond holds this long away (dead, or out of the server) before fading
	},

	-- Ownership
	OwnerGoneSeconds = 180, -- someone else can win it once its owner has been dead or out this long
	SwitchMargin = 5, -- a challenger needs this much more trust than the owner; a tie stays put
	LeftHoldSeconds = 300, -- owner left the server: it waits this long, then goes back to curious
	StageLossCooldown = 20, -- one burst of your shots costs one stage, not one per bullet
	-- Shooting it: no trust from it for the rest of the day, and it backs off you, chirping
	WaryRange = 10,
	WaryBackOff = 8,
	WaryChirpEvery = 4,

	-- Movement (studs)
	NoticeRange = 32, -- a curious robot turns to look at players this close
	TiltRange = 16, -- and tilts its head at ones this close
	TiltDegrees = 22,
	DoorInset = 4,
	TrailDistance = 15, -- Watching keeps this far behind by day
	BesideDistance = 4, -- Learning walks this far off your shoulder
	FollowDistance = 6, -- Bonded
	NightFollowDistance = 4,
	HurryDistance = 35, -- further than this it hurries to catch up
	LostDistance = 140, -- further than this it stops and waits where it is
	ArriveSlack = 2.5,

	-- Learning: carries one loose prop it found near you, and sets it down when you stop
	ScavengeRange = 24,
	ScavengeEvery = 3,
	ScavengeTimeout = 20,
	ScavengeRest = 15, -- seconds after a hand-off before it looks for the next one
	MaxHaulSize = 7,
	StillSeconds = 3, -- you stood still this long: it hands over what it carries

	-- Teaching by doing
	TeachRadius = 20,
	TeachHoldSeconds = 60,
	TeachMoved = 1.5, -- moved further than this before the minute is up and it didn't count

	-- Guarding (Bonded)
	GuardRadius = 16, -- players or robots this close to your fort set off the alarm chirp
	GuardScanEvery = 1,
	AlarmCooldown = 5,
	TugReach = 22, -- a pry on one of your pieces this close gets a tug-of-war
	TugSeconds = 0.6, -- added to the pry for every second it tugs
	TugCap = 6, -- most it can add to one pry
	FortRadius = 30, -- your placed pieces this close to it make up the fort it guards
	FortMinPieces = 2,

	-- Night: within KeepRadius of you or inside your fort, it stays yours. Otherwise a scout that
	-- sees it pulls it into the pack until morning.
	KeepRadius = 20,
	ScoutRange = 40,
	ScoutCheckEvery = 1,
	HidePad = 1, -- how far inside the fort's outline counts as inside

	-- Knocked down by guns: down this long, then a hold prompt stands it back up
	DownSeconds = 45,
	HomeSeconds = 20, -- not repaired in time: it wanders home this long, a stage lower
	RepairHold = 2.5,
	RepairReach = 10,
	-- What a repair uses, first one the player has: a battery, or scrap (blaster cells) in its place
	RepairItems = { { id = "FlashlightBattery", count = 1 }, { id = "BlasterCells", count = 10 } },
	GiveHold = 0.5,
	GiveReach = 10,
	BuildHold = 1,
	HoldSlack = 0.25, -- the server's hold timer may run this much short of a prompt's (lag)

	-- Builder (Bonded + a fort plan near your spot). Plan limits are SimPlayers.Forts.Plan.
	Build = {
		MaxPieces = 6,
		FetchTimeout = 35, -- seconds to reach a piece before giving up on it and picking another
		CarryTimeout = 45, -- seconds to get a carried piece to its slot before skipping the slot
		StuckSeconds = 3, -- no progress this long: re-path
		Repaths = 2, -- re-paths before giving up on this leg
		ProgressStep = 1, -- studs closer that count as progress
		PlaceTries = 3, -- refused set-downs before planning around whatever's in the slot
		PlayerPlaceTries = 8, -- refused because a player stands in the slot: wait longer, then move on
		PickupTime = 1.5,
		PlaceTime = 2.2,
		RestTime = 2,
		PickRetry = 4,
		SkipFor = 120, -- a piece it gave up on is left alone this long
		-- One fort a day per owner: MaxPieces new pieces a day across every "Build here", repairs free
		FoundCooldown = 30, -- seconds between "Build here" presses
	},

	-- Sounds (names in the sound pack; silent until uploaded), all through Mix.route SFX
	Sounds = {
		Notice = "curious_beep_1",
		Tilt = "servo_whirr_1",
		HappyLow = "curious_beep_2",
		HappyHigh = "curious_beep_3",
		HappyGap = 0.18,
		Sad = "error_stall",
		Alarm = "scanner_ping",
		Repair = "hydraulic_hiss",
		Flicker = "scout_eye_whine",
		Volume = 0.8,
	},

	-- Keani's robot voice (the robots copy the ghost kid's dad), kept soft and spaced out
	Voice = {
		Notice = "robot_notice", -- turns to look at you
		Gift = "robot_chatter",
		Bonded = "robot_resume",
		BuildStart = "robot_task",
		BuildDone = "robot_chatter",
		Down = "robot_error",
		Volume = 0.55,
		Cooldown = 12, -- seconds between lines from one robot
	},

	-- A Bonded robot wears your colour on its head when you never gave it anything
	BadgeColors = {
		Color3.fromRGB(240, 196, 80),
		Color3.fromRGB(110, 200, 140),
		Color3.fromRGB(120, 170, 240),
		Color3.fromRGB(230, 120, 170),
		Color3.fromRGB(200, 140, 250),
		Color3.fromRGB(250, 150, 90),
	},
	BadgeScale = 0.45,

	-- First-time hints (client)
	Hints = {
		Wants = "It wants something. Bring it.",
		Watching = "It's following you. Keep it close tonight.",
		Bonded = "It's yours now. Show it a spot to build.",
		Down = "It's down. Hold to fix it with a battery.",
		HintRange = 24,
	},
	FlickerRate = 12, -- eye flickers per second during the siren

	TickRate = 5,
}
