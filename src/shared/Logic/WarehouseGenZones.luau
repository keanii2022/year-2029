-- What fills each square zone of the warehouse floor: racking aisles, store departments, stock
-- rooms, furniture piles, giant pillar halls, near-empty stretches, and installations (a dark hall
-- with a lit dreamcore set inside it, where a robot lives; see WarehouseGenInstallations).
-- Everything is plain data appended to the layout; Systems/Warehouse turns it into parts.
local Installations = if script
	then require(script.Parent.WarehouseGenInstallations)
	else require("./WarehouseGenInstallations")
local Pieces = if script then require(script.Parent.WarehouseGenPieces) else require("./WarehouseGenPieces")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Zones = {}

export type Rect = Pieces.Rect

local piece, light, loose = Pieces.piece, Pieces.light, Pieces.loose

local function junkStack(layout: any, rng: Rng.Rng, x: number, z: number, count: number, big: boolean)
	local boxes = {}
	local y = 0
	for _ = 1, count do
		local sy = if big then rng:range(2.4, 4) else rng:range(1.6, 3.2)
		table.insert(boxes, {
			sx = if big then rng:range(3.5, 5) else rng:range(2, 4.5),
			sy = sy,
			sz = if big then rng:range(3.5, 5) else rng:range(2, 4),
			x = rng:range(-0.5, 0.5),
			y = y + sy / 2,
			z = rng:range(-0.5, 0.5),
			turn = rng:range(-20, 20),
		})
		y += sy
	end
	table.insert(layout.junk, { x = x, z = z, boxes = boxes })
	layout.addSolid({ x0 = x - 3, x1 = x + 3, z0 = z - 3, z1 = z + 3 })
end

-- Racking aisles: tall packed racks in rows, cold strip lights over every other aisle, tape, wet floor
function Zones.racking(layout: any, config: any, rng: Rng.Rng, rect: Rect)
	local depth, pitch = config.RackDepth, config.RackPitch
	local z = rect.z0 + depth / 2
	local rows = {}
	while z + depth / 2 <= rect.z1 do
		local shelf = { x0 = rect.x0, x1 = rect.x1, z = z, depth = depth }
		table.insert(layout.shelves, shelf)
		layout.addSolid({ x0 = shelf.x0, x1 = shelf.x1, z0 = z - depth / 2, z1 = z + depth / 2 })
		table.insert(rows, z)
		z += pitch
	end
	if #rows > 0 then
		-- Numbers are random on purpose: the signs don't really help
		table.insert(layout.signs, { x = rect.x0 - 3, z = rows[1], number = rng:int(1, 99) })
	end
	for i = 1, #rows - 1, 2 do
		local aisleZ = (rows[i] + rows[i + 1]) / 2
		local x = rect.x0 + config.LightGap / 2
		while x < rect.x1 do
			light(layout, config, rng, x, aisleZ, config.RackLightY, "x", "cold")
			x += config.LightGap
		end
	end
	-- Caution tape across a few aisle mouths
	for i = 1, #rows - 1 do
		if rng:next() < config.TapeChance then
			local side = if rng:next() < 0.5 then rect.x0 + 0.3 else rect.x1 - 0.3
			piece(layout, {
				x = side,
				y = 3.2,
				z = (rows[i] + rows[i + 1]) / 2,
				sx = 0.08,
				sy = 0.35,
				sz = pitch - depth,
				style = "tape",
				collide = false,
			})
		end
	end
	Pieces.wetPatches(layout, rng, rect, rng:int(0, 2))
end

