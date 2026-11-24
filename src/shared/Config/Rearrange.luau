-- The store rearranges itself overnight: distant dragging while it's dark, then at dawn loose boxes,
-- furniture and carts have moved and a few signs read wrong. Distances in studs, times in seconds.
return {
	-- Nothing within this of a player moves, and nothing moves to within it
	KeepAway = 40,

	-- Share of each kind's movable things that move each dawn, and a cap per dawn
	Share = { junk = 0.2, furniture = 0.15, cart = 0.35 },
	Max = { junk = 250, furniture = 60, cart = 10 },

	-- Boxes and furniture get shoved this far; carts roll to an aisle spot a different aisle over
	MinShift = 6,
	MaxShift = 22,
	Tries = 8,
	Gap = 3, -- two moved things never land closer than this
	Clearance = 2, -- WarehouseGen.isClear padding around racks and walls
	CartRange = 140,
	AisleGap = 10,
	CoverCell = 8, -- grid size for finding boxes stacked on boxes

	-- Pairs of hanging signs whose texts swap each dawn
	SignSwaps = { dept = 2, aisle = 5 },

	-- Moves per frame so dawn never hitches the server, and instances scanned between yields
	BatchSize = 30,
	ScanYieldEvery = 1500,

	-- Robots restocking somewhere far off: one of these from a spot Distance away from a player
	Drag = {
		Sounds = { "drag", "scrape", "shelf_scrape_far" },
		Gap = { Min = 20, Max = 55 },
		Distance = { Min = 60, Max = 110 },
		Volume = 0.7,
		RollOffMin = 20,
		RollOffMax = 160,
	},
}
