return {
	-- Showroom: every model in labelled rows, one row per art group. Far from the step 1 test room at the origin.
	ShowroomEnabled = true,
	ShowroomOrigin = Vector3.new(2000, 0, 0),
	ShowroomSpacing = 4, -- studs of floor between neighbours in a row
	ShowroomRowGap = 14, -- studs between rows, room for the walkway and labels
	ShowroomMaxRowWidth = 160, -- a group wraps onto a new row past this
	ShowroomSpawnPlayers = false, -- true drops players into the showroom instead of the test room
	ShowroomDemoMotion = true, -- swing every moving part back and forth so you can check the hinges

	-- How far moving parts go at full open
	HingeOpenDegrees = 100,
	SlideOpenFraction = 0.8, -- of the part's own length along the slide axis
	MoverDegrees = 30,

	-- Greybox stand-in colors (used until a model is uploaded)
	GreyboxColor = Color3.fromRGB(150, 150, 155),
	GreyboxGlowColor = Color3.fromRGB(255, 190, 90),
	GreyboxScreenColor = Color3.fromRGB(25, 30, 35),

	-- Parts whose axis differs from the default for their kind, per model (from art/MOVES.md)
	AxisOverrides = {
		entrance_gate = { Slide = "Y" }, -- the grate slides up
		noise_maker = { Spin = "Z" }, -- the key turns around the model's front axis
		record_player = { Arm = "Y" }, -- tone arm swings over the record
		greeter = { Arm = "Z" }, -- waves side to side
		security_cam = { Cam = "Y" },
	},

	-- Models that hang from a point at their top (signs, lights) rather than sitting on the floor
	HangingModels = {
		aisle_sign = true,
		aisle_sign_hanging = true,
		dept_sign = true,
		light_dangling = true,
		light_strip = true,
		light_strip_dead = true,
		light_highbay = true,
		light_troffer = true,
		sale_banner = true,
	},
}
