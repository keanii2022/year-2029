-- Where story spots and critter groups go: random clear floor spots kept apart from each other,
-- and group layouts (a survivor camp, a leak with its puddle) turned to face any way. No Roblox here.
local HauntPlacement = {}

export type Spot = { x: number, z: number, turn: number }
export type GroupItem = { name: string, dx: number, dz: number, turn: number }
export type Placed = { name: string, x: number, z: number, turn: number }

-- Up to count spots inside +-half, each clear by isClear(x, z) and at least gap from every spot
-- in taken (which this adds to). next() rolls in [0, 1).
function HauntPlacement.spots(
	count: number,
	half: number,
	gap: number,
	tries: number,
	isClear: (x: number, z: number) -> boolean,
	taken: { Spot },
	next: () -> number
): { Spot }
	local found = {}
	for _ = 1, count * tries do
		if #found >= count then
			break
		end
		local x = (next() * 2 - 1) * half
		local z = (next() * 2 - 1) * half
		local apart = true
		for _, other in taken do
			if (other.x - x) ^ 2 + (other.z - z) ^ 2 < gap * gap then
				apart = false
				break
			end
		end
		if apart and isClear(x, z) then
			local spot = { x = x, z = z, turn = math.floor(next() * 4) * 90 }
			table.insert(found, spot)
			table.insert(taken, spot)
		end
	end
	return found
end

-- Places each item of a group around a spot, turning the offsets by the spot's turn (degrees
-- around +y, 0 means the group faces +z).
function HauntPlacement.arrange(items: { GroupItem }, spot: Spot): { Placed }
	local radians = math.rad(spot.turn)
	local c, s = math.cos(radians), math.sin(radians)
	local placed = {}
	for _, item in items do
		table.insert(placed, {
			name = item.name,
			x = spot.x + item.dx * c + item.dz * s,
			z = spot.z - item.dx * s + item.dz * c,
			turn = (spot.turn + item.turn) % 360,
		})
	end
	return placed
end

-- Spreads count picks evenly over a list (every n-th), so a few out of many lamps or pillars land
-- all over the warehouse instead of in one corner.
function HauntPlacement.everyNth<T>(list: { T }, count: number): { T }
	local picked = {}
	if count <= 0 or #list == 0 then
		return picked
	end
	local step = math.max(#list / count, 1)
	local at = 1
	while at <= #list and #picked < count do
		table.insert(picked, list[math.floor(at)])
		at += step
	end
	return picked
end

return HauntPlacement
