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

	-- Look and feel.
	MuzzleOffset = Vector3.new(0.7, -0.6, -1.5), -- from the camera, where your own tracer starts
	TracerColor = Color3.fromRGB(255, 120, 90),
	TracerWidth = 0.07,
	TracerTime = 0.08,
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
}
