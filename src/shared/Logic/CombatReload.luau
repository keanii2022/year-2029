-- Magazine and reload rules. The mag is how many of the cells in the bag are loaded, so the bag
-- stays the one source of truth: a shot spends a cell from both, a reload only moves the count up
-- to what the bag holds, and dropping your bag can't duplicate or lose cells.
local CombatReload = {}

export type ReloadCheck = {
	alive: boolean,
	carrying: boolean,
	cuffed: boolean?,
	hasGun: boolean,
	reloading: boolean,
	mag: number,
	magSize: number,
	bag: number,
}

-- The mag can never hold more than the cells still in the bag (they may have been dropped).
function CombatReload.loaded(mag: number, bag: number): number
	return math.clamp(mag, 0, math.max(bag, 0))
end

function CombatReload.refill(magSize: number, bag: number): number
	return math.clamp(bag, 0, magSize)
end

-- Cells in the bag that aren't in the mag.
function CombatReload.reserve(mag: number, bag: number): number
	return math.max(0, bag - CombatReload.loaded(mag, bag))
end

function CombatReload.canReload(check: ReloadCheck): (boolean, string?)
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
	local mag = CombatReload.loaded(check.mag, check.bag)
	if mag >= check.magSize then
		return false, "full"
	end
	if check.bag <= mag then
		return false, "no cells"
	end
	return true, nil
end

local function smoothStep(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- slack below 1 lets the server finish a little early, so a shot sent the moment the client's own
-- reload ends isn't refused for arriving first.
function CombatReload.isDone(startedAt: number, now: number, duration: number, slack: number): boolean
	return now - startedAt >= duration * slack
end

export type ReloadTimes = {
	magSize: number,
	reloadTime: number,
	emptyReloadTime: number?, -- an empty mag also racks the slide or bolt at the end
	shellReloadTime: number?, -- loads one shell at a time instead of swapping a mag
	pumpTime: number?,
}

-- Whether this reload starts from an empty gun, so it ends with a rack.
function CombatReload.isEmpty(gun: ReloadTimes, mag: number): boolean
	return mag <= 0 and (gun.emptyReloadTime ~= nil or gun.shellReloadTime ~= nil)
end

-- How long a reload takes from mag (already loaded), with bag cells to fill from when known.
-- Shell by shell guns take a share per missing shell plus a pump when empty.
function CombatReload.timeFor(gun: ReloadTimes, mag: number, bag: number?): number
	local shellTime = gun.shellReloadTime
	if shellTime then
		local fillTo = if bag then math.min(gun.magSize, bag) else gun.magSize
		local shells = math.max(fillTo - mag, 1)
		return shells * shellTime + (if mag <= 0 then gun.pumpTime or 0 else 0)
	end
	if mag <= 0 and gun.emptyReloadTime then
		return gun.emptyReloadTime
	end
	return gun.reloadTime
end

-- How far the slide or bolt is pulled back, 0..1, at progress through an empty reload: back over
-- the first part of the rack window, snapped forward over its last third.
function CombatReload.rack(progress: number, from: number, to: number): number
	if progress <= from or progress >= to or to <= from then
		return 0
	end
	local share = (progress - from) / (to - from)
	if share < 2 / 3 then
		return smoothStep(share * 1.5)
	end
	return 1 - (share - 2 / 3) * 3
end

function CombatReload.shouldAutoReload(mag: number, bag: number): boolean
	return CombatReload.loaded(mag, bag) <= 0 and bag > 0
end

-- How far the blaster is tipped down for the reload, 0..1: it dips over the first share of the
-- reload, holds while the mag is swapped, and comes back up over the last share.
function CombatReload.motion(t: number, duration: number, dipShare: number, riseShare: number): number
	if t <= 0 or t >= duration or duration <= 0 then
		return 0
	end
	local progress = t / duration
	if progress < dipShare then
		return smoothStep(progress / dipShare)
	end
	if progress > 1 - riseShare then
		return smoothStep((1 - progress) / riseShare)
	end
	return 1
end

return CombatReload
