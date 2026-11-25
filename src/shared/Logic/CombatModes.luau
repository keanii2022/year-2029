-- How each gun fires: semi (one shot per pull), auto (holds), burst (a few quick shots per pull),
-- pump (one shot, then racks the pump) and single-action (cocks the hammer, then fires). Also the
-- shotgun's pellet pattern and the moving parts' curves (pump, hammer, revolver drum).
local CombatModes = {}

export type Mode = "semi" | "auto" | "burst" | "pump" | "single-action"

export type FireMode = {
	mode: Mode,
	fireInterval: number,
	burstCount: number?,
	burstInterval: number?,
}

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

function CombatModes.shotsPerPull(gun: FireMode): number
	return if gun.mode == "burst" then gun.burstCount or 1 else 1
end

function CombatModes.holdsToFire(gun: FireMode): boolean
	return gun.mode == "auto"
end

-- Seconds between shot k and k+1 inside one pull (burst), or between pulls / auto shots.
function CombatModes.gapAfter(gun: FireMode, shotInPull: number): number
	if gun.mode == "burst" and shotInPull < CombatModes.shotsPerPull(gun) then
		return gun.burstInterval or gun.fireInterval
	end
	return gun.fireInterval
end

-- Server side: the shortest gap allowed before the next shot, given how many shots the current
-- burst has had. A burst may run quick; once it's spent (or a full interval has passed) the next
-- shot starts a new burst and must wait the full interval.
function CombatModes.minGap(gun: FireMode, burstShots: number): number
	if gun.mode == "burst" and burstShots > 0 and burstShots < CombatModes.shotsPerPull(gun) then
		return gun.burstInterval or gun.fireInterval
	end
	return gun.fireInterval
end

-- Server side: the burst count after a shot that came sinceLast seconds after the previous one.
function CombatModes.burstAfterShot(
	gun: FireMode,
	burstShots: number,
	sinceLast: number,
	slack: number
): number
	if gun.mode ~= "burst" then
		return 0
	end
	local spent = burstShots <= 0 or burstShots >= CombatModes.shotsPerPull(gun)
	if spent or sinceLast >= gun.fireInterval * slack then
		return 1
	end
	return burstShots + 1
end

-- Fixed spread pattern in degrees, { x = yaw, y = pitch } per pellet: one dead centre, the rest
-- around alternating inner and outer rings. Fixed so the shooter's tracers match the server's hits.
function CombatModes.pelletOffsets(pellets: number, spread: number): { { x: number, y: number } }
	local offsets = { { x = 0, y = 0 } }
	local ring = pellets - 1
	for index = 1, ring do
		local angle = (index - 1) / ring * math.pi * 2
		local radius = if index % 2 == 0 then spread * 0.55 else spread
		table.insert(offsets, { x = math.cos(angle) * radius, y = math.sin(angle) * radius })
	end
	return offsets
end

-- How far the pump is slid back, 0..1: back over the first half, forward over the second.
function CombatModes.pumpTravel(t: number, duration: number): number
	if duration <= 0 or t <= 0 or t >= duration then
		return 0
	end
	local progress = t / duration
	return if progress < 0.5 then smooth(progress * 2) else smooth((1 - progress) * 2)
end

-- How far the hammer is cocked back, 0..1. It eases back over cockTime from cockedAt and snaps
-- forward over snapTime once the shot goes off at firedAt (a shot before the cock started counts
-- as down).
function CombatModes.hammerLift(
	now: number,
	cockedAt: number,
	cockTime: number,
	firedAt: number,
	snapTime: number
): number
	if firedAt >= cockedAt then
		local sinceShot = now - firedAt
		if sinceShot >= snapTime or snapTime <= 0 then
			return 0
		end
		return 1 - sinceShot / snapTime
	end
	if cockTime <= 0 then
		return 1
	end
	return smooth((now - cockedAt) / cockTime)
end

-- Revolver drum turn in whole chambers: one per shot fired since the last reload, plus the share
-- of the current cock (the drum turns as the hammer comes back). Wraps every chambers.
function CombatModes.drumTurn(mag: number, magSize: number, chambers: number, cockShare: number): number
	local fired = math.max(0, magSize - mag)
	return (fired + math.clamp(cockShare, 0, 1)) % chambers
end

return CombatModes
