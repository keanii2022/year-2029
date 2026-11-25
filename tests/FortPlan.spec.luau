local FortPlan = require("../src/shared/Logic/FortPlan")
local expect = require("./expect")

local LIMITS: FortPlan.Limits = {
	Reach = 14,
	Room = 4,
	Margin = 6,
	Door = 4,
	Width = { 8, 16 },
	Depth = { 6, 12 },
	Overhang = 1.5,
	Fit = 0.2,
	MinPiece = 1.5,
	MinWallHeight = 2.5,
	StackBelow = 4,
	MaxHeight = 8,
}

local OPEN = 30

local function spot(walls: { number }, available: number?): FortPlan.Spot
	return { x = 0, z = 0, walls = walls, front = 3, available = available or 40 }
end

-- Fills the fort with pieces of one size until it has nowhere left, confirming each.
local function fill(plan: FortPlan.Plan, length: number, depth: number, height: number): { FortPlan.Slot }
	local slots = {}
	for n = 1, 100 do
		local slot = FortPlan.slotFor(plan, length, depth, height)
		if not slot then
			break
		end
		FortPlan.reserve(plan, slot, `p{n}`)
		FortPlan.confirm(plan, `p{n}`)
		table.insert(slots, slot)
	end
	return slots
end

local function overlaps(a: FortPlan.Slot, b: FortPlan.Slot): boolean
	local function extent(s: FortPlan.Slot): (number, number)
		return math.abs(s.dx) * s.length / 2 + math.abs(s.nx) * s.depth / 2,
			math.abs(s.dz) * s.length / 2 + math.abs(s.nz) * s.depth / 2
	end
	local ax, az = extent(a)
	local bx, bz = extent(b)
	local sameHeight = a.bottom < b.bottom + b.height - 0.01 and b.bottom < a.bottom + a.height - 0.01
	return sameHeight
		and math.abs(a.x - b.x) < ax + bx - 0.25 -- Fit lets ends squeeze 0.2 into a neighbour
		and math.abs(a.z - b.z) < az + bz - 0.25
end

