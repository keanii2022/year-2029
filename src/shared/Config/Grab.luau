return {
	Tag = "Grabbable",

	-- Reach, in studs from the player's root part.
	GrabReach = 12,
	PlaceReach = 18,
	MinHoldDistance = 4,
	MaxHoldDistance = 12,
	DefaultHoldDistance = 7,
	WheelStep = 1,

	GridSize = 1,
	RotateStep = 15,
	FreeRotateSpeed = 120, -- degrees per second while the free-rotate button is held
	MaxPlaceAboveFeet = 12, -- tallest a stack can get: prop bottom above the placer's feet
	MaxDropFall = 60,

	AimRate = 20, -- client aim updates per second
	GhostRate = 10, -- server ghost previews per second
	CarrySmoothing = 18,

	-- Heavy props slow the carrier down: full speed at LightMass, MinSpeedMultiplier at HeavyMass.
	LightMass = 15,
	HeavyMass = 80,
	MinSpeedMultiplier = 0.55,

	-- Pulling a piece out of someone else's fort.
	PrySeconds = 3,
	PryGrace = 0.25, -- seconds of network slack when the client says the pry finished
	PryNoiseInterval = 1, -- loud noise and a creak at the piece this often while prying
	PrySounds = { "cabinet_creak", "scrape", "wardrobe_creak" },
	PryOwnerWarning = "Someone is pulling apart your fort",
	PryOwnerWarningCooldown = 10,
	PryHint = "[Hold F] Pry loose",

	SpawnTestProps = true,
	TestPropsOrigin = Vector3.new(20, 0, 20),
}
