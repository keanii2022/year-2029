-- Procedural limb poses until the real clips are imported in Studio. Each pose returns a joint value
-- per part for ModelRig.setPose (1 = one full swing, about 30 degrees; negative swings the other way).
-- stride: walk cycle in radians, advanced by how far the robot moved. clock: seconds, for idle motion.
-- progress: 0..1 through a one-off motion (shelving a box), for poses that have one.
local RobotPoses = {}

local LEFT_RIGHT = { "UpperArm", "Forearm", "Hand", "Thigh", "Shin" }
local CRAWLER_LEGS = { "Leg1", "Leg2", "Leg3", "Leg4", "Leg5", "Leg6" }

local function rest(): { [string]: number }
	local pose = { Head = 0, Legs = 0 }
	for _, name in LEFT_RIGHT do
		pose[name] = 0
		pose[`Left{name}`] = 0
	end
	for _, name in CRAWLER_LEGS do
		pose[name] = 0
	end
	return pose
end

local function legs(pose: { [string]: number }, stride: number, amount: number)
	local s = math.sin(stride)
	pose.Thigh = amount * s
	pose.LeftThigh = -amount * s
	pose.Shin = -amount * math.max(0, -s)
	pose.LeftShin = -amount * math.max(0, s)
	pose.Legs = 0.2 * amount * math.sin(stride * 2)
	for i, name in CRAWLER_LEGS do
		pose[name] = amount * s * (if i % 2 == 0 then 1 else -1)
	end
	pose.UpperArm = -0.6 * amount * s
	pose.LeftUpperArm = 0.6 * amount * s
end

-- -1..1, the broom's side-to-side swing; the server turns the body and the broom with the same beat.
function RobotPoses.sweepSwing(clock: number): number
	return math.sin(clock * 3)
end

