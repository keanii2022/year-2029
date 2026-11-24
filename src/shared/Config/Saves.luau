-- Saves, the locker, blueprints, stats, leaderboards and cosmetics (server Saves + Scores systems).
return {
	-- DataStores. Bump nothing here to "reset" saves: change the save schema version in Logic/Saves instead.
	StoreName = "Year2029Saves",
	KeyPrefix = "player_",
	BoardPrefix = "Year2029Board_",

	AutosaveInterval = 120,
	-- A save written soon after a locker change, so a crash loses at most this much stash work
	SaveSoonDelay = 15,
	-- A session lock older than this belongs to a dead server and can be taken over.
	-- Autosave refreshes the lock, so keep this a few autosaves long.
	LockExpiry = 360,
	-- Load and save attempts, waiting RetryBase, 2x, 4x ... up to RetryMax seconds between them
	Retries = 6,
	RetryBase = 1,
	RetryMax = 16,
	-- Longest a request waits for DataStore budget before trying anyway
	BudgetWait = 10,
	-- Roblox gives BindToClose 30 seconds; stop waiting on saves a bit before that
	CloseTimeout = 25,

	Locker = {
		Model = "locker",
		Slots = 12,
		-- The spawn kit comes back every life, so storing it would be free loot
		Blocked = { StarterBlaster = true },
		Range = 10, -- studs from the locker to use it
		PromptHold = 0.3,
		-- One locker beside every spawn, this far out and turned to face it
		SpawnOffset = Vector3.new(6, 0, 0),
	},

	Blueprint = {
		PaperModel = "paper_and_pen",
		PaperPerDay = 8,
		PaperSpotTries = 30,
		PaperSpotClearance = 4,
		PromptHold = 1.5,
		PromptRange = 8,
		Radius = 30, -- props this close to you count as your fort when you draw it
		MaxPieces = 40,
		SnapDistance = 3, -- drop a matching piece this close to its ghost and it snaps in
		GhostTransparency = 0.75,
		GhostColor = Color3.fromRGB(140, 170, 190),
	},

	-- Stats every player keeps. Other systems add to them with Scores.add(player, key, amount).
	Stats = {
		{ key = "NightsSurvived", label = "Nights survived" },
		{ key = "PlayerKills", label = "Takedowns" },
		{ key = "RobotKills", label = "Robots disabled" },
		{ key = "Downs", label = "Times down" },
		{ key = "LongestLife", label = "Longest life", minutes = true },
	},

	Boards = {
		Title = "BEST OF US",
		Size = 10,
		ReadInterval = 300,
		WriteInterval = 300,
		List = {
			{ stat = "NightsSurvived", title = "MOST NIGHTS SURVIVED" },
			{ stat = "PlayerKills", title = "MOST TAKEDOWNS" },
			{ stat = "RobotKills", title = "MOST ROBOTS DISABLED" },
		},
		-- Stands beside each spawn's locker
		Offset = Vector3.new(6, 0, 4),
		PartSize = Vector3.new(9, 6, 0.4),
	},

	-- Cosmetics are earned by stats, never sold. unlock = nil means everyone has it.
	-- Hat parts sit on top of the head; offset is from the head's centre. paint = takes the chosen colour.
	Cosmetics = {
		Hat = {
			{
				id = "HardHat",
				label = "Hard Hat",
				unlock = { stat = "NightsSurvived", at = 1 },
				parts = {
					-- Ball parts are always round, so this pokes through the head as a dome
					{
						shape = "Ball",
						size = Vector3.new(1.3, 1.3, 1.3),
						offset = Vector3.new(0, 0.55, 0),
						paint = true,
					},
					{
						shape = "Block",
						size = Vector3.new(1.6, 0.12, 1.6),
						offset = Vector3.new(0, 0.45, 0),
						paint = true,
					},
				},
			},
			{
				id = "FoilCap",
				label = "Foil Cap",
				unlock = { stat = "NightsSurvived", at = 5 },
				parts = {
					{
						shape = "Wedge",
						size = Vector3.new(1.3, 0.7, 1.3),
						offset = Vector3.new(0, 0.85, 0),
						material = Enum.Material.Foil,
						color = Color3.fromRGB(190, 192, 196),
					},
				},
			},
			{
				id = "Antenna",
				label = "Salvaged Antenna",
				unlock = { stat = "RobotKills", at = 1 },
				parts = {
					{
						shape = "Block",
						size = Vector3.new(0.12, 1.1, 0.12),
						offset = Vector3.new(0.3, 1.1, 0),
					},
					{
						shape = "Ball",
						size = Vector3.new(0.3, 0.3, 0.3),
						offset = Vector3.new(0.3, 1.7, 0),
						neon = true,
						paint = true,
					},
				},
			},
		},
		Colour = {
			{ id = "Concrete", label = "Concrete", color = Color3.fromRGB(150, 148, 142) },
			{
				id = "HazardYellow",
				label = "Hazard Yellow",
				color = Color3.fromRGB(222, 178, 40),
				unlock = { stat = "NightsSurvived", at = 3 },
			},
			{
				id = "OilBlack",
				label = "Oil Black",
				color = Color3.fromRGB(22, 22, 24),
				unlock = { stat = "RobotKills", at = 3 },
			},
			{
				id = "SprayRed",
				label = "Spray Red",
				color = Color3.fromRGB(200, 28, 22),
				unlock = { stat = "PlayerKills", at = 5 },
			},
			{
				id = "ExitGreen",
				label = "Exit Green",
				color = Color3.fromRGB(40, 190, 90),
				unlock = { stat = "NightsSurvived", at = 10 },
			},
		},
		Trail = {
			{
				id = "Dust",
				label = "Dust",
				unlock = { stat = "LongestLife", at = 1200 },
				lifetime = 0.6,
				width = 0.6,
				transparency = 0.7,
			},
			{
				id = "Sparks",
				label = "Sparks",
				unlock = { stat = "RobotKills", at = 10 },
				lifetime = 0.35,
				width = 0.3,
				transparency = 0.3,
				neon = true,
			},
			{
				id = "OilDrip",
				label = "Oil Drip",
				unlock = { stat = "NightsSurvived", at = 25 },
				lifetime = 1.2,
				width = 0.5,
				transparency = 0.2,
			},
		},
	},

	-- Opens your record (stats, looks, blueprint) anywhere
	RecordKey = Enum.KeyCode.M,
	RecordPad = Enum.KeyCode.ButtonSelect,
}
