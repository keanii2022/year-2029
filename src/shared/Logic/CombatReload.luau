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

-- slack below 1 lets the server finish a little early, so a shot sent the moment the client's own
-- reload ends isn't refused for arriving first.
function CombatReload.isDone(startedAt: number, now: number, duration: number, slack: number): boolean
	return now - startedAt >= duration * slack
end

function CombatReload.shouldAutoReload(mag: number, bag: number): boolean
	return CombatReload.loaded(mag, bag) <= 0 and bag > 0
end

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- How far the blaster is tipped down for the reload, 0..1: it dips over the first share of the
-- reload, holds while the mag is swapped, and comes back up over the last share.
function CombatReload.motion(t: number, duration: number, dipShare: number, riseShare: number): number
	if t <= 0 or t >= duration or duration <= 0 then
		return 0
	end
	local progress = t / duration
	if progress < dipShare then
		return smooth(progress / dipShare)
	end
	if progress > 1 - riseShare then
		return smooth((1 - progress) / riseShare)
	end
	return 1
end

return CombatReload
