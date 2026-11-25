-- Player footsteps, no Roblox: which floor a material counts as, which step sound a stance makes on
-- it, and when a walking body puts its next foot down.
local Footsteps = {}

export type Step = { sound: string, volume: number, rollOff: { number } }

-- "concrete", "metal" or "wood" for an Enum.Material name; anything unlisted sounds like concrete.
function Footsteps.floor(material: string, floors: { [string]: string }): string
	return floors[material] or "concrete"
end

-- Crouching is one soft step on any floor; walking and sprinting pick the floor's own sound.
function Footsteps.step(stance: string, floor: string, settings: any): Step
	if stance == "Crouch" then
		local crouch = settings.Crouch
		return { sound = crouch.Sound, volume = crouch.Volume, rollOff = crouch.RollOff }
	end
	local kind = if stance == "Sprint" then settings.Sprint else settings.Walk
	return { sound = kind.Prefix .. floor, volume = kind.Volume, rollOff = kind.RollOff }
end

-- The head bob's phase runs 0..2pi per two steps, lowest at 0 and pi: a foot lands each time it
-- passes one of those.
function Footsteps.footDown(lastPhase: number, phase: number): boolean
	return math.floor(lastPhase / math.pi) ~= math.floor(phase / math.pi)
end

-- For bodies without a camera bob: walked distance builds up and every `stride` studs is a step.
-- Returns whether a foot lands now and the distance carried over.
function Footsteps.advance(walked: number, moved: number, stride: number): (boolean, number)
	walked += moved
	if walked >= stride then
		return true, walked % stride
	end
	return false, walked
end

return Footsteps
