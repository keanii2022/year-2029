-- A damped spring that pulls a value back to its target. Kicks add up instead of restarting, so
-- held auto fire keeps climbing and shaking until the trigger is let go.
local Spring = {}

export type Spring = {
	position: number,
	velocity: number,
	target: number,
	stiffness: number,
	dampingRatio: number,
}

-- A long frame (a hitch or a phone stutter) would skip the whole kick, so steps are capped.
local MAX_STEP = 1 / 30

function Spring.new(stiffness: number?, dampingRatio: number?): Spring
	local k = stiffness or 300
	local ratio = dampingRatio or 0.7
	return {
		position = 0,
		velocity = 0,
		target = 0,
		stiffness = k,
		dampingRatio = ratio,
	}
end

function Spring.impulse(spring: Spring, velocity: number)
	spring.velocity += velocity
end

-- The velocity that carries a resting spring out to `peak` before it turns back.
function Spring.velocityForPeak(spring: Spring, peak: number): number
	local omega = math.sqrt(spring.stiffness)
	local ratio = spring.dampingRatio
	if ratio >= 1 then
		return peak * omega * math.exp(1)
	end
	local root = math.sqrt(1 - ratio * ratio)
	local turnAngle = math.atan2(root, ratio)
	return peak * omega * math.exp(ratio * turnAngle / root)
end

-- An impulse sized in the units you see: from rest the spring swings out about `peak`.
function Spring.kick(spring: Spring, peak: number)
	Spring.impulse(spring, Spring.velocityForPeak(spring, peak))
end

-- Puts the spring somewhere with no speed, to swing back from there (the equip raise).
function Spring.reset(spring: Spring, position: number)
	spring.position = position
	spring.velocity = 0
end

-- Solved exactly rather than nudged forward, so it feels the same at 30 and 240 frames a second.
function Spring.step(spring: Spring, dt: number): number
	local t = math.clamp(dt, 0, MAX_STEP)
	local omega = math.sqrt(spring.stiffness)
	local ratio = spring.dampingRatio
	local offset = spring.position - spring.target
	local velocity = spring.velocity
	local fade = math.exp(-ratio * omega * t)
	if ratio < 1 then
		local decay = ratio * omega
		local turn = omega * math.sqrt(1 - ratio * ratio)
		local cosine, sine = math.cos(turn * t), math.sin(turn * t)
		offset, velocity =
			fade * (offset * cosine + (velocity + decay * offset) / turn * sine),
			fade * (velocity * cosine - (decay * velocity + omega * omega * offset) / turn * sine)
	else
		local lead = velocity + omega * offset
		offset, velocity = (offset + lead * t) * fade, (velocity - omega * lead * t) * fade
	end
	spring.position = spring.target + offset
	spring.velocity = velocity
	return spring.position
end

return Spring
