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

-- The bait drop's rare jackpot: one big find plus a pile of the good stuff
local JACKPOT = {
	{ item = "MarksmanRifle", model = "marksman_rifle", count = { 1, 1 }, near = 3, deep = 3 },
	{ item = "Rifle", model = "rifle", count = { 1, 1 }, near = 3, deep = 3 },
	{ item = "Handcuffs", model = "handcuffs", count = { 2, 2 }, near = 2, deep = 2 },
	{ item = "Medkit", model = "medkit", count = { 4, 6 }, near = 2, deep = 2 },
}

local JACKPOT_FILL = {
	{ item = "Medkit", model = "medkit", count = { 2, 3 }, near = 3, deep = 3 },
	{ item = "Handcuffs", model = "handcuffs", count = { 1, 1 }, near = 2, deep = 2 },
	{ item = "EmpCharge", model = "emp_charge", count = { 2, 3 }, near = 2, deep = 2 },
	{ item = "Disruptor", model = "disruptor", count = { 1, 1 }, near = 1, deep = 1 },
	{ item = "BlasterCells", model = "ammo_cell", count = { 30, 50 }, near = 2, deep = 2 },
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

		-- text: {spot} becomes the aisle number or installation name (a list picks one line at random).
		-- voice: the clip for each text line, in the same order (one name when there's one line). The
		-- clips say it without the aisle number (art/_kit/voice_lines.py); the subtitle names the spot. Where each one lands is up to the director (Config.Director).
		Events = {
			delivery = {
				weight = 3,
				text = "Attention shoppers, a delivery has arrived in aisle {spot}.",
				voice = "pa_delivery",
				value = 0.7,
				loot = { headline = HEADLINE, fill = FILL, rolls = { 3, 5 } },
			},
			open = {
				weight = 2,
				text = "Attention shoppers, the {spot} is now open.",
				voice = "pa_open",
			},
			lost = {
				weight = 1,
				text = "Lost item at the front desk. Lost item at the front desk.",
				voice = "pa_lost_item",
				value = 1,
				loot = { headline = RARE, fill = {}, rolls = { 0, 0 } },
			},
			-- The bait: biggest beam in the store, a crate that stays shut for countdown seconds so a
			-- crowd forms, usually good loot and now and then a jackpot worth chasing every time
			bait = {
				weight = 2,
				text = {
					"Attention shoppers, a special prize has been left in aisle {spot}.",
					"Lucky shopper giveaway in aisle {spot}. Lucky shopper giveaway in aisle {spot}.",
					"Attention shoppers, one lucky winner awaits in aisle {spot}.",
				},
				voice = { "pa_bait_1", "pa_bait_2", "pa_bait_3" },
				value = 0.85,
				loot = { headline = HEADLINE, fill = FILL, rolls = { 3, 5 } },
				jackpot = {
					chance = 0.15,
					value = 1,
					loot = { headline = JACKPOT, fill = JACKPOT_FILL, rolls = { 2, 3 } },
				},
				countdown = 25,
				beam = {
					Width = 7,
					Height = 140,
					Color = Color3.fromRGB(255, 90, 210),
					Transparency = 0.35,
					LightRange = 40,
					LightBrightness = 4,
					Seconds = 150,
				},
			},
			-- A rumor: no chime, no beam, no arrow. Just a crackle and a line, and a crate waiting
			-- quietly where it said. place lines are used when the spot is by an installation.
			rumor = {
				weight = 1.5,
				rumor = true,
				text = {
					"*crackle* ...heard someone crying for help near aisle {spot}. nobody was there. found a crate though...",
					"*crackle* ...left a stash behind in aisle {spot}, couldn't carry it all...",
					"*crackle* ...anyone near aisle {spot}? something fell off a robot cart...",
				},
				place = {
					"*crackle* ...the robots dropped something by the {spot}...",
					"*crackle* ...heard a crate land outside the {spot}...",
				},
				voice = { "pa_rumor_1", "pa_rumor_2", "pa_rumor_3" },
				placeVoice = { "pa_rumor_place_1", "pa_rumor_place_2" },
				value = 0.55,
				loot = { headline = HEADLINE, fill = FILL, rolls = { 1, 2 } },
			},
			-- Last call: never picked at random (weight 0). Runs once a day LastCall.Before seconds
			-- before the siren, a bait crate that opens with about a minute of daylight left, so the
			-- greedy are still out when the siren goes.
			lastcall = {
				weight = 0,
				text = {
					"Last call, shoppers. One final prize in aisle {spot}. The store closes soon.",
					"Attention shoppers, last chance savings in aisle {spot}. Hurry, we're closing.",
				},
				voice = { "pa_lastcall_1", "pa_lastcall_2" },
				value = 0.9,
				loot = { headline = HEADLINE, fill = FILL, rolls = { 3, 5 } },
				jackpot = {
					chance = 0.2,
					value = 1,
					loot = { headline = JACKPOT, fill = JACKPOT_FILL, rolls = { 2, 3 } },
				},
				countdown = 25,
				beam = {
					Width = 7,
					Height = 140,
					Color = Color3.fromRGB(255, 60, 40),
					Transparency = 0.35,
					LightRange = 40,
					LightBrightness = 4,
					Seconds = 150,
				},
			},
		},
		LastCall = { Before = 90 },
		-- The Sweep: once a night, At (share of the night) in, the PA sends every hunter to the
		-- loudest zone of the night so far for Seconds. Noise is bucketed into Cell-stud zones.
		-- Calls repeat every Every seconds so robots that lose the trail get pulled back in.
		Sweep = {
			At = 0.5,
			Seconds = 40,
			Every = 6,
			Cell = 90,
			-- How much each loudness level counts toward a zone (Config.Interact.Loudness levels)
			Weights = { quiet = 1, normal = 2, loud = 4 },
			text = {
				"Cleanup crew to aisle {spot}. All units. Cleanup crew to aisle {spot}.",
				"Attention staff: mess reported in aisle {spot}. All helpers respond.",
			},
			voice = { "pa_sweep_1", "pa_sweep_2" },
			beam = {
				Width = 4,
				Height = 120,
				Color = Color3.fromRGB(200, 28, 22),
				Transparency = 0.45,
				LightRange = 30,
				LightBrightness = 3,
				Seconds = 40,
			},
		},
		Rumor = {
			Sound = "walkie_static",
			PlaceRange = 120, -- studs from an installation's middle to call the spot by its name
		},
		Bait = {
			CountdownText = "OPENS IN {n}",
			TickSound = "clock_tick_fast_loop",
			OpenSound = "store_jingle",
			OpenLoudness = "loud", -- robots hear the prize unlock too
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
