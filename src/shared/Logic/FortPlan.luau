-- Planning a sim player fort: which kind fits a spot (a U against a wall, a nook in a corner, or a
-- free-standing ring), how big it gets from the furniture lying around, and where each hauled piece
-- goes. The inside is a rectangle of clear floor; pieces line its built sides on the outside, end to
-- end, so neighbours touch (FortLink) and two sides only ever meet at a corner point, never overlap.
-- Low pieces get a second piece stacked on top once the ground row has no room left.
-- Flat x / z numbers in studs, heights from the floor. No Roblox.
local FortPlan = {}

export type Kind = "wall" | "corner" | "ring"

export type Limits = {
	Reach: number, -- a wall this close to the spot shapes the fort
	Room: number, -- floor kept outside each built side for its pieces
	Margin: number, -- walkway kept clear in front of the fort before the next wall across
	Door: number, -- gap left in the front side
	Width: { number }, -- inside, side to side { min, max }
	Depth: { number }, -- inside, back to front { min, max }
	Overhang: number, -- a piece may run this far past the open end of a side into the corner
	Fit: number, -- a piece may squeeze into a gap this much shorter than itself
	MinPiece: number, -- gaps shorter than this count as closed
	MinWallHeight: number, -- a piece lower than this when upright is stood on its edge instead
	StackBelow: number, -- pieces lower than this get another stacked on top
	MaxHeight: number, -- a stack never gets taller than this
}

-- walls: distance to the nearest solid face along +x, -x, +z, -z (the probe length when none).
-- front: the AXES index a ring's door faces. available: total length of the pieces lying around.
export type Spot = { x: number, z: number, walls: { number }, front: number, available: number }

export type Edge = {
	sx: number, -- start of the side line
	sz: number,
	dx: number, -- along the side
	dz: number,
	nx: number, -- out of the fort
	nz: number,
	length: number,
	overhang: number,
}

export type Piece = {
	key: string,
	edge: number,
	from: number,
	to: number,
	depth: number,
	height: number,
	bottom: number,
	placed: boolean,
	blocked: boolean,
	on: string?, -- the piece it's stacked on
	top: string?, -- the piece stacked on it
}

export type Plan = {
	kind: Kind,
	ox: number,
	oz: number,
	ux: number,
	uz: number,
	vx: number,
	vz: number,
	umin: number,
	umax: number,
	vmin: number,
	vmax: number,
	edges: { Edge },
	pieces: { [string]: Piece },
	limits: Limits,
	blocks: number,
}

export type Slot = {
	edge: number,
	from: number,
	to: number,
	x: number,
	z: number,
	bottom: number,
	dx: number,
	dz: number,
	nx: number,
	nz: number,
	length: number,
	depth: number,
	height: number,
	on: string?,
}

FortPlan.AXES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function opposite(axis: number): number
	return if axis % 2 == 1 then axis + 1 else axis - 1
end

local function perpendicular(a: number, b: number): boolean
	return (a <= 2) ~= (b <= 2)
end

-- Which kind of fort the walls around a spot call for. back is the wall it leans on, side the
-- second wall of a corner (both AXES indexes).
function FortPlan.chooseSite(walls: { number }, reach: number): (Kind, number?, number?)
	local close = {}
	for axis = 1, 4 do
		if walls[axis] <= reach then
			table.insert(close, axis)
		end
	end
	table.sort(close, function(a, b)
		return walls[a] < walls[b]
	end)
	if #close == 3 then
		-- an aisle end: lean on the end wall, the aisle sides close in the U
		for _, axis in close do
			if walls[opposite(axis)] > reach then
				return "wall", axis, nil
			end
		end
	end
	if #close == 2 and perpendicular(close[1], close[2]) then
		return "corner", close[1], close[2]
	end
	if #close > 0 then
		return "wall", close[1], nil
	end
	return "ring", nil, nil
end

-- Which way up a piece goes and which side runs along the wall. sizes are its box sides and up the
-- one that points up as it lies. Returns the indexes of its length, height and depth sides.
function FortPlan.orient(sizes: { number }, up: number, minWallHeight: number): (number, number, number)
	local a, b = up % 3 + 1, (up + 1) % 3 + 1
	if sizes[up] >= minWallHeight then
		if sizes[a] >= sizes[b] then
			return a, up, b
		end
		return b, up, a
	end
	-- too low lying flat (a mattress, a panel): stand it on its long edge like a player would
	local order = { 1, 2, 3 }
	table.sort(order, function(i, j)
		return sizes[i] > sizes[j]
	end)
	return order[1], order[2], order[3]
end

local function clampSize(wanted: number, range: { number }, space: number): number?
	local most = math.min(range[2], space)
	if most < range[1] then
		return nil
	end
	return math.clamp(wanted, range[1], most)
end

