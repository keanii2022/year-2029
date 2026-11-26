return {
	-- Needs run 0..Max and live on the player as the "Hunger" and "Energy" attributes
	Needs = {
		Max = 100,
		SpawnHunger = 100,
		SpawnEnergy = 100,

		-- Per second. A full belly lasts about one day and night.
		HungerDrain = 0.16,
		HungerSprintMultiplier = 1.5,
		EnergyDrain = 0.03,
		EnergySprintDrain = 1.1, -- about 90 seconds of running from full
		-- Catching your breath while not sprinting, but only up to RestCap: drinks fill the rest
		EnergyRestRegen = 0.25,
		EnergyRestCap = 35,

		-- Empty energy sets "Exhausted" until energy climbs back to this
		ExhaustedRecover = 10,
		-- Empty hunger hurts this much per second
		StarveDamage = 0.5,

		-- Under this the HUD calls it low
		LowAt = 30,
	},

	TickInterval = 1,

	-- What using an item does. kind is the quick-use button that picks it (Eat, Drink, Heal).
	-- opens: using it unpacks these instead of eating. loudness: what robots hear (Logic/Loudness).
	-- sound: name in the sound pack, played if it has been uploaded.
	Uses = {
		Snack = { kind = "Eat", hunger = 15, time = 1.2, loudness = "quiet", sound = "wrapper_crinkle" },
		Chips = { kind = "Eat", hunger = 20, time = 2, loudness = "loud", sound = "chips_crinkle" },
		Apple = { kind = "Eat", hunger = 10, energy = 5, time = 1.2, loudness = "quiet", sound = "crunch" },
		Sandwich = { kind = "Eat", hunger = 30, time = 2, loudness = "quiet", sound = "bite" },
		PizzaSlice = { kind = "Eat", hunger = 20, time = 1.5, loudness = "quiet", sound = "bite" },
		Popcorn = { kind = "Eat", hunger = 25, time = 2.5, loudness = "normal", sound = "chew" },
		NoodleCup = { kind = "Eat", hunger = 35, time = 3, loudness = "normal", sound = "chew" },
		WatermelonSlice = {
			kind = "Eat",
			hunger = 12,
			energy = 5,
			time = 1.5,
			loudness = "quiet",
			sound = "bite",
		},
		RationPack = {
			kind = "Eat",
			hunger = 70,
			energy = 15,
			time = 4,
			loudness = "quiet",
			sound = "tin_lid",
		},
		PizzaBox = {
			kind = "Eat",
			time = 1,
			loudness = "normal",
			sound = "cardboard_lid",
			opens = { { id = "PizzaSlice", count = 4 } },
		},
		Watermelon = {
			kind = "Eat",
			time = 2,
			loudness = "normal",
			opens = { { id = "WatermelonSlice", count = 4 } },
		},
		Lunchbox = {
			kind = "Eat",
			time = 1,
			loudness = "quiet",
			opens = {
				{ id = "Sandwich", count = 1 },
				{ id = "Apple", count = 1 },
				{ id = "JuiceBox", count = 1 },
			},
		},
		JuiceBox = {
			kind = "Drink",
			energy = 15,
			hunger = 5,
			time = 1.2,
			loudness = "quiet",
			sound = "straw_slurp",
		},
		EnergyDrink = {
			kind = "Drink",
			energy = 60,
			time = 1.5,
			loudness = "normal",
			sound = "energy_crack_fizz",
		},
		Bandage = { kind = "Heal", health = 35, time = 3, loudness = "quiet", sound = "tape_rip" },
		-- health matches Config.Guns.MaxHealth, so a medkit always fills you up
		Medkit = { kind = "Medkit", health = 100, time = 4, loudness = "quiet", sound = "medkit_latch" },
	},

	-- Gamepad quick-use buttons in HUD order. action is the Input action that fires it (keys live in
	-- Controllers/Input, drawn by Glyphs); label sits beside it. Heal falls back to the medkit when
	-- there's no bandage. Keyboard and phone players pick supplies from the hotbar instead.
	QuickUse = {
		{ kind = "Eat", action = "Eat", label = "EAT" },
		{ kind = "Drink", action = "Drink", label = "DRINK" },
		{ kind = "Heal", action = "Heal", label = "HEAL" },
	},
	UseCooldown = 0.3,

	-- The shopping list on the HUD: how much of each kind of supply feels safe for a night
	ShoppingList = {
		{ label = "Food", kind = "Eat", want = 3 },
		{ label = "Drinks", kind = "Drink", want = 2 },
		{ label = "Bandages", kind = "Heal", want = 2 },
		{ label = "Cells", item = "BlasterCells", want = 30 },
		{ label = "Batteries", item = "FlashlightBattery", want = 1 },
	},

	-- World loot. Weight slides from near (entrance) to deep (far corners); nothing below minDepth.
	-- model is the asset library name for the pickup; count is { min, max } of item given.
	Loot = {
		{ item = "BlasterCells", model = "ammo_cell", count = { 8, 20 }, near = 22, deep = 16 },
		{ item = "Snack", model = "snack_bar", count = { 1, 2 }, near = 18, deep = 6 },
		{ item = "Chips", model = "chips_bag", count = { 1, 1 }, near = 12, deep = 5 },
		{ item = "Apple", model = "apple", count = { 1, 2 }, near = 10, deep = 3 },
		{ item = "JuiceBox", model = "juice_box", count = { 1, 2 }, near = 10, deep = 4 },
		{ item = "Popcorn", model = "popcorn_bag", count = { 1, 1 }, near = 6, deep = 5 },
		{ item = "Sandwich", model = "sandwich", count = { 1, 1 }, near = 4, deep = 6, minDepth = 0.1 },
		{ item = "NoodleCup", model = "noodle_cup", count = { 1, 1 }, near = 3, deep = 7, minDepth = 0.15 },
		{ item = "PizzaBox", model = "pizza_box", count = { 1, 1 }, near = 1, deep = 6, minDepth = 0.2 },
		{ item = "Watermelon", model = "watermelon", count = { 1, 1 }, near = 1, deep = 4, minDepth = 0.2 },
		{ item = "Lunchbox", model = "lunchbox", count = { 1, 1 }, near = 1, deep = 5, minDepth = 0.2 },
		{ item = "EnergyDrink", model = "energy_drink", count = { 1, 1 }, near = 5, deep = 9 },
		{ item = "Bandage", model = "bandage", count = { 1, 2 }, near = 4, deep = 9 },
		{ item = "FlashlightBattery", model = "battery", count = { 1, 2 }, near = 4, deep = 7 },
		{ item = "RationPack", model = "ration_pack", count = { 1, 1 }, near = 0, deep = 4, minDepth = 0.4 },
		{ item = "EmpCharge", model = "emp_charge", count = { 1, 1 }, near = 0, deep = 0.6, minDepth = 0.75 },
		{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 0, deep = 0.3, minDepth = 0.85 },
		{ item = "Medkit", model = "medkit", count = { 1, 1 }, near = 0, deep = 1.2, minDepth = 0.6 },
		-- Guns: the weak ones turn up anywhere, the strong ones only deeper in. The dart blaster is
		-- rare but can be anywhere. Ammo for the non-cell guns spawns on its own. About one pickup
		-- in twelve is a gun, so a new gun turns up within a few minutes of looting.
		{ item = "NailGun", model = "nail_gun", count = { 1, 1 }, near = 2.5, deep = 2.5 },
		{ item = "FlareGun", model = "flare_gun", count = { 1, 1 }, near = 2.2, deep = 2 },
		{ item = "Smg", model = "smg", count = { 1, 1 }, near = 1.5, deep = 3 },
		{ item = "Revolver", model = "revolver", count = { 1, 1 }, near = 1.2, deep = 2.5, minDepth = 0.1 },
		{ item = "Shotgun", model = "shotgun", count = { 1, 1 }, near = 0.8, deep = 2.5, minDepth = 0.15 },
		{ item = "Rifle", model = "rifle", count = { 1, 1 }, near = 0, deep = 2, minDepth = 0.3 },
		{
			item = "MarksmanRifle",
			model = "marksman_rifle",
			count = { 1, 1 },
			near = 0,
			deep = 1.2,
			minDepth = 0.45,
		},
		{ item = "DartBlaster", model = "dart_blaster", count = { 1, 1 }, near = 0.8, deep = 1 },
		{ item = "Shells", model = "ammo_shells", count = { 4, 8 }, near = 1, deep = 3, minDepth = 0.15 },
		{ item = "Flares", model = "ammo_flares", count = { 1, 3 }, near = 1.5, deep = 1.5 },
		{ item = "Darts", model = "ammo_darts", count = { 2, 4 }, near = 0.8, deep = 1.2 },
	},

	-- Pickups across the open floor, plus extra in robot rooms (riskier, so rolled deeper)
	FloorSpots = 900,
	SpotTries = 6, -- random tries per spot before giving up on it
	SpotClearance = 2,
	RoomLootChance = 0.7,
	RoomDepthBonus = 0.15,

	-- Every installation also gets InstallationLootCount guaranteed pickups by its furniture, rolled
	-- from this better list (weights at full depth), plus the guarded stash crate (Config.Containers)
	InstallationLootCount = { 2, 4 },
	-- ...and the first of them (two in a giant hall) is always a real find worth the robots: a gun,
	-- shells, a medkit or robot gear. Rolled at the hall's depth, so the deep, dangerous halls hold
	-- the rifles and disruptors while the ones near the entrance lean to pistols and ammo.
	InstallationGoodFinds = 1,
	GiantInstallationGoodFinds = 2,
	GoodFinds = {
		{ item = "Smg", model = "smg", count = { 1, 1 }, near = 3, deep = 2 },
		{ item = "Revolver", model = "revolver", count = { 1, 1 }, near = 3, deep = 2 },
		{ item = "Shotgun", model = "shotgun", count = { 1, 1 }, near = 2, deep = 3 },
		{ item = "NailGun", model = "nail_gun", count = { 1, 1 }, near = 2, deep = 0.5 },
		{ item = "FlareGun", model = "flare_gun", count = { 1, 1 }, near = 1.5, deep = 1 },
		{ item = "Rifle", model = "rifle", count = { 1, 1 }, near = 0.3, deep = 2.5 },
		{
			item = "MarksmanRifle",
			model = "marksman_rifle",
			count = { 1, 1 },
			near = 0,
			deep = 1.5,
			minDepth = 0.3,
		},
		{ item = "DartBlaster", model = "dart_blaster", count = { 1, 1 }, near = 0.8, deep = 1 },
		{ item = "Shells", model = "ammo_shells", count = { 8, 14 }, near = 2, deep = 2 },
		{ item = "Medkit", model = "medkit", count = { 1, 1 }, near = 2, deep = 2.5 },
		{ item = "EmpCharge", model = "emp_charge", count = { 1, 2 }, near = 0.8, deep = 2 },
		{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 0, deep = 1, minDepth = 0.5 },
	},
	InstallationLootReach = 3.5, -- studs out from the furniture
	InstallationLoot = {
		{ item = "BlasterCells", model = "ammo_cell", count = { 15, 30 }, near = 10, deep = 10 },
		{ item = "RationPack", model = "ration_pack", count = { 1, 1 }, near = 7, deep = 7 },
		{ item = "Medkit", model = "medkit", count = { 1, 1 }, near = 5, deep = 5 },
		{ item = "Bandage", model = "bandage", count = { 2, 3 }, near = 5, deep = 5 },
		{ item = "FlashlightBattery", model = "battery", count = { 2, 3 }, near = 4, deep = 4 },
		{ item = "EmpCharge", model = "emp_charge", count = { 1, 1 }, near = 1, deep = 1 },
		{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 0.5, deep = 0.5 },
		{ item = "Shotgun", model = "shotgun", count = { 1, 1 }, near = 1.2, deep = 1.2 },
		{ item = "Smg", model = "smg", count = { 1, 1 }, near = 1.2, deep = 1.2 },
		{ item = "Revolver", model = "revolver", count = { 1, 1 }, near = 1, deep = 1 },
		{ item = "Rifle", model = "rifle", count = { 1, 1 }, near = 0.8, deep = 0.8 },
		{ item = "MarksmanRifle", model = "marksman_rifle", count = { 1, 1 }, near = 0.6, deep = 0.6 },
		{ item = "DartBlaster", model = "dart_blaster", count = { 1, 1 }, near = 0.6, deep = 0.6 },
		{ item = "Shells", model = "ammo_shells", count = { 6, 12 }, near = 3, deep = 3 },
		{ item = "Darts", model = "ammo_darts", count = { 3, 6 }, near = 1.5, deep = 1.5 },
		{ item = "Flares", model = "ammo_flares", count = { 2, 3 }, near = 1, deep = 1 },
	},

	PickupTag = "SupplyPickup",
	PickupRange = 8,
	PickupHold = 0.3,
}
