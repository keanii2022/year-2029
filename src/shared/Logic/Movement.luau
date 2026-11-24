-- Pure movement math: stance, speed, head bob and sway. No Roblox services.
local Movement = {}

export type Stance = "Walk" | "Sprint" | "Crouch"

Movement.Stances = table.freeze({ Walk = true, Sprint = true, Crouch = true })

function Movement.isStance(value: any): boolean
	return type(value) == "string" and Movement.Stances[value] == true
end

-- Crouch wins over sprint; sprint only counts while actually moving.
function Movement.stance(sprintWanted: boolean, crouched: boolean, moveAmount: number): Stance
	if crouched then
		return "Crouch"
	end
	if sprintWanted and moveAmount > 0.1 then
		return "Sprint"
	end
	return "Walk"
end

function Movement.targetSpeed(config: any, stance: Stance): number
	if stance == "Sprint" then
		return config.SprintSpeed
	elseif stance == "Crouch" then
		return config.CrouchSpeed
	end
	return config.WalkSpeed
end

-- Frame-rate independent ease toward a target.
function Movement.smooth(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- Bob strength from real ground speed: 1 at walk speed, more when running, capped.
function Movement.bobAmount(config: any, groundSpeed: number): number
	return math.clamp(groundSpeed / config.WalkSpeed, 0, config.BobMaxAmount)
end

-- Phase advances with distance walked, so steps line up with the bob at any speed.
function Movement.advancePhase(config: any, phase: number, groundSpeed: number, dt: number): number
	return (phase + groundSpeed * dt / config.BobStride * 2 * math.pi) % (2 * math.pi)
end

-- Returns side offset, up offset (studs) and roll (degrees) for the camera.
function Movement.bobOffset(config: any, phase: number, amount: number): (number, number, number)
	local side = math.sin(phase) * config.BobSide * amount
	local up = -math.abs(math.cos(phase)) * config.BobUp * amount
	local roll = math.sin(phase) * config.BobRoll * amount
	return side, up, roll
end

-- Target roll in degrees for a given turn rate (radians/second), clamped.
function Movement.swayTarget(config: any, turnRate: number): number
	return math.clamp(-turnRate * config.SwayPerTurn, -config.SwayMax, config.SwayMax)
end

return Movement
