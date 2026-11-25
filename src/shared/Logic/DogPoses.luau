-- Procedural dog poses until the real clips (idle, walk, run, sit, bark, bite) are imported in Studio.
-- limbs() gives a joint value per part for ModelRig.setPose (1 = about 30 degrees); body() gives how far
-- the body drops and pitches, since the body is the anchored root and moves with the whole model.
-- stride: gait cycle in radians, advanced by distance moved. clock: seconds, for idle motion.
local DogPoses = {}

local LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }

local function rest(): { [string]: number }
	local pose = { Head = 0, Jaw = 0, Tail = 0 }
	for _, name in LEGS do
		pose[name] = 0
	end
	return pose
end

local function gait(pose: { [string]: number }, stride: number, amount: number)
	local s = math.sin(stride)
	-- diagonal pairs move together, like a trot
	pose.LegFL, pose.LegBR = amount * s, amount * s
	pose.LegFR, pose.LegBL = -amount * s, -amount * s
end

function DogPoses.limbs(
	state: string,
	stride: number,
	clock: number,
	moving: boolean,
	wagging: boolean,
	tell: string?
): { [string]: number }
	local pose = rest()
	local fast = state == "flee" or state == "alert" or state == "bite"
	if moving then
		gait(pose, stride, if fast then 1.3 elseif state == "creep" then 0.45 else 0.8)
	end

	if state == "sit" then
		pose.LegBL, pose.LegBR = 2.2, 2.2
		pose.Head = 0.4 * math.sin(clock * 0.6)
	elseif state == "hide" then
		for _, name in LEGS do
			pose[name] = 2.4
		end
	elseif state == "eat" then
		pose.Jaw = 0.5 + 0.5 * math.sin(clock * 9)
	elseif state == "alert" then
		pose.Jaw = math.max(0, math.sin(clock * 14)) * 1.2 -- barking
	elseif state == "bite" then
		pose.Jaw = 1.6
		pose.Head = 0.6 * math.sin(clock * 30)
	elseif state == "flee" then
		pose.Jaw = 0.25 -- bared, growling
	elseif state == "flinch" then
		pose.Head = 0.5 -- turns its head away
	elseif state == "sniff" then
		-- nose working: small quick twitches and a little jaw
		pose.Head = 0.15 * math.sin(clock * 12)
		pose.Jaw = 0.12 * math.max(0, math.sin(clock * 10))
	elseif state == "watch" or state == "backoff" then
		pose.Head = 0 -- frozen, eyes on you
	elseif not moving then
		pose.Head = 0.6 * math.sin(clock * 0.4)
	end

	if tell == "tilt" then
		pose.Head = 0.7
	elseif tell == "sneeze" then
		pose.Jaw = 0.9 * math.max(0, math.sin(clock * 18))
		pose.Head = 0.2 * math.sin(clock * 18)
	end

	if wagging then
		pose.Tail = 1.2 * math.sin(clock * (if state == "hide" then 4 else 14))
	elseif state == "settle" or state == "sniff" or state == "creep" then
		pose.Tail = 0.35 * math.sin(clock * 2.5) -- slow, unsure wag
	elseif state == "flee" or state == "hide" or state == "flinch" or state == "backoff" then
		pose.Tail = -1 -- tucked
	end
	return pose
end

-- How far the body sinks (studs) and tips (degrees, positive is nose up) for a state.
function DogPoses.body(state: string): (number, number)
	if state == "sit" then
		return 0.35, 18
	elseif state == "hide" then
		return 0.55, 0
	elseif state == "eat" then
		return 0.1, -12
	elseif state == "flinch" then
		return 0.4, -10
	elseif state == "watch" or state == "backoff" or state == "creep" then
		-- low and wary, head below the shoulders (the rig has no ears or neck to lay back)
		return 0.22, -7
	elseif state == "sniff" then
		return 0.15, -9 -- stretched out toward you
	elseif state == "settle" then
		return 0.1, -3
	end
	return 0, 0
end

return DogPoses
