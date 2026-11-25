-- Pure gun math and shot rules. Returns ok plus a reason when a shot is refused.
local Combat = {}

export type Gun = {
	rank: number,
	ammo: string,
	damage: number,
	minDamage: number,
	falloffStart: number,
	falloffEnd: number,
	range: number,
	fireInterval: number,
	mode: "semi" | "auto" | "burst" | "pump" | "single-action",
	magSize: number,
	reloadTime: number,
	burstCount: number?,
	burstInterval: number?,
	pellets: number?, -- shotgun: damage is per pellet
	spread: number?, -- degrees, the pellet pattern's outer ring
	pumpTime: number?, -- seconds the pump racks after a shot (inside fireInterval)
	cockTime: number?, -- seconds the hammer takes to come back before a single-action shot
	flare: boolean?, -- leaves a light burning where it lands
	robotWeapon: boolean?, -- also fires RobotGear's disruptor arc
}

export type FireCheck = {
	alive: boolean,
	carrying: boolean,
	cuffed: boolean?,
	hasGun: boolean,
	reloading: boolean?,
	ammo: number,
	sinceLastShot: number,
	minInterval: number,
}

export type ShotCheck = {
	originOffset: number,
	maxOriginOffset: number,
	directionLength: number,
}

function Combat.damageAt(gun: Gun, distance: number): number
	if distance <= gun.falloffStart then
		return gun.damage
	end
	if distance >= gun.falloffEnd then
		return gun.minDamage
	end
	local t = (distance - gun.falloffStart) / (gun.falloffEnd - gun.falloffStart)
	return gun.damage + (gun.minDamage - gun.damage) * t
end

-- The gun the client says is in hand, if it's a real gun the player owns.
function Combat.selectedGun(guns: { [string]: Gun }, gunId: any, owns: (string) -> boolean): Gun?
	if type(gunId) ~= "string" or not guns[gunId] or not owns(gunId) then
		return nil
	end
	return guns[gunId]
end

function Combat.canFire(check: FireCheck): (boolean, string?)
	if not check.alive then
		return false, "down"
	end
	if check.carrying then
		return false, "hands full"
	end
	if check.cuffed then
		return false, "cuffed"
	end
	if not check.hasGun then
		return false, "no gun"
	end
	if check.reloading then
		return false, "reloading"
	end
	if check.ammo <= 0 then
		return false, "no ammo"
	end
	if check.sinceLastShot < check.minInterval then
		return false, "too fast"
	end
	return true, nil
end

-- The client says where it fired from and which way. The origin must sit near its head and the
-- direction must be close to a unit vector. x ~= x catches NaN, which slips past every comparison.
function Combat.checkShot(check: ShotCheck): (boolean, string?)
	if check.originOffset ~= check.originOffset or check.originOffset > check.maxOriginOffset then
		return false, "bad origin"
	end
	if check.directionLength ~= check.directionLength or math.abs(check.directionLength - 1) > 0.05 then
		return false, "bad direction"
	end
	return true, nil
end

-- firstHitAt: distance to the first thing between the head and the target, nil if nothing.
function Combat.lineOfSightClear(targetDistance: number, firstHitAt: number?, slack: number): boolean
	return firstHitAt == nil or firstHitAt >= targetDistance - slack
end

function Combat.respawnSecondsLeft(downUntil: number, now: number): number
	return math.max(0, math.ceil(downUntil - now))
end

return Combat
