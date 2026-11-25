-- How a dog that doesn't trust you yet reacts to how you move. No meter on screen: it freezes and
-- watches, backs off if you walk straight at it, bolts if you sprint at it or shoot nearby, and
-- settles, sniffs and steps closer if you crouch and move slowly. Food in your hand draws it in.
export type Reaction = "watch" | "backoff" | "run" | "stay" | "sniff" | "creep"
export type Input = {
	stage: string, -- DogTrust stage of the closest player ("wary" or "eats" here)
	distance: number,
	stance: string?, -- "Walk" | "Sprint" | "Crouch"
	speed: number, -- the player's flat speed, studs per second
	closing: number, -- how fast they come toward the dog (negative: moving away)
	holdingFood: boolean,
	spooked: boolean, -- a bad move happened a moment ago
	calmFor: number, -- seconds they've been crouched and slow nearby
}
export type Settings = {
	WaryDistance: number,
	CautiousDistance: number,
	Wary: {
		SlowSpeed: number,
		ClosingSpeed: number,
		SprintRange: number,
		SniffAfter: number,
		StepAfter: number,
		FoodDistance: number,
	},
}

local DogWary = {}

local function keepDistance(stage: string, settings: Settings): number
	return if stage == "eats" then settings.CautiousDistance else settings.WaryDistance
end

local function isSlow(input: Input, settings: Settings): boolean
	return input.stance == "Crouch" and input.speed <= settings.Wary.SlowSpeed
end

-- Sprinting straight at it from close enough is a bad move, like a shot nearby.
function DogWary.isBadMove(input: Input, settings: Settings): boolean
	return input.stance == "Sprint"
		and input.closing >= settings.Wary.ClosingSpeed
		and input.distance <= settings.Wary.SprintRange
end

-- Crouched and slow long enough: one step closer, then back to sniffing (the server resets calmFor).
function DogWary.react(input: Input, settings: Settings): Reaction
	local wary = settings.Wary
	if input.spooked or DogWary.isBadMove(input, settings) then
		return "run"
	end
	local keep = keepDistance(input.stage, settings)
	local slow = isSlow(input, settings)
	local still = input.speed <= wary.SlowSpeed
	if input.distance < keep and input.closing >= wary.ClosingSpeed then
		return "backoff"
	end
	if input.holdingFood and still then
		return if input.distance > wary.FoodDistance then "creep" else "stay"
	end
	if input.distance < keep * 0.6 and not slow then
		return "backoff"
	end
	if not slow then
		return "watch"
	end
	if input.calmFor < wary.SniffAfter then
		return "stay"
	elseif input.calmFor < wary.StepAfter or input.distance <= DogWary.closest(input.stage, settings) then
		return "sniff"
	end
	return "creep"
end

-- The nearest crouching alone gets it to come; food in hand lets it come right up.
function DogWary.closest(stage: string, settings: Settings): number
	return keepDistance(stage, settings) * 0.5
end

return DogWary