function RobotPoses.limbs(
	name: string,
	stride: number,
	clock: number,
	moving: boolean,
	progress: number?
): { [string]: number }
	local pose = rest()
	if name == "walk" then
		legs(pose, stride, if moving then 0.9 else 0)
		pose.Forearm, pose.LeftForearm = 0.4, 0.4
	elseif name == "chase" then
		legs(pose, stride, if moving then 1.4 else 0)
		pose.UpperArm, pose.LeftUpperArm = 2 + pose.UpperArm * 0.3, 2 + pose.LeftUpperArm * 0.3
		pose.Forearm, pose.LeftForearm = 1.5, 1.5
		pose.Head = 0.15 * math.sin(clock * 9)
	elseif name == "scan" then
		legs(pose, stride, if moving then 0.7 else 0)
		pose.Head = 2 * math.sin(clock * 0.8)
	elseif name == "study" then
		legs(pose, stride, if moving then 0.9 else 0)
		if not moving then
			pose.UpperArm = 2 + 0.3 * math.sin(clock * 2)
			pose.LeftUpperArm = 1.8 + 0.3 * math.sin(clock * 2.3 + 1)
			pose.Forearm = 1 + 0.4 * math.sin(clock * 3)
			pose.LeftForearm = 0.8 + 0.4 * math.sin(clock * 2.7 + 2)
			pose.Hand = 0.5 * math.sin(clock * 4)
			pose.Head = 0.8 * math.sin(clock * 0.5)
		end
	elseif name == "carry" then
		-- both arms out front, holding a box at chest height
		legs(pose, stride, if moving then 0.8 else 0)
		pose.UpperArm, pose.LeftUpperArm = 2.2, 2.2
		-- the weight bobs in its hands with each step
		local bob = if moving then 0.1 * math.sin(stride * 2) else 0.05 * math.sin(clock * 2)
		pose.Forearm, pose.LeftForearm = 0.8 + bob, 0.8 + bob
		pose.Head = -0.2
	elseif name == "shelve" then
		-- arms push the box forward and up onto the shelf, leaning into it
		local p = math.clamp(progress or 0, 0, 1)
		pose.UpperArm = 2.2 + 1.4 * p
		pose.LeftUpperArm = pose.UpperArm
		pose.Forearm = 0.8 - 0.7 * p
		pose.LeftForearm = pose.Forearm
		pose.Head = 0.3 + 0.4 * p
		pose.Legs = 0.25 * p
		pose.Thigh, pose.LeftThigh = 0.3 * p, -0.3 * p
	elseif name == "sweep" then
		-- arms low and together, pushing a broom side to side, head down at the floor
		local swing = RobotPoses.sweepSwing(clock)
		legs(pose, stride, if moving then 0.6 else 0)
		pose.UpperArm = 1.2 + 0.6 * swing
		pose.LeftUpperArm = 1.0 + 0.6 * swing
		pose.Forearm, pose.LeftForearm = 0.6, 0.6
		pose.Hand = 0.3 * swing
		pose.Head = -0.5 + 0.2 * swing
		pose.Legs = 0.15 * math.sin(clock * 6)
		if not moving then
			-- shuffles its feet with each stroke
			pose.Thigh, pose.LeftThigh = 0.25 * swing, -0.25 * swing
		end
	elseif name == "restock" then
		-- reaching up to a high shelf and back down for the next item, hands taking turns
		legs(pose, stride, if moving then 0.9 else 0)
		if not moving then
			local beat = clock * 2.6
			pose.UpperArm = 3.5 + 1.1 * math.cos(beat)
			pose.LeftUpperArm = 3.5 - 1.1 * math.cos(beat)
			pose.Forearm = 0.5 + 0.5 * math.max(0, -math.cos(beat))
			pose.LeftForearm = 0.5 + 0.5 * math.max(0, math.cos(beat))
			pose.Hand = 0.6 * math.sin(beat * 2)
			pose.LeftHand = -pose.Hand
			pose.Head = 0.6 + 0.3 * math.cos(beat)
			-- up on its toes at the top of each reach
			pose.Legs = 0.2 * math.abs(math.cos(beat))
			pose.Shin, pose.LeftShin = -0.2 * math.abs(math.cos(beat)), -0.2 * math.abs(math.cos(beat))
		end
	elseif name == "grab" then
		pose.UpperArm, pose.LeftUpperArm = 2.6, 2.6
		pose.Forearm, pose.LeftForearm = 1, 1
	elseif name == "stall" or name == "wake" then
		-- frozen mid step; waking adds hard jerks
		pose.Thigh, pose.LeftThigh, pose.LeftShin = 0.7, -0.5, -0.4
		pose.UpperArm, pose.LeftUpperArm = -0.4, 0.5
		pose.Head = 0.3
		for i, leg in CRAWLER_LEGS do
			pose[leg] = if i % 2 == 0 then 0.6 else -0.3
		end
		if name == "wake" and math.sin(clock * 13) > 0.7 then
			pose.Head = 1.1
			pose.UpperArm = 1.5
		end
	elseif name == "crouch" then
		-- a curious robot copying a crouching player: knees bent, low, arms tucked in
		pose.Thigh, pose.LeftThigh = 1.6, 1.6
		pose.Shin, pose.LeftShin = -2.2, -2.2
		pose.Legs = -0.6
		pose.UpperArm, pose.LeftUpperArm = 0.8, 0.8
		pose.Forearm, pose.LeftForearm = 1.4, 1.4
		pose.Head = 0.25 + 0.1 * math.sin(clock * 0.7)
	elseif name == "offer" then
		-- holding the thing it wants up high in both hands, as if showing it to you
		legs(pose, stride, if moving then 0.7 else 0)
		pose.UpperArm = 4 + 0.15 * math.sin(clock * 1.5)
		pose.LeftUpperArm = 4 + 0.15 * math.sin(clock * 1.5 + 0.5)
		pose.Forearm, pose.LeftForearm = 0.6, 0.6
		pose.Head = 0.5
	elseif name == "tug" then
		-- both hands on a piece someone is prying, leaning back and heaving
		local heave = math.sin(clock * 5)
		pose.UpperArm, pose.LeftUpperArm = 2.4 + 0.2 * heave, 2.4 + 0.2 * heave
		pose.Forearm, pose.LeftForearm = 0.3, 0.3
		pose.Thigh, pose.LeftThigh = 0.6, -0.4
		pose.Legs = -0.3 + 0.15 * heave
		pose.Head = -0.3
	else -- idle
		pose.Head = 0.15 * math.sin(clock * 0.8)
	end
	return pose
end

return RobotPoses
