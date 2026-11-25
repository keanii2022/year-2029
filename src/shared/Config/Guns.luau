return {
	-- Every spawn gets this kit, so a fresh player can fight right away.
	StartingLoadout = {
		{ id = "StarterBlaster", count = 1 },
		{ id = "BlasterCells", count = 36 },
	},
	MaxHealth = 100,
	HealthRegen = false, -- healing comes from supplies later, not from standing still
	RespawnDelay = 6,

	-- rank orders the gun slots on the hotbar, best first. The server fires the gun selected there.
	-- Damage is full up to falloffStart studs, sliding down to minDamage at falloffEnd.
	-- mode (Logic/CombatModes): semi, auto (hold), burst (burstCount shots burstInterval apart per
	-- pull, fireInterval between pulls), pump (pumpTime rack after each shot, inside fireInterval)
	-- or single-action (the hammer takes cockTime to come back, then it fires). pellets: shotgun,
	-- damage is per pellet, spread in degrees. flare: leaves a light where it lands. robotWeapon:
	-- also fires the robot-killing arc (RobotGear, on its own cooldown).
	Blasters = {
		StarterBlaster = {
			rank = 1,
			ammo = "BlasterCells",
			mode = "semi",
			damage = 22,
			minDamage = 11,
			falloffStart = 40,
			falloffEnd = 140,
			range = 300,
			fireInterval = 0.22,
			magSize = 12,
			reloadTime = 1.6,
		},
		FlareGun = {
			rank = 2,
			ammo = "Flares",
			mode = "semi",
			flare = true,
			damage = 20,
			minDamage = 15,
			falloffStart = 30,
			falloffEnd = 120,
			range = 160,
			fireInterval = 1,
			magSize = 1,
			reloadTime = 1.8,
		},
		NailGun = {
			rank = 3,
			ammo = "BlasterCells",
			mode = "auto",
			damage = 16,
			minDamage = 9,
			falloffStart = 20,
			falloffEnd = 70,
			range = 160,
			fireInterval = 0.13,
			magSize = 24,
			reloadTime = 2.2,
		},
		Smg = {
			rank = 4,
			ammo = "BlasterCells",
			mode = "auto",
			damage = 13,
			minDamage = 7,
			falloffStart = 25,
			falloffEnd = 90,
			range = 220,
			fireInterval = 0.09,
			magSize = 30,
			reloadTime = 1.9,
		},
		Revolver = {
			rank = 5,
			ammo = "BlasterCells",
			mode = "single-action",
			cockTime = 0.18,
			damage = 45,
			minDamage = 25,
			falloffStart = 40,
			falloffEnd = 150,
			range = 300,
			fireInterval = 0.5,
			magSize = 6,
			reloadTime = 2.4,
		},
		Shotgun = {
			rank = 6,
			ammo = "Shells",
			mode = "pump",
			pellets = 8,
			spread = 5,
			pumpTime = 0.45,
			damage = 12,
			minDamage = 2,
			falloffStart = 10,
			falloffEnd = 40,
			range = 120,
			fireInterval = 0.95,
			magSize = 6,
			reloadTime = 2.6,
		},
		Rifle = {
			rank = 7,
			ammo = "BlasterCells",
			mode = "burst",
			burstCount = 3,
			burstInterval = 0.08,
			damage = 24,
			minDamage = 14,
			falloffStart = 60,
			falloffEnd = 200,
			range = 400,
			fireInterval = 0.45,
			magSize = 24,
			reloadTime = 2.2,
		},
		DartBlaster = {
			rank = 8,
			ammo = "Darts",
			mode = "semi",
			damage = 75,
			minDamage = 60,
			falloffStart = 50,
			falloffEnd = 200,
			range = 300,
			fireInterval = 1.2,
			magSize = 3,
			reloadTime = 2,
		},
		MarksmanRifle = {
			rank = 9,
			ammo = "BlasterCells",
			mode = "semi",
			damage = 65,
			minDamage = 50,
			falloffStart = 100,
			falloffEnd = 400,
			range = 600,
			fireInterval = 1.1,
			magSize = 5,
			reloadTime = 2.8,
		},
		Disruptor = {
			rank = 10,
			ammo = "BlasterCells",
			mode = "semi",
			robotWeapon = true,
			damage = 40,
			minDamage = 30,
			falloffStart = 40,
			falloffEnd = 160,
			range = 200,
			fireInterval = 1.2,
			magSize = 4,
			reloadTime = 3,
		},
	},
	-- Under the ammo count on the HUD
	AmmoLabels = { BlasterCells = "CELLS", Shells = "SHELLS", Flares = "FLARES", Darts = "DARTS" },

	-- A flare lights up where it lands for FlareTime seconds, fading out over the last FlareFadeTime.
	FlareTime = 25,
	FlareFadeTime = 3,
	FlareSize = 0.35,
	FlareColor = Color3.fromRGB(255, 90, 60),
	FlareBrightness = 3,
	FlareRange = 40,

	-- Server shot checks.
	FireIntervalSlack = 0.8, -- shots may arrive this fraction of the interval apart (network jitter)
	MaxOriginOffset = 6, -- studs between the client's camera and its head
	LineOfSightSlack = 0.5,
	ReloadTimeSlack = 0.8, -- the server may finish a reload this fraction of the time in (network jitter)

	-- Reload look: the blaster dips over the first share of the reload and rises over the last;
	-- the old mag drops out at the start and fades on the floor.
	ReloadDipShare = 0.25,
	ReloadRiseShare = 0.2,
	ReloadDropPitch = 35, -- degrees the blaster tips down mid-reload
	ReloadDropRoll = 25,
	ReloadDropSink = 0.25, -- studs
	MagFallTime = 1.5, -- seconds a dropped mag lies there before fading
	MagFadeTime = 0.6,
	MagStandInSize = Vector3.new(0.1, 0.22, 0.16),
	MagStandInColor = Color3.fromRGB(38, 40, 44),

	-- Moving parts on the gun models (Config.Hotbar.Guns says which reload each gun does).
	-- The shotgun's Pump slides PumpTravel studs back toward the grip and forward after each shot,
	-- starting when its shotgun_pump sound plays. The revolver's Hammer tips back HammerCockAngle
	-- degrees about its base and snaps forward over HammerSnapTime; its Mag drum turns one of
	-- DrumChambers per shot, and on reload swings DrumSwingOut studs out and spins DrumReloadSpins times.
	PumpTravel = 0.16,
	HammerCockAngle = 40,
	HammerSnapTime = 0.05,
	DrumChambers = 6,
	DrumSwingOut = 0.14,
	DrumReloadSpins = 2,

	-- Look and feel. The bullet is only a picture; the hit was already decided by the server's
	-- instant raycast. Its flight time is clamped so it lands about when the server answers.
	MuzzleOffset = Vector3.new(0.7, -0.6, -1.5), -- from the camera, where your shot starts with no held blaster
	OthersMuzzleForward = 1.8, -- studs ahead of another player's camera where their bullet starts
	BulletSpeed = 1400, -- studs per second
	BulletMinTravel = 0.04,
	BulletMaxTravel = 0.2,
	BulletLength = 4,
	BulletWidth = 0.22,
	BulletColor = Color3.fromRGB(255, 150, 80),
	BulletImage = "bullet_tracer", -- manifest image, head at the right end; Neon streak until uploaded
	BulletBrightness = 3, -- the texture has its own white core and orange glow, so it isn't tinted
	BulletGlowBrightness = 2.5,
	BulletGlowRange = 6,
	MuzzleFlashTime = 0.05,
	MuzzleFlashSize = 2.2,
	MuzzleFlashScaleJitter = 0.3, -- each flash is up to this share bigger or smaller
	MuzzleFlashColor = Color3.fromRGB(255, 190, 120),
	MuzzleFlashImage = "muzzle_flash_card",
	MuzzleLightTime = 0.035, -- about two frames
	MuzzleLightBrightness = 9,
	MuzzleLightRange = 18,
	ScorchSize = 0.55,
	ScorchColor = Color3.fromRGB(28, 24, 22),
	ScorchTime = 3, -- seconds before a scorch mark fades
	ScorchFadeTime = 1,
	MaxScorches = 40,
	ChipCount = 5, -- concrete chips knocked off the wall per shot
	ChipSize = 0.12,
	ChipSpeed = 14,
	ChipLife = 0.8,
	ChipDarken = 0.6, -- chips take the wall's colour times this

	-- Each gun shoots with a feel: its sound, camera kick (degrees up), a random sideways twitch up
	-- to twitch degrees, an FOV punch in degrees, a screen shake in degrees (0 for none) and weight,
	-- which scales how hard the held gun snaps back. followUp plays followUpDelay seconds later.
	GunFeel = {
		StarterBlaster = "pistol",
		Smg = "smg",
		Rifle = "rifle",
		Shotgun = "shotgun",
		Revolver = "revolver",
		MarksmanRifle = "marksman",
		Disruptor = "disruptor",
		NailGun = "nail",
		FlareGun = "flare",
		DartBlaster = "dart",
	},
	ShotFeel = {
		pistol = { sound = "shot_pistol", kick = 2.4, twitch = 0.5, fovPunch = 1.2, shake = 0, weight = 1 },
		smg = { sound = "shot_smg", kick = 2, twitch = 0.7, fovPunch = 1, shake = 0, weight = 0.8 },
		rifle = {
			sound = "shot_rifle",
			oncePerPull = 0.45,
			kick = 2.8,
			twitch = 0.5,
			fovPunch = 1.4,
			shake = 0.3,
			weight = 1.3,
		},
		marksman = {
			sound = "shot_marksman",
			kick = 3.2,
			twitch = 0.4,
			fovPunch = 1.6,
			shake = 0,
			weight = 1.3,
		},
		revolver = {
			sound = "shot_revolver",
			kick = 3.4,
			twitch = 0.8,
			fovPunch = 1.8,
			shake = 0.5,
			weight = 1.4,
		},
		heavy = { sound = "shot_heavy", kick = 3.6, twitch = 0.9, fovPunch = 2, shake = 0.7, weight = 1.5 },
		shotgun = {
			sound = "shot_shotgun",
			kick = 4,
			twitch = 1,
			fovPunch = 2,
			shake = 0.8,
			weight = 1.6,
			followUp = "shotgun_pump",
			followUpDelay = 0.35,
		},
		nail = { sound = "nail_gun", kick = 1.6, twitch = 0.4, fovPunch = 0.8, shake = 0, weight = 0.7 },
		flare = { sound = "flare_pop", kick = 2.2, twitch = 0.5, fovPunch = 1.2, shake = 0, weight = 1 },
		dart = {
			sound = "dart_pop_1",
			takes = {
				"dart_pop_1",
				"dart_pop_2",
				"dart_pop_3",
				"dart_pop_4",
				"dart_pop_5",
				"dart_pop_6",
				"dart_pop_7",
				"dart_pop_8",
			},
			kick = 1.4,
			twitch = 0.3,
			fovPunch = 0.8,
			shake = 0,
			weight = 0.6,
		},
		disruptor = {
			sound = "disruptor_crack",
			kick = 3,
			twitch = 0.6,
			fovPunch = 1.6,
			shake = 0.4,
			weight = 1.2,
		},
	},
	FlareBurnSound = "flare_burn_loop",
	FlareBurnoutSound = "flare_burnout",
	DefaultShotFeel = "pistol", -- for a gun missing from GunFeel
	CameraKickRise = 0.02, -- seconds the view snaps up over
	CameraKickSettle = 0.16, -- seconds it springs back over
	ShakeTime = 0.18,

	-- Held blaster, relative to the camera. Recoil snaps in over RecoilRise, settles over RecoilSettle.
	ViewmodelOffset = Vector3.new(0.75, -0.72, -1.45),
	ViewmodelAimOffset = Vector3.new(0, -0.42, -1.2), -- centred under the crosshair while aiming
	ViewmodelLoweredDrop = 1.1, -- studs it sinks when carrying a prop or holding no blaster
	ViewmodelLoweredPitch = 40, -- degrees it tips down when lowered
	ViewmodelLowerEase = 10,
	ViewmodelBobScale = 0.6, -- share of the head bob the blaster follows
	RecoilRise = 0.02,
	RecoilSettle = 0.13,
	RecoilKickBack = 0.32, -- studs toward you
	RecoilKickPitch = 10, -- degrees muzzle up
	SparkColor = Color3.fromRGB(255, 190, 110),
	SparkCount = 10,
	PlayerSparkCount = 18,
	AimFieldOfViewScale = 0.72,
	AimEase = 14,
	HitMarkerTime = 0.15,
	HitMarkerPop = 1.7, -- the X starts this much bigger and shrinks back over HitMarkerTime

	-- A shot passing this close to another player's head plays a whiz for them. Not within
	-- WhizMinDistance studs of the shooter, so standing beside a teammate stays quiet.
	WhizRadius = 4,
	WhizMinDistance = 6,

	-- Inventory and loot piles.
	BaseSlots = 10,
	LootPileTag = "LootPile",
	LootPickupRange = 8,
	LootPickupHold = 0.6,

	-- Sound names from the manifest. Each gun's shot is in ShotFeel; impacts land where the shot
	-- hits, picked by the surface (Impact on players), Empty is the dry click with no cells.
	-- Others hear shots out to SoundRollOff[2] studs (guns are loud).
	Sounds = {
		FireVolume = 1,
		FirePitch = 1, -- below 1 is deeper
		Impact = "emp_thump",
		ImpactConcrete = "impact_concrete",
		ImpactMetal = "impact_metal",
		ImpactVolume = 0.6,
		ImpactPitch = 1,
		HitMarker = "hit_marker",
		HitMarkerVolume = 0.8,
		Whiz = "bullet_whiz",
		WhizVolume = 0.9,
		Empty = "flashlight_click",
		Reload = "cell_eject",
		ReloadVolume = 0.8,
		ShellReload = "shell_clink", -- the shotgun loads shells instead of ejecting a cell
		Cock = "revolver_cock",
		CockVolume = 0.8,
	},
	SoundRollOff = { 8, 120 },
	SoundPitchJitter = 0.12,
}
