-- Rules for the life everyone sees: what spooks pigeons and rats, when a mannequin may change pose,
-- and how the greeter's voice wears down night after night. No Roblox here.
local HauntSight = if script then require(script.Parent.HauntSight) else require("./HauntSight")

type Point = HauntSight.Point

local HauntLife = {}

export type Watcher = {
	position: Point,
	look: Point,
	speed: number,
	flashlight: boolean,
}
export type Spook = {
	near: number, -- anyone this close
	sprintNear: number?, -- anyone sprinting this close
	sprintSpeed: number?,
	beamRange: number?, -- a lit flashlight pointing at it from this close
	beamHalfAngle: number?,
}

-- Index of the first watcher that spooks a critter at position, or nil.
function HauntLife.spookedBy(position: Point, watchers: { Watcher }, rules: Spook): number?
	for index, watcher in watchers do
		local distance = HauntSight.distance(position, watcher.position)
		if distance <= rules.near then
			return index
		end
		if
			rules.sprintNear
			and distance <= rules.sprintNear
			and watcher.speed >= (rules.sprintSpeed or math.huge)
		then
			return index
		end
		if
			rules.beamRange
			and watcher.flashlight
			and HauntSight.inView(
				watcher.position,
				watcher.look,
				position,
				rules.beamHalfAngle or 0,
				rules.beamRange
			)
		then
			return index
		end
	end
	return nil
end

-- A mannequin changes only when someone is near enough to notice and nobody is looking at it.
function HauntLife.mannequinMayMove(
	position: Point,
	viewers: { HauntSight.Viewer },
	halfAngle: number,
	viewRange: number,
	nearPlayer: number
): boolean
	local near = false
	for _, viewer in viewers do
		if HauntSight.distance(position, viewer.eye) <= nearPlayer then
			near = true
			break
		end
	end
	return near and not HauntSight.anyoneLooking(viewers, position, halfAngle, viewRange)
end

-- A different pose from the current one, picked by roll in [0, 1).
function HauntLife.nextPose(poses: { [string]: any }, current: string?, roll: number): string?
	local names = {}
	for name in poses do
		if name ~= current then
			table.insert(names, name)
		end
	end
	if #names == 0 then
		return current
	end
	table.sort(names)
	return names[math.clamp(math.floor(roll * #names) + 1, 1, #names)]
end

export type Voice = {
	SpeedDropPerNight: number,
	MinSpeed: number,
	DistortionPerNight: number,
	MaxDistortion: number,
}

-- Playback speed and distortion level for the greeter on a given day (day 1 sounds clean).
function HauntLife.greeterVoice(voice: Voice, day: number): (number, number)
	local nights = math.max(day - 1, 0)
	local speed = math.max(1 - voice.SpeedDropPerNight * nights, voice.MinSpeed)
	local distortion = math.min(voice.DistortionPerNight * nights, voice.MaxDistortion)
	return speed, distortion
end

-- Offsets for a critter group: count points scattered within spread of the centre, picked by
-- rolls in [0, 1) from next().
function HauntLife.scatter(count: number, spread: number, next: () -> number): { { x: number, z: number } }
	local points = {}
	for _ = 1, count do
		local angle = next() * math.pi * 2
		local radius = math.sqrt(next()) * spread
		table.insert(points, { x = math.cos(angle) * radius, z = math.sin(angle) * radius })
	end
	return points
end

return HauntLife
