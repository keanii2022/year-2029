-- Installations: you step through a doorway into a pitch dark hall that reaches the roof, and in
-- the middle of the dark there's a lit set built after one of Keani's dreamcore references. Robots
-- live in each one, guarding a stash. Every set has its own look, its own wrongness and, often, something far too big.
-- Each set is registered as a robot room (id, kind, rect, doors, walls, items) so Robots and the
-- other systems find it like any room.
local Fill = if script then require(script.Parent.WarehouseGenFill) else require("./WarehouseGenFill")
local Pieces = if script then require(script.Parent.WarehouseGenPieces) else require("./WarehouseGenPieces")
local Prizes = if script then require(script.Parent.WarehouseGenPrizes) else require("./WarehouseGenPrizes")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")
local Rooms = if script then require(script.Parent.WarehouseGenRooms) else require("./WarehouseGenRooms")

local Installations = {}

local piece = Pieces.piece

type Ctx = {
	layout: any,
	config: any,
	rng: Rng.Rng,
	room: any,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	w: number,
	d: number,
	cx: number,
	cz: number,
	h: number,
}

-- A model the robot can study and stash things by; also counts as room furniture for Robots
local function item(ctx: Ctx, name: string, x: number, z: number, nx: number, nz: number)
	table.insert(ctx.room.items, { name = name, x = x, z = z, nx = nx, nz = nz })
	ctx.layout.addSolid({ x0 = x - 2, x1 = x + 2, z0 = z - 2, z1 = z + 2 })
end

-- Walls round the set with doorways cut in; recorded on the room for decals and robots
local function walls(
	ctx: Ctx,
	height: number,
	style: string,
	paint: string?,
	doors: number,
	doorWidth: number?
)
	local box = ctx.room
	box.doors = Rooms.doors(box, ctx.rng, doorWidth or 7, 1, doors)
	box.walls = Rooms.walls(box, 1, doorWidth or 7)
	for _, wall in box.walls do
		piece(ctx.layout, {
			x = (wall.x0 + wall.x1) / 2,
			y = height / 2,
			z = (wall.z0 + wall.z1) / 2,
			sx = wall.x1 - wall.x0,
			sy = height,
			sz = wall.z1 - wall.z0,
			style = style,
			paint = paint,
			solid = true,
		})
	end
end

local function inner(ctx: Ctx, pad: number): Pieces.Rect
	return { x0 = ctx.x0 + pad, z0 = ctx.z0 + pad, x1 = ctx.x1 - pad, z1 = ctx.z1 - pad }
end

local function lamp(ctx: Ctx, x: number, y: number, z: number, tone: string)
	piece(ctx.layout, {
		x = x,
		y = y,
		z = z,
		sx = 0.6,
		sy = 0.6,
		sz = 0.6,
		style = "lamp_bulb",
		collide = false,
		lamp = tone,
	})
end

-- Little black human shapes, far too small for the space around them
local function silhouette(ctx: Ctx, x: number, z: number, lying: boolean)
	if lying then
		piece(ctx.layout, {
			x = x,
			y = 0.3,
			z = z,
			sx = 0.6,
			sy = 0.4,
			sz = 1.8,
			turn = ctx.rng:range(0, 180),
			style = "silhouette",
			collide = false,
		})
	else
		piece(
			ctx.layout,
			{ x = x, y = 0.9, z = z, sx = 0.5, sy = 1.8, sz = 0.4, style = "silhouette", collide = false }
		)
	end
end

local Sets = {}

-- c1: a pinkish office hallway with a diamond marble floor, framed pictures and exit arrows that
-- point at each other. Three identical doors along the wall all open onto the same sunny hill.
function Sets.sky_door(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, 12, "wall_blush", nil, 1)
	Pieces.ceiling(L, ctx.room, 12, "drop_ceiling")
	Pieces.floor(L, ctx.room, "marble_dark", nil, nil, "floor_marble")
	local tile = 4
	local x = ctx.x0 + tile
	while x < ctx.x1 - tile do
		local z = ctx.z0 + tile
		while z < ctx.z1 - tile do
			piece(L, {
				x = x,
				y = 0.12,
				z = z,
				sx = tile * 0.62,
				sy = 0.06,
				sz = tile * 0.62,
				turn = 45,
				style = "marble_cream",
				collide = false,
				skipIfKit = "floor_marble",
			})
			z += tile
		end
		x += tile
	end
	local back = ctx.z0 + 1.3
	for n = 1, 3 do
		Pieces.dreamDoor(L, ctx.x0 + n * ctx.w / 4, back + 6, 1)
	end
	for n = 0, 3 do
		local fx = ctx.x0 + (n + 0.5) * ctx.w / 4
		piece(L, {
			x = fx + ctx.w / 8,
			y = 6,
			z = back + 0.1,
			sx = 4,
			sy = 3,
			sz = 0.2,
			style = "frame",
			collide = false,
			skipIfKit = "picture_frame",
		})
		Pieces.kitProp(L, "picture_frame", fx + ctx.w / 8, back + 0.3, 0, 4.5)
		piece(L, {
			x = fx + ctx.w / 8,
			y = 6,
			z = back + 0.22,
			sx = 3.4,
			sy = 2.4,
			sz = 0.05,
			style = "art_grey",
			collide = false,
			skipIfKit = "picture_frame",
		})
		piece(L, {
			x = fx,
			y = 9.5,
			z = back + 0.15,
			sx = 1.6,
			sy = 0.8,
			sz = 0.1,
			style = "exit_green",
			label = if n % 2 == 0 then "→" else "←",
			collide = false,
		})
	end
	item(ctx, "armchair", ctx.x1 - 6, ctx.z1 - 6, -1, -1)
	Pieces.panelGrid(L, inner(ctx, 2), 12, 10, 3, "panel", 3)
end