local function addEdge(
	plan: Plan,
	u: number,
	v: number,
	du: number,
	dv: number,
	nu: number,
	nv: number,
	length: number,
	overhang: number
)
	if length < plan.limits.MinPiece then
		return
	end
	table.insert(plan.edges, {
		sx = plan.ox + plan.ux * u + plan.vx * v,
		sz = plan.oz + plan.uz * u + plan.vz * v,
		dx = plan.ux * du + plan.vx * dv,
		dz = plan.uz * du + plan.vz * dv,
		nx = plan.ux * nu + plan.vx * nv,
		nz = plan.uz * nu + plan.vz * nv,
		length = length,
		overhang = overhang,
	})
end

-- The front side, split by the door: each half starts at the door so the doorway stays clean.
local function addFront(plan: Plan)
	local door = plan.limits.Door / 2
	local middle = (plan.umin + plan.umax) / 2
	addEdge(plan, middle - door, plan.vmax, -1, 0, 0, 1, middle - door - plan.umin, 0)
	addEdge(plan, middle + door, plan.vmax, 1, 0, 0, 1, plan.umax - middle - door, 0)
end

-- A fort for the spot, or nil when there's no room for even the smallest one.
function FortPlan.new(spot: Spot, limits: Limits): Plan?
	local walls = spot.walls
	local kind, back, side = FortPlan.chooseSite(walls, limits.Reach)
	local frontAxis = if back then opposite(back) else spot.front
	local v = FortPlan.AXES[frontAxis]
	local vx, vz = v[1], v[2]
	local ux, uz = vz, -vx
	if kind == "corner" then
		-- u runs away from the side wall
		local s = FortPlan.AXES[side :: number]
		ux, uz = -s[1], -s[2]
	end
	local function wallAlong(x: number, z: number): number
		for axis, a in FortPlan.AXES do
			if a[1] == x and a[2] == z then
				return walls[axis]
			end
		end
		return 0
	end
	local ahead, behind = wallAlong(vx, vz), wallAlong(-vx, -vz)
	local right, left = wallAlong(ux, uz), wallAlong(-ux, -uz)
	local perimeter = spot.available + limits.Door
	local room, margin = limits.Room, limits.Margin

	local width, depth, ox, oz, umin, vmin
	if kind == "wall" then
		width = clampSize(perimeter * 0.4, limits.Width, left + right - 2 * room)
		depth = width and clampSize((perimeter - width) / 2, limits.Depth, behind + ahead - room - margin)
		if not width or not depth then
			return nil
		end
		ox, oz = spot.x - vx * behind, spot.z - vz * behind
		umin = math.clamp(-width / 2, -left + room, right - room - width)
		vmin = 0
	elseif kind == "corner" then
		width = clampSize(perimeter / 2, limits.Width, left + right - room - margin)
		depth = width and clampSize(perimeter - width, limits.Depth, behind + ahead - room - margin)
		if not width or not depth then
			return nil
		end
		ox, oz = spot.x - vx * behind - ux * left, spot.z - vz * behind - uz * left
		umin, vmin = 0, 0
	else
		width = clampSize(perimeter / 4, limits.Width, 2 * (math.min(left, right) - room))
		depth = width and clampSize(perimeter / 2 - width, limits.Depth, 2 * (math.min(ahead, behind) - room))
		if not width or not depth then
			return nil
		end
		ox, oz = spot.x, spot.z
		umin, vmin = -width / 2, -depth / 2
	end

	local plan: Plan = {
		kind = kind,
		ox = ox,
		oz = oz,
		ux = ux,
		uz = uz,
		vx = vx,
		vz = vz,
		umin = umin,
		umax = umin + width,
		vmin = vmin,
		vmax = vmin + depth,
		edges = {},
		pieces = {},
		limits = limits,
		blocks = 0,
	}
	local over = limits.Overhang
	if kind == "ring" then
		addEdge(plan, plan.umin, plan.vmin, 1, 0, 0, -1, width, over)
	end
	if kind ~= "corner" then
		addEdge(plan, plan.umin, plan.vmin, 0, 1, -1, 0, depth, over)
	end
	addEdge(plan, plan.umax, plan.vmin, 0, 1, 1, 0, depth, over)
	addFront(plan)
	return plan
end

-- Ground pieces on one side, in order along it.
local function groundOn(plan: Plan, edge: number): { Piece }
	local list = {}
	for _, piece in plan.pieces do
		if piece.edge == edge and piece.on == nil then
			table.insert(list, piece)
		end
	end
	table.sort(list, function(a, b)
		return a.from < b.from
	end)
	return list
end

local function slotAt(
	plan: Plan,
	edge: number,
	from: number,
	length: number,
	depth: number,
	height: number,
	bottom: number
): Slot
	local e = plan.edges[edge]
	local along = from + length / 2
	return {
		edge = edge,
		from = from,
		to = from + length,
		x = e.sx + e.dx * along + e.nx * depth / 2,
		z = e.sz + e.dz * along + e.nz * depth / 2,
		bottom = bottom,
		dx = e.dx,
		dz = e.dz,
		nx = e.nx,
		nz = e.nz,
		length = length,
		depth = depth,
		height = height,
	}
end

