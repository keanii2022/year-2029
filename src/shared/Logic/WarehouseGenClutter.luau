-- Big overhead, tight underfoot. After the zones are built, this fills what's left:
-- clutter islands every 30-40 studs of open floor so there's always cover a few seconds away, things
-- hanging in the air at different heights for the fog to catch, and a floor that tells a story.
-- Wide open floor stays only where it's meant to be: pillar halls, installations, cul-de-sacs.
local Pieces = if script then require(script.Parent.WarehouseGenPieces) else require("./WarehouseGenPieces")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Clutter = {}

local piece, kitProp = Pieces.piece, Pieces.kitProp

local Islands = {}

-- A tower of pallets, wrapped loads and crates
function Islands.pallets(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	for _ = 1, rng:int(2, 4) do
		local px, pz = x + rng:range(-4, 4), z + rng:range(-4, 4)
		local h = rng:range(4, 10)
		piece(layout, {
			x = px,
			y = h / 2,
			z = pz,
			sx = 5.2,
			sy = h,
			sz = 5.2,
			turn = rng:range(-10, 10),
			style = if rng:next() < 0.3 then "wrap" else "stack",
			solid = true,
			kit = rng:pick({
				"pallet_tower",
				"pallet_boxes",
				"pallet_wrapped",
				"crate_stack",
				"pallet_sacks",
			}),
		})
	end
end

-- A rack that gave up: beams leaning on each other, its load spilled across the floor
function Islands.wreck(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	local turn = rng:range(0, 180)
	kitProp(layout, rng:pick({ "rack_collapsed", "rack_toppled_beam" }), x, z, turn)
	for n = 0, 2 do
		piece(layout, {
			x = x + rng:range(-3, 3),
			y = 4 + n * 2,
			z = z + rng:range(-3, 3),
			sx = 12,
			sy = 0.5,
			sz = 0.6,
			turn = turn + rng:range(-20, 20),
			lean = rng:range(-35, 35),
			style = if n % 2 == 0 then "rack_beam" else "rack_upright",
			collide = false,
			skipIfKit = "rack_collapsed",
		})
	end
	Pieces.junkStack(layout, rng, x + rng:range(-5, 5), z + rng:range(-5, 5), rng:int(2, 4), false)
	layout.addSolid({ x0 = x - 6, x1 = x + 6, z0 = z - 6, z1 = z + 6 })
end

-- Old furniture heaped up: grab a piece and run
function Islands.heap(layout: any, config: any, rng: Rng.Rng, x: number, z: number)
	if rng:next() < 0.5 then
		kitProp(layout, rng:pick({ "furniture_heap", "junk_pile" }), x, z, rng:range(0, 360))
		layout.addSolid({ x0 = x - 6, x1 = x + 6, z0 = z - 6, z1 = z + 6 })
	end
	for _ = 1, rng:int(2, 4) do
		Pieces.loose(
			layout,
			rng:pick(config.LooseFurniture),
			x + rng:range(-6, 6),
			z + rng:range(-6, 6),
			rng:range(0, 360)
		)
	end
end

-- Cardboard boxes, some stacked, some fallen
function Islands.boxes(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	kitProp(layout, rng:pick({ "box_pile_big", "box_pile_small" }), x, z, rng:range(0, 360))
	for _ = 1, rng:int(2, 3) do
		Pieces.junkStack(
			layout,
			rng,
			x + rng:range(-5, 5),
			z + rng:range(-5, 5),
			rng:int(1, 4),
			rng:next() < 0.4
		)
	end
end

-- Shopping carts nested in a long train, one wandered off on its own
function Islands.carts(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	local turn = rng:pick({ 0, 90, 180, 270 })
	local dx, dz = math.sin(math.rad(turn)), math.cos(math.rad(turn))
	for n = 0, rng:int(3, 6) do
		local cx, cz = x + dx * n * 1.6, z + dz * n * 1.6
		kitProp(layout, "shopping_cart", cx, cz, turn)
		piece(layout, {
			x = cx,
			y = 1.6,
			z = cz,
			sx = 2,
			sy = 2,
			sz = 3,
			turn = turn,
			style = "cart_wire",
			skipIfKit = "shopping_cart",
		})
	end
	local lone = rng:range(0, 360)
	kitProp(layout, "shopping_cart", x + rng:range(-9, 9), z + rng:range(-9, 9), lone)
	layout.addSolid({ x0 = x - 5, x1 = x + 5, z0 = z - 5, z1 = z + 5 })
end

-- Oil drums, a couple tipped over, black oil leaking out
function Islands.drums(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	for _ = 1, rng:int(3, 6) do
		local px, pz = x + rng:range(-4, 4), z + rng:range(-4, 4)
		local tipped = rng:next() < 0.25
		kitProp(layout, "oil_drum", px, pz, rng:range(0, 360))
		piece(layout, {
			shape = "cylinder",
			x = px,
			y = if tipped then 1.3 else 1.6,
			z = pz,
			sx = 2.6,
			sy = 3.2,
			sz = 2.6,
			lean = if tipped then 90 else 0,
			style = "drum",
			solid = true,
			skipIfKit = "oil_drum",
		})
	end
	piece(layout, {
		x = x + 3,
		y = 0.05,
		z = z + 2,
		sx = rng:range(5, 9),
		sy = 0.04,
		sz = rng:range(4, 7),
		style = "oil",
		collide = false,
	})
end

-- A spill: wet floor, caution tape strung between barriers, a sign nobody read
function Islands.spill(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	local w, d = rng:range(10, 16), rng:range(8, 12)
	piece(layout, { x = x, y = 0.05, z = z, sx = w, sy = 0.04, sz = d, style = "wet", collide = false })
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local bx, bz = x + corner[1] * w / 2, z + corner[2] * d / 2
		kitProp(layout, "hazard_barrier", bx, bz, if corner[1] == corner[2] then 0 else 90)
		piece(layout, {
			x = bx,
			y = 1.5,
			z = bz,
			sx = 0.4,
			sy = 3,
			sz = 0.4,
			style = "barrier",
			solid = true,
			skipIfKit = "hazard_barrier",
		})
	end
	for _, side in { -1, 1 } do
		piece(layout, {
			x = x,
			y = 2.8,
			z = z + side * d / 2,
			sx = w,
			sy = 0.3,
			sz = 0.06,
			style = "tape",
			collide = false,
		})
		piece(layout, {
			x = x + side * w / 2,
			y = 2.8,
			z = z,
			sx = 0.06,
			sy = 0.3,
			sz = d,
			style = "tape",
			collide = false,
		})
	end
	kitProp(layout, "wet_floor_sign", x + rng:range(-2, 2), z + rng:range(-2, 2), rng:range(0, 360))
end

-- Checkout lanes from the old store: a row of counters, belts stopped mid-item
function Islands.checkout(layout: any, _config: any, rng: Rng.Rng, x: number, z: number)
	local turn = rng:pick({ 0, 90 })
	for n = -1, 1 do
		local cx = if turn == 0 then x + n * 5 else x
		local cz = if turn == 0 then z else z + n * 5
		kitProp(layout, "checkout_lane", cx, cz, turn)
		piece(layout, {
			x = cx,
			y = 1.6,
			z = cz,
			sx = if turn == 0 then 1.8 else 9,
			sy = 3.2,
			sz = if turn == 0 then 9 else 1.8,
			style = "counter_grey",
			solid = true,
			skipIfKit = "checkout_lane",
		})
		piece(layout, {
			x = cx,
			y = 3.3,
			z = cz,
			sx = if turn == 0 then 1.2 else 5,
			sy = 0.2,
			sz = if turn == 0 then 5 else 1.2,
			style = "rubber",
			collide = false,
			skipIfKit = "checkout_lane",
		})
	end
end

-- Should this spot get a clutter island? Not inside racking, store displays, installations, homes
-- or pillar halls, and only where the floor is actually clear
local function openFloor(layout: any, config: any, x: number, z: number, zoneAt: any): boolean
	local zone = zoneAt(layout, x, z)
	if zone then
		local inside = x > zone.x0 and x < zone.x1 and z > zone.z0 and z < zone.z1
		if inside and config.ClutterSkipZones[zone.kind] then
			return false
		end
	end
	return true
end

-- Something hanging in the air over a cross aisle: a sign, a banner, a dangling light, a cable run
local function airborne(layout: any, config: any, rng: Rng.Rng, x: number, z: number, alongX: boolean)
	local roll = rng:next()
	local y = rng:range(config.AirHeight[1], config.AirHeight[2])
	if roll < 0.3 then
		local text = if rng:next() < 0.5 then tostring(rng:int(1, 99)) else rng:pick(config.Departments).name
		table.insert(layout.deptSigns, { x = x, z = z, y = y, text = text })
	elseif roll < 0.55 then
		Pieces.light(layout, config, rng, x, z, y, if alongX then "x" else "z", "cold")
	elseif roll < 0.75 then
		local banner = piece(layout, {
			x = x,
			y = y,
			z = z,
			sx = if alongX then 10 else 0.2,
			sy = 4,
			sz = if alongX then 0.2 else 10,
			style = "banner",
			label = rng:pick(config.BannerLines),
			collide = false,
			skipIfKit = "sale_banner",
		})
		local cable = config.CeilingHeight - y - 2
		for _, offset in { -4, 4 } do
			piece(layout, {
				x = x + (if alongX then offset else 0),
				y = y + 2 + cable / 2,
				z = z + (if alongX then 0 else offset),
				sx = 0.1,
				sy = cable,
				sz = 0.1,
				style = "cable",
				collide = false,
			})
		end
		kitProp(layout, "sale_banner", x, z, if alongX then 0 else 90, y - 2.8)
		return banner
	else
		-- A sagging cable run strung across the aisle high up
		piece(layout, {
			x = x,
			y = config.CeilingHeight - rng:range(6, 14),
			z = z,
			sx = if alongX then 0.25 else config.BlockSize,
			sy = 0.25,
			sz = if alongX then config.BlockSize else 0.25,
			style = "cable",
			collide = false,
		})
	end
	return nil
end

function Clutter.fill(layout: any, config: any, rng: Rng.Rng, zoneAt: any, isClear: any)
	local half = layout.half - config.WallThickness - 6
	local step = config.ClutterSpacing
	local x = -half + step / 2
	while x < half do
		local z = -half + step / 2
		while z < half do
			local px, pz = x + rng:range(-step * 0.25, step * 0.25), z + rng:range(-step * 0.25, step * 0.25)
			if
				rng:next() < config.ClutterChance
				and openFloor(layout, config, px, pz, zoneAt)
				and isClear(layout, config, px, pz, config.ClutterClearance)
			then
				Islands[rng:weighted(config.ClutterKinds)](layout, config, rng, px, pz)
			elseif rng:next() < config.FloorStoryChance and isClear(layout, config, px, pz, 2) then
				-- Story on the floor: drag trails through the dust, oil blots
				piece(layout, {
					x = px,
					y = 0.04,
					z = pz,
					sx = rng:range(0.8, 1.6),
					sy = 0.03,
					sz = rng:range(10, 24),
					turn = rng:range(0, 180),
					style = "oil",
					collide = false,
				})
			end
			z += step
		end
		x += step
	end

	-- Things hanging over the cross aisles
	local size = config.BlockSize
	for line = 1, layout.blocks - 1 do
		local c = -layout.half + line * size
		local along = -half + rng:range(0, config.AirSpacing)
		while along < half do
			airborne(layout, config, rng, along, c, true)
			airborne(layout, config, rng, c, along, false)
			along += config.AirSpacing * rng:range(0.6, 1.4)
		end
	end
end

return Clutter
