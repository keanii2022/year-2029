return {
	Tag = "Grabbable",
	-- Placed props get an invisible box (robot pathing). Bullets cast in ShotGroup pass through
	-- BlockerGroup, so a shot over a couch seat doesn't stop on thin air.
	BlockerGroup = "FortBlocker",
	ShotGroup = "Shots",

	-- Reach, in studs from the player's root part.
	GrabReach = 12,
	GrabReachUp = 14, -- this much straight up is free, so high shelves can be reached from the floor
	AimConeRadius = 1.5, -- studs around the crosshair ray a prop may sit and still be picked
	PlaceReach = 24,
	MinHoldDistance = 4,
	MaxHoldDistance = 12,
	DefaultHoldDistance = 7,
	WheelStep = 1,

	GridSize = 1,
	RotateStep = 90, -- a spin or tip tap turns this much
	FineRotateStep = 15, -- with the fine modifier held (Shift, L2), or each step of a held SPIN on a phone
	TouchSpinRepeat = 0.25, -- a held SPIN steps FineRotateStep this often
	RepeatDelay = 0.2, -- a tap steps WheelStep; holding closer / farther past this keeps going
	HoldDistanceSpeed = 6, -- studs per second while closer / farther is held
	MaxPlaceAboveFeet = 20, -- tallest a stack can get: prop bottom above the placer's feet
	MaxDropFall = 60,
	PlaceTolerance = 0.3, -- studs a placed prop may sink into its neighbours or a bumpy floor
	PlaceSlack = 0.1, -- extra sink the server allows on top, so a green ghost always places
	PushMax = 1.5, -- a blocked spot is nudged out along the blocking face up to this far
	PushStep = 0.25,
	-- Still blocked: try stepping the spot back toward you up to SearchBack and sideways up to
	-- SearchSide, SearchStep at a time, so a cluttered corner still finds the nearest free spot
	SearchBack = 3,
	SearchSide = 1,
	SearchStep = 1, -- 11 tries at most, so a red ghost never costs a frame
	CameraSlack = 6, -- studs the reported camera may sit from the head before the head is used instead
	HoldToLetGo = 0.6, -- seconds holding the grab button to let go in place, whatever's in the way
	SettleSeconds = 6, -- a let-go prop falls with physics, then freezes once still or after this

	-- Snapping to placed pieces: within SnapReach and facing within SnapAngle degrees the same way,
	-- a face closer than SnapRange goes flush and ends closer than SnapRange line up.
	SnapReach = 2,
	SnapRange = 0.75,
	SnapAngle = 5,

	GhostTransparency = 0.5,
	AimRate = 10, -- hold reports per second; the server moves the real prop for everyone else from these

	-- Heavy props slow the carrier down: full speed at LightMass, MinSpeedMultiplier at HeavyMass.
	LightMass = 15,
	HeavyMass = 80,
	MinSpeedMultiplier = 0.55,

	-- Pulling a piece out of someone else's fort.
	PrySeconds = 3,
	FortPrySeconds = 4.5, -- a fortified piece (touching another placed piece or a wall) holds longer
	BrutePrySeconds = 5, -- brutes are the only robots that pull fortified pieces, and it takes this
	FortGap = 0.3, -- closer than this to a placed piece or a wall counts as touching
	FortWallOverlap = 0.5, -- a fixed neighbour must share this much height to count as a wall, not a floor
	FortOutlineRange = 40, -- your own fort pieces this close get a faint outline, on your screen only
	FortOutlineEvery = 1, -- seconds between outline rescans
	PryGrace = 0.25, -- seconds of network slack when the client says the pry finished
	PryNoiseInterval = 1, -- loud noise and a creak at the piece this often while prying
	PrySounds = { "cabinet_creak", "scrape", "wardrobe_creak" },
	PryOwnerWarning = "Someone is pulling apart your fort",
	PryOwnerWarningCooldown = 10,

	-- Shown when a grab or drop is refused, keyed by the GrabRules reason
	Refused = {
		["too far"] = "Out of reach",
		taken = "Someone's carrying that",
		["hands full"] = "Your hands are full",
		["no ground"] = "Nothing under it to land on",
		["too high"] = "Too high to stack",
		blocked = "No room here",
		player = "Someone's standing there",
		["through wall"] = "Can't place through that",
	},

	SpawnTestProps = true,
	TestPropsOrigin = Vector3.new(20, 0, 20),
}