-- c2: a kids' party corner: pink, blue and yellow walls, a wild carpet, painted stars and balloons,
-- coloured cubbies stacked so high they go up through a hole in the ceiling, a glowing vending
-- machine, and a doorway far too small to fit through.
function Sets.kids_corner(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	local styles = { "wall_pink", "wall_blue", "wall_yellow" }
	ctx.room.doors = Rooms.doors(ctx.room, rng, 7, 1, 1)
	ctx.room.walls = Rooms.walls(ctx.room, 1, 7)
	for index, wall in ctx.room.walls do
		piece(L, {
			x = (wall.x0 + wall.x1) / 2,
			y = 6,
			z = (wall.z0 + wall.z1) / 2,
			sx = wall.x1 - wall.x0,
			sy = 12,
			sz = wall.z1 - wall.z0,
			style = styles[(index - 1) % 3 + 1],
			paint = if index % 3 == 2 then "stars" else nil,
			solid = true,
		})
	end
	Pieces.ceiling(L, ctx.room, 12, "drop_ceiling")
	Pieces.floor(L, ctx.room, "carpet_party", nil, nil, "floor_carpet_wild")
	for _ = 1, 60 do
		piece(L, {
			x = rng:range(ctx.x0 + 2, ctx.x1 - 2),
			y = 0.13,
			z = rng:range(ctx.z0 + 2, ctx.z1 - 2),
			sx = rng:range(0.4, 1.4),
			sy = 0.04,
			sz = rng:range(0.2, 0.5),
			turn = rng:range(0, 180),
			style = rng:pick({ "neon_pink", "neon_green", "neon_blue", "neon_yellow" }),
			collide = false,
			skipIfKit = "floor_carpet_wild",
		})
	end
	local towerX, towerZ = ctx.x1 - 5, ctx.z0 + 5
	for level = 0, 9 do
		piece(L, {
			x = towerX + rng:range(-0.3, 0.3),
			y = 1.2 + level * 2.4,
			z = towerZ,
			sx = 4,
			sy = 2.2,
			sz = 3,
			style = rng:pick({ "cubby_red", "cubby_blue", "cubby_yellow" }),
			solid = level == 0,
			skipIfKit = "cubbies",
		})
	end
	for level = 0, 2 do
		Pieces.kitProp(L, "cubbies", towerX, towerZ, 180, level * 6.6)
	end
	Pieces.kitProp(L, "star_decal", ctx.cx - 12, ctx.z0 + 1.3, 0, 6)
	Pieces.kitProp(L, "star_decal", ctx.cx + 14, ctx.z0 + 1.3, 0, 8)
	piece(L, { x = towerX, y = 12.6, z = towerZ, sx = 5, sy = 0.4, sz = 4, style = "void", collide = false })
	item(ctx, "vending_machine", ctx.cx, ctx.z0 + 3, 0, 1)
	-- The tiny doorway, lit from inside
	piece(L, {
		x = ctx.x0 + 1.3,
		y = 1,
		z = ctx.cz,
		sx = 0.2,
		sy = 2,
		sz = 1.2,
		style = "exit_glow",
		collide = false,
		lamp = "warm",
	})
	Pieces.kitProp(L, "crate_stack_plastic", ctx.x0 + 6, ctx.z0 + 5, 45)
	item(ctx, "toy_chest", ctx.x0 + 5, ctx.z1 - 5, 1, -1)
	for gx = ctx.x0 + 6, ctx.x1 - 6, 10 do
		for gz = ctx.z0 + 6, ctx.z1 - 6, 10 do
			piece(L, {
				shape = "cylinder",
				x = gx,
				y = 11.9,
				z = gz,
				sx = 1.4,
				sy = 0.15,
				sz = 1.4,
				style = "panel",
				collide = false,
				lamp = if (gx + gz) % 20 < 10 then "panel" else nil,
			})
		end
	end
end

-- c3: sky everywhere, even under your feet. In the middle, an open hatch in the floor with a ladder
-- climbing out of it toward the painted sky, and another ladder hanging down from a hatch above.
function Sets.sky_hatch(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "sky", "sky", 1)
	Pieces.ceiling(L, ctx.room, ctx.h, "sky", "sky")
	Pieces.floor(L, ctx.room, "sky", 0.05, "sky_floor")
	local function hatch(y: number, flip: boolean)
		local hx, hz = ctx.cx, ctx.cz
		piece(L, { x = hx, y = y, z = hz - 3, sx = 8.4, sy = 0.6, sz = 0.4, style = "hatch_wood" })
		piece(L, { x = hx, y = y, z = hz + 3, sx = 8.4, sy = 0.6, sz = 0.4, style = "hatch_wood" })
		piece(L, { x = hx - 4, y = y, z = hz, sx = 0.4, sy = 0.6, sz = 6, style = "hatch_wood" })
		piece(L, { x = hx + 4, y = y, z = hz, sx = 0.4, sy = 0.6, sz = 6, style = "hatch_wood" })
		piece(L, {
			x = hx,
			y = y + (if flip then 0.2 else -0.2),
			z = hz,
			sx = 7.6,
			sy = 0.1,
			sz = 5.6,
			style = "void",
			collide = false,
		})
		-- A ladder standing straight up out of the hatch, or hanging straight down from it
		local dir = if flip then -1 else 1
		for _, side in { -0.9, 0.9 } do
			piece(L, {
				x = hx + side,
				y = y + dir * 9,
				z = hz + 1,
				sx = 0.25,
				sy = 18,
				sz = 0.35,
				style = "ladder",
				collide = false,
			})
		end
		for r = 0, 9 do
			piece(L, {
				x = hx,
				y = y + dir * (1 + r * 1.8),
				z = hz + 1,
				sx = 1.8,
				sy = 0.15,
				sz = 0.25,
				style = "ladder",
				collide = false,
			})
		end
	end
	Pieces.kitProp(L, "sky_hatch", ctx.cx + 14, ctx.cz - 10, 30, 0.2)
	hatch(0.3, false)
	hatch(ctx.h - 0.3, true)
	item(ctx, "kitchen_chair", ctx.x0 + 6, ctx.z0 + 6, 1, 1)
	lamp(ctx, ctx.cx, ctx.h * 0.6, ctx.cz, "sky")
end

-- c4: flooded rooms of white tile, turquoise water to the knee, doorways into more of the same,
-- a tile stair going down into the water, and tunnels far too small to crawl into
function Sets.tile_maze(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	local height = 14
	walls(ctx, height, "tile_white", nil, 2)
	Pieces.ceiling(L, ctx.room, height, "tile_white")
	Pieces.floor(L, ctx.room, "tile_white", nil, nil, "floor_pool")
	piece(L, {
		x = ctx.cx,
		y = 0.7,
		z = ctx.cz,
		sx = ctx.w - 2,
		sy = 1.2,
		sz = ctx.d - 2,
		style = "water_turq",
		collide = false,
	})
	local cell = 18
	for gx = ctx.x0 + cell, ctx.x1 - cell / 2, cell do
		for gz = ctx.z0 + cell / 2, ctx.z1 - cell / 2, cell do
			if rng:next() < 0.6 then
				-- A wall segment with an opening, so the rooms chain into each other
				piece(L, {
					x = gx,
					y = height / 2,
					z = gz - cell / 2 + 2.5,
					sx = 1.2,
					sy = height,
					sz = 5,
					style = "tile_white",
					solid = true,
				})
				piece(L, {
					x = gx,
					y = height / 2,
					z = gz + cell / 2 - 2.5,
					sx = 1.2,
					sy = height,
					sz = 5,
					style = "tile_white",
					solid = true,
				})
				piece(
					L,
					{ x = gx, y = height - 2, z = gz, sx = 1.2, sy = 4, sz = cell - 10, style = "tile_white" }
				)
				if rng:next() < 0.3 then
					piece(L, {
						x = gx + 0.65,
						y = 1.4,
						z = gz + rng:range(-3, 3),
						sx = 0.1,
						sy = 1.4,
						sz = 1.4,
						style = "void",
						collide = false,
					})
				end
			end
		end
	end
	for s = 0, 5 do
		piece(L, {
			x = ctx.x1 - 8 - s * 1.2,
			y = 0.9 - s * 0.3,
			z = ctx.cz,
			sx = 1.2,
			sy = 0.3,
			sz = 6,
			style = "tile_white",
			collide = false,
		})
	end
	-- Light pouring down through square openings in the ceiling
	for _ = 1, 4 do
		local lx, lz = rng:range(ctx.x0 + 8, ctx.x1 - 8), rng:range(ctx.z0 + 8, ctx.z1 - 8)
		piece(L, {
			x = lx,
			y = height - 0.1,
			z = lz,
			sx = 6,
			sy = 0.2,
			sz = 6,
			style = "sun",
			collide = false,
			lamp = "sun",
		})
	end
	item(ctx, "leak_bucket", ctx.x0 + 4, ctx.z0 + 4, 1, 1)
end

-- c5: megalophobia. The floor rises into a grass hill toward a deep blue wall, and on top of the
-- hill sits a solid cloud the size of a building. Tiny dark figures lie on the grass.
function Sets.cloud_hill(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "sky_deep", nil, 1, 10)
	Pieces.ceiling(L, ctx.room, ctx.h, "sky_deep")
	Pieces.floor(L, ctx.room, "grass")
	local rise = 14
	piece(L, {
		shape = "wedge",
		x = ctx.cx,
		y = rise / 2,
		z = ctx.z0 + ctx.d * 0.35,
		sx = ctx.w - 2,
		sy = rise,
		sz = ctx.d * 0.5,
		turn = 180,
		style = "grass",
		solid = true,
	})
	piece(L, {
		x = ctx.cx,
		y = rise / 2,
		z = ctx.z0 + ctx.d * 0.06,
		sx = ctx.w - 2,
		sy = rise,
		sz = ctx.d * 0.1,
		style = "grass",
		solid = true,
	})
	local cloudZ = ctx.z0 + ctx.d * 0.12
	for _ = 1, 22 do
		local r = rng:range(10, 22)
		piece(L, {
			shape = "ball",
			x = ctx.cx + rng:range(-ctx.w * 0.25, ctx.w * 0.25),
			y = rise + rng:range(r * 0.4, ctx.h - r * 0.6),
			z = cloudZ + rng:range(-6, 6),
			sx = r,
			sy = r,
			sz = r,
			style = "cloud",
			collide = false,
			skipIfKit = "giant_cloud",
		})
	end
	for _, spot in { { -14, 0 }, { 14, 2 }, { 0, 16 }, { -6, 30 } } do
		Pieces.kitProp(L, "giant_cloud", ctx.cx + spot[1], cloudZ, rng:range(-10, 10), rise + spot[2])
	end
	for _ = 1, 9 do
		silhouette(ctx, rng:range(ctx.x0 + 8, ctx.x1 - 8), rng:range(ctx.cz, ctx.z1 - 6), rng:next() < 0.6)
	end
	lamp(ctx, ctx.cx, ctx.h - 6, ctx.z1 - 10, "sun")
	lamp(ctx, ctx.cx, ctx.h - 6, ctx.cz, "sun")
	item(ctx, "sleeping_bag", ctx.cx + 10, ctx.z1 - 8, 0, -1)
end

-- c6: a foggy lawn. A picket fence runs off into the dark, a wooden house with no door, and pale
-- shafts of light slanting through blue haze.
function Sets.fog_lawn(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "haze_wall", "sky", 1, 10)
	Pieces.ceiling(L, ctx.room, ctx.h, "sky", "sky")
	Pieces.floor(L, ctx.room, "grass")
	Pieces.fence(L, ctx.x0 + 1, ctx.x1 - 1, ctx.z0 + ctx.d * 0.35)
	piece(L, {
		x = ctx.x1 - 10,
		y = 5.5,
		z = ctx.z0 + ctx.d * 0.2,
		sx = 16,
		sy = 11,
		sz = 14,
		style = "siding",
		solid = true,
	})
	piece(L, {
		shape = "wedge",
		x = ctx.x1 - 10,
		y = 13.5,
		z = ctx.z0 + ctx.d * 0.2 - 3.5,
		sx = 17,
		sy = 5,
		sz = 7.5,
		style = "roof",
	})
	piece(L, {
		shape = "wedge",
		x = ctx.x1 - 10,
		y = 13.5,
		z = ctx.z0 + ctx.d * 0.2 + 3.5,
		sx = 17,
		sy = 5,
		sz = 7.5,
		turn = 180,
		style = "roof",
	})
	piece(L, {
		x = ctx.x1 - 10,
		y = 6,
		z = ctx.z0 + ctx.d * 0.2 + 7.05,
		sx = 1.6,
		sy = 2.6,
		sz = 0.1,
		style = "window_dark",
		collide = false,
	})
	for n = 0, 7 do
		piece(L, {
			x = ctx.x0 + (n + 0.5) * ctx.w / 8 + rng:range(-3, 3),
			y = ctx.h / 2,
			z = ctx.cz + rng:range(-8, 8),
			sx = rng:range(2, 5),
			sy = ctx.h * 1.1,
			sz = 0.2,
			turn = rng:range(-15, 15),
			style = "haze_ray",
			collide = false,
			lean = 18,
		})
	end
	for n = 0, 3 do
		piece(L, {
			x = ctx.cx,
			y = 2 + n * 3,
			z = ctx.cz + 10,
			sx = ctx.w - 4,
			sy = 3,
			sz = ctx.d * 0.5,
			style = "haze_layer",
			collide = false,
		})
	end
	lamp(ctx, ctx.x0 + 10, ctx.h - 4, ctx.z0 + 10, "haze")
	item(ctx, "leak_bucket", ctx.x0 + 8, ctx.z1 - 8, 1, -1)
end

-- c7: a carpeted basement. A staircase climbs into the ceiling, another goes down into the floor
-- and stops at a wall, white doors that don't open, and one doorway glowing blue.
function Sets.basement(ctx: Ctx)
	local L = ctx.layout
	local height = 10
	walls(ctx, height, "plaster_white", nil, 1)
	Pieces.ceiling(L, ctx.room, height, "plaster_white")
	Pieces.floor(L, ctx.room, "carpet_beige")
	for s = 0, 9 do
		piece(L, {
			x = ctx.cx - 6 + s * 1.2,
			y = 0.5 + s * 1,
			z = ctx.z0 + 4,
			sx = 1.2,
			sy = 1 + s * 2,
			sz = 5,
			style = "carpet_beige",
			solid = s == 0,
			skipIfKit = "stairs_to_wall",
		})
	end
	piece(L, { x = ctx.cx + 7, y = 3, z = ctx.z0 + 1.5, sx = 1.4, sy = 6, sz = 0.3, style = "banister" })
	for n = 1, 3 do
		piece(L, {
			x = ctx.x0 + 1.2,
			y = 3.6,
			z = ctx.z0 + n * ctx.d / 4,
			sx = 0.2,
			sy = 7.2,
			sz = 3.4,
			style = "door_white",
			collide = false,
		})
	end
	-- The blue room: a small tiled room glowing cold blue
	local bx, bz = ctx.x1 - 9, ctx.z1 - 9
	piece(L, {
		x = bx - 7,
		y = height / 2,
		z = bz,
		sx = 0.6,
		sy = height,
		sz = 14,
		style = "plaster_white",
		solid = true,
	})
	piece(L, {
		x = bx,
		y = height / 2,
		z = bz - 7,
		sx = 6,
		sy = height,
		sz = 0.6,
		style = "plaster_white",
		solid = true,
	})
	piece(L, { x = bx, y = 0.12, z = bz, sx = 14, sy = 0.12, sz = 14, style = "tile_white" })
	piece(L, { x = bx + 3, y = 2, z = bz + 3, sx = 3, sy = 4, sz = 3, style = "appliance", solid = true })
	piece(L, { x = bx - 2, y = 2, z = bz + 3, sx = 3, sy = 4, sz = 3, style = "appliance", solid = true })
	piece(L, {
		x = bx,
		y = height - 0.2,
		z = bz,
		sx = 5,
		sy = 0.2,
		sz = 1,
		style = "panel_blue",
		collide = false,
		lamp = "blue",
	})
	Pieces.kitProp(L, "stairs_to_wall", ctx.cx, ctx.z0 + 13, 180)
	Pieces.kitProp(L, "doorway_blue", ctx.x1 - 9, ctx.z1 - 16, 0)
	item(ctx, "couch", ctx.x0 + 10, ctx.cz, 1, 0)
	lamp(ctx, ctx.cx, height - 1, ctx.cz, "dim")
end

-- c8: an L-shaped pool under a painted sky wall, two walls of little windows lit in odd colours
-- (some on the ceiling too), grass along the far end
function Sets.poolroom(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "plaster_white", nil, 1)
	piece(L, {
		x = ctx.cx,
		y = ctx.h / 2,
		z = ctx.z0 + 1.2,
		sx = ctx.w - 2,
		sy = ctx.h - 1,
		sz = 0.2,
		style = "sky",
		paint = "sky",
		collide = false,
	})
	Pieces.ceiling(L, ctx.room, ctx.h, "night_ceiling")
	Pieces.floor(L, ctx.room, "tile_cream")
	local px0, px1 = ctx.x0 + ctx.w * 0.15, ctx.x0 + ctx.w * 0.6
	local pz0, pz1 = ctx.z0 + ctx.d * 0.2, ctx.z0 + ctx.d * 0.75
	piece(L, {
		x = (px0 + px1) / 2,
		y = 0.7,
		z = (pz0 + pz1) / 2,
		sx = px1 - px0,
		sy = 1.2,
		sz = pz1 - pz0,
		style = "water",
		collide = false,
	})
	piece(L, {
		x = (px1 + ctx.x1 - 8) / 2,
		y = 0.7,
		z = pz0 + 8,
		sx = ctx.x1 - 8 - px1,
		sy = 1.2,
		sz = 16,
		style = "water",
		collide = false,
	})
	Pieces.floor(
		L,
		{ x0 = ctx.x0 + 1, x1 = ctx.x1 - 1, z0 = ctx.z0 + 2, z1 = ctx.z0 + ctx.d * 0.12 },
		"grass",
		0.14
	)
	Pieces.windowGrid(L, rng, ctx.x0 + 3, ctx.x1 - 3, ctx.z1 - 1.2, -1, 3, ctx.h - 3)
	for _ = 1, 10 do
		piece(L, {
			x = rng:range(ctx.x0 + 4, ctx.x1 - 4),
			y = ctx.h - 0.05,
			z = rng:range(ctx.z0 + 4, ctx.z1 - 4),
			sx = 1.6,
			sy = 0.1,
			sz = 1.6,
			style = "window_lit",
			collide = false,
		})
	end
	lamp(ctx, ctx.cx, 5, ctx.z0 + 6, "sky")
	item(ctx, "armchair", ctx.x1 - 6, ctx.z1 - 6, -1, -1)
end

-- c9: a dead mall. Shuttered storefronts on both sides, a carpet runner, and at the far end a wall of
-- light that looks like the way out and isn't. One shop is open: a tiny room with a TV glowing.
function Sets.dead_mall(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	local height = 16
	walls(ctx, height, "plaster_cream", nil, 1)
	Pieces.ceiling(L, ctx.room, height, "drop_ceiling")
	Pieces.floor(L, ctx.room, "tile_cream")
	piece(L, {
		x = ctx.cx,
		y = 0.16,
		z = ctx.cz,
		sx = ctx.w - 2,
		sy = 0.1,
		sz = ctx.d * 0.3,
		style = "carpet_dark",
	})
	local open = rng:int(1, 4)
	local n = 0
	for x = ctx.x0 + 10, ctx.x1 - 14, 16 do
		n += 1
		for _, side in { -1, 1 } do
			local z = if side < 0 then ctx.z0 + 1.2 else ctx.z1 - 1.2
			if not (side < 0 and n == open) then
				piece(L, {
					x = x,
					y = 5,
					z = z,
					sx = 12,
					sy = 9,
					sz = 0.3,
					style = "grate",
					collide = false,
					skipIfKit = "shutter_front",
				})
				Pieces.kitProp(L, "shutter_front", x, z - side * 0.5, if side < 0 then 0 else 180)
				piece(L, {
					x = x,
					y = 4.5,
					z = z + side * 0.5,
					sx = 11.6,
					sy = 8.6,
					sz = 0.1,
					style = "void",
					collide = false,
					skipIfKit = "shutter_front",
				})
			else
				piece(
					L,
					{ x = x, y = 2, z = z + 2, sx = 3, sy = 2.4, sz = 2, style = "tv_glow", lamp = "tv" }
				)
			end
			piece(L, {
				x = x,
				y = 11,
				z = z,
				sx = 14,
				sy = 2.4,
				sz = 0.6,
				style = "store_band",
				label = rng:pick(ctx.config.StoreNames),
				skipIfKit = "shutter_front",
			})
		end
		piece(L, {
			x = x,
			y = height - 0.15,
			z = ctx.cz,
			sx = 3,
			sy = 0.2,
			sz = 8,
			style = "panel",
			collide = false,
			lamp = if n % 2 == 0 then "panel" else nil,
		})
	end
	piece(L, {
		x = ctx.x1 - 1.4,
		y = height / 2,
		z = ctx.cz,
		sx = 0.3,
		sy = height - 1,
		sz = ctx.d * 0.5,
		style = "exit_glow",
		lamp = "glare",
	})
	piece(L, {
		x = ctx.cx + 6,
		y = 1.2,
		z = ctx.cz + 3,
		sx = 2.4,
		sy = 2.4,
		sz = 2.4,
		style = "stack",
		solid = true,
	})
	Pieces.kitProp(L, "mall_kiosk", ctx.cx - 18, ctx.cz, 90)
	Pieces.kitProp(L, "mall_planter", ctx.cx + 22, ctx.cz, 0)
	Pieces.kitProp(L, "mall_planter", ctx.x0 + 16, ctx.cz, 0)
	item(ctx, "crt_tv", ctx.x0 + 10, ctx.z0 + 6, 0, 1)
end

-- light_grid is laid out in walk-in terms from its doorway: u is how far in from the doorway wall,
-- p is the position along that wall. box() places a piece from those terms.
type WalkFrame = {
	depth: number,
	pMin: number,
	pMax: number,
	pDoor: number,
	at: (u: number, p: number) -> (number, number),
	facing: (du: number, dp: number) -> (number, number),
	box: (u: number, p: number, su: number, sp: number, spec: any) -> any,
	lane: (p: number, pad: number) -> number,
}

local function walkFrame(ctx: Ctx): WalkFrame
	local door = ctx.room.doors[1]
	local across = door.side == "north" or door.side == "south"
	local flip = if door.side == "south" or door.side == "east" then -1 else 1
	local wall = if across
		then (if flip > 0 then ctx.z0 else ctx.z1)
		else (if flip > 0 then ctx.x0 else ctx.x1)
	local pMin = if across then ctx.x0 else ctx.z0
	local pMax = if across then ctx.x1 else ctx.z1
	local function at(u: number, p: number): (number, number)
		if across then
			return p, wall + flip * u
		end
		return wall + flip * u, p
	end
	local function facing(du: number, dp: number): (number, number)
		if across then
			return dp, flip * du
		end
		return flip * du, dp
	end
	local function box(u: number, p: number, su: number, sp: number, spec: any)
		spec.x, spec.z = at(u, p)
		spec.sx = if across then sp else su
		spec.sz = if across then su else sp
		return piece(ctx.layout, spec)
	end
	local function lane(p: number, pad: number): number
		return math.clamp(p, pMin + pad, pMax - pad)
	end
	return {
		depth = if across then ctx.d else ctx.w,
		pMin = pMin,
		pMax = pMax,
		pDoor = pMin + door.at,
		at = at,
		facing = facing,
		box = box,
		lane = lane,
	}
end

-- A door frame of three bars facing down the hall; lift raises it off the floor
local function lightGridFrame(f: WalkFrame, u: number, p: number, lift: number)
	f.box(u, p, 0.5, 4.4, { y = lift + 7.4, sy = 0.5, style = "door_frame" })
	for _, side in { -2, 2 } do
		f.box(u, p + side, 0.5, 0.4, { y = lift + 3.6, sy = 7.2, style = "door_frame" })
	end
end

-- c10: megalophobia with a goal. A vast flooded hall under a ceiling of glowing squares. From the
-- doorway you see one thing: a lit island far out in the black water, a little living room under a
-- column of light, robots keeping its chest. A narrow tile walkway jogs out toward it, breaks into
-- stepping stones under lights that blink as you pass, and joins up again for the last stretch.
-- Everything else is cover, or wrong.
function Sets.light_grid(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "tile_white", nil, 1, 6)
	Pieces.ceiling(L, ctx.room, ctx.h, "void")
	Pieces.floor(L, ctx.room, "tile_dark")
	local f = walkFrame(ctx)
	local depth, span = f.depth, f.pMax - f.pMin
	local center = (f.pMin + f.pMax) / 2
	-- side: which way along the doorway wall the island sits; most things mirror off it
	local side = if f.pDoor < center then 1 else -1
	local isle = math.clamp(math.floor(math.min(depth, span) * 0.16), 16, 26)
	local uI = depth - isle / 2 - 7
	local pI = f.lane(center + side * span * 0.1, isle / 2 + 6)
	local uA, uB, uC = depth * 0.3, depth * 0.55, uI - isle / 2
	local waterTop = 0.6

	-- The water: shin deep and black everywhere but the island
	local function water(u0: number, u1: number, p0: number, p1: number)
		if u1 - u0 > 0.5 and p1 - p0 > 0.5 then
			f.box((u0 + u1) / 2, (p0 + p1) / 2, u1 - u0, p1 - p0, {
				y = (waterTop + 0.1) / 2,
				sy = waterTop - 0.1,
				style = "water_dark",
				collide = false,
			})
		end
	end
	water(1, uC, f.pMin + 1, f.pMax - 1)
	water(uI + isle / 2, depth - 1, f.pMin + 1, f.pMax - 1)
	water(uC, uI + isle / 2, f.pMin + 1, pI - isle / 2)
	water(uC, uI + isle / 2, pI + isle / 2, f.pMax - 1)

	-- The ceiling: squares of light with dark seams. Over the stepping stones they blink as you
	-- come near; one square is missing where the ladder goes up.
	local rows = math.clamp(math.round(depth / 20), 6, 9)
	local cols = math.clamp(math.round(span / 20), 6, 9)
	local cu, cp = depth / rows, span / cols
	local ladderRow = math.clamp(math.floor(uA / cu) + 1, 1, rows)
	local ladderCol = math.clamp(math.floor((pI - side * span * 0.32 - f.pMin) / cp) + 1, 1, cols)
	local n = 0
	for row = 1, rows do
		for col = 1, cols do
			local u, p = (row - 0.5) * cu, f.pMin + (col - 0.5) * cp
			local blink = u > uA and u < uB and math.abs(p - pI) < cp
			if not (row == ladderRow and col == ladderCol) then
				n += 1
				f.box(u, p, cu - 1.6, cp - 1.6, {
					y = ctx.h - 0.12,
					sy = 0.2,
					style = "panel",
					collide = false,
					lamp = if blink or n % 8 == 0 then "panel" else nil,
					flicker = if blink then true else nil,
				})
			end
		end
	end
	local uL, pL = (ladderRow - 0.5) * cu, f.pMin + (ladderCol - 0.5) * cp
	for _, rail in { -0.9, 0.9 } do
		f.box(uL, pL + rail, 0.3, 0.25, { y = ctx.h / 2, sy = ctx.h, style = "ladder", collide = false })
	end
	for y = 1.5, ctx.h - 1, 3 do
		f.box(uL, pL, 0.25, 1.8, { y = y, sy = 0.15, style = "ladder", collide = false })
	end

	-- The way out: walkway, a jog, stepping stones, walkway again, lit all along
	local function path(u: number, p: number, su: number, sp: number)
		f.box(u, p, su, sp, { y = 0.5, sy = 1, style = "tile_white" })
	end
	path((1 + uA) / 2, f.pDoor, uA - 1, 2.6)
	if math.abs(pI - f.pDoor) > 2.6 then
		path(uA, (f.pDoor + pI) / 2, 2.6, math.abs(pI - f.pDoor) + 2.6)
	end
	for u = uA + 4, uB - 2, 5 do
		path(u, pI + rng:range(-0.6, 0.6), 3, 3)
	end
	path((uB + uC) / 2, pI, uC - uB, 2.6)
	for _, stop in { { depth * 0.15, f.pDoor }, { (uA + uB) / 2, pI }, { (uB + uC) / 2, pI } } do
		local x, z = f.at(stop[1], stop[2])
		lamp(ctx, x, 10, z, "panel")
	end

	-- The island: a dry floor with a curb, open where the walkway lands, under a column of light
	f.box(uI, pI, isle, isle, { y = 0.175, sy = 0.35, style = "carpet_blue" })
	f.box(uI + isle / 2, pI, 0.6, isle + 0.6, { y = 0.4, sy = 0.8, style = "tile_white" })
	for _, edge in { -1, 1 } do
		f.box(uI, pI + edge * isle / 2, isle, 0.6, { y = 0.4, sy = 0.8, style = "tile_white" })
		f.box(uC, pI + edge * (isle / 4 + 1), 0.6, isle / 2 - 2, { y = 0.4, sy = 0.8, style = "tile_white" })
	end
	f.box(
		uI,
		pI,
		isle * 0.7,
		isle * 0.7,
		{ y = ctx.h / 2, sy = ctx.h - 1, style = "haze_ray", collide = false }
	)
	for _, edge in { -1, 1 } do
		local x, z = f.at(uI, pI + edge * isle / 4)
		lamp(ctx, x, 12, z, "panel")
	end
	local function furnish(name: string, u: number, p: number, du: number, dp: number)
		local x, z = f.at(u, p)
		local nx, nz = f.facing(du, dp)
		item(ctx, name, x, z, nx, nz)
	end
	-- The prize chest sits deepest, facing the way in, so loot and the robots' stash land on the island
	local back, rim = uI + isle / 2 - 3, isle / 2 - 3
	furnish("toy_chest", back, pI, -1, 0)
	furnish("armchair", uI, pI - rim, 0, 1)
	furnish("crt_tv", uI, pI + rim, 0, -1)
	furnish("floor_lamp", back, pI - rim, -1, 0)
	for p = pI - 3, pI + 3, 2 do
		local x, z = f.at(uI - 2, p)
		Pieces.loose(L, rng:pick(ctx.config.InstallationFill.HumanStuff), x, z, 0)
	end

	-- Cover along the way: crates, pillars, a shelf on its side, a cubicle, a door frame in the air
	for _, stack in
		{ { 0.18, f.pDoor - side * 9, 3 }, { 0.4, pI - side * 7, 2 }, { 0.64, pI + side * 10, 4 } }
	do
		local x, z = f.at(depth * stack[1], f.lane(stack[2], 5))
		Pieces.junkStack(L, rng, x, z, stack[3], stack[3] > 3)
	end
	for _, spot in
		{
			{ 0.25, f.pDoor + side * 14 },
			{ 0.25, f.pDoor - side * 16 },
			{ 0.72, pI - side * 15 },
			{ 0.72, pI + side * 17 },
		}
	do
		f.box(
			depth * spot[1],
			f.lane(spot[2], 4),
			3.5,
			3.5,
			{ y = ctx.h / 2, sy = ctx.h, style = "tile_white", solid = true }
		)
	end
	local uS, pS = depth * 0.47, f.lane(pI + side * 9, 6)
	for _, y in { 0.2, 2.3 } do
		f.box(uS + 1.1, pS, 0.4, 9, { y = y, sy = 0.3, style = "rack_upright" })
	end
	for _, board in { -4.2, -1.4, 1.4, 4.2 } do
		f.box(uS, pS + board, 2.4, 0.3, { y = 1.2, sy = 2.4, style = "wood_shelf", solid = true })
	end
	local uK, pK = depth * 0.45, f.lane(pI - side * 18, 8)
	f.box(uK + 4, pK, 0.4, 8, { y = 2.5, sy = 5, style = "office_wall", solid = true })
	for _, edge in { -4, 4 } do
		f.box(uK, pK + edge, 8, 0.4, { y = 2.5, sy = 5, style = "office_wall", solid = true })
	end
	furnish("desk", uK + 2.2, pK, -1, 0)
	furnish("office_chair", uK - 0.2, pK, 1, 0)
	lightGridFrame(f, depth * 0.52, f.lane(pI + side * 5, 4), 1.6)

	-- Wrong things: a chair facing the wall, a desk phone out in the water blinking like it rings,
	-- a doorway full of light with nothing behind it, a reflection of someone who isn't there
	local wallP = if side > 0 then f.pMax - 3 else f.pMin + 3
	local uO = depth * 0.6
	f.box(uO, wallP, 1.6, 1.6, { y = 0.15, sy = 0.2, style = "chair_grey" })
	f.box(uO, wallP, 0.3, 0.3, { y = 0.9, sy = 1.3, style = "chair_grey" })
	f.box(uO, wallP, 1.7, 1.7, { y = 1.7, sy = 0.3, style = "chair_grey" })
	f.box(uO, wallP - side * 0.75, 1.7, 0.3, { y = 2.9, sy = 2.1, style = "chair_grey" })
	furnish("vending_machine", depth * 0.35, wallP, 0, -side)
	local uP, pP = depth * 0.14, f.lane(f.pDoor + side * 9, 4)
	f.box(uP, pP, 2, 3.6, { y = 2.6, sy = 0.2, style = "wood" })
	for _, edge in { -1.6, 1.6 } do
		f.box(uP, pP + edge, 1.8, 0.2, { y = 1.25, sy = 2.5, style = "wood", collide = false })
	end
	f.box(uP, pP + 0.6, 1, 1.2, { y = 2.95, sy = 0.5, style = "phone_beige", collide = false })
	f.box(uP, pP + 0.6, 0.3, 0.3, {
		y = 3.3,
		sy = 0.2,
		style = "neon_yellow",
		collide = false,
		lamp = "tv",
		flicker = true,
	})
	local uD, pD = depth * 0.58, f.lane(pI - side * span * 0.38, 5)
	lightGridFrame(f, uD, pD, 0)
	f.box(uD, pD, 0.1, 3.6, { y = 3.6, sy = 7.2, style = "exit_glow", collide = false })
	f.box(depth * 0.2, f.pDoor + 2.4, 0.6, 1.8, {
		y = waterTop + 0.02,
		sy = 0.02,
		style = "silhouette",
		collide = false,
	})
end

-- c11: yellow. Yellow walls in a maze that doesn't make sense, olive patterned carpet, buzzing
-- strip lights in a low ceiling, and one vending machine glowing at the end of a corridor
function Sets.backroom(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	local height = 9
	walls(ctx, height, "wall_mono_yellow", nil, 2)
	Pieces.ceiling(L, ctx.room, height, "ceiling_yellow")
	Pieces.floor(L, ctx.room, "carpet_olive", nil, nil, "carpet_office")
	for _ = 1, 14 do
		local horizontal = rng:next() < 0.5
		local len = rng:range(10, 30)
		piece(L, {
			x = rng:range(ctx.x0 + 8, ctx.x1 - 8),
			y = height / 2,
			z = rng:range(ctx.z0 + 8, ctx.z1 - 8),
			sx = if horizontal then len else 0.8,
			sy = height,
			sz = if horizontal then 0.8 else len,
			style = "wall_mono_yellow",
			solid = true,
		})
	end
	for gx = ctx.x0 + 8, ctx.x1 - 8, 16 do
		for gz = ctx.z0 + 8, ctx.z1 - 8, 12 do
			piece(L, {
				x = gx,
				y = height - 0.12,
				z = gz,
				sx = 6,
				sy = 0.2,
				sz = 1,
				style = "panel_yellow",
				collide = false,
				lamp = if rng:next() < 0.25 then "yellow" else nil,
			})
		end
	end
	item(ctx, "vending_machine", ctx.x1 - 4, ctx.cz, -1, 0)
end

-- c12: a long hall, lime green curved walls bulging along one side, blue carpet, blue doors that
-- are painted on, a perspective line of ceiling panels, one small orange chair in the middle,
-- and the same chair at the far end, thirty studs tall.
function Sets.green_hall(ctx: Ctx)
	local L = ctx.layout
	local height = 14
	walls(ctx, height, "plaster_white", nil, 1)
	Pieces.ceiling(L, ctx.room, height, "plaster_white")
	Pieces.floor(L, ctx.room, "carpet_blue_bright", nil, nil, "floor_carpet_blue")
	local alongX = ctx.w >= ctx.d
	local count = 5
	for n = 0, count - 1 do
		local t = (n + 0.5) / count
		if alongX then
			piece(L, {
				shape = "cylinder",
				x = ctx.x0 + t * ctx.w,
				y = height / 2,
				z = ctx.z0 + 4,
				sx = 10,
				sy = height,
				sz = 10,
				style = "lime",
				solid = true,
			})
			piece(L, {
				x = ctx.x0 + t * ctx.w,
				y = 3.6,
				z = ctx.z1 - 1.2,
				sx = 3.4,
				sy = 7.2,
				sz = 0.2,
				style = "door_blue",
				collide = false,
			})
			piece(L, {
				x = ctx.x0 + t * ctx.w,
				y = height - 0.12,
				z = ctx.cz,
				sx = 4,
				sy = 0.2,
				sz = 2,
				style = "panel",
				collide = false,
				lamp = if n % 2 == 0 then "panel" else nil,
			})
		else
			piece(L, {
				shape = "cylinder",
				x = ctx.x0 + 4,
				y = height / 2,
				z = ctx.z0 + t * ctx.d,
				sx = 10,
				sy = height,
				sz = 10,
				style = "lime",
				solid = true,
			})
			piece(L, {
				x = ctx.x1 - 1.2,
				y = 3.6,
				z = ctx.z0 + t * ctx.d,
				sx = 0.2,
				sy = 7.2,
				sz = 3.4,
				style = "door_blue",
				collide = false,
			})
			piece(L, {
				x = ctx.cx,
				y = height - 0.12,
				z = ctx.z0 + t * ctx.d,
				sx = 2,
				sy = 0.2,
				sz = 4,
				style = "panel",
				collide = false,
				lamp = if n % 2 == 0 then "panel" else nil,
			})
		end
	end
	local function chair(x: number, z: number, scale: number)
		local seat = 1.6 * scale
		local swap = if scale > 2 then "giant_chair" else nil
		if swap then
			Pieces.kitProp(L, swap, x, z, 180)
		end
		piece(L, {
			x = x,
			y = seat,
			z = z,
			sx = 1.8 * scale,
			sy = 0.25 * scale,
			sz = 1.8 * scale,
			style = "chair_orange",
			solid = scale > 2,
			skipIfKit = swap,
		})
		piece(L, {
			x = x,
			y = seat + 1.1 * scale,
			z = z + 0.85 * scale,
			sx = 1.8 * scale,
			sy = 1.6 * scale,
			sz = 0.2 * scale,
			style = "chair_orange",
			skipIfKit = swap,
		})
		for _, lx in { -0.75, 0.75 } do
			for _, lz in { -0.75, 0.75 } do
				piece(L, {
					x = x + lx * scale,
					y = seat / 2,
					z = z + lz * scale,
					sx = 0.12 * scale,
					sy = seat,
					sz = 0.12 * scale,
					style = "rail",
					collide = scale > 2,
					skipIfKit = swap,
				})
			end
		end
	end
	chair(ctx.cx, ctx.cz, 1)
	if alongX then
		chair(ctx.x1 - 10, ctx.cz, math.min(7, (height - 1) / 3.6))
	else
		chair(ctx.cx, ctx.z1 - 10, math.min(7, (height - 1) / 3.6))
	end
	item(ctx, "filing_cabinet", ctx.x0 + 12, ctx.z1 - 4, 0, -1)
end

-- c13: pastel houses packed together under a purple painted sky, narrow grass alleys between
-- them, windows and no doors, low sun from one side, a puddle. One house is far too tall.
function Sets.pastel_houses(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "dusk", "dusk", 1, 10)
	Pieces.ceiling(L, ctx.room, ctx.h, "dusk", "dusk")
	Pieces.floor(L, ctx.room, "grass")
	local styles = { "stucco_pink", "stucco_yellow", "stucco_peach" }
	local tall = rng:int(1, 4)
	for n = 1, 4 do
		local hx = ctx.x0 + n * ctx.w / 5
		local hz = ctx.z0 + ctx.d * (if n % 2 == 0 then 0.32 else 0.6)
		local hh = if n == tall then ctx.h - 8 else 10
		piece(L, {
			x = hx,
			y = hh / 2,
			z = hz,
			sx = ctx.w / 6,
			sy = hh,
			sz = 18,
			style = styles[(n - 1) % 3 + 1],
			solid = true,
		})
		piece(L, { x = hx, y = hh + 0.4, z = hz, sx = ctx.w / 6 + 1.6, sy = 0.8, sz = 19.6, style = "roof" })
		for k = 0, math.floor(hh / 8) - 1 do
			piece(L, {
				x = hx,
				y = 5 + k * 8,
				z = hz + 9.05,
				sx = 2.4,
				sy = 2.4,
				sz = 0.1,
				style = "window_black",
				collide = false,
			})
		end
	end
	piece(
		L,
		{ x = ctx.cx, y = 0.16, z = ctx.z1 - 10, sx = 8, sy = 0.05, sz = 3, style = "wet", collide = false }
	)
	lamp(ctx, ctx.x0 + 4, 14, ctx.cz, "dusk_sun")
	item(ctx, "leak_bucket", ctx.cx + 4, ctx.z1 - 6, 0, -1)
end

-- c14: green carpet, a long pink bench, heavy blue curtains hanging in folds, and a short stair up
-- to a black window. The moon is in the window, and the moon is inside the room.
function Sets.curtain_room(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	local height = 13
	walls(ctx, height, "plaster_grey", nil, 1)
	Pieces.ceiling(L, ctx.room, height, "night_ceiling")
	Pieces.floor(L, ctx.room, "carpet_green")
	for n = 0, 2 do
		local x = ctx.x0 + (n + 1) * ctx.w / 4
		for fold = 0, 6 do
			piece(L, {
				x = x + rng:range(-0.4, 0.4),
				y = height / 2,
				z = ctx.z0 + 6 + fold * 2.2,
				sx = 0.6,
				sy = height - 0.4,
				sz = 2.6,
				turn = if fold % 2 == 0 then 18 else -18,
				style = "curtain_blue",
				solid = fold == 0,
				skipIfKit = "curtains",
			})
		end
		Pieces.kitProp(L, "curtains", x, ctx.z0 + 12.6, 90)
	end
	piece(L, {
		x = ctx.cx,
		y = 1,
		z = ctx.z1 - 3,
		sx = ctx.w * 0.5,
		sy = 1.2,
		sz = 2.4,
		style = "bench_pink",
		solid = true,
		skipIfKit = "pink_bench",
	})
	for bx = ctx.cx - ctx.w * 0.2, ctx.cx + ctx.w * 0.2, 8.4 do
		Pieces.kitProp(L, "pink_bench", bx, ctx.z1 - 2.6, 180)
	end
	piece(L, {
		x = ctx.cx,
		y = 2.4,
		z = ctx.z1 - 1.8,
		sx = ctx.w * 0.5,
		sy = 2,
		sz = 0.6,
		style = "bench_pink",
		skipIfKit = "pink_bench",
	})
	for s = 0, 3 do
		piece(L, {
			x = ctx.x1 - 8,
			y = 0.5 + s * 0.5,
			z = ctx.cz - s * 1.4,
			sx = 6,
			sy = 1 + s,
			sz = 1.4,
			style = "carpet_beige",
			solid = s == 0,
		})
	end
	piece(L, {
		x = ctx.x1 - 8,
		y = 6.5,
		z = ctx.cz - 6.5,
		sx = 4,
		sy = 4,
		sz = 0.2,
		style = "window_black",
		collide = false,
		skipIfKit = "moon_window",
	})
	Pieces.kitProp(L, "moon_window", ctx.x1 - 8, ctx.cz - 6.5, 0, 4.8)
	piece(L, {
		shape = "ball",
		x = ctx.x1 - 8,
		y = 7,
		z = ctx.cz - 6.3,
		sx = 0.9,
		sy = 0.9,
		sz = 0.9,
		style = "moon",
		collide = false,
	})
	piece(L, {
		shape = "ball",
		x = ctx.cx - 6,
		y = 9,
		z = ctx.cz + 2,
		sx = 2.2,
		sy = 2.2,
		sz = 2.2,
		style = "moon",
		collide = false,
		lamp = "moon",
	})
	item(ctx, "floor_lamp", ctx.x0 + 4, ctx.z1 - 4, 1, -1)
end

-- c15: a store with a grass floor. Rows of empty wooden shelves under a drop ceiling, cream pillars,
-- a curved counter, a sign on the far wall, and the shelves grow taller the further back you go.
function Sets.grass_store(ctx: Ctx)
	local L = ctx.layout
	local height = 18
	walls(ctx, height, "cream_wall", nil, 1)
	Pieces.ceiling(L, ctx.room, height, "drop_ceiling")
	Pieces.floor(L, ctx.room, "grass", nil, nil, "floor_grass")
	piece(L, {
		x = ctx.cx,
		y = 12,
		z = ctx.z0 + 1.3,
		sx = 16,
		sy = 2,
		sz = 0.2,
		style = "cream_wall",
		label = "THE END",
		collide = false,
	})
	local rows = 6
	for r = 0, rows - 1 do
		local z = ctx.z1 - 14 - r * ((ctx.d - 24) / rows)
		local tall = 5 + r * 2
		for x = ctx.x0 + 10, ctx.x1 - 10, 14 do
			piece(
				L,
				{ x = x, y = tall / 2, z = z, sx = 10, sy = tall, sz = 2, style = "wood_shelf", solid = true }
			)
			for k = 1, math.floor(tall / 2.5) - 1 do
				piece(L, {
					x = x,
					y = k * 2.5,
					z = z - 1.05,
					sx = 9.6,
					sy = 0.2,
					sz = 0.1,
					style = "wood_dark",
					collide = false,
				})
			end
		end
	end
	for _, px in { ctx.x0 + ctx.w * 0.25, ctx.x0 + ctx.w * 0.75 } do
		piece(L, {
			x = px,
			y = height / 2,
			z = ctx.cz,
			sx = 3,
			sy = height,
			sz = 3,
			style = "pillar_cream",
			solid = true,
		})
	end
	piece(L, {
		shape = "cylinder",
		x = ctx.x0 + 10,
		y = 1.8,
		z = ctx.z1 - 8,
		sx = 10,
		sy = 3.6,
		sz = 10,
		style = "wood_shelf",
		solid = true,
	})
	Pieces.panelGrid(L, inner(ctx, 2), height, 12, 4, "panel_warm", 3)
	Pieces.kitProp(L, "reading_desk", ctx.cx, ctx.z1 - 10, 180)
	item(ctx, "bookshelf", ctx.x1 - 5, ctx.z1 - 5, -1, -1)
end

-- c16: a night courtyard boxed in by four towering walls of small windows, some glowing warm, some
-- teal, under a painted cloudy night sky. Lawns, paths, one bench, a lit doorway nobody comes out of.
function Sets.window_court(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "plaster_grey", nil, 1)
	Pieces.ceiling(L, ctx.room, ctx.h, "night_sky", "night")
	Pieces.floor(L, ctx.room, "paving")
	Pieces.windowGrid(L, rng, ctx.x0 + 3, ctx.x1 - 3, ctx.z0 + 1.2, 1, 4, ctx.h - 4)
	Pieces.windowGrid(L, rng, ctx.x0 + 3, ctx.x1 - 3, ctx.z1 - 1.2, -1, 4, ctx.h - 4)
	for i = 0, 1 do
		for j = 0, 1 do
			Pieces.floor(L, {
				x0 = ctx.x0 + ctx.w * (0.1 + i * 0.47),
				x1 = ctx.x0 + ctx.w * (0.43 + i * 0.47),
				z0 = ctx.z0 + ctx.d * (0.14 + j * 0.42),
				z1 = ctx.z0 + ctx.d * (0.44 + j * 0.42),
			}, "grass", 0.14)
		end
	end
	piece(
		L,
		{ x = ctx.cx, y = 0.8, z = ctx.cz, sx = 5, sy = 0.4, sz = 1.4, style = "bench_stone", solid = true }
	)
	piece(L, {
		x = ctx.x1 - 12,
		y = 3.6,
		z = ctx.z0 + 1.3,
		sx = 3.4,
		sy = 7.2,
		sz = 0.2,
		style = "exit_glow",
		collide = false,
		lamp = "warm",
	})
	item(ctx, "survivor_tent", ctx.x0 + 10, ctx.z1 - 10, 0, -1)
	-- Courtyard lamps on the path corners between the lawns, each with a bench under it
	for _, fx in { 0.45, 0.55 } do
		for _, fz in { 0.44, 0.56 } do
			local x, z = ctx.x0 + ctx.w * fx, ctx.z0 + ctx.d * fz
			piece(L, { x = x, y = 3, z = z, sx = 0.4, sy = 6, sz = 0.4, style = "cable", solid = true })
			lamp(ctx, x, 6.4, z, "street")
		end
	end
	for _, fx in { 0.27, 0.73 } do
		for _, fz in { 0.1, 0.9 } do
			piece(L, {
				x = ctx.x0 + ctx.w * fx,
				y = 0.8,
				z = ctx.z0 + ctx.d * fz,
				sx = 5,
				sy = 0.4,
				sz = 1.4,
				style = "bench_stone",
				solid = true,
			})
		end
	end
end

-- Catwalk Void: no floor at all, just black far below. A narrow catwalk with railings runs out
-- over the drop under an endless grid of panels and ends in mid air, with a drinks machine
-- standing at the very end.
function Sets.catwalk_void(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "dark_wall", nil, 1, 6)
	Pieces.ceiling(L, ctx.room, ctx.h, "tile_white")
	piece(L, {
		x = ctx.cx,
		y = 0.08,
		z = ctx.cz,
		sx = ctx.w - 2,
		sy = 0.06,
		sz = ctx.d - 2,
		style = "void",
		collide = false,
	})
	local door = ctx.room.doors[1]
	local alongX = door.side == "west" or door.side == "east"
	local length = (if alongX then ctx.w else ctx.d) * 0.62
	local y = 6
	local x, z, sx, sz
	if alongX then
		x = if door.side == "west" then ctx.x0 + length / 2 else ctx.x1 - length / 2
		z, sx, sz = ctx.z0 + door.at, length, 3
	else
		z = if door.side == "north" then ctx.z0 + length / 2 else ctx.z1 - length / 2
		x, sx, sz = ctx.x0 + door.at, 3, length
	end
	-- Steps up from the doorway to the walkway, then the walkway itself with rails and edge glow
	piece(L, {
		x = x,
		y = y / 2,
		z = z,
		sx = sx,
		sy = y,
		sz = sz,
		style = "dark_wall",
		collide = false,
		skipIfKit = "catwalk",
	})
	piece(L, { x = x, y = y + 0.1, z = z, sx = sx, sy = 0.2, sz = sz, style = "grate", solid = true })
	for _, side in { -1, 1 } do
		local rx = if alongX then x else x + side * 1.5
		local rz = if alongX then z + side * 1.5 else z
		piece(L, {
			x = rx,
			y = y + 2.4,
			z = rz,
			sx = if alongX then sx else 0.15,
			sy = 0.15,
			sz = if alongX then 0.15 else sz,
			style = "rail",
			collide = false,
		})
		piece(L, {
			x = rx,
			y = y + 0.25,
			z = rz,
			sx = if alongX then sx else 0.1,
			sy = 0.1,
			sz = if alongX then 0.1 else sz,
			style = "neon_blue",
			collide = false,
		})
	end
	Pieces.kitProp(L, "catwalk", x, z, if alongX then 90 else 0, y)
	-- The real floor under the walkway, painted black, so you can walk down there if you dare
	local endX = if alongX then (if door.side == "west" then ctx.x0 + length else ctx.x1 - length) else x
	local endZ = if alongX then z else (if door.side == "north" then ctx.z0 + length else ctx.z1 - length)
	piece(L, {
		x = endX,
		y = y + 2.6,
		z = endZ,
		sx = 2.4,
		sy = 5,
		sz = 2.4,
		style = "plastic_white",
		collide = false,
		skipIfKit = "vending_machine",
	})
	Pieces.kitProp(L, "vending_machine", endX, endZ, 0, y + 0.2)
	-- The prize sits on the walkway just short of the vending machine: the floor below is the void
	local outX = if alongX then (if door.side == "west" then 1 else -1) else 0
	local outZ = if alongX then 0 else (if door.side == "north" then 1 else -1)
	ctx.room.prizeHints = {
		{
			x = endX - outX * 4.5,
			z = endZ - outZ * 4.5,
			y = y + 0.2,
			turn = math.deg(math.atan2(-outX, -outZ)),
		},
	}
	piece(L, {
		x = endX,
		y = y + 3,
		z = endZ,
		sx = 0.5,
		sy = 0.5,
		sz = 0.5,
		style = "lamp_bulb",
		collide = false,
		lamp = "warm",
	})
	Pieces.panelGrid(L, inner(ctx, 1), ctx.h, 8, 3, "panel", 12)
	item(ctx, "office_chair", ctx.x0 + 4, ctx.z0 + 4, 1, 1)
end

-- Black Sun: a flat grid floor running off to a painted sky, flat blue daylight, and hung high in
-- the middle, a perfectly round black sun that gives off no light at all
function Sets.black_sun(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "sky", "sky", 1, 10)
	Pieces.ceiling(L, ctx.room, ctx.h, "sky", "sky")
	Pieces.floor(L, ctx.room, "plaster_white", nil, nil, "grid_floor")
	for x = ctx.x0 + 8, ctx.x1 - 8, 8 do
		piece(L, {
			x = x,
			y = 0.16,
			z = ctx.cz,
			sx = 0.15,
			sy = 0.02,
			sz = ctx.d - 4,
			style = "art_grey",
			collide = false,
			skipIfKit = "grid_floor",
		})
	end
	for z = ctx.z0 + 8, ctx.z1 - 8, 8 do
		piece(L, {
			x = ctx.cx,
			y = 0.16,
			z = z,
			sx = ctx.w - 4,
			sy = 0.02,
			sz = 0.15,
			style = "art_grey",
			collide = false,
			skipIfKit = "grid_floor",
		})
	end
	piece(L, {
		shape = "ball",
		x = ctx.cx,
		y = ctx.h * 0.7,
		z = ctx.cz,
		sx = 16,
		sy = 16,
		sz = 16,
		style = "void",
		collide = false,
		skipIfKit = "black_sun",
	})
	Pieces.kitProp(L, "black_sun", ctx.cx, ctx.cz, 0, ctx.h * 0.7 - 8)
	lamp(ctx, ctx.cx, ctx.h - 4, ctx.z0 + 10, "sky")
	lamp(ctx, ctx.cx, ctx.h - 4, ctx.z1 - 10, "sky")
	item(ctx, "kitchen_chair", ctx.cx, ctx.cz + 14, 0, -1)
end

-- Orb Dunes: soft sand in rolling dunes, a chrome orb resting on top, red light from one side and
-- blue from the other, and a line of footprints that stops dead in the middle
function Sets.orb_dunes(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "dark_wall", nil, 1)
	Pieces.floor(L, ctx.room, "sand", nil, nil, "sand_floor")
	for _ = 1, 7 do
		local r = rng:range(14, 30)
		piece(L, {
			shape = "ball",
			x = rng:range(ctx.x0 + r / 2, ctx.x1 - r / 2),
			y = -r * 0.36,
			z = rng:range(ctx.z0 + r / 2, ctx.z1 - r / 2),
			sx = r,
			sy = r,
			sz = r,
			style = "sand",
			collide = true,
		})
	end
	piece(L, {
		shape = "ball",
		x = ctx.cx,
		y = 4.6,
		z = ctx.cz,
		sx = 8,
		sy = 8,
		sz = 8,
		style = "chrome",
		solid = true,
		skipIfKit = "chrome_orb",
	})
	Pieces.kitProp(L, "chrome_orb", ctx.cx, ctx.cz, 0, 0.6)
	local fx, fz = ctx.x0 + 6, ctx.z1 - 6
	for n = 0, 14 do
		piece(L, {
			x = fx + n * 2.2,
			y = 0.13,
			z = fz - n * 1.4 + (n % 2) * 0.6,
			sx = 0.5,
			sy = 0.03,
			sz = 0.9,
			turn = -32,
			style = "sand_dark",
			collide = false,
		})
	end
	lamp(ctx, ctx.x0 + 3, 6, ctx.cz, "red_rim")
	lamp(ctx, ctx.x1 - 3, 6, ctx.cz, "blue_rim")
	item(ctx, "leak_bucket", ctx.x1 - 6, ctx.z0 + 6, -1, 1)
end

-- Night Lot: a parking lot at night inside a building. Painted bays, a night sky ceiling, orange
-- sodium lamps buzzing over rows of nothing, a cart corral and one cart left out in the open
function Sets.night_lot(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "night_sky", "night", 1, 12)
	Pieces.ceiling(L, ctx.room, ctx.h, "night_sky", "night")
	Pieces.floor(L, ctx.room, "asphalt", nil, nil, "parking_tile")
	for row = 0, 2 do
		local z = ctx.z0 + (row + 1) * ctx.d / 4
		for x = ctx.x0 + 6, ctx.x1 - 6, 9 do
			piece(L, {
				x = x,
				y = 0.16,
				z = z,
				sx = 0.3,
				sy = 0.02,
				sz = 14,
				style = "paint_white",
				collide = false,
				skipIfKit = "parking_tile",
			})
		end
	end
	for n = 0, 3 do
		local lx = ctx.x0 + (n + 0.5) * ctx.w / 4
		piece(L, {
			x = lx,
			y = 9,
			z = ctx.cz,
			sx = 0.6,
			sy = 18,
			sz = 0.6,
			style = "rail",
			solid = true,
			skipIfKit = "sodium_lamp",
		})
		Pieces.kitProp(L, "sodium_lamp", lx, ctx.cz, 0)
		piece(L, {
			x = lx,
			y = 17.6,
			z = ctx.cz,
			sx = 2.4,
			sy = 0.4,
			sz = 1.2,
			style = "sodium",
			collide = false,
			lamp = "sodium",
		})
	end
	Pieces.kitProp(L, "cart_corral", ctx.x1 - 12, ctx.z0 + 10, 90)
	item(ctx, "shopping_cart", ctx.cx + rng:range(-10, 10), ctx.cz + rng:range(4, 12), 0, 1)
end

-- Playground: mulch, a slide, a swing set with one swing wrapped round and round the bar, a fake
-- tree, a painted dusk sky, and the swings creaking with no wind
function Sets.playground(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "dusk", "dusk", 1, 10)
	Pieces.ceiling(L, ctx.room, ctx.h, "dusk", "dusk")
	Pieces.floor(L, ctx.room, "mulch", nil, nil, "mulch_tile")
	local sx, sz = ctx.cx - 12, ctx.cz
	piece(L, { x = sx, y = 6, z = sz, sx = 12, sy = 0.5, sz = 0.5, style = "rail", skipIfKit = "swing_set" })
	for _, dx in { -6, 6 } do
		piece(L, {
			x = sx + dx,
			y = 3,
			z = sz,
			sx = 0.4,
			sy = 6,
			sz = 0.4,
			style = "rail",
			solid = true,
			skipIfKit = "swing_set",
		})
	end
	piece(L, {
		x = sx - 2.5,
		y = 2,
		z = sz,
		sx = 1.6,
		sy = 0.2,
		sz = 0.8,
		style = "rubber",
		collide = false,
		skipIfKit = "swing_set",
	})
	piece(L, {
		x = sx + 2.5,
		y = 5.4,
		z = sz,
		sx = 1.6,
		sy = 0.2,
		sz = 0.8,
		style = "rubber",
		collide = false,
		skipIfKit = "swing_set",
	})
	Pieces.kitProp(L, "swing_set", sx, sz, 0)
	piece(L, {
		shape = "wedge",
		x = ctx.cx + 12,
		y = 2.5,
		z = ctx.cz,
		sx = 3,
		sy = 5,
		sz = 10,
		turn = 180,
		style = "slide_red",
		skipIfKit = "slide",
	})
	Pieces.kitProp(L, "slide", ctx.cx + 12, ctx.cz, 0)
	Pieces.kitProp(L, "fake_tree", ctx.x1 - 10, ctx.z0 + 10, 30)
	lamp(ctx, ctx.x0 + 8, ctx.h - 4, ctx.cz, "dusk_sun")
	item(ctx, "kid_ball", ctx.cx, ctx.cz + 10, 0, -1)
end

-- Stairs to Nowhere: grass, dusk, and a long flight of stairs climbing up out of the lawn into
-- empty air, with a door frame standing at the very top
function Sets.stairs_nowhere(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "dusk", "dusk", 1, 10)
	Pieces.ceiling(L, ctx.room, ctx.h, "dusk", "dusk")
	Pieces.floor(L, ctx.room, "grass", nil, nil, "turf_tile")
	local steps = math.floor((ctx.h - 14) / 1)
	local x0 = ctx.cx - steps * 0.6
	for s = 0, steps - 1 do
		piece(L, {
			x = x0 + s * 1.2,
			y = s + 0.5,
			z = ctx.cz,
			sx = 1.2,
			sy = 1,
			sz = 6,
			style = "concrete_step",
			solid = s == 0,
			skipIfKit = "stairs_nowhere",
		})
	end
	Pieces.kitProp(L, "stairs_nowhere", ctx.cx, ctx.cz, 90)
	local topX, topY = x0 + steps * 1.2, steps
	piece(L, { x = topX, y = topY + 7.4, z = ctx.cz, sx = 0.5, sy = 0.5, sz = 4.4, style = "door_frame" })
	piece(L, { x = topX, y = topY + 3.6, z = ctx.cz - 2, sx = 0.5, sy = 7.2, sz = 0.4, style = "door_frame" })
	piece(L, { x = topX, y = topY + 3.6, z = ctx.cz + 2, sx = 0.5, sy = 7.2, sz = 0.4, style = "door_frame" })
	piece(L, {
		x = topX + 0.3,
		y = topY + 3.6,
		z = ctx.cz,
		sx = 0.1,
		sy = 7,
		sz = 3.6,
		style = "exit_glow",
		collide = false,
		lamp = "warm",
	})
	lamp(ctx, ctx.x0 + 8, ctx.h - 4, ctx.z0 + 8, "dusk_sun")
	item(ctx, "leak_bucket", ctx.x0 + 6, ctx.z1 - 6, 1, -1)
end

-- Soft Play: padded floors and a padded corridor in bright colours, a mirror ball throwing sparkles,
-- one ball left in the middle of the floor, and silence where screaming kids should be
function Sets.soft_play(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, 12, "pad_blue", nil, 1)
	Pieces.ceiling(L, ctx.room, 12, "night_ceiling")
	Pieces.floor(L, ctx.room, "pad_red", nil, nil, "padded_floor")
	local colours = { "pad_red", "pad_blue", "pad_yellow", "pad_green" }
	for n = 0, 5 do
		local x = ctx.x0 + 8 + n * (ctx.w - 16) / 5
		piece(L, {
			x = x,
			y = 2,
			z = ctx.cz - 6,
			sx = 4,
			sy = 4,
			sz = 1.2,
			style = colours[n % 4 + 1],
			solid = true,
			skipIfKit = "padded_wall",
		})
		piece(L, {
			x = x,
			y = 2,
			z = ctx.cz + 6,
			sx = 4,
			sy = 4,
			sz = 1.2,
			style = colours[(n + 2) % 4 + 1],
			solid = true,
			skipIfKit = "padded_wall",
		})
		Pieces.kitProp(L, "padded_wall", x, ctx.cz - 6, 0)
		Pieces.kitProp(L, "padded_wall", x, ctx.cz + 6, 180)
	end
	for _ = 1, 30 do
		piece(L, {
			shape = "ball",
			x = rng:range(ctx.x0 + 3, ctx.x1 - 3),
			y = 0.5,
			z = rng:range(ctx.z0 + 3, ctx.z1 - 3),
			sx = 0.8,
			sy = 0.8,
			sz = 0.8,
			style = rng:pick(colours),
			collide = false,
		})
	end
	piece(L, {
		shape = "ball",
		x = ctx.cx,
		y = 10,
		z = ctx.cz,
		sx = 2,
		sy = 2,
		sz = 2,
		style = "chrome",
		collide = false,
		lamp = "disco",
		skipIfKit = "disco_ball",
	})
	Pieces.kitProp(L, "disco_ball", ctx.cx, ctx.cz, 0, 8.5)
	for _, c in { { -1, -1, "neon_pink" }, { 1, 1, "neon_blue" } } do
		piece(L, {
			shape = "cylinder",
			x = ctx.cx + c[1] * 14,
			y = 11.9,
			z = ctx.cz + c[2] * 8,
			sx = 1.4,
			sy = 0.15,
			sz = 1.4,
			style = c[3],
			collide = false,
			lamp = "warm",
		})
	end
	item(ctx, "kid_ball", ctx.cx + 3, ctx.cz + 2, 0, 1)
end

-- Floating Block: a lawn under a dark ceiling, and over it a block the size of a house hanging in
-- the air with nothing holding it up. One thin seam of cold light runs round its middle.
function Sets.floating_block(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "dark_wall", nil, 1, 10)
	Pieces.floor(L, ctx.room, "grass", nil, nil, "turf_tile")
	local size = math.min(ctx.w, ctx.d) * 0.4
	local y = ctx.h * 0.55
	piece(L, {
		x = ctx.cx,
		y = y,
		z = ctx.cz,
		sx = size,
		sy = size,
		sz = size,
		style = "monolith",
		collide = false,
		skipIfKit = "monolith",
	})
	piece(L, {
		x = ctx.cx,
		y = y,
		z = ctx.cz,
		sx = size + 0.1,
		sy = 0.25,
		sz = size + 0.1,
		style = "panel_blue",
		collide = false,
		lamp = "seam",
	})
	Pieces.kitProp(L, "monolith", ctx.cx, ctx.cz, 0, y - size / 2)
	-- Its shadow on the grass, though nothing is lighting it from above
	piece(L, {
		x = ctx.cx + 3,
		y = 0.2,
		z = ctx.cz + 3,
		sx = size,
		sy = 0.02,
		sz = size,
		style = "oil",
		collide = false,
	})
	item(ctx, "sleeping_bag", ctx.cx + size, ctx.cz + size * 0.8, 0, -1)
end

-- Grandma's Room: a rug, a couch, an armchair, a lamp, a fan turning slowly, framed pictures, and
-- the TV on with no cord. Every piece of furniture faces the wall.
function Sets.grandmas_room(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, 11, "wall_floral", nil, 1)
	Pieces.ceiling(L, ctx.room, 11, "plaster_cream")
	Pieces.floor(L, ctx.room, "carpet_red")
	item(ctx, "rug", ctx.cx, ctx.cz, 0, 1)
	item(ctx, "couch", ctx.cx, ctx.z0 + 6, 0, -1)
	item(ctx, "armchair", ctx.x0 + 6, ctx.cz, -1, 0)
	item(ctx, "crt_tv", ctx.x1 - 5, ctx.cz + 4, 1, 0)
	item(ctx, "floor_lamp", ctx.x0 + 4, ctx.z0 + 4, -1, -1)
	piece(L, {
		x = ctx.x1 - 3,
		y = 2,
		z = ctx.cz + 4,
		sx = 0.2,
		sy = 2,
		sz = 2.6,
		style = "tv_glow",
		collide = false,
		lamp = "tv",
	})
	lamp(ctx, ctx.x0 + 4, 5, ctx.z0 + 4, "warm")
	piece(L, {
		shape = "cylinder",
		x = ctx.cx,
		y = 10.6,
		z = ctx.cz,
		sx = 1,
		sy = 0.6,
		sz = 1,
		style = "wood_dark",
		collide = false,
		skipIfKit = "ceiling_fan",
	})
	piece(L, {
		x = ctx.cx,
		y = 10.2,
		z = ctx.cz,
		sx = 7,
		sy = 0.1,
		sz = 0.8,
		turn = 20,
		style = "wood_dark",
		collide = false,
		skipIfKit = "ceiling_fan",
	})
	piece(L, {
		x = ctx.cx,
		y = 10.2,
		z = ctx.cz,
		sx = 7,
		sy = 0.1,
		sz = 0.8,
		turn = 110,
		style = "wood_dark",
		collide = false,
		skipIfKit = "ceiling_fan",
	})
	Pieces.kitProp(L, "ceiling_fan", ctx.cx, ctx.cz, 0, 9)
	for n = 0, 2 do
		Pieces.kitProp(L, "picture_frame", ctx.x0 + 8 + n * 5, ctx.z1 - 1.4, 180, 5)
		piece(L, {
			x = ctx.x0 + 8 + n * 5,
			y = 6,
			z = ctx.z1 - 1.3,
			sx = 2.4,
			sy = 3,
			sz = 0.2,
			style = "frame",
			collide = false,
			skipIfKit = "picture_frame",
		})
	end
end

-- Giant Nursery: curtains, a moon in the window, a tiny bed and a tiny toy chest, and a rocking
-- horse taller than a house, rocked a little off true. A night light glows by the bed.
function Sets.giant_nursery(ctx: Ctx)
	local L = ctx.layout
	walls(ctx, ctx.h, "wall_nursery", nil, 1)
	Pieces.ceiling(L, ctx.room, ctx.h, "night_sky", "night")
	Pieces.floor(L, ctx.room, "wood")
	local hx, hz, scale = ctx.cx, ctx.cz, math.min(ctx.h / 8, 6)
	piece(L, {
		x = hx,
		y = 3.4 * scale,
		z = hz,
		sx = 1.4 * scale,
		sy = 1.4 * scale,
		sz = 3.6 * scale,
		turn = 8,
		style = "horse_cream",
		collide = false,
		skipIfKit = "rocking_horse_giant",
	})
	piece(L, {
		x = hx,
		y = 4.6 * scale,
		z = hz - 1.8 * scale,
		sx = 1 * scale,
		sy = 1.6 * scale,
		sz = 1.2 * scale,
		turn = 8,
		style = "horse_cream",
		collide = false,
		skipIfKit = "rocking_horse_giant",
	})
	piece(L, {
		x = hx,
		y = 1 * scale,
		z = hz,
		sx = 2 * scale,
		sy = 0.4 * scale,
		sz = 5 * scale,
		turn = 8,
		style = "wood_dark",
		solid = true,
		skipIfKit = "rocking_horse_giant",
	})
	Pieces.kitProp(L, "rocking_horse_giant", hx, hz, 8)
	item(ctx, "kid_bed", ctx.x1 - 6, ctx.z1 - 6, -1, -1)
	item(ctx, "toy_chest", ctx.x0 + 5, ctx.z1 - 5, 1, -1)
	Pieces.kitProp(L, "curtains", ctx.cx, ctx.z0 + 1.6, 0)
	Pieces.kitProp(L, "moon_window", ctx.cx, ctx.z0 + 1.4, 0, 8)
	piece(L, {
		shape = "ball",
		x = ctx.x1 - 4,
		y = 0.6,
		z = ctx.z1 - 9,
		sx = 0.8,
		sy = 0.8,
		sz = 0.8,
		style = "moon",
		collide = false,
		lamp = "moon",
	})
end

-- Hedge Maze: perfectly clipped hedges in a maze under ceiling sun panels, a flamingo on the lawn,
-- and no way out but the way you came
function Sets.hedge_maze(ctx: Ctx)
	local L, rng = ctx.layout, ctx.rng
	walls(ctx, ctx.h, "hedge", nil, 1)
	Pieces.floor(L, ctx.room, "grass", nil, nil, "turf_tile")
	local cell = 10
	for x = ctx.x0 + cell, ctx.x1 - cell, cell do
		for z = ctx.z0 + cell, ctx.z1 - cell, cell do
			if rng:next() < 0.55 then
				local alongX = rng:next() < 0.5
				piece(L, {
					x = x,
					y = 4,
					z = z,
					sx = if alongX then cell else 2,
					sy = 8,
					sz = if alongX then 2 else cell,
					style = "hedge",
					solid = true,
					skipIfKit = "hedge_wall",
				})
				Pieces.kitProp(L, "hedge_wall", x, z, if alongX then 0 else 90)
			end
		end
	end
	for n = 0, 1 do
		local px = ctx.x0 + (n + 1) * ctx.w / 3
		piece(L, {
			x = px,
			y = ctx.h - 0.3,
			z = ctx.cz,
			sx = 16,
			sy = 0.3,
			sz = 16,
			style = "sun",
			collide = false,
			lamp = "sun",
			skipIfKit = "sun_panel",
		})
		Pieces.kitProp(L, "sun_panel", px, ctx.cz, 0, ctx.h - 2.5)
	end
	Pieces.kitProp(L, "lawn_flamingo", ctx.cx + 2, ctx.cz + 1, rng:range(0, 360))
	item(ctx, "leak_bucket", ctx.x0 + 4, ctx.z0 + 4, 1, 1)
end

------------------------------------------------------------------ weird details
-- Small wrong things scattered through every set on top of its own: each set gets several, no repeats.

local function spot(ctx: Ctx, pad: number): (number, number)
	return ctx.rng:range(ctx.x0 + pad, ctx.x1 - pad), ctx.rng:range(ctx.z0 + pad, ctx.z1 - pad)
end

local Weird = {}

-- A door frame standing on its own in the middle of the floor, no wall around it
function Weird.lone_door(ctx: Ctx)
	local x, z = spot(ctx, 6)
	local L = ctx.layout
	piece(L, {
		x = x,
		y = 7.4,
		z = z,
		sx = 4.4,
		sy = 0.5,
		sz = 0.5,
		style = "door_frame",
		skipIfKit = "door_frame_lone",
	})
	piece(L, {
		x = x - 2,
		y = 3.6,
		z = z,
		sx = 0.4,
		sy = 7.2,
		sz = 0.5,
		style = "door_frame",
		solid = true,
		skipIfKit = "door_frame_lone",
	})
	piece(L, {
		x = x + 2,
		y = 3.6,
		z = z,
		sx = 0.4,
		sy = 7.2,
		sz = 0.5,
		style = "door_frame",
		solid = true,
		skipIfKit = "door_frame_lone",
	})
	Pieces.kitProp(L, "door_frame_lone", x, z, 0)
end

-- A wall socket the size of a door
function Weird.giant_outlet(ctx: Ctx)
	local L = ctx.layout
	local x = ctx.rng:range(ctx.x0 + 8, ctx.x1 - 8)
	local z = ctx.z0 + 1.3
	piece(L, { x = x, y = 4.5, z = z, sx = 5, sy = 7, sz = 0.4, style = "plastic_white", collide = false })
	for _, dx in { -1, 1 } do
		piece(L, {
			x = x + dx,
			y = 5.6,
			z = z + 0.22,
			sx = 0.5,
			sy = 1.6,
			sz = 0.05,
			style = "void",
			collide = false,
		})
		piece(L, {
			x = x + dx,
			y = 3.2,
			z = z + 0.22,
			sx = 0.5,
			sy = 1.6,
			sz = 0.05,
			style = "void",
			collide = false,
		})
	end
end

-- A wall clock with no hands, stuck at a time anyway
function Weird.handless_clock(ctx: Ctx)
	local x = ctx.rng:range(ctx.x0 + 6, ctx.x1 - 6)
	piece(ctx.layout, {
		shape = "cylinder_wall",
		x = x,
		y = 9,
		z = ctx.z0 + 1.3,
		sx = 3,
		sy = 3,
		sz = 0.3,
		style = "plastic_white",
		label = "4:44",
		collide = false,
	})
end

-- A TV face down on the floor, glowing out from underneath
function Weird.floor_tv(ctx: Ctx)
	local x, z = spot(ctx, 5)
	piece(ctx.layout, {
		x = x,
		y = 0.9,
		z = z,
		sx = 3,
		sy = 1.6,
		sz = 2.4,
		turn = ctx.rng:range(0, 90),
		style = "plastic_black",
		solid = true,
	})
	piece(ctx.layout, {
		x = x,
		y = 0.06,
		z = z,
		sx = 4.5,
		sy = 0.04,
		sz = 4,
		style = "tv_glow",
		collide = false,
		lamp = "tv",
	})
end

-- A row of identical chairs facing a blank wall
function Weird.chair_row(ctx: Ctx)
	local z = ctx.z0 + 6
	local start = ctx.rng:range(ctx.x0 + 4, ctx.cx)
	for n = 0, 5 do
		local x = start + n * 2.4
		piece(
			ctx.layout,
			{ x = x, y = 1.4, z = z, sx = 1.6, sy = 0.2, sz = 1.6, style = "chair_grey", solid = n == 0 }
		)
		piece(ctx.layout, { x = x, y = 2.5, z = z + 0.75, sx = 1.6, sy = 2, sz = 0.15, style = "chair_grey" })
	end
end

-- A window set into the floor, sky underneath
function Weird.floor_window(ctx: Ctx)
	local x, z = spot(ctx, 6)
	piece(ctx.layout, {
		x = x,
		y = 0.16,
		z = z,
		sx = 5,
		sy = 0.06,
		sz = 5,
		style = "sky",
		paint = "sky_floor",
		collide = false,
	})
	piece(
		ctx.layout,
		{ x = x, y = 0.2, z = z, sx = 5.4, sy = 0.08, sz = 0.3, style = "door_frame", collide = false }
	)
	piece(
		ctx.layout,
		{ x = x, y = 0.2, z = z, sx = 0.3, sy = 0.08, sz = 5.4, style = "door_frame", collide = false }
	)
end

-- One balloon floating against the ceiling, its string hanging still
function Weird.balloon(ctx: Ctx)
	local x, z = spot(ctx, 4)
	local top = math.min(ctx.h, 16) - 1.2
	piece(ctx.layout, {
		shape = "ball",
		x = x,
		y = top,
		z = z,
		sx = 1.8,
		sy = 2.1,
		sz = 1.8,
		style = ctx.rng:pick({ "balloon_red", "neon_pink", "neon_yellow" }),
		collide = false,
	})
	piece(
		ctx.layout,
		{ x = x, y = top - 4, z = z, sx = 0.05, sy = 6, sz = 0.05, style = "silhouette", collide = false }
	)
end

-- A doll-sized table and chairs, perfectly set
function Weird.tiny_table(ctx: Ctx)
	local x, z = spot(ctx, 5)
	local L = ctx.layout
	piece(L, { x = x, y = 0.55, z = z, sx = 1.2, sy = 0.1, sz = 1.2, style = "wood_dark" })
	piece(L, { x = x, y = 0.25, z = z, sx = 0.12, sy = 0.5, sz = 0.12, style = "wood_dark", collide = false })
	for _, offset in { { 0.9, 0 }, { -0.9, 0 }, { 0, 0.9 } } do
		piece(L, {
			x = x + offset[1],
			y = 0.3,
			z = z + offset[2],
			sx = 0.45,
			sy = 0.08,
			sz = 0.45,
			style = "chair_orange",
			collide = false,
		})
	end
end

-- An exit sign pointing straight into a wall
function Weird.exit_to_wall(ctx: Ctx)
	local x = ctx.rng:range(ctx.x0 + 4, ctx.x1 - 4)
	piece(ctx.layout, {
		x = x,
		y = 8,
		z = ctx.z1 - 1.4,
		sx = 2.4,
		sy = 1,
		sz = 0.2,
		style = "exit_green",
		label = "EXIT ↓",
		collide = false,
		lamp = "exit",
	})
end

-- A bathroom sign beside a doorway that's been plastered over
function Weird.sealed_door(ctx: Ctx)
	local z = ctx.rng:range(ctx.z0 + 6, ctx.z1 - 6)
	piece(ctx.layout, {
		x = ctx.x1 - 1.3,
		y = 3.6,
		z = z,
		sx = 0.15,
		sy = 7.2,
		sz = 3.6,
		style = "plaster_patch",
		collide = false,
	})
	piece(ctx.layout, {
		x = ctx.x1 - 1.35,
		y = 8,
		z = z + 3,
		sx = 0.1,
		sy = 1,
		sz = 1,
		style = "plastic_white",
		label = "WC",
		collide = false,
	})
end

-- Footprints in the dust walking in a circle that never ends
function Weird.footprint_loop(ctx: Ctx)
	local x, z = spot(ctx, 8)
	for n = 0, 15 do
		local a = n / 16 * math.pi * 2
		piece(ctx.layout, {
			x = x + math.cos(a) * 4,
			y = 0.13,
			z = z + math.sin(a) * 4,
			sx = 0.4,
			sy = 0.02,
			sz = 0.9,
			turn = -math.deg(a),
			style = "oil",
			collide = false,
		})
	end
end

-- A telephone in the middle of the floor, receiver off the hook
function Weird.lone_phone(ctx: Ctx)
	local x, z = spot(ctx, 5)
	piece(
		ctx.layout,
		{ x = x, y = 0.3, z = z, sx = 1, sy = 0.5, sz = 1.2, style = "phone_beige", collide = false }
	)
	piece(ctx.layout, {
		x = x + 1.2,
		y = 0.15,
		z = z + 0.6,
		sx = 0.4,
		sy = 0.25,
		sz = 1.4,
		turn = 40,
		style = "phone_beige",
		collide = false,
	})
end

-- A staircase of three steps up to nothing
function Weird.short_stair(ctx: Ctx)
	local x, z = spot(ctx, 6)
	for s = 0, 2 do
		piece(ctx.layout, {
			x = x,
			y = 0.4 + s * 0.4,
			z = z + s * 1.2,
			sx = 4,
			sy = 0.8 + s * 0.8,
			sz = 1.2,
			style = "plaster_white",
			solid = s == 0,
		})
	end
end

-- A mannequin standing with its face to the wall
function Weird.mannequin(ctx: Ctx)
	local x = ctx.rng:range(ctx.x0 + 4, ctx.x1 - 4)
	item(ctx, "mannequin", x, ctx.z0 + 3, 0, -1)
end

local WEIRD_NAMES = {}
for name in Weird do
	table.insert(WEIRD_NAMES, name)
end
table.sort(WEIRD_NAMES)
Installations.WeirdDetails = WEIRD_NAMES

local SHAPES = {
	catwalk_void = { 0.9, 0.9, "tall" },
	black_sun = { 0.9, 0.9, "tall" },
	orb_dunes = { 0.85, 0.85, "tall" },
	night_lot = { 0.9, 0.85, "tall" },
	playground = { 0.75, 0.75, "tall" },
	stairs_nowhere = { 0.8, 0.6, "tall" },
	soft_play = { 0.7, 0.7 },
	floating_block = { 0.85, 0.85, "tall" },
	grandmas_room = { 0.45, 0.45 },
	giant_nursery = { 0.75, 0.75, "tall" },
	hedge_maze = { 0.85, 0.85, "tall" },
	sky_door = { 0.7, 0.35, "tall" },
	kids_corner = { 0.55, 0.55 },
	sky_hatch = { 0.6, 0.6, "tall" },
	tile_maze = { 0.85, 0.85 },
	cloud_hill = { 0.9, 0.9, "tall" },
	fog_lawn = { 0.85, 0.85, "tall" },
	basement = { 0.6, 0.55 },
	poolroom = { 0.8, 0.75, "tall" },
	dead_mall = { 0.95, 0.4 },
	light_grid = { 0.95, 0.95, "tall" },
	backroom = { 0.85, 0.85 },
	green_hall = { 0.95, 0.4 },
	pastel_houses = { 0.85, 0.85, "tall" },
	curtain_room = { 0.6, 0.6 },
	grass_store = { 0.85, 0.85 },
	window_court = { 0.8, 0.8, "tall" },
}
Installations.Kinds = SHAPES

-- Small lights that don't set the mood of a set
local MINOR_TONES = { exit = true, tv = true }

-- The light a set is lit with: its most used lamp tone since piece number `from`
local function mainTone(layout: any, from: number, fallback: string): string
	local counts, best, bestCount = {}, fallback, 0
	for index = from, #layout.pieces do
		local tone = layout.pieces[index].lamp
		if tone and not MINOR_TONES[tone] then
			counts[tone] = (counts[tone] or 0) + 1
			if counts[tone] > bestCount then
				best, bestCount = tone, counts[tone]
			end
		end
	end
	return best
end

-- Where a doorway sits on its room's edge, and which way is out
local function doorway(box: any, door: any): (number, number, number, number)
	if door.side == "north" then
		return box.x0 + door.at, box.z0, 0, -1
	elseif door.side == "south" then
		return box.x0 + door.at, box.z1, 0, 1
	elseif door.side == "west" then
		return box.x0, box.z0 + door.at, -1, 0
	end
	return box.x1, box.z0 + door.at, 1, 0
end
Installations.doorway = doorway

-- The set's light spilling out of a hall doorway: a pool on the floor outside and a glowing frame
local function doorSpill(layout: any, config: any, hall: any, door: any, tone: string)
	local spill = config.InstallationSpill
	local x, z, nx, nz = doorway(hall, door)
	local half = config.HallDoorWidth / 2
	local px, pz = math.abs(nz), math.abs(nx) -- along the wall
	local glow = `spill_{tone}`
	piece(layout, {
		x = x + nx * spill.reach,
		y = spill.height,
		z = z + nz * spill.reach,
		sx = 4,
		sy = 0.3,
		sz = 4,
		style = "lamp_bulb",
		collide = false,
		lamp = glow,
		spill = true,
	})
	local t = spill.frame
	for _, side in { -1, 1 } do
		piece(layout, {
			x = x + px * side * (half + t / 2) + nx * t / 2,
			y = spill.frameHeight / 2,
			z = z + pz * side * (half + t / 2) + nz * t / 2,
			sx = t,
			sy = spill.frameHeight,
			sz = t,
			style = glow,
			collide = false,
			spill = true,
		})
	end
	piece(layout, {
		x = x + nx * t / 2,
		y = spill.frameHeight + t / 2,
		z = z + nz * t / 2,
		sx = if px > 0 then config.HallDoorWidth + t * 2 else t,
		sy = t,
		sz = if pz > 0 then config.HallDoorWidth + t * 2 else t,
		style = glow,
		collide = false,
		spill = true,
	})
end

-- The stash crate: by the piece of furniture furthest from the way in, where the robots keep watch
local function placeStash(layout: any, config: any, room: any, hall: any)
	local ex, ez = doorway(hall, hall.doors[1])
	local best, bestDistance = nil, -1
	for _, thing in room.items do
		local d = (thing.x - ex) ^ 2 + (thing.z - ez) ^ 2
		if d > bestDistance then
			best, bestDistance = thing, d
		end
	end
	local reach = config.InstallationStashReach
	local x = if best then best.x + best.nx * reach else room.cx
	local z = if best then best.z + best.nz * reach else room.cz
	local turn = math.deg(math.atan2(room.cx - x, room.cz - z))
	Pieces.loose(layout, config.InstallationStash, x, z, turn)
	room.stash = { x = x, z = z }
end

-- A dark hall filling the zone, roof to floor, with the lit set inside it
function Installations.build(layout: any, config: any, rng: Rng.Rng, rect: Pieces.Rect, set: string?)
	local kind = set or rng:weighted(config.InstallationKinds)
	local hallHeight = config.CeilingHeight
	local hall: any = { x0 = rect.x0 + 1, z0 = rect.z0 + 1, x1 = rect.x1 - 1, z1 = rect.z1 - 1 }
	hall.doors = Rooms.doors(hall, rng, config.HallDoorWidth, 1, 2)
	for _, wall in Rooms.walls(hall, 1, config.HallDoorWidth) do
		piece(layout, {
			x = (wall.x0 + wall.x1) / 2,
			y = hallHeight / 2,
			z = (wall.z0 + wall.z1) / 2,
			sx = wall.x1 - wall.x0,
			sy = hallHeight,
			sz = wall.z1 - wall.z0,
			style = "dark_wall",
			solid = true,
		})
	end
	Pieces.floor(layout, hall, "dark_floor", 0.02)

	local shape = SHAPES[kind]
	local hw, hd = hall.x1 - hall.x0, hall.z1 - hall.z0
	local w, d = math.floor(hw * shape[1]), math.floor(hd * shape[2])
	if rng:next() < 0.5 and shape[1] ~= shape[2] then
		w, d = math.floor(hw * shape[2]), math.floor(hd * shape[1])
	end
	local x0 = math.floor(hall.x0 + (hw - w) / 2 + rng:range(-1, 1) * (hw - w) * 0.3)
	local z0 = math.floor(hall.z0 + (hd - d) / 2 + rng:range(-1, 1) * (hd - d) * 0.3)
	local room: any = {
		id = #layout.rooms + 1,
		kind = kind,
		x0 = x0,
		z0 = z0,
		x1 = x0 + w,
		z1 = z0 + d,
		cx = x0 + w / 2,
		cz = z0 + d / 2,
		doors = {},
		walls = {},
		items = {},
		installation = true,
	}
	local ctx: Ctx = {
		layout = layout,
		config = config,
		rng = rng,
		room = room,
		x0 = room.x0,
		z0 = room.z0,
		x1 = room.x1,
		z1 = room.z1,
		w = w,
		d = d,
		cx = room.cx,
		cz = room.cz,
		h = if hw > config.BlockSize
			then config.MegaHeight
			elseif shape[3] == "tall" then config.InstallationTallHeight
			else 16,
	}
	local firstPiece = #layout.pieces + 1
	Sets[kind](ctx)
	local picks = rng:shuffle(WEIRD_NAMES)
	for n = 1, rng:int(config.WeirdDetails[1], config.WeirdDetails[2]) do
		Weird[picks[n]](ctx)
	end
	room.tone = mainTone(layout, firstPiece, config.InstallationSpill.fallback)
	room.giant = hw > config.BlockSize
	local doorways = {}
	for _, door in room.doors do
		local x, z = doorway(room, door)
		table.insert(doorways, { x, z })
	end
	Fill.room(layout, config, room, firstPiece, ctx.h, doorways)
	placeStash(layout, config, room, hall)
	local entrances = {}
	for _, door in hall.doors do
		local x, z = doorway(hall, door)
		table.insert(entrances, { x, z })
	end
	Prizes.place(layout, config, room, firstPiece, doorways, entrances)
	for _, door in hall.doors do
		doorSpill(layout, config, hall, door, room.tone)
	end
	table.insert(layout.rooms, room)
	layout.addSolid({ x0 = room.x0, x1 = room.x1, z0 = room.z0, z1 = room.z1, room = true })
	table.insert(layout.pockets, {
		kind = kind,
		x0 = hall.x0,
		z0 = hall.z0,
		x1 = hall.x1,
		z1 = hall.z1,
		height = hallHeight,
		doors = hall.doors,
	})
end

return Installations
