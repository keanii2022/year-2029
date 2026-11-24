-- The body at night: flashlight battery, holding your breath while hidden, getting winded.
local NightTricksBody = {}

export type Breath = { level: number, holding: boolean }
export type BreathEvent = "gasp" | nil

-- Battery left after dt seconds; only drains while the light is on.
function NightTricksBody.drainBattery(level: number, on: boolean, dt: number, settings: any): number
	if not on then
		return level
	end
	return math.max(0, level - settings.DrainPerSecond * dt)
end

-- What to do when a player switches the light on: "on", "swap" (use a battery item), or "dead".
function NightTricksBody.switchOn(level: number, hasSpare: boolean): "on" | "swap" | "dead"
	if level > 0 then
		return "on"
	end
	return if hasSpare then "swap" else "dead"
end

local function hash(n: number): number
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

-- Beam brightness share (0-1) at time t. Full above LowAt; below it dips get more frequent
-- as the battery runs out, and at 0 the beam is gone.
function NightTricksBody.flicker(level: number, t: number, settings: any): number
	if level <= 0 then
		return 0
	end
	if level >= settings.LowAt then
		return 1
	end
	local dipChance = 0.6 * (1 - level / settings.LowAt) + 0.05
	local slot = math.floor(t / settings.FlickerSlot)
	return if hash(slot) < dipChance then settings.FlickerDim else 1
end

function NightTricksBody.newBreath(settings: any): Breath
	return { level = settings.Max, holding = false }
end

-- Whether a player asking to hold their breath may start.
function NightTricksBody.canHold(breath: Breath, hidden: boolean, settings: any): boolean
	return hidden and breath.level >= settings.MinToStart
end

-- Steps breath by dt. Holding drains; running out lets go with a gasp. Not holding refills.
function NightTricksBody.stepBreath(breath: Breath, dt: number, settings: any): (Breath, BreathEvent)
	if not breath.holding then
		local refilled = math.min(settings.Max, breath.level + settings.RefillPerSecond * dt)
		return { level = refilled, holding = false }, nil
	end
	local level = breath.level - settings.DrainPerSecond * dt
	if level <= 0 then
		return { level = 0, holding = false }, "gasp"
	end
	return { level = level, holding = true }, nil
end

-- Effort builds while sprinting and fades at rest.
function NightTricksBody.stepEffort(effort: number, sprinting: boolean, dt: number, settings: any): number
	if sprinting then
		return math.min(settings.Max, effort + settings.SprintGain * dt)
	end
	return math.max(0, effort - settings.Rest * dt)
end

-- Heavy breathing plays after a sprint, not during it.
function NightTricksBody.isWinded(effort: number, sprinting: boolean, settings: any): boolean
	return not sprinting and effort > settings.BreatheAbove
end

return NightTricksBody
