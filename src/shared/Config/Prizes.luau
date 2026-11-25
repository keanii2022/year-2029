-- Prize chests (Systems/PrizeChests) and PA events (Systems/PaEvents). Chest spots in the sets come
-- from Config.Warehouse.PrizeSpots. Loot lists use the Config.Supplies.Loot shape: weight slides
-- from near to deep over the chest's value (0..1), nothing below minDepth.
local HEADLINE = {
	{ item = "Smg", model = "smg", count = { 1, 1 }, near = 4, deep = 2 },
	{ item = "Revolver", model = "revolver", count = { 1, 1 }, near = 4, deep = 2 },
	{ item = "Shotgun", model = "shotgun", count = { 1, 1 }, near = 2, deep = 3 },
	{ item = "Rifle", model = "rifle", count = { 1, 1 }, near = 0.5, deep = 3, minDepth = 0.2 },
	{
		item = "MarksmanRifle",
		model = "marksman_rifle",
		count = { 1, 1 },
		near = 0,
		deep = 2,
		minDepth = 0.45,
	},
	{ item = "DartBlaster", model = "dart_blaster", count = { 1, 1 }, near = 1, deep = 1.5 },
	{ item = "Medkit", model = "medkit", count = { 1, 2 }, near = 3, deep = 3 },
	{ item = "EmpCharge", model = "emp_charge", count = { 1, 2 }, near = 1, deep = 3 },
	{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 0, deep = 2, minDepth = 0.5 },
	{ item = "Handcuffs", model = "handcuffs", count = { 1, 1 }, near = 1, deep = 1.5 },
}

local FILL = {
	{ item = "BlasterCells", model = "ammo_cell", count = { 20, 40 }, near = 10, deep = 8 },
	{ item = "Shells", model = "ammo_shells", count = { 8, 14 }, near = 4, deep = 5 },
	{ item = "Darts", model = "ammo_darts", count = { 4, 8 }, near = 2, deep = 2 },
	{ item = "Flares", model = "ammo_flares", count = { 2, 4 }, near = 2, deep = 1.5 },
	{ item = "FlashlightBattery", model = "battery", count = { 2, 4 }, near = 5, deep = 4 },
	{ item = "Bandage", model = "bandage", count = { 2, 4 }, near = 5, deep = 4 },
	{ item = "Medkit", model = "medkit", count = { 1, 1 }, near = 2, deep = 4 },
	{ item = "RationPack", model = "ration_pack", count = { 1, 2 }, near = 3, deep = 3 },
	{ item = "EnergyDrink", model = "energy_drink", count = { 1, 2 }, near = 3, deep = 2 },
	{ item = "EmpCharge", model = "emp_charge", count = { 1, 1 }, near = 0.5, deep = 2 },
	{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 0, deep = 0.8, minDepth = 0.6 },
}

local RARE = {
	{ item = "Handcuffs", model = "handcuffs", count = { 1, 1 }, near = 3, deep = 3 },
	{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 2, deep = 2 },
	{ item = "MarksmanRifle", model = "marksman_rifle", count = { 1, 1 }, near = 1.5, deep = 1.5 },
	{ item = "DartBlaster", model = "dart_blaster", count = { 1, 1 }, near = 1.5, deep = 1.5 },
	{ item = "EmpCharge", model = "emp_charge", count = { 2, 3 }, near = 2, deep = 2 },
}

