-- Planning a fake public lobby: how many simulated players for this warehouse size, how they split
-- into solos and small groups, which spread-out spawn each group starts at, and what it's doing.
local WarehouseSizes = if script then require(script.Parent.WarehouseSizes) else require("./WarehouseSizes")

local Lobby = {}

export type Spot = { x: number, z: number }
export type Group = { spot: Spot, size: number, opening: string }

-- settings: Config.SimPlayers.Lobby (Bots is the range at BotsAt studs). roll returns 0..1.
function Lobby.botCount(size: number, warehouseConfig: any, settings: any, roll: () -> number): number
	local low, high = settings.Bots[1], settings.Bots[2]
	local count = low + math.floor(roll() * (high - low + 1))
	local relative = WarehouseSizes.scale(size, warehouseConfig)
		/ WarehouseSizes.scale(settings.BotsAt, warehouseConfig)
	return math.max(1, math.floor(count * relative + 0.5))
end

-- Splits total into groups of 1 to 3: SoloShare of groups alone, TrioShare in threes, the rest pairs
function Lobby.groupSizes(total: number, settings: any, roll: () -> number): { number }
	local sizes = {}
	local left = total
	while left > 0 do
		local r = roll()
		local size = if r < settings.SoloShare
			then 1
			elseif r < settings.SoloShare + settings.TrioShare then 3
			else 2
		size = math.min(size, left)
		table.insert(sizes, size)
		left -= size
	end
	return sizes
end

-- count spots from the list, each the furthest from every one picked so far (first one random).
-- With more groups than spots it goes round again.
function Lobby.spreadSpots(spots: { Spot }, count: number, roll: () -> number): { Spot }
	local picked: { Spot } = {}
	if #spots == 0 then
		return picked
	end
	local used: { [number]: boolean } = {}
	local usedCount = 0
	for _ = 1, count do
		if usedCount == #spots then
			table.clear(used)
			usedCount = 0
		end
		local best, bestGap = nil, -1
		if usedCount == 0 then
			best = math.clamp(math.floor(roll() * #spots) + 1, 1, #spots)
		else
			for index, spot in spots do
				if not used[index] then
					local gap = math.huge
					for usedIndex in used do
						local other = spots[usedIndex]
						gap = math.min(gap, (spot.x - other.x) ^ 2 + (spot.z - other.z) ^ 2)
					end
					if gap > bestGap then
						best, bestGap = index, gap
					end
				end
			end
		end
		local index = best :: number
		used[index] = true
		usedCount += 1
		table.insert(picked, spots[index])
	end
	return picked
end

-- Weighted pick from settings.Openings, in name order so the same roll always lands the same
function Lobby.opening(settings: any, roll: number): string
	local names = {}
	local total = 0
	for name, weight in settings.Openings do
		table.insert(names, name)
		total += weight
	end
	table.sort(names)
	local point = roll * total
	for _, name in names do
		point -= settings.Openings[name]
		if point < 0 then
			return name
		end
	end
	return names[#names]
end

function Lobby.plan(total: number, spots: { Spot }, settings: any, roll: () -> number): { Group }
	local sizes = Lobby.groupSizes(total, settings, roll)
	local chosen = Lobby.spreadSpots(spots, #sizes, roll)
	local groups: { Group } = {}
	for index, size in sizes do
		local spot = chosen[index]
		if spot then
			table.insert(groups, { spot = spot, size = size, opening = Lobby.opening(settings, roll()) })
		end
	end
	return groups
end

return Lobby
