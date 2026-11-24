-- First-person hands (Controllers/Hands, Logic/Hands). Poses are where a hand's grip sits in
-- camera space: x right, y up, z forward is negative. Angles in degrees.
local function pose(x: number, y: number, z: number, pitch: number?, yaw: number?, roll: number?)
	return { x = x, y = y, z = z, pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

local FOOD_CRUMBS = Color3.fromRGB(196, 150, 92)

return {
	-- Uploaded arm models the server copies into ReplicatedStorage.Viewmodels
	Arms = {
		Right = "viewmodel_arm_right",
		Left = "viewmodel_arm_left",
		LeftOpen = "viewmodel_arm_left_open",
	},

	-- Out of view below the screen
	Rest = pose(0.2, -2.2, -0.9, -30),
	Poses = {
		Eat = { right = pose(0.06, -0.42, -0.95, 5, 0, 8) },
		Drink = { right = pose(0.1, -0.5, -1, 0, 0, 6) },
		Heal = { right = pose(0.28, -0.62, -1.2, 10, 0, -30), left = pose(-0.12, -0.78, -1.25, 0, -20, 70) },
		Open = { right = pose(0.22, -0.62, -1.15, 10, 0, -10), left = pose(-0.22, -0.62, -1.15, 10, 0, 10) },
	},
	-- Forearms rise into view from below and come in from their own side
	ArmTilt = { Right = { pitch = 55, yaw = 18 }, Left = { pitch = 55, yaw = -18 } },
	-- Stand-in arm shape (the uploaded ones are 0.69 x 1.87 x 0.48)
	StandInLength = 1.7,
	SleeveColor = Color3.fromRGB(86, 92, 58),
	GloveColor = Color3.fromRGB(42, 40, 38),

	RaiseTime = 0.22,
	LowerTime = 0.25,

	-- Eating: a bite every BiteInterval, each push toward the mouth lasting BiteLength
	BiteInterval = 0.45,
	BiteLength = 0.2,
	BitePush = pose(0, 0.12, 0.3, 14),
	BiteShrink = 0.12, -- share of the food gone per bite
	MinFoodScale = 0.35,
	ChewBob = 0.025,
	ChewSpeed = 18,
	CrumbsPerBite = 8,

	DrinkTilt = 75,
	DrinkLift = 0.18,
	SipBob = 0.012,

	WrapTurns = 3,
	WrapRadius = 0.16,

	OpenPull = 0.12,
	OpenTwist = 18,

	-- Use/open reach with the left open hand
	ReachTime = 0.35,
	ReachStart = pose(-0.35, -0.75, -0.9, 20, -10, 0),
	ReachDistance = 1.1,

	-- Progress ring round the crosshair while a supply is in use
	RingDots = 24,
	RingRadius = 26,
	RingDotSize = 5,

	-- What sits in the hand for each item. model: asset library name used once uploaded.
	-- shape is the stand-in until then: Box, Can, Roll, Ball or Wedge. size: stand-in size and,
	-- by its longest side, how big the uploaded model is scaled to. crumbs: colour of bite bits.
	Items = {
		Snack = {
			model = "snack_bar",
			shape = "Box",
			size = Vector3.new(0.42, 0.16, 0.08),
			color = Color3.fromRGB(186, 74, 44),
			crumbs = FOOD_CRUMBS,
		},
		Chips = {
			model = "chips_bag",
			shape = "Box",
			size = Vector3.new(0.36, 0.48, 0.12),
			color = Color3.fromRGB(214, 176, 52),
			crumbs = Color3.fromRGB(232, 196, 96),
		},
		Apple = {
			model = "apple",
			shape = "Ball",
			size = Vector3.new(0.28, 0.28, 0.28),
			color = Color3.fromRGB(150, 32, 28),
			crumbs = Color3.fromRGB(236, 226, 190),
		},
		Sandwich = {
			model = "sandwich",
			shape = "Box",
			size = Vector3.new(0.42, 0.16, 0.34),
			color = Color3.fromRGB(214, 180, 122),
			crumbs = FOOD_CRUMBS,
		},
		PizzaSlice = {
			shape = "Wedge",
			size = Vector3.new(0.06, 0.34, 0.42),
			color = Color3.fromRGB(222, 150, 62),
			crumbs = FOOD_CRUMBS,
		},
		Popcorn = {
			model = "popcorn_bag",
			shape = "Box",
			size = Vector3.new(0.3, 0.42, 0.2),
			color = Color3.fromRGB(230, 226, 214),
			crumbs = Color3.fromRGB(250, 240, 200),
		},
		NoodleCup = {
			model = "noodle_cup",
			shape = "Can",
			size = Vector3.new(0.3, 0.34, 0.3),
			color = Color3.fromRGB(232, 228, 220),
			crumbs = Color3.fromRGB(240, 210, 140),
		},
		WatermelonSlice = {
			model = "watermelon_slice",
			shape = "Wedge",
			size = Vector3.new(0.08, 0.3, 0.46),
			color = Color3.fromRGB(228, 86, 94),
			crumbs = Color3.fromRGB(240, 120, 128),
		},
		RationPack = {
			model = "ration_pack",
			shape = "Box",
			size = Vector3.new(0.36, 0.24, 0.12),
			color = Color3.fromRGB(96, 100, 66),
			crumbs = FOOD_CRUMBS,
		},
		PizzaBox = {
			model = "pizza_box",
			shape = "Box",
			size = Vector3.new(0.7, 0.1, 0.7),
			color = Color3.fromRGB(176, 140, 96),
		},
		Watermelon = {
			model = "watermelon",
			shape = "Ball",
			size = Vector3.new(0.6, 0.5, 0.5),
			color = Color3.fromRGB(52, 108, 50),
		},
		Lunchbox = {
			model = "lunchbox",
			shape = "Box",
			size = Vector3.new(0.5, 0.34, 0.24),
			color = Color3.fromRGB(60, 96, 140),
		},
		JuiceBox = {
			model = "juice_box",
			shape = "Box",
			size = Vector3.new(0.18, 0.3, 0.12),
			color = Color3.fromRGB(230, 150, 50),
		},
		EnergyDrink = {
			model = "energy_drink",
			shape = "Can",
			size = Vector3.new(0.16, 0.36, 0.16),
			color = Color3.fromRGB(40, 190, 210),
		},
		Bandage = {
			model = "bandage",
			shape = "Roll",
			size = Vector3.new(0.2, 0.2, 0.2),
			color = Color3.fromRGB(236, 232, 222),
		},
	},
	-- Generic held item when an item has no entry above, by quick-use kind
	Fallback = {
		Eat = {
			shape = "Box",
			size = Vector3.new(0.36, 0.16, 0.1),
			color = Color3.fromRGB(150, 120, 80),
			crumbs = FOOD_CRUMBS,
		},
		Drink = { shape = "Can", size = Vector3.new(0.16, 0.34, 0.16), color = Color3.fromRGB(150, 150, 156) },
		Heal = { shape = "Roll", size = Vector3.new(0.2, 0.2, 0.2), color = Color3.fromRGB(236, 232, 222) },
	},
	-- Grip to item centre: food held up in front of the fist, cans standing on it
	ItemOffset = CFrame.new(0, 0.12, -0.05),
}