return {
	Chests = {
		Model = "loot_crate",
		Scale = 1.5, -- bigger than the robots' stash crate, so the prize reads as the prize
		Slots = 10,
		OpenHold = 3, -- seconds of holding E / Square / the button to pry one open
		TakeHold = 0.3, -- once open, taking what's left is quick (anyone can, so rob the opener)
		Range = 9,
		-- Prying is loud work: a noise robots hear every HoldNoiseEvery seconds, then a bang on open
		HoldLoudness = "normal",
		HoldNoiseEvery = 1,
		OpenLoudness = "loud",
		Sounds = { Pry = "cabinet_creak", Open = "crate_lid", Clang = "locker_clang" },
		Light = { Color = Color3.fromRGB(255, 196, 92), Brightness = 1.6, Range = 18 },
		-- What it stands on in the sets; the edge glows with the light and goes dark once it's emptied
		Plinth = {
			Height = 1,
			Pad = 1.2, -- studs wider than the chest on each side
			Color = Color3.fromRGB(34, 32, 30),
			Edge = 0.15,
			EdgeOff = Color3.fromRGB(60, 56, 50),
		},

		-- A chest's value (0..1, picks the loot) is its spot's depth plus these: the deep, scary,
		-- giant halls pay best
		GiantBonus = 0.15,
		ScaryBonus = {
			black_sun = 0.2,
			catwalk_void = 0.25, -- one chest, out over the void
			giant_nursery = 0.15,
			basement = 0.15,
			backroom = 0.15,
			curtain_room = 0.1,
			hedge_maze = 0.1,
			night_lot = 0.1,
			tile_maze = 0.1,
		},
		Headline = HEADLINE, -- one guaranteed real find per chest
		Fill = FILL,
		Rolls = { 2, 4 }, -- extra Fill rolls at value 0 and value 1

		-- A few out in the open aisles, rarer and a little leaner: no robots stand guard over them
		Aisle = { Count = 6, MinDepth = 0.35, Clearance = 4, Value = -0.15, Tries = 40 },
	},

	Pa = {
		-- Seconds between events. Lights on: Day and Siren. Lights out: Night, rarer.
		Gap = { Day = { 150, 240 }, Siren = { 150, 240 }, Night = { 360, 600 } },
		FirstDelay = { 60, 120 }, -- after the server starts
		GlitchChance = 0.25, -- pa_glitch after the line now and then
		Prefix = "[PA] ",
		SubtitleSeconds = 7,
		ChimeLead = 1.5, -- the chime rings out before the line shows
		Sounds = { Chime = "pa_chime", Glitch = "pa_glitch" },
		Volume = 0.6,

		-- text: {spot} becomes the aisle number or installation name. voice: a recorded clip name
		-- (Music.playVoiceLine) once Keani records one; nil plays only the chime and subtitle.
		Events = {
			delivery = {
				weight = 3,
				text = "Attention shoppers, a delivery has arrived in aisle {spot}.",
				voice = nil,
				value = 0.7,
				loot = { headline = HEADLINE, fill = FILL, rolls = { 3, 5 } },
			},
			open = {
				weight = 2,
				text = "Attention shoppers, the {spot} is now open.",
				voice = nil,
			},
			lost = {
				weight = 1,
				text = "Lost item at the front desk. Lost item at the front desk.",
				voice = nil,
				value = 1,
				loot = { headline = RARE, fill = {}, rolls = { 0, 0 } },
			},
		},

		-- The delivery crate drops from DropHeight with a bang robots hear
		DropHeight = 40,
		DropTime = 1.2,
		DropLoudness = "loud",
		DropSound = "prop_metal_clang",
		DeliverySearch = { 6, 30 }, -- studs from the aisle sign to look for clear floor
		FrontDeskInset = 40, -- studs in from the entrance
		Lifetime = 300, -- seconds an event crate and its beam last if nobody empties it

		-- The marker: a tall beam of light over the spot, plus a faint arrow on the screen edge
		Beam = {
			Width = 2.5,
			Height = 66,
			Color = Color3.fromRGB(255, 186, 72),
			Transparency = 0.55,
			LightRange = 24,
			LightBrightness = 2,
			Seconds = 150,
		},
		Marker = {
			Seconds = 10,
			FadeSeconds = 2,
			Size = 40,
			Inset = 0.42,
			Color = Color3.fromRGB(255, 196, 92),
			Transparency = 0.5,
		},
	},
}