return {
	["open floor plans a ring, one wall a U, two walls a corner nook"] = function()
		expect((FortPlan.chooseSite({ OPEN, OPEN, OPEN, OPEN }, 14))).toBe("ring")
		local kind, back = FortPlan.chooseSite({ OPEN, 5, OPEN, OPEN }, 14)
		expect(kind).toBe("wall")
		expect(back).toBe(2)
		local corner, cornerBack, side = FortPlan.chooseSite({ OPEN, 8, 3, OPEN }, 14)
		expect(corner).toBe("corner")
		expect(cornerBack).toBe(3)
		expect(side).toBe(2)
	end,
	["an aisle end leans on the end wall, not a rack side"] = function()
		local kind, back = FortPlan.chooseSite({ 4, 5, 6, OPEN }, 14)
		expect(kind).toBe("wall")
		expect(back).toBe(3)
	end,
	["a narrow aisle with walls on both sides still gets a U"] = function()
		local kind = FortPlan.chooseSite({ 6, 6, OPEN, OPEN }, 14)
		expect(kind).toBe("wall")
	end,
	["wardrobes stand up; a mattress lying flat goes on its long edge"] = function()
		local length, height, depth = FortPlan.orient({ 4, 7, 2 }, 2, 2.5)
		expect(length).toBe(1)
		expect(height).toBe(2)
		expect(depth).toBe(3)
		length, height, depth = FortPlan.orient({ 4, 1, 7 }, 2, 2.5)
		expect(length).toBe(3)
		expect(height).toBe(1)
		expect(depth).toBe(2)
	end,
	["the fort grows with the furniture around it, within limits"] = function()
		local small = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }, 10), LIMITS) :: FortPlan.Plan
		local big = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }, 200), LIMITS) :: FortPlan.Plan
		expect(small.umax - small.umin).toBe(8)
		expect(small.vmax - small.vmin).toBe(6)
		expect(big.umax - big.umin).toBe(16)
		expect(big.vmax - big.vmin).toBe(12)
	end,
	["no room for the smallest fort means no plan"] = function()
		expect(FortPlan.new(spot({ 5, 5, 5, 5 }), LIMITS)).toBe(nil)
	end,
	["a U starts flush against its wall and builds both sides then the front"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		expect(plan.kind).toBe("wall")
		expect(#plan.edges).toBe(4)
		local first = FortPlan.slotFor(plan, 3, 2, 3) :: FortPlan.Slot
		-- back wall face is at x = -3; the piece runs out from it along +x
		expect(first.x - first.length / 2).toBeNear(-3)
		expect(first.dx).toBe(1)
	end,
	["pieces sit end to end, touching, never overlapping"] = function()
		local plan = FortPlan.new(spot({ OPEN, OPEN, OPEN, OPEN }, 60), LIMITS) :: FortPlan.Plan
		local slots = fill(plan, 3, 2, 3)
		expect(#slots > 8).toBeTruthy()
		for i, a in slots do
			for j, b in slots do
				if i < j then
					expect(overlaps(a, b)).toBeFalsy()
				end
			end
		end
		local a, b = slots[1], slots[2]
		expect(b.from).toBeNear(a.to)
	end,
	["the doorway stays open"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		fill(plan, 2, 2, 5)
		expect(FortPlan.closed(plan)).toBeTruthy()
		-- the wall is at -x, so the front runs along z with the door around the centre's z
		local _, mz = FortPlan.center(plan)
		local fronts = 0
		for _, piece in plan.pieces do
			local edge = plan.edges[piece.edge]
			if edge.nx == 1 then
				fronts += 1
				local a = edge.sz + edge.dz * piece.from
				local b = edge.sz + edge.dz * piece.to
				local near, far = math.min(a, b), math.max(a, b)
				expect(far <= mz - 2 + 1e-6 or near >= mz + 2 - 1e-6).toBeTruthy()
			end
		end
		expect(fronts > 0).toBeTruthy()
	end,
	["low pieces get stacked once the ground row is closed"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		local stacked, groundAfterStack = 0, false
		for _, slot in fill(plan, 3, 2, 3) do
			if slot.bottom > 0 then
				stacked += 1
				expect(slot.bottom).toBe(3)
				expect(plan.pieces[slot.on :: string].top ~= nil).toBeTruthy()
			elseif stacked > 0 then
				groundAfterStack = true
			end
		end
		expect(stacked > 0).toBeTruthy()
		expect(groundAfterStack).toBeFalsy()
	end,
	["a pried piece leaves a gap the crew fills again"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		local slots = fill(plan, 3, 2, 5)
		local count = FortPlan.count(plan)
		FortPlan.remove(plan, "p2")
		expect(FortPlan.count(plan)).toBe(count - 1)
		expect(FortPlan.closed(plan)).toBeFalsy()
		local again = FortPlan.slotFor(plan, 3, 2, 5) :: FortPlan.Slot
		expect(again.edge).toBe(slots[2].edge)
		expect(again.from).toBeNear(slots[2].from)
	end,
	["a blocked stretch is planned around"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		FortPlan.block(plan, 1, 0, 2)
		local slot = FortPlan.slotFor(plan, 3, 2, 3) :: FortPlan.Slot
		expect(slot.from).toBe(2)
		expect(FortPlan.count(plan)).toBe(0)
	end,
	["a reserved slot isn't handed out twice"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		local a = FortPlan.slotFor(plan, 3, 2, 3) :: FortPlan.Slot
		FortPlan.reserve(plan, a, "a")
		local b = FortPlan.slotFor(plan, 3, 2, 3) :: FortPlan.Slot
		expect(b.from).toBeNear(a.to)
	end,
	["standing spots and hiding spots are inside the fort"] = function()
		local plan = FortPlan.new(spot({ OPEN, 3, OPEN, OPEN }), LIMITS) :: FortPlan.Plan
		local slot = FortPlan.slotFor(plan, 3, 2, 3) :: FortPlan.Slot
		local sx, sz = FortPlan.stand(slot, 1)
		expect(FortPlan.contains(plan, sx, sz, 0)).toBeTruthy()
		local hx, hz = FortPlan.inside(plan, 0.9, 0.1, 1)
		expect(FortPlan.contains(plan, hx, hz, 0)).toBeTruthy()
		expect(FortPlan.contains(plan, slot.x, slot.z, 0)).toBeFalsy()
		expect(FortPlan.contains(plan, 100, 100, 5)).toBeFalsy()
	end,
}
