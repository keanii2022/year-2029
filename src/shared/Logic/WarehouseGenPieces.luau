-- Small builders shared by the zone and installation generators. All of them append plain data
-- to the layout: pieces (primitives with a style name), loose furniture, strip lights.
-- A piece: { shape, x, y, z, sx, sy, sz, turn, style, solid, collide, label, paint, lamp }.
-- Blender kit hooks, used once the kit is uploaded: kit (place that model instead of the box),
-- kitOnly (place the model or nothing), skipIfKit (drop this box when that model is uploaded),
-- kitFloor (tile that 32-stud floor model over the box).
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Pieces = {}

export type Rect = { x0: number, z0: number, x1: number, z1: number }

function Pieces.piece(layout: any, spec: any)
	spec.shape = spec.shape or "box"
	spec.turn = spec.turn or 0
	if spec.collide == nil then
		spec.collide = true
	end
	table.insert(layout.pieces, spec)
	if spec.solid then
		local square = spec.turn % 180 == 0
		local hx = if square then spec.sx / 2 else spec.sz / 2
		local hz = if square then spec.sz / 2 else spec.sx / 2
		if spec.turn % 90 ~= 0 then
			hx = math.max(spec.sx, spec.sz) / 2
			hz = hx
		end
		layout.addSolid({ x0 = spec.x - hx, x1 = spec.x + hx, z0 = spec.z - hz, z1 = spec.z + hz })
	end
	return spec
end

local piece = Pieces.piece

function Pieces.floor(
	layout: any,
	rect: Rect,
	style: string,
	lift: number?,
	paint: string?,
	kitFloor: string?
)
	return piece(layout, {
		x = (rect.x0 + rect.x1) / 2,
		y = (lift or 0.05) + 0.05,
		z = (rect.z0 + rect.z1) / 2,
		sx = rect.x1 - rect.x0,
		sy = 0.1,
		sz = rect.z1 - rect.z0,
		style = style,
		paint = paint,
		kitFloor = kitFloor,
	})
end

-- A Blender kit model that only appears once it's uploaded; turn is degrees about up, y lifts it
function Pieces.kitProp(layout: any, name: string, x: number, z: number, turn: number?, y: number?)
	table.insert(layout.pieces, {
		shape = "box",
		x = x,
		y = y or 0,
		z = z,
		sx = 1,
		sy = 1,
		sz = 1,
		turn = turn or 0,
		style = "kit",
		collide = true,
		kit = name,
		kitOnly = true,
	})
end

function Pieces.ceiling(layout: any, rect: Rect, height: number, style: string, paint: string?)
	piece(layout, {
		x = (rect.x0 + rect.x1) / 2,
		y = height + 0.5,
		z = (rect.z0 + rect.z1) / 2,
		sx = rect.x1 - rect.x0,
		sy = 1,
		sz = rect.z1 - rect.z0,
		style = style,
		paint = paint,
	})
end

-- A strip light hanging on a cable from the roof. state: on, dead or flicker.
function Pieces.light(
	layout: any,
	config: any,
	rng: Rng.Rng,
	x: number,
	z: number,
	y: number,
	axis: string,
	tone: string
)
	local roll = rng:next()
	local state = if roll < config.LightDead
		then "dead"
		elseif roll < config.LightDead + config.LightFlicker then "flicker"
		else "on"
	table.insert(layout.lights, {
		x = x,
		y = y,
		z = z,
		length = config.LightLength,
		axis = axis,
		tone = tone,
		state = state,
		cable = config.CeilingHeight - y,
	})
end

function Pieces.loose(layout: any, name: string, x: number, z: number, turn: number)
	table.insert(layout.loose, { name = name, x = x, z = z, turn = turn })
	layout.addSolid({ x0 = x - 2.5, x1 = x + 2.5, z0 = z - 2.5, z1 = z + 2.5 })
end

-- A leaning stack of cardboard boxes you can pull apart for a fort
function Pieces.junkStack(layout: any, rng: Rng.Rng, x: number, z: number, count: number, big: boolean)
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

function Pieces.wetPatches(layout: any, rng: Rng.Rng, rect: Rect, count: number)
	for _ = 1, count do
		local w, d = rng:range(8, 26), rng:range(6, 18)
		local x, z = rng:range(rect.x0 + w / 2, rect.x1 - w / 2), rng:range(rect.z0 + d / 2, rect.z1 - d / 2)
		piece(layout, { x = x, y = 0.04, z = z, sx = w, sy = 0.06, sz = d, style = "wet", collide = false })
	end
end

-- A grid of small windows on the inside of a wall that runs along x, some glowing
function Pieces.windowGrid(
	layout: any,
	rng: Rng.Rng,
	x0: number,
	x1: number,
	z: number,
	nz: number,
	y0: number,
	y1: number
)
	local cols = math.max(1, math.floor((x1 - x0) / 4))
	local rows = math.max(1, math.floor((y1 - y0) / 3.5))
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local roll = rng:next()
			piece(layout, {
				x = x0 + (c + 0.5) * (x1 - x0) / cols,
				y = y0 + (r + 0.5) * (y1 - y0) / rows,
				z = z + nz * 0.05,
				sx = 1.6,
				sy = 1.6,
				sz = 0.1,
				style = if roll < 0.12
					then "window_lit"
					elseif roll < 0.2 then "window_teal"
					else "window_dark",
				collide = false,
			})
		end
	end
