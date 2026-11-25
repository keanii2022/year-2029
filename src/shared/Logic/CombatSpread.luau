-- How wide a shot can stray from the crosshair, in degrees: the gun's hip or aimed base, the bloom
-- its recent shots built up, and how you're moving. The client rolls a direction inside the cone.
local CombatSpread = {}

export type SpreadGun = {
	hipSpread: number?,
	adsSpread: number?,
	bloomPerShot: number?,
	bloomMax: number?, -- the widest the hip cone gets with bloom, before movement
}

export type SpreadState = {
	aim: number, -- 0 at the hip, 1 fully aimed
	bloom: number,
	moving: boolean,
	airborne: boolean,
	crouching: boolean,
}

export type SpreadTuning = {
	walk: number, -- degrees added while moving on the ground
	airborne: number, -- degrees added in the air (instead of walk)
	crouchScale: number,
}

function CombatSpread.cone(gun: SpreadGun, state: SpreadState, tuning: SpreadTuning): number
	local hip = gun.hipSpread or 0
	local ads = gun.adsSpread or hip
	local aim = math.clamp(state.aim, 0, 1)
	local cone = hip + (ads - hip) * aim + math.max(state.bloom, 0)
	if state.airborne then
		cone += tuning.airborne
	else
		if state.moving then
			cone += tuning.walk
		end
		if state.crouching then
			cone *= tuning.crouchScale
		end
	end
	return cone
end

-- Bloom after one more shot, capped so the hip cone never passes bloomMax.
function CombatSpread.bloomAfterShot(gun: SpreadGun, bloom: number): number
	local most = math.max((gun.bloomMax or 0) - (gun.hipSpread or 0), 0)
	return math.min(bloom + (gun.bloomPerShot or 0), most)
end

function CombatSpread.recover(bloom: number, dt: number, rate: number): number
	return math.max(bloom - rate * dt, 0)
end

-- A point spread evenly over the cone's disc from two random numbers 0..1, as yaw and pitch degrees.
function CombatSpread.offset(cone: number, radiusRoll: number, angleRoll: number): (number, number)
	local radius = cone * math.sqrt(math.clamp(radiusRoll, 0, 1))
	local angle = angleRoll * math.pi * 2
	return math.cos(angle) * radius, math.sin(angle) * radius
end

return CombatSpread
