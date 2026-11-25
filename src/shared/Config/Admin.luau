-- Admin mode: who gets the panel in a live game and what its buttons hand out.
-- Studio playtests are always admin.
return {
	UserIds = { 5167289516 },
	UserNames = { "ghostyboy2k17" }, -- turned into ids on the server at start; the name also matches directly

	-- The speed button cycles these; fly speed scales with the same multiplier
	SpeedLevels = {
		{ name = "normal", multiplier = 1 },
		{ name = "fast", multiplier = 1.8 },
		{ name = "very fast", multiplier = 3 },
	},
	FlySpeed = 40, -- studs per second at normal speed

	-- give_food_kit: food, drinks and healing, plus batteries
	FoodKit = {
		{ id = "Sandwich", count = 5 },
		{ id = "NoodleCup", count = 5 },
		{ id = "JuiceBox", count = 10 },
		{ id = "EnergyDrink", count = 5 },
		{ id = "Bandage", count = 5 },
		{ id = "Medkit", count = 2 },
		{ id = "FlashlightBattery", count = 6 },
	},

	-- Frozen robots get a short disable that keeps being renewed, so waking them is just stopping
	RobotFreezeSeconds = 3,
	RobotFreezeRefresh = 1,

	SimCounts = { 5, 10, 20 },
	SimMoods = { "calm", "normal", "chaos" },
	SimMaxSpawn = 20,
	SimCountPoll = 2, -- seconds between live count updates while the Sim tab is open

	OpenKey = Enum.KeyCode.F2,
	PadHold = 0.5, -- seconds L1 + R1 are held together to open it on a controller
	CardLine = {
		Keyboard = "{=F2} Admin panel",
		Gamepad = "Hold {=L1} + {=R1} Admin panel",
		Touch = "ADMIN button (top left): admin panel",
	},
}
