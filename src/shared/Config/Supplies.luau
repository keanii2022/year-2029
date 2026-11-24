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
	},

	-- Quick-use buttons in HUD order; hints are the keyboard and gamepad labels shown on screen. Gamepad buttons only work while not carrying (Grab uses D-pad and L1 then). D-pad up/down/right belong to flashlight, EMP and disruptor.
	QuickUse = {
		{
			kind = "Eat",
			key = Enum.KeyCode.One,
			pad = Enum.KeyCode.DPadLeft,
			hints = { "1", "LEFT" },
			label = "EAT",
		},
		{
			kind = "Drink",
			key = Enum.KeyCode.Two,
			pad = Enum.KeyCode.ButtonL1,
			hints = { "2", "L1" },
			label = "DRINK",
		},
		{
			kind = "Heal",
			key = Enum.KeyCode.Three,
			pad = Enum.KeyCode.ButtonSelect,
			hints = { "3", "PAD" },
			label = "BANDAGE",
		},
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
	},

	-- Pickups across the open floor, plus extra in robot rooms (riskier, so rolled deeper)
	FloorSpots = 900,
	SpotTries = 6, -- random tries per spot before giving up on it
	SpotClearance = 2,
	RoomLootChance = 0.7,
	RoomDepthBonus = 0.15,

	PickupTag = "SupplyPickup",
	PickupRange = 8,
	PickupHold = 0.3,
}
