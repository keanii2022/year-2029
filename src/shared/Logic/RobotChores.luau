-- Day errands for chore bots: which chore each type does, the pose for each leg of the trip, and
-- which aisle spot to send a robot to so a player sees it at work. Flat x/z, no Roblox.
local RobotChores = {}

export type Chore = "carry" | "sweep" | "restock"
export type Point = { x: number, z: number }
export type Spot = { x: number, z: number, kind: string, dx: number, dz: number }
export type SpotSettings = { MinDistance: number, MaxDistance: number, Reach: number }

-- out: pose walking to the spot. work: pose while doing the chore there. Home is always "walk".
local POSES: { [string]: { out: string, work: string } } = {
	carry = { out = "carry", work = "shelve" }, -- brings a box out, shelves it, tidies the shelf
	sweep = { out = "walk", work = "sweep" },
	restock = { out = "walk", work = "restock" },
}

function RobotChores.choreFor(typeName: string, choreFor: { [string]: Chore }): Chore
	return choreFor[typeName] or "sweep"
end

function RobotChores.poses(chore: string): (string, string)
	local poses = POSES[chore] or POSES.sweep
	return poses.out, poses.work
end

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
end

-- A spot the player at viewer can see from a distance (MinDistance..MaxDistance away) that the robot
-- living at home can walk to (within Reach). roll in [0, 1) picks one at random.
-- Returns the spot and the point to face while working (the rack, for a spot beside one).
function RobotChores.pickSpot(
	spots: { Spot },
	home: Point,
	viewer: Point,
	settings: SpotSettings,
	roll: number
): (Point?, Point?)
	local candidates = {}
	for _, spot in spots do
		local fromViewer = distance(spot.x, spot.z, viewer.x, viewer.z)
		if
			fromViewer >= settings.MinDistance
			and fromViewer <= settings.MaxDistance
			and distance(spot.x, spot.z, home.x, home.z) <= settings.Reach
		then
			table.insert(candidates, spot)
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local spot = candidates[math.clamp(math.floor(roll * #candidates) + 1, 1, #candidates)]
	-- aisle spots point away from the rack face; end spots point across the cross aisle
	local sign = if spot.kind == "aisle" then -1 else 1
	return { x = spot.x, z = spot.z }, { x = spot.x + sign * spot.dx * 3, z = spot.z + sign * spot.dz * 3 }
end

-- How far a carrier is through shelving its box, elapsed seconds after arriving: holds it for lift
-- seconds, slides it onto the shelf over slide seconds (progress 0..1), then placed is true.
function RobotChores.shelve(elapsed: number, lift: number, slide: number): (number, boolean)
	local progress = math.clamp((elapsed - lift) / slide, 0, 1)
	return progress, elapsed >= lift + slide
end

-- How many more robots to send out near one player.
function RobotChores.needed(outNear: number, perPlayer: number): number
	return math.max(0, perPlayer - outNear)
end

return RobotChores
