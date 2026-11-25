-- Where a hunter drops into an aisle from the top of a rack bay, no Roblox here. Shelves run along x
-- (warehouse-local, x0..x1 at z, depth deep). It perches on top of a rack inside Distance of the
-- player, behind them if it can, and lands Inset studs out from the rack face on the player's side.
local RobotRacks = {}

export type Point = { x: number, z: number }
export type Shelf = { x0: number, x1: number, z: number, depth: number }

-- look: the player's facing (x, z). roll (0..1) picks among the spots that work. Returns the perch on
-- top of the rack and the landing in the aisle, or nil when no rack is in range.
function RobotRacks.dropSpot(
	shelves: { Shelf },
	player: Point,
	look: Point,
	settings: { Distance: { number }, Along: { number }, Inset: number },
	roll: number
): (Point?, Point?)
	local behind, ahead = {}, {}
	for _, shelf in shelves do
		local side = if player.z >= shelf.z then 1 else -1
		for _, along in settings.Along do
			local x = player.x + along
			if x < shelf.x0 + 2 or x > shelf.x1 - 2 then
				continue
			end
			local dx, dz = x - player.x, shelf.z - player.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < settings.Distance[1] or d > settings.Distance[2] then
				continue
			end
			local spot = {
				top = { x = x, z = shelf.z },
				land = { x = x, z = shelf.z + side * (shelf.depth / 2 + settings.Inset) },
			}
			table.insert(if dx * look.x + dz * look.z < 0 then behind else ahead, spot)
		end
	end
	local pool = if #behind > 0 then behind else ahead
	if #pool == 0 then
		return nil, nil
	end
	local pick = pool[math.clamp(1 + math.floor(roll * #pool), 1, #pool)]
	return pick.top, pick.land
end

return RobotRacks
