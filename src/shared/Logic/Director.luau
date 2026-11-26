-- The event director's picking: groups players by where they stand, then finds spots that make
-- groups cross paths (halfway between two, just past someone's fort, an installation in between).
-- Flat x/z numbers only, no Roblox. Settings: Config.Director.
local Director = {}

-- id: who a point belongs to (a player standing there, or the placer of a fort prop), when known
export type Point = { x: number, z: number, id: any?, ids: { [any]: boolean }? }
-- members: indexes into the clustered points, so a caller can tell which ones made the group
export type Group = { x: number, z: number, count: number, members: { number }?, ids: { [any]: boolean }? }
export type Installation = { x: number, z: number, room: any }
export type Candidate = { x: number, z: number, kind: string, weight: number, room: any? }

local function distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Points chained within radius of each other end up in one group, centred on their average
function Director.cluster(points: { Point }, radius: number): { Group }
	local parent: { number } = {}
	for index in points do
		parent[index] = index
	end
	local function root(index: number): number
		while parent[index] ~= index do
			parent[index] = parent[parent[index]]
			index = parent[index]
		end
		return index
	end
	for i = 1, #points do
		for j = i + 1, #points do
			if distance(points[i], points[j]) <= radius then
				parent[root(i)] = root(j)
			end
		end
	end
	local byRoot: { [number]: Group } = {}
	local groups: { Group } = {}
	for index, point in points do
		local key = root(index)
		local group = byRoot[key]
		if not group then
			group = { x = 0, z = 0, count = 0, members = {}, ids = {} }
			byRoot[key] = group
			table.insert(groups, group)
		end
		group.x += point.x
		group.z += point.z
		group.count += 1
		table.insert(group.members :: { number }, index)
		if point.id ~= nil then
			(group.ids :: any)[point.id] = true
		end
	end
	for _, group in groups do
		group.x /= group.count
		group.z /= group.count
	end
	return groups
end

-- Two groups already close enough to see or shoot each other
function Director.together(groups: { Group }, meetRange: number): boolean
	for i = 1, #groups do
		for j = i + 1, #groups do
			if distance(groups[i], groups[j]) <= meetRange then
				return true
			end
		end
	end
	return false
end

-- How fast the clock to the next event runs: slower while groups are already mixing it up, faster
-- the longer everyone has kept to themselves
function Director.pace(apartSeconds: number, together: boolean, settings: any): number
	if together then
		return settings.BackOff
	end
	local ramp = math.clamp((apartSeconds - settings.NudgeAfter) / settings.NudgeRamp, 0, 1)
	return 1 + (settings.NudgeMax - 1) * ramp
end

-- Far enough from every group and fort that nobody just gets handed it
local function roomy(spot: Point, groups: { Group }, forts: { Point }, settings: any): boolean
	for _, group in groups do
		if distance(spot, group) < settings.GroupClearance then
			return false
		end
	end
	for _, fort in forts do
		if distance(spot, fort) < settings.FortClearance then
			return false
		end
	end
	return true
end

function Director.candidates(
	groups: { Group },
	forts: { Point },
	installations: { Installation },
	settings: any
): { Candidate }
	local found: { Candidate } = {}
	local function add(candidate: Candidate)
		if roomy(candidate, groups, forts, settings) then
			table.insert(found, candidate)
		end
	end
	for i = 1, #groups do
		for j = i + 1, #groups do
			local a, b = groups[i], groups[j]
			local gap = distance(a, b)
			if gap >= settings.MinGap and gap <= settings.MaxGap then
				add({
					x = (a.x + b.x) / 2,
					z = (a.z + b.z) / 2,
					kind = "midpoint",
					weight = settings.Weights.midpoint,
				})
				for _, place in installations do
					local detour = distance(a, place) + distance(place, b) - gap
					if detour <= gap * settings.BetweenSlack then
						add({
							x = place.x,
							z = place.z,
							kind = "installation",
							weight = settings.Weights.installation,
							room = place.room,
						})
					end
				end
			end
		end
	end
	-- Just beyond a fort, seen from a group that doesn't own it, so their walk passes the fort
	local function owns(group: Group, fort: Point): boolean
		for id in fort.ids or {} do
			if group.ids and group.ids[id] then
				return true
			end
		end
		return false
	end
	for _, group in groups do
		for _, fort in forts do
			local gap = distance(group, fort)
			if gap >= settings.MinGap and gap <= settings.MaxGap and not owns(group, fort) then
				local past = settings.PastFort / gap
				add({
					x = fort.x + (fort.x - group.x) * past,
					z = fort.z + (fort.z - group.z) * past,
					kind = "pastFort",
					weight = settings.Weights.pastFort,
				})
			end
		end
	end
	return found
end

-- A weighted candidate nudged a little off its exact spot, or nil (RandomShare of the time, or with
-- nothing to pick) so the caller falls back to an ordinary random spot. roll() gives 0..1.
function Director.pick(candidates: { Candidate }, settings: any, roll: () -> number): Candidate?
	if #candidates == 0 or roll() < settings.RandomShare then
		return nil
	end
	local total = 0
	for _, candidate in candidates do
		total += candidate.weight
	end
	if total <= 0 then
		return nil
	end
	local point = roll() * total
	local chosen = candidates[#candidates]
	for _, candidate in candidates do
		point -= candidate.weight
		if point < 0 then
			chosen = candidate
			break
		end
	end
	local angle, reach = roll() * math.pi * 2, roll() * settings.Jitter
	return {
		x = chosen.x + math.cos(angle) * reach,
		z = chosen.z + math.sin(angle) * reach,
		kind = chosen.kind,
		weight = chosen.weight,
		room = chosen.room,
	}
end

-- The point in list nearest to spot, or nil for an empty list
function Director.nearest(list: { any }, spot: Point): any?
	local best, bestDistance = nil, math.huge
	for _, item in list do
		local d = distance(item, spot)
		if d < bestDistance then
			best, bestDistance = item, d
		end
	end
	return best
end

return Director
