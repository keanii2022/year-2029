-- Rules for handcuffs: who can be cuffed, and how long it lasts with mashing.
-- Positions and facings are flat { x, z } tables so this runs in Lune without Vector3.
export type Flat = { x: number, z: number }

export type CuffCheck = {
	cufferPosition: Flat,
	targetPosition: Flat,
	targetFacing: Flat,
	targetHealth: number,
	targetMaxHealth: number,
	targetAlive: boolean,
	targetCuffed: boolean,
	cufferCuffed: boolean,
	hasCuffs: boolean,
	sinceTargetLastCuffed: number?, -- nil if never cuffed
}

export type Settings = {
	Range: number,
	BehindDot: number,
	LowHealthFraction: number,
	TargetCooldown: number,
	Duration: number,
	MinDuration: number,
	MashSeconds: number,
	MashMinInterval: number,
}

export type Hold = { startedAt: number, endsAt: number, lastMashAt: number }

local Cuffs = {}

-- How directly behind the target the cuffer stands: 1 dead behind, 0 side-on, -1 in front.
function Cuffs.behindness(cufferPosition: Flat, targetPosition: Flat, targetFacing: Flat): number
	local dx, dz = cufferPosition.x - targetPosition.x, cufferPosition.z - targetPosition.z
	local distance = math.sqrt(dx * dx + dz * dz)
	local facingLength = math.sqrt(targetFacing.x * targetFacing.x + targetFacing.z * targetFacing.z)
	if distance == 0 or facingLength == 0 then
		return 0
	end
	return -(dx * targetFacing.x + dz * targetFacing.z) / (distance * facingLength)
end

-- Returns true, or false and the reason it was refused.
function Cuffs.canCuff(check: CuffCheck, settings: Settings): (boolean, string?)
	if not check.hasCuffs then
		return false, "no cuffs"
	end
	if check.cufferCuffed then
		return false, "cuffer is cuffed"
	end
	if not check.targetAlive then
		return false, "target is down"
	end
	if check.targetCuffed then
		return false, "already cuffed"
	end
	local since = check.sinceTargetLastCuffed
	if since and since < settings.TargetCooldown then
		return false, "cooldown"
	end
	local dx = check.cufferPosition.x - check.targetPosition.x
	local dz = check.cufferPosition.z - check.targetPosition.z
	if dx * dx + dz * dz > settings.Range * settings.Range then
		return false, "too far"
	end
	local low = check.targetMaxHealth > 0
		and check.targetHealth / check.targetMaxHealth <= settings.LowHealthFraction
	local behind = Cuffs.behindness(check.cufferPosition, check.targetPosition, check.targetFacing)
		>= settings.BehindDot
	if not low and not behind then
		return false, "not behind"
	end
	return true, nil
end

function Cuffs.start(now: number, settings: Settings): Hold
	return { startedAt = now, endsAt = now + settings.Duration, lastMashAt = -math.huge }
end

-- One button press from the cuffed player. Returns true if it counted.
function Cuffs.mash(hold: Hold, now: number, settings: Settings): boolean
	if now - hold.lastMashAt < settings.MashMinInterval then
		return false
	end
	hold.lastMashAt = now
	hold.endsAt = math.max(hold.endsAt - settings.MashSeconds, hold.startedAt + settings.MinDuration)
	return true
end

function Cuffs.isOver(hold: Hold, now: number): boolean
	return now >= hold.endsAt
end

-- Moves up to count from one bag to another. add returns how many fit; whatever
-- didn't fit goes back, so nothing is lost when the robber's bag is full.
function Cuffs.transfer(
	remove: (count: number) -> number,
	add: (count: number) -> number,
	giveBack: (count: number) -> (),
	count: number
): number
	local taken = remove(count)
	if taken <= 0 then
		return 0
	end
	local added = add(taken)
	if added < taken then
		giveBack(taken - added)
	end
	return added
end

return Cuffs