-- The first free stretch a piece fits, in build order: the ground row side by side, then on top of
-- low pieces. nil when the fort has nowhere for it.
function FortPlan.slotFor(plan: Plan, length: number, depth: number, height: number): Slot?
	local limits = plan.limits
	local need = length - limits.Fit
	for index, edge in plan.edges do
		local cursor = 0
		for _, piece in groundOn(plan, index) do
			if piece.from - cursor >= math.max(need, limits.MinPiece) then
				return slotAt(plan, index, cursor, length, depth, height, 0)
			end
			cursor = math.max(cursor, piece.to)
		end
		local left = edge.length - cursor
		if left >= limits.MinPiece and left + edge.overhang >= need then
			return slotAt(plan, index, cursor, length, depth, height, 0)
		end
	end
	for index in plan.edges do
		for _, below in groundOn(plan, index) do
			local span = below.to - below.from
			local fits = below.placed
				and not below.blocked
				and below.top == nil
				and below.height < limits.StackBelow
				and below.height + height <= limits.MaxHeight
				and need <= span
				and depth <= below.depth + limits.Fit
			if fits then
				local slot =
					slotAt(plan, index, below.from + (span - length) / 2, length, depth, height, below.height)
				slot.on = below.key
				return slot
			end
		end
	end
	return nil
end

-- Holds a slot for a piece on its way, so crewmates don't haul something to the same spot.
function FortPlan.reserve(plan: Plan, slot: Slot, key: string)
	plan.pieces[key] = {
		key = key,
		edge = slot.edge,
		from = slot.from,
		to = slot.to,
		depth = slot.depth,
		height = slot.height,
		bottom = slot.bottom,
		placed = false,
		blocked = false,
		on = slot.on,
	}
	local below = slot.on and plan.pieces[slot.on]
	if below then
		below.top = key
	end
end

function FortPlan.confirm(plan: Plan, key: string)
	local piece = plan.pieces[key]
	if piece then
		piece.placed = true
	end
end

-- A piece that never arrived, or was pried away: its stretch is free again.
function FortPlan.remove(plan: Plan, key: string)
	local piece = plan.pieces[key]
	if not piece then
		return
	end
	plan.pieces[key] = nil
	local below = piece.on and plan.pieces[piece.on]
	if below and below.top == key then
		below.top = nil
	end
end

-- Something fixed is in the way of this stretch: plan around it from now on.
function FortPlan.block(plan: Plan, edge: number, from: number, to: number)
	plan.blocks += 1
	local key = `block{plan.blocks}`
	plan.pieces[key] = {
		key = key,
		edge = edge,
		from = from,
		to = to,
		depth = 0,
		height = 0,
		bottom = 0,
		placed = true,
		blocked = true,
	}
end

-- Nothing will go on top of this piece (something hangs over it).
function FortPlan.blockTop(plan: Plan, key: string)
	local piece = plan.pieces[key]
	if piece and piece.top == nil then
		piece.top = "blocked"
	end
end

-- Pieces actually standing in the fort.
function FortPlan.count(plan: Plan): number
	local n = 0
	for _, piece in plan.pieces do
		if piece.placed and not piece.blocked then
			n += 1
		end
	end
	return n
end

-- The ground row is closed all round: no gap a piece could still fill.
function FortPlan.closed(plan: Plan): boolean
	for index, edge in plan.edges do
		local cursor = 0
		for _, piece in groundOn(plan, index) do
			if piece.from - cursor >= plan.limits.MinPiece then
				return false
			end
			cursor = math.max(cursor, piece.to)
		end
		if edge.length - cursor >= plan.limits.MinPiece then
			return false
		end
	end
	return true
end

-- Where to stand to set a slot's piece down: inside the fort, gap studs off its inner face.
function FortPlan.stand(slot: Slot, gap: number): (number, number)
	local back = slot.depth / 2 + gap
	return slot.x - slot.nx * back, slot.z - slot.nz * back
end

local function toWorld(plan: Plan, u: number, v: number): (number, number)
	return plan.ox + plan.ux * u + plan.vx * v, plan.oz + plan.uz * u + plan.vz * v
end

function FortPlan.center(plan: Plan): (number, number)
	return toWorld(plan, (plan.umin + plan.umax) / 2, (plan.vmin + plan.vmax) / 2)
end

-- A spot on the inside floor, pad studs in from the sides; a and b are 0..1.
function FortPlan.inside(plan: Plan, a: number, b: number, pad: number): (number, number)
	local u = plan.umin + pad + (plan.umax - plan.umin - 2 * pad) * a
	local v = plan.vmin + pad + (plan.vmax - plan.vmin - 2 * pad) * b
	return toWorld(plan, u, v)
end

-- Whether a point is inside the fort, or within pad studs of it.
function FortPlan.contains(plan: Plan, x: number, z: number, pad: number): boolean
	local dx, dz = x - plan.ox, z - plan.oz
	local u = dx * plan.ux + dz * plan.uz
	local v = dx * plan.vx + dz * plan.vz
	return u >= plan.umin - pad and u <= plan.umax + pad and v >= plan.vmin - pad and v <= plan.vmax + pad
end

return FortPlan
