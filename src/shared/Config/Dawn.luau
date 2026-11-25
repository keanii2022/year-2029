-- The morning payoff (server Dawn + Tokens systems, client Dawn controller): the Dawn Report card,
-- Tokens, locker banking during the siren and forts paying out. Tokens are earned only by playing
-- and are never sold for Robux.
return {
	Tokens = {
		-- Surviving a night pays NightBase times the life streak multiplier: x1 the first night in
		-- one life, x2 the second ... up to x MaxMultiplier. Dying resets the streak.
		NightBase = 10,
		MaxMultiplier = 5,
		Mission = 5, -- each finished mission
		-- Each locker item stack added between the siren and lights out
		BankedPerStack = 2,
		BankedCap = 10,
		-- Each of your placed props still standing at dawn, capped
		FortPerPiece = 2,
		FortCap = 20,
		FortDogBonus = 5, -- your dog is near your fort at dawn
	},

	-- A placed prop still counts as standing if it moved less than this (studs) since lights out
	FortDrift = 4,
	FortTilt = 40, -- degrees; tipped further than this it was knocked over
	DogNearFort = 30, -- studs from any standing piece of your fort
	DogWithYou = 40, -- studs from you for the card's "dog with you" line

	-- Veteran tell: a life this many nights long gets a brighter flashlight beam (as everyone else
	-- sees it) and a faint glint on the head, so the hunted can hunt back. Gone when that life ends.
	Veteran = {
		Nights = 3,
		BeamBoost = 1.5,
		Glint = { Range = 6, Brightness = 0.35, Color = Color3.fromRGB(255, 225, 170) },
	},

	-- The card
	CarryShown = 4, -- most valuable things in your bag, by name
	BankedShown = 4,
	CardSeconds = 7,
	-- Presses this soon after it shows don't close it, so someone mid-sprint still gets to see it
	CardGrace = 0.75,
	-- Lets the lights finish coming on before the card and the chime arrive
	CardDelay = 2.1,
	Title = "DAY {day}. You made it.",
	Sounds = { Chime = "pa_chime" },
	ChimeVolume = 0.7,

	-- Lights snap on bank by bank, nearest first, a clunk each, then the store jingle.
	-- Music reads JingleDelay so the jingle lands after the last bank.
	LightsOn = {
		Banks = 4,
		Gap = 0.45, -- seconds between banks
		Clunk = "lights_out_clunk",
		ClunkVolume = 0.55,
	},
	JingleDelay = 2.6,

	-- Dim pillars over every locker from the siren until lights out, so siren runs lead to them
	LockerBeam = {
		Width = 1.6,
		Height = 40,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 0.75,
		LightRange = 14,
		LightBrightness = 1,
	},
}