end

-- A closet behind a door frame that opens onto a painted sunny hill. nz points out of the closet.
function Pieces.dreamDoor(layout: any, x: number, z: number, nz: number)
	local back = z - nz * 6
	piece(
		layout,
		{ x = x, y = 4, z = back, sx = 6, sy = 8, sz = 0.4, style = "sky", paint = "hill", solid = true }
	)
	piece(
		layout,
		{ x = x - 3, y = 4, z = z - nz * 3, sx = 0.4, sy = 8, sz = 6, style = "plaster_cream", solid = true }
	)
	piece(
		layout,
		{ x = x + 3, y = 4, z = z - nz * 3, sx = 0.4, sy = 8, sz = 6, style = "plaster_cream", solid = true }
	)
	piece(layout, { x = x, y = 8.2, z = z - nz * 3, sx = 6.4, sy = 0.4, sz = 6.4, style = "plaster_cream" })
	piece(layout, { x = x, y = 0.12, z = z - nz * 3, sx = 6, sy = 0.14, sz = 6, style = "grass" })
	piece(layout, { x = x, y = 7.4, z = z, sx = 4.4, sy = 0.5, sz = 0.5, style = "door_frame" })
	piece(layout, { x = x - 2, y = 3.6, z = z, sx = 0.4, sy = 7.2, sz = 0.5, style = "door_frame" })
	piece(layout, { x = x + 2, y = 3.6, z = z, sx = 0.4, sy = 7.2, sz = 0.5, style = "door_frame" })
	-- Sunlight spilling out of the door
	piece(layout, {
		x = x,
		y = 7.8,
		z = z - nz * 3,
		sx = 3,
		sy = 0.2,
		sz = 3,
		style = "sun",
		collide = false,
		lamp = "sun",
	})
end

-- A little pastel house: box, two roof slopes, a door and two windows. nz is the front.
function Pieces.house(
	layout: any,
	rng: Rng.Rng,
	x: number,
	z: number,
	nz: number,
	w: number?,
	style: string?,
	noDoor: boolean?,
	kit: string?
)
	local width, depth, height = w or 22, 12, 9
	local function part(spec: any)
		spec.skipIfKit = kit
		return Pieces.piece(layout, spec)
	end
	style = style or rng:pick({ "pastel_pink", "pastel_yellow", "pastel_peach" })
	piece(
		layout,
		{ x = x, y = height / 2, z = z, sx = width, sy = height, sz = depth, style = style, solid = true }
	)
	part({
		shape = "wedge",
		x = x,
		y = height + 2.5,
		z = z - depth / 4,
		sx = width + 1,
		sy = 5,
		sz = depth / 2 + 0.5,
		turn = 0,
		style = "roof",
	})
	part({
		shape = "wedge",
		x = x,
		y = height + 2.5,
		z = z + depth / 4,
		sx = width + 1,
		sy = 5,
		sz = depth / 2 + 0.5,
		turn = 180,
		style = "roof",
	})
	local front = z + nz * (depth / 2 + 0.05)
	if not noDoor then
		piece(
			layout,
			{ x = x, y = 3.5, z = front, sx = 3.4, sy = 7, sz = 0.2, style = "door_dark", collide = false }
		)
	end
	for _, wx in { -width * 0.3, width * 0.3 } do
		part({
			x = x + wx,
			y = 5,
			z = front,
			sx = 3,
			sy = 2.6,
			sz = 0.2,
			style = if rng:next() < 0.4 then "window_lit" else "window_dark",
			collide = false,
		})
	end
end

-- A picket fence running along x
function Pieces.fence(layout: any, x0: number, x1: number, z: number)
	piece(layout, {
		x = (x0 + x1) / 2,
		y = 1.2,
		z = z,
		sx = x1 - x0,
		sy = 0.3,
		sz = 0.2,
		style = "picket",
		solid = true,
		skipIfKit = "picket_fence",
	})
	piece(layout, {
		x = (x0 + x1) / 2,
		y = 2.4,
		z = z,
		sx = x1 - x0,
		sy = 0.3,
		sz = 0.2,
		style = "picket",
		skipIfKit = "picket_fence",
	})
	for x = x0, x1, 1.2 do
		piece(layout, {
			x = x,
			y = 1.6,
			z = z,
			sx = 0.6,
			sy = 3.2,
			sz = 0.15,
			style = "picket",
			skipIfKit = "picket_fence",
		})
	end
	for x = x0 + 4, x1 - 4, 8 do
		Pieces.kitProp(layout, "picket_fence", x, z, 0)
	end
end

-- A grid of glowing ceiling panels; every Nth one actually casts light
function Pieces.panelGrid(
	layout: any,
	rect: Rect,
	height: number,
	step: number,
	size: number,
	style: string,
	lampEvery: number
)
	local n = 0
	local x = rect.x0 + step / 2
	while x < rect.x1 do
		local z = rect.z0 + step / 2
		while z < rect.z1 do
			n += 1
			piece(layout, {
				x = x,
				y = height - 0.12,
				z = z,
				sx = size,
				sy = 0.2,
				sz = size,
				style = style,
				collide = false,
				lamp = if n % lampEvery == 0 then style else nil,
			})
			z += step
		end
		x += step
	end
end

return Pieces
