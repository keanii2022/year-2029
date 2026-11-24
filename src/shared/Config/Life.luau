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
	PhaseRate = { Day = 1, Siren = 0.8, Night = 0.7 },
	MaxLive = 4,
	Lifetime = 45, -- a box or cart stays this long, then goes once nobody is looking

	-- kind: which spots it uses ("aisle" beside a rack, "end" at a rack end, "any"); none means the
	-- event finds its own place. A phase set to a number scales the weight there.
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
		phone_ring = { weight = 1, kind = "any", phases = { Day = true } },
		shelf_drag = {
			weight = 1,
			kind = "aisle",
			phases = { Day = 0.5, Siren = true, Night = true },
			sounds = { "shelf_scrape_far", "drag" },
		},
		strip_die = { weight = 2, phases = { Day = true, Siren = true } },
		silhouette = { weight = 2, phases = { Day = 0.1, Night = true } },
		drip = { weight = 2, phases = { Day = true, Siren = true, Night = true } },
		vending_can = { weight = 1, phases = { Day = true, Siren = true, Night = 0.5 } },
		pigeons = { weight = 2, phases = { Day = true, Siren = true, Night = 0.5 } },
		rat = { weight = 2, phases = { Day = 0.5, Siren = true, Night = true } },
	},

	Sounds = {
		BoxThump = "prop_cardboard_thump",
		BoxScrape = "shelf_scrape_far",
		CartRoll = "chair_roll",
		Step = "walk_concrete",
		Chime = "pa_chime",
		Glitch = "pa_glitch",
		RoomTone = "distant_hum_loop",
		Phone = "phone_ring_far",
		StripCrackle = "neon_crackle",
		Drip = "glug", -- no drip in the pack yet: a sped-up, clipped glug stands in
		VendingHum = "vending_whirr",
		VendingDrop = "vending_thud",
		Wings = "sheets_rustle", -- no wing flap in the pack yet: sped-up cloth rustle stands in
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

	-- Far phone: rings a few times, and goes quiet the moment you get close
	Phone = { Rings = { 2, 4 }, Pause = 1.2, StopRadius = 30 },

	-- Shelving dragged somewhere: one long slowed-down scrape that slides along the aisle
	ShelfDrag = { Speed = { 0.55, 0.75 }, Slide = 8 },

	-- A strip light overhead stutters and dies as you walk under it, then comes back
	StripDie = {
		Radius = 4, -- flat gap from the strip's footprint that counts as under it
		Wait = 25, -- how long it waits for you to pass under one
		Dark = { 40, 90 },
		-- A shade off Lighting's dead colour: if it's still this when the dark ends, nobody else
		-- has set the strip since, so it's safe to put back.
		DeadColor = Color3.fromRGB(64, 66, 69),
		Flicker = { Blinks = { 3, 6 }, Short = { 0.04, 0.18 }, Dark = { 0.2, 0.7 } },
	},

	-- A dark robot shape crossing the far end of the aisle you're looking down
	Silhouette = {
		Model = "scout_night",
		Near = 60,
		Far = 100,
		Margin = 4, -- stops this short of whatever ends the sightline
		Width = 14, -- walks this far across the aisle end
		Seconds = { 2, 3 },
		Color = Color3.fromRGB(8, 8, 10),
		EyeColor = Color3.fromRGB(90, 30, 24),
	},

	-- Drips from the roof into a wet patch near you, with a ripple
	Drip = {
		MinDistance = 8,
		MaxDistance = 35,
		Height = 30,
		Count = { 2, 4 },
		Every = { 1.2, 2.8 },
		Color = Color3.fromRGB(150, 170, 185),
		RippleSize = 3,
		RippleSeconds = 0.9,
	},

	-- A vending machine near you whirrs and drops a can that rolls out
	VendingCan = {
		MinDistance = 10,
		MaxDistance = 40,
		Size = Vector3.new(0.9, 0.5, 0.5), -- cylinder: length, then diameter
		Colors = { Color3.fromRGB(150, 40, 36), Color3.fromRGB(40, 90, 140), Color3.fromRGB(200, 170, 50) },
		Push = 4,
	},

	-- Pigeons perched on a rack top that burst up when you come near
	Pigeons = {
		Model = "pigeon",
		Count = { 3, 5 },
		Burst = 22,
		Wait = 40,
		Rise = { 14, 22 },
		Seconds = 2.5,
		Flap = 40, -- wing swing in degrees
		MinDistance = 30,
		MaxDistance = 60,
		SeenChance = 0.5,
	},

	-- A rat darting along the foot of a rack and in under it
	Rat = {
		Model = "rat",
		MinDistance = 12,
		MaxDistance = 35,
		SeenChance = 0.7,
		Run = { 6, 11 },
		Speed = 9,
	},

	-- Always on, only near the camera: signs sway, dust drifts under lit strips, moths round a light
	Sway = { Radius = 90, Max = 8, Every = 1, DeptAngle = 1.4, AisleAngle = 0.6, Period = 7 },
	Dust = { Radius = 45, Max = 3, Rate = 4, Below = 7, Depth = 4, Height = 10 },
	Moths = { Model = "moth", Scale = 2.5, Radius = 40, Count = 3, Orbit = { 1.2, 2.6 }, Speed = { 1.5, 3 } },

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
