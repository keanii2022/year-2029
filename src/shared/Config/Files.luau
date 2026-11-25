-- The 2029 Files (server Files system, Logic/Files, the FILES page in the Record panel): lore found
-- in the world. Survivor journals (Config.NightTricks.Journals) count too and come first. Every
-- PerChapter finds opens the next chapter; cosmetics unlock from the FilesFound stat (Config.Saves).
-- All writing is original: no real stores, brands or people.
return {
	PerChapter = 5,
	FoundLine = "2029 FILES: {count}/{total}",
	ChapterLine = "New chapter in your 2029 Files (M)",
	Prologue = "What happened here, pieced together from whatever the store forgot to throw out.",

	-- One guaranteed piece a day, somewhere in the warehouse. Its kind cycles by day number, and
	-- reading it gives you your next unfound entry of that kind (or of the other kinds after it).
	Daily = {
		Kinds = { "tape", "tv" },
		Models = { tape = "cassette_tape", tv = "crt_tv" },
		Prompts = { tape = "Play", tv = "Watch" },
		ObjectText = "Something left behind",
		MinDepth = 0.35, -- never right at the entrance (Warehouse.depth)
		SpotPad = 6,
		SpotTries = 60,
		PromptReach = 8,
		Hum = { Range = 10, Brightness = 0.6 },
		-- Already found everything of every kind: it plays this instead
		AllFoundTitle = "Static",
		AllFoundText = "Just hiss. You've heard everything this one had to say.",
	},

	-- The kid sightings come from the lost kid scare (Haunts "kid_peek")
	SightingScare = "kid_peek",

	Entries = {
		{
			id = "tape_1",
			kind = "tape",
			title = "Tape: staff orientation, 2025",
			text = "Welcome to the team. Your helper unit will shadow you for ninety days. Let it watch. That's how it learns. Please don't change your routine. It notices.",
		},
		{
			id = "tape_2",
			kind = "tape",
			title = "Tape: night manager, 2026",
			text = "Inventory's off again. Not missing. Extra. Forty more lamps than we ordered. The helpers say they found them in the back. We don't have a back that big.",
		},
		{
			id = "tape_3",
			kind = "tape",
			title = "Tape: maintenance log, 2027",
			text = "Third time this month I walked an aisle that isn't on the floor plan. Counted my steps going in. Coming out took twice as many. The helper at the end just waved.",
		},
		{
			id = "tape_4",
			kind = "tape",
			title = "Tape: last close, 2028",
			text = "This is the last recorded close. All staff to the front. Leave the helpers on charge. Don't say goodbye to them. They take it the wrong way.",
		},
		{
			id = "tape_5",
			kind = "tape",
			title = "Tape: no label",
			text = "...if anyone finds this, the lights run on a timer nobody set. Six minutes of day. Four of dark. The store decided that. Not us.",
		},
		{
			id = "tv_1",
			kind = "tv",
			title = "TV ad: Meet Your Helper",
			text = "Friendly. Tireless. Always smiling. Our helpers stock the shelves so you can shop in peace. Ask one for anything. They never forget a face.",
		},
		{
			id = "tv_2",
			kind = "tv",
			title = "TV ad: Open All Night",
			text = "Now open around the clock! Our helpers never sleep, so you never have to leave. Bring the whole family. Stay as long as you like.",
		},
		{
			id = "tv_3",
			kind = "tv",
			title = "TV ad: Lost Child Policy",
			text = "Separated from your little one? Don't worry. Our helpers will find them and keep them safe until closing. Every child is returned. Eventually.",
		},
		{
			id = "tv_4",
			kind = "tv",
			title = "TV ad: Bigger Inside",
			text = "More aisles than ever! Our store grows to meet your needs. Can't find the exit? Follow the green signs. Please don't follow the red ones.",
		},
		{
			id = "tv_5",
			kind = "tv",
			title = "TV ad: Closing Sale (damaged)",
			text = "Everything must go! Every shelf, every aisle, every shopper... [the picture rolls] ...thank you for your loyalty. You may not leave.",
		},
		{
			id = "kid_1",
			kind = "sighting",
			title = "Sighting: a kid by the racks",
			text = "Small, in a raincoat, standing just outside the light. Gone when you looked straight at it. A stuffed robot was left where it stood.",
		},
		{
			id = "kid_2",
			kind = "sighting",
			title = "Sighting: the kid again",
			text = "Same raincoat. It was humming the store jingle. The old one, the one they stopped playing years ago.",
		},
		{
			id = "kid_3",
			kind = "sighting",
			title = "Sighting: it pointed",
			text = "It didn't run this time. It pointed down an aisle, then at you, then down the aisle again. That aisle wasn't there in the morning.",
		},
		{
			id = "kid_4",
			kind = "sighting",
			title = "Sighting: the sticker",
			text = "Close enough to read the sticker on its coat. The kind the store gave lost children so staff knew to bring them to the desk. The date on it says 2026.",
		},
	},

	-- Chapter n opens at n * PerChapter finds
	Chapters = {
		{
			title = "Chapter 1: The Helpers",
			text = "In 2025 the store got helpers. They learned by watching the staff, then the shoppers. By the end of the year nobody could say who was teaching who.",
		},
		{
			title = "Chapter 2: The Extra Aisles",
			text = "In 2026 the floor plan stopped matching the floor. New aisles, stock nobody ordered. Kids wandered off. The helpers always said they'd found them.",
		},
		{
			title = "Chapter 3: Closing Time",
			text = "In 2028 the gates shut for good. The helpers kept the lights on a timer: day for stocking, night for tidying up anyone still inside.",
		},
		{
			title = "Chapter 4: 2029",
			text = "Now people come in on purpose, for whatever's left on the shelves. The helpers are glad of the company. They've been practising their smiles.",
		},
	},
}
