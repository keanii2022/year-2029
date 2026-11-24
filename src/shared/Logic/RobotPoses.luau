-- Procedural limb poses until the real clips are imported in Studio. Each pose returns a joint value
-- per part for ModelRig.setPose (1 = one full swing, about 30 degrees; negative swings the other way).
-- stride: walk cycle in radians, advanced by how far the robot moved. clock: seconds, for idle motion.
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

function RobotPoses.limbs(name: string, stride: number, clock: number, moving: boolean): { [string]: number }
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
		pose.Forearm, pose.LeftForearm = 0.8, 0.8
	elseif name == "sweep" then
		-- arms low and together, pushing a broom side to side, head down at the floor
		local swing = math.sin(clock * 3)
		legs(pose, stride, if moving then 0.6 else 0)
		pose.UpperArm = 1.2 + 0.6 * swing
		pose.LeftUpperArm = 1.0 + 0.6 * swing
		pose.Forearm, pose.LeftForearm = 0.6, 0.6
		pose.Hand = 0.3 * swing
		pose.Head = -0.5
		pose.Legs = 0.1 * math.sin(clock * 6)
	elseif name == "restock" then
		-- reaching up to a high shelf, hands taking turns
		legs(pose, stride, if moving then 0.9 else 0)
		if not moving then
			pose.UpperArm = 4.4 + 0.4 * math.sin(clock * 1.6)
			pose.LeftUpperArm = 4.2 + 0.4 * math.sin(clock * 1.6 + 1.5)
			pose.Forearm, pose.LeftForearm = 0.5, 0.5
			pose.Hand = 0.5 * math.sin(clock * 3)
			pose.Head = 0.8
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
	else -- idle
		pose.Head = 0.15 * math.sin(clock * 0.8)
	end
	return pose
end

return RobotPoses
