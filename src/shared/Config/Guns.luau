return {
	-- Every spawn gets this kit, so a fresh player can fight right away.
	StartingLoadout = {
		{ id = "StarterBlaster", count = 1 },
		{ id = "BlasterCells", count = 36 },
	},
	MaxHealth = 100,
	HealthRegen = false, -- healing comes from supplies later, not from standing still
	RespawnDelay = 6,

	-- rank: when a player carries several guns, the highest rank is the one in hand.
	-- Damage is full up to falloffStart studs, sliding down to minDamage at falloffEnd.
	Blasters = {
		StarterBlaster = {
			rank = 1,
			ammo = "BlasterCells",
			damage = 22,
			minDamage = 11,
			falloffStart = 40,
			falloffEnd = 140,
			range = 300,
			fireInterval = 0.22,
			automatic = false,
		},
	},

	-- Server shot checks.
	FireIntervalSlack = 0.8, -- shots may arrive this fraction of the interval apart (network jitter)
	MaxOriginOffset = 6, -- studs between the client's camera and its head
	LineOfSightSlack = 0.5,

	-- Look and feel. The bullet is only a picture; the hit was already decided by the server's
	-- instant raycast. Its flight time is clamped so it lands about when the server answers.
	MuzzleOffset = Vector3.new(0.7, -0.6, -1.5), -- from the camera, where your shot starts with no held blaster
	OthersMuzzleForward = 1.8, -- studs ahead of another player's camera where their bullet starts
	BulletSpeed = 650, -- studs per second
	BulletMinTravel = 0.05,
	BulletMaxTravel = 0.2,
	BulletLength = 7,
	BulletWidth = 0.16,
	BulletColor = Color3.fromRGB(255, 150, 80),
	BulletImage = "bullet_tracer", -- manifest image, head at the right end; Neon streak until uploaded
	MuzzleFlashTime = 0.05,
	MuzzleFlashSize = 1.4,
	MuzzleFlashColor = Color3.fromRGB(255, 190, 120),
	MuzzleFlashImage = "muzzle_flash_card",
	ScorchSize = 0.55,
	ScorchColor = Color3.fromRGB(28, 24, 22),
	ScorchTime = 8, -- seconds before a scorch mark fades
	MaxScorches = 40,
	CameraKick = 1.2, -- degrees the view tips up per shot

	-- Held blaster, relative to the camera. Recoil snaps in over RecoilRise, settles over RecoilSettle.
	ViewmodelOffset = Vector3.new(0.75, -0.72, -1.45),
	ViewmodelAimOffset = Vector3.new(0, -0.42, -1.2), -- centred under the crosshair while aiming
	ViewmodelLoweredDrop = 1.1, -- studs it sinks when carrying a prop or holding no blaster
	ViewmodelLoweredPitch = 40, -- degrees it tips down when lowered
	ViewmodelLowerEase = 10,
	ViewmodelBobScale = 0.6, -- share of the head bob the blaster follows
	RecoilRise = 0.03,
	RecoilSettle = 0.18,
	RecoilKickBack = 0.22, -- studs toward you
	RecoilKickPitch = 7, -- degrees muzzle up
	SparkColor = Color3.fromRGB(255, 190, 110),
	SparkCount = 10,
	PlayerSparkCount = 18,
	AimFieldOfViewScale = 0.72,
	AimEase = 14,
	HitMarkerTime = 0.15,

	-- Inventory and loot piles.
	BaseSlots = 10,
	LootPileTag = "LootPile",
	LootPickupRange = 8,
	LootPickupHold = 0.6,

	-- Sound names from the manifest. Fire is the zap, Impact lands where the shot hits, Empty is
	-- the dry click with no cells. Others hear shots out to SoundRollOff[2] studs (guns are loud).
	Sounds = {
		Fire = "blaster_thump",
		FireVolume = 1,
		FirePitch = 0.72, -- below 1 is deeper
		Impact = "emp_thump",
		ImpactVolume = 0.35,
		ImpactPitch = 1.3,
		Empty = "flashlight_click",
	},
	SoundRollOff = { 8, 120 },
	SoundPitchJitter = 0.12,
}
