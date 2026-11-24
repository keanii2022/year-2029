-- A livelier warehouse: small things happening around each player, drawn only on their own client.
-- Distances in studs, times in seconds. Every sound and model is a manifest name and stays silent or
-- falls back to a plain part until it's uploaded.
return {
	-- Server: aisle spots it hands each player (beside rack faces and just past rack ends)
	SpotsEvery = 5,
	SpotsRadius = 110,
	SpotsMax = 40,
	EndGap = 3.5, -- past the rack end post, where a cross aisle starts
	AisleStep = 12, -- one spot per rack bay along each face
	AisleOffset = 1.5, -- out from the rack face onto the aisle floor

	-- Where events may happen: never close, mostly out of sight, now and then a far glimpse
	MinDistance = 25,
	MaxDistance = 90,
	HiddenAngle = 50, -- half-angle of the view cone, in degrees
	GlimpseChance = 0.25,
	GlimpseMinDistance = 50,

	-- How often something happens. Night is quieter so robot sounds stay readable.
	EventGap = { Min = 9, Max = 22 },
	PhaseRate = { Day = 1, Siren = 0.8, Night = 0.5 },
	MaxLive = 4,
	Lifetime = 45, -- a box or cart stays this long, then goes once nobody is looking

	-- kind: which spots it uses ("aisle" beside a rack, "end" at a rack end, "any")
	Events = {
		box_fall = { weight = 4, kind = "aisle", phases = { Day = true, Siren = true, Night = true } },
		cart_roll = { weight = 2, kind = "end", phases = { Day = true, Siren = true } },
		footsteps = { weight = 2, kind = "aisle", phases = { Day = true, Siren = true, Night = true } },
		pallet_creak = {
			weight = 2,
			kind = "aisle",
			phases = { Day = true, Siren = true },
			sounds = { "shelf_scrape_far" },
		},
		far_clang = {
			weight = 3,
			kind = "any",
			phases = { Day = true, Siren = true, Night = true },
			sounds = { "prop_metal_clang", "pipe_knock", "shelf_thud_far" },
		},
		door_slam = {
			weight = 1,
			kind = "end",
			phases = { Day = true, Siren = true, Night = true },
			sounds = { "cabinet_shut", "locker_clang" },
		},
		phone_ring = { weight = 1, kind = "any", phases = { Day = true }, sounds = { "phone_ring_far" } },
	},

	Sounds = {
		BoxThump = "prop_cardboard_thump",
		BoxScrape = "shelf_scrape_far",
		CartRoll = "chair_roll",
		Step = "walk_concrete",
		Chime = "pa_chime",
		Glitch = "pa_glitch",
		RoomTone = "distant_hum_loop",
	},
	Volume = {
		Event = 0.9,
		Step = 0.5,
		Machine = 0.4,
		Chime = 0.5,
	},
	RollOff = { Min = 12, Max = 140 },

	-- Falling box: model when uploaded, else a cardboard block
	BoxModel = "box_loose",
	BoxSize = Vector3.new(2.2, 1.6, 1.8),
	BoxColor = Color3.fromRGB(150, 116, 78),
	BoxDropHeights = { 6.5, 13, 19.5 }, -- rack deck heights
	BoxPush = { 3, 7 }, -- sideways speed off the deck

	CartModel = "shopping_cart",
	CartRoll = { Distance = 12, Seconds = 7 },

	Footsteps = { Count = { 5, 9 }, Every = 0.55, Stride = 2.3 },

	-- Machines in range flicker and hum now and then
	Machines = {
		vending_machine = { "vending_whirr", "vending_beep" },
		arcade_cabinet = { "neon_crackle" },
		crt_tv = { "tv_static_burst", "tv_channel_thunk" },
	},
	MachineGap = { Min = 6, Max = 16 },
	MachineRadius = 70,
	MachineDarkColor = Color3.fromRGB(12, 12, 14),
	Flicker = { Blinks = { 2, 5 }, Short = { 0.05, 0.25 }, Dark = { 0.6, 2.5 } },

	-- PA by day: chime, then a subtitle (and the voice line once Keani records it)
	PaGap = { Min = 40, Max = 90 },
	PaSubtitleSeconds = 6,
	PaGlitchChance = 0.2,
	PaPrefix = "[PA] ",
	PaLines = {
		{ voice = "pa_never_close", text = "Attention shoppers: the store will never close." },
		{ voice = "pa_smiling_mandatory", text = "A reminder that smiling is mandatory in aisle 40." },
		{ voice = "pa_special_everything", text = "Today's special: everything. Forever." },
		{ voice = "pa_lost_children", text = "Lost children may collect themselves at the front desk." },
		{
			voice = "pa_helpers_looking",
			text = "Please do not look at the helpers. The helpers are looking at you.",
		},
		{
			voice = "pa_keep_moving",
			text = "Shoppers are reminded to keep moving. Standing still is shoplifting.",
		},
		{ voice = "pa_always_happy", text = "Our staff are always happy to help. Always." },
		{ voice = "pa_aisle_12", text = "Aisle 12 has been cleaned. Please do not go into aisle 12." },
		{ voice = "pa_thank_you", text = "Thank you for shopping with us. Thank you. Thank you." },
		{ voice = "pa_exit_elsewhere", text = "The exit is temporarily somewhere else." },
		{ voice = "pa_your_name", text = "If you hear your name, do not answer." },
		{ voice = "pa_fresh_bread", text = "Fresh bread in the bakery. There is no bakery." },
	},

	-- Room tone by day: louder the more open space around you. Music's night hum takes over at night.
	RoomTone = { Min = 0.05, Max = 0.35, Near = 12, Far = 90, Rays = 8, Every = 1, Fade = 2 },
}