-- A store department: a floor of wood, carpet or tile under a sign hanging on long cables, with
-- little furniture displays (a fake bedroom, a fake living room) behind half-height partitions
function Zones.showroom(layout: any, config: any, rng: Rng.Rng, rect: Rect)
	local dept = rng:pick(config.Departments)
	local floorStyle = rng:pick(config.ShowroomFloors)
	Pieces.floor(layout, rect, floorStyle, nil, nil, config.ShowroomKitFloors[floorStyle])
	local cx, cz = (rect.x0 + rect.x1) / 2, (rect.z0 + rect.z1) / 2
	table.insert(layout.deptSigns, { x = cx, z = cz, y = config.DeptSignY, text = dept.name })

	local cells = 2
	local cw, cd = (rect.x1 - rect.x0) / cells, (rect.z1 - rect.z0) / cells
	for j = 0, cells - 1 do
		for i = 0, cells - 1 do
			local x0, z0 = rect.x0 + i * cw, rect.z0 + j * cd
			local mx, mz = x0 + cw / 2, z0 + cd / 2
			-- Partition along the cell's back edge (away from the zone centre)
			local backZ = if j == 0 then z0 + 2 else z0 + cd - 2
			piece(layout, {
				x = mx,
				y = config.PartitionHeight / 2,
				z = backZ,
				sx = cw * 0.7,
				sy = config.PartitionHeight,
				sz = 0.6,
				style = "partition",
				solid = true,
			})
			table.insert(layout.loose, { name = config.RoomRug, x = mx, z = mz, turn = 0 })
			local pool = rng:shuffle(dept.furniture)
			local count = math.min(rng:int(3, 5), #pool)
			for n = 1, count do
				local angle = (n / count) * math.pi * 2 + rng:range(-0.3, 0.3)
				local radius = math.min(cw, cd) * 0.24
				local x, z = mx + math.cos(angle) * radius, mz + math.sin(angle) * radius
				-- Faces the middle of the display, like a staged room
				local turn = math.deg(math.atan2(mx - x, mz - z))
				loose(layout, pool[n], x, z, turn)
			end
		end
	end
	for n = 0, 3 do
		light(
			layout,
			config,
			rng,
			rect.x0 + (n + 0.5) * (rect.x1 - rect.x0) / 4,
			cz,
			config.ShowroomLightY,
			"z",
			"warm"
		)
	end
end

-- Stock room: tall pallet stacks in tight rows, shrink-wrapped loads, tape, sparse cold light
function Zones.stockroom(layout: any, config: any, rng: Rng.Rng, rect: Rect)
	local step = config.StackPitch
	local x = rect.x0 + 4
	while x < rect.x1 - 4 do
		local z = rect.z0 + 4
		while z < rect.z1 - 4 do
			local roll = rng:next()
			if roll < 0.08 then
				-- A few loose stacks you can pull apart for a fort
				junkStack(layout, rng, x, z, rng:int(2, 4), true)
			elseif roll < 0.8 then
				local h = rng:range(5, 12)
				piece(layout, {
					x = x,
					y = h / 2,
					z = z,
					sx = 5.5,
					sy = h,
					sz = 5.5,
					turn = rng:range(-6, 6),
					style = if rng:next() < 0.3 then "wrap" else "stack",
					solid = true,
					kit = rng:pick(config.StockKit),
				})
			end
			z += step
		end
		x += step * 1.6
	end
	if rng:next() < 0.7 then
		piece(layout, {
			x = (rect.x0 + rect.x1) / 2,
			y = 3.2,
			z = rect.z0 + 1,
			sx = rect.x1 - rect.x0,
			sy = 0.35,
			sz = 0.08,
			style = "tape",
			collide = false,
		})
	end
	for n = 0, 2 do
		light(
			layout,
			config,
			rng,
			rect.x0 + (n + 0.5) * (rect.x1 - rect.x0) / 3,
			(rect.z0 + rect.z1) / 2,
			config.RackLightY,
			"x",
			"cold"
		)
	end
	Pieces.wetPatches(layout, rng, rect, rng:int(0, 1))
end

-- Furniture piled up in heaps, the leftovers of the old store
function Zones.junkyard(layout: any, config: any, rng: Rng.Rng, rect: Rect)
	for _ = 1, rng:int(3, 6) do
		local px, pz = rng:range(rect.x0 + 12, rect.x1 - 12), rng:range(rect.z0 + 12, rect.z1 - 12)
		for _ = 1, rng:int(4, 8) do
			loose(
				layout,
				rng:pick(config.LooseFurniture),
				px + rng:range(-8, 8),
				pz + rng:range(-8, 8),
				rng:range(0, 360)
			)
		end
		junkStack(layout, rng, px + rng:range(-6, 6), pz + rng:range(-6, 6), rng:int(2, 4), false)
	end
	light(
		layout,
		config,
		rng,
		(rect.x0 + rect.x1) / 2,
		(rect.z0 + rect.z1) / 2,
		config.RackLightY,
		"x",
		"cold"
	)
end

-- Giant round pillars that make you feel tiny, on a wet floor
function Zones.hall(layout: any, config: any, rng: Rng.Rng, rect: Rect)
	local n = 3
	for j = 0, n - 1 do
		for i = 0, n - 1 do
			piece(layout, {
				shape = "cylinder",
				x = rect.x0 + (i + 0.5) * (rect.x1 - rect.x0) / n,
				y = config.CeilingHeight / 2,
				z = rect.z0 + (j + 0.5) * (rect.z1 - rect.z0) / n,
				sx = config.HallPillar,
				sy = config.CeilingHeight,
				sz = config.HallPillar,
				style = "pillar",
				solid = true,
			})
		end
	end
	Pieces.wetPatches(layout, rng, rect, rng:int(2, 4))
end

function Zones.empty(layout: any, _config: any, rng: Rng.Rng, rect: Rect)
	Pieces.wetPatches(layout, rng, rect, rng:int(1, 2))
	-- Sometimes the only thing out here is one glowing vending machine
	if rng:next() < 0.5 then
		loose(
			layout,
			"vending_machine",
			(rect.x0 + rect.x1) / 2,
			(rect.z0 + rect.z1) / 2,
			rng:pick({ 0, 90, 180, 270 })
		)
		return
	end
	junkStack(
		layout,
		rng,
		rng:range(rect.x0 + 6, rect.x1 - 6),
		rng:range(rect.z0 + 6, rect.z1 - 6),
		rng:int(1, 3),
		false
	)
end

-- A pretend cul-de-sac indoors: a ring road round a grass island, houses facing in across lawns,
-- driveways, mailboxes, streetlights and one fake sun overhead that stay on all night. It sits in
-- total darkness: you round a corner into a pool of cold, fake daylight and warm, empty windows.
-- Every house is the same house, and none of them have doors. The Blender cul-de-sac kit takes over
-- from the boxes once it's uploaded.
function Zones.neighborhood(layout: any, config: any, rng: Rng.Rng, rect: Rect)
	local cx, cz = (rect.x0 + rect.x1) / 2, (rect.z0 + rect.z1) / 2
	local w, d = rect.x1 - rect.x0, rect.z1 - rect.z0
	Pieces.floor(layout, rect, "grass", nil, nil, "turf_tile")
	local outer, road = math.min(w, d) * 0.3, config.NeighborhoodRoad
	for _, side in { -1, 1 } do
		piece(layout, {
			x = cx,
			y = 0.2,
			z = cz + side * (outer - road / 2),
			sx = outer * 2,
			sy = 0.1,
			sz = road,
			style = "asphalt",
		})
		piece(layout, {
			x = cx + side * (outer - road / 2),
			y = 0.2,
			z = cz,
			sx = road,
			sy = 0.1,
			sz = outer * 2 - road * 2,
			style = "asphalt",
		})
	end
	piece(layout, {
		x = cx,
		y = 0.2,
		z = (cz + outer + rect.z1) / 2,
		sx = road,
		sy = 0.1,
		sz = rect.z1 - cz - outer,
		style = "asphalt",
	})
	local style = rng:pick({ "stucco_pink", "stucco_yellow", "stucco_peach", "siding" })
	local houseKit = rng:pick(config.NeighborhoodHouses)
	for _, row in { { rect.z0 + 9, 1 }, { rect.z1 - 9, -1 } } do
		local turn = if row[2] > 0 then 0 else 180
		for n = -1, 1 do
			local hx = cx + n * w * 0.3
			if not (row[2] < 0 and n == 0) then
				Pieces.house(layout, rng, hx, row[1], row[2], 18, style, true, houseKit)
				Pieces.kitProp(layout, houseKit, hx, row[1], turn, 0.7)
				local roadEdge = cz - row[2] * outer
				piece(layout, {
					x = hx,
					y = 0.18,
					z = (row[1] + row[2] * 6 + roadEdge) / 2,
					sx = 5,
					sy = 0.08,
					sz = math.abs(roadEdge - (row[1] + row[2] * 6)),
					style = "paving",
				})
				local mz = roadEdge - row[2] * 1.5
				piece(layout, {
					x = hx + 4,
					y = 1.6,
					z = mz,
					sx = 0.25,
					sy = 3.2,
					sz = 0.25,
					style = "rail",
					collide = false,
					skipIfKit = "mailbox",
				})
				piece(layout, {
					x = hx + 4,
					y = 3.4,
					z = mz,
					sx = 0.8,
					sy = 0.7,
					sz = 1.3,
					style = "mailbox",
					skipIfKit = "mailbox",
				})
				Pieces.kitProp(layout, "mailbox", hx + 4, mz, turn, 0.7)
				-- Lawn dressing, only once the kit is up: hedges, a tree, a porch light, the odd toy
				Pieces.kitProp(layout, "hedge", hx - 7, row[1] + row[2] * 7, turn, 0.7)
				Pieces.kitProp(layout, "porch_light", hx + 2.6, row[1] + row[2] * 4.2, turn, 4)
				Pieces.kitProp(layout, "welcome_mat", hx, row[1] + row[2] * 4.6, turn, 0.7)
				if rng:next() < 0.5 then
					Pieces.kitProp(layout, "fake_tree", hx + 9, row[1] + row[2] * 9, rng:range(0, 360), 0.7)
				end
				if rng:next() < 0.3 then
					Pieces.kitProp(
						layout,
						rng:pick({ "lawn_flamingo", "tricycle", "garden_sprinkler" }),
						hx - 3,
						row[1] + row[2] * 10,
						rng:range(0, 360),
						0.7
					)
				end
			end
		end
	end
	-- One car parked in one driveway, nobody in it
	piece(layout, {
		x = cx - w * 0.3,
		y = 1.4,
		z = rect.z0 + 22,
		sx = 4.4,
		sy = 2.2,
		sz = 8,
		style = "car_body",
		solid = true,
	})
	piece(
		layout,
		{ x = cx - w * 0.3, y = 3, z = rect.z0 + 22.5, sx = 3.8, sy = 1.4, sz = 4.4, style = "window_black" }
	)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local lx, lz = cx + corner[1] * (outer + 2), cz + corner[2] * (outer + 2)
		piece(layout, {
			x = lx,
			y = 7,
			z = lz,
			sx = 0.5,
			sy = 14,
			sz = 0.5,
			style = "rail",
			solid = true,
			skipIfKit = "streetlamp",
		})
		piece(layout, {
			x = lx,
			y = 14.2,
			z = lz,
			sx = 1.6,
			sy = 0.5,
			sz = 1.6,
			style = "panel_warm",
			collide = false,
			lamp = "street",
			skipIfKit = "streetlamp",
		})
		Pieces.kitProp(layout, "streetlamp", lx, lz, if corner[2] < 0 then 0 else 180, 0.2)
		piece(layout, {
			x = lx,
			y = 13.4,
			z = lz,
			sx = 0.4,
			sy = 0.4,
			sz = 0.4,
			style = "lamp_bulb",
			collide = false,
			lamp = "street",
		})
	end
	-- The fake sun: one glowing ceiling panel high over the island, lighting the whole street
	piece(layout, {
		x = cx,
		y = config.NeighborhoodSunY,
		z = cz,
		sx = 24,
		sy = 0.4,
		sz = 24,
		style = "sun",
		collide = false,
		skipIfKit = "sun_panel",
	})
	Pieces.kitProp(layout, "sun_panel", cx, cz, 0, config.NeighborhoodSunY) -- The light itself hangs lower than the panel: lights only reach 60 studs
	piece(layout, {
		x = cx,
		y = 36,
		z = cz,
		sx = 0.5,
		sy = 0.5,
		sz = 0.5,
		style = "lamp_bulb",
		collide = false,
		lamp = "fake_sun",
	})
end

Zones.installation = Installations.build

return Zones
