-- A builder robot's legs of work: walking to a piece (fetch), then carrying it to its slot (carry).
-- Each leg watches its own progress so the robot never stands stuck: no progress for a while (or a
-- wall in its way) re-paths, a few re-paths in a row or the leg's timeout gives the leg up, and the
-- caller skips that piece or slot and picks another. Pieces given up on are left alone a while.
-- FortPlan decides where pieces go; this only decides when to stop trying. No Roblox here.
export type Kind = "fetch" | "carry"
export type Leg = {
	kind: Kind,
	since: number,
	best: number, -- closest it has been to the leg's goal
	progressAt: number, -- when it last got ProgressStep closer
	repaths: number,
}
export type Settings = {
	FetchTimeout: number,
	CarryTimeout: number,
	StuckSeconds: number,
	Repaths: number,
	ProgressStep: number,
}
export type PlaceSettings = {
	CarryTimeout: number,
	PlaceTries: number, -- refusals for something fixed in the slot
	PlayerPlaceTries: number, -- refusals for a player standing in it: they usually move, so more
}
export type Step = "go" | "repath" | "give_up"

local BuildPlan = {}

-- A wall in the way re-paths sooner than a slow, unexplained stall.
local BLOCKED_SECONDS = 1

function BuildPlan.leg(kind: Kind, now: number, distance: number): Leg
	return { kind = kind, since = now, best = distance, progressAt = now, repaths = 0 }
end

function BuildPlan.step(leg: Leg, now: number, distance: number, blocked: boolean, settings: Settings): Step
	local timeout = if leg.kind == "fetch" then settings.FetchTimeout else settings.CarryTimeout
	if now - leg.since > timeout then
		return "give_up"
	end
	if distance < leg.best - settings.ProgressStep then
		leg.best = distance
		leg.progressAt = now
		leg.repaths = 0
		return "go"
	end
	local stalled = now - leg.progressAt
	if stalled > settings.StuckSeconds or (blocked and stalled > BLOCKED_SECONDS) then
		if leg.repaths >= settings.Repaths then
			return "give_up"
		end
		leg.repaths += 1
		leg.progressAt = now
		return "repath"
	end
	return "go"
end

-- Standing at the slot setting the piece down, where step() doesn't run: whether to stop trying this
-- slot. playerTries counts the refusals for a player in the way; tries counts every refusal.
function BuildPlan.stopPlacing(
	leg: Leg,
	now: number,
	tries: number,
	playerTries: number,
	settings: PlaceSettings
): boolean
	if now - leg.since > settings.CarryTimeout then
		return true
	end
	return tries - playerTries >= settings.PlaceTries or playerTries >= settings.PlayerPlaceTries
end

-- Whether a builder may set down one more piece. Filling a gap below the most its fort has had
-- (peak) is a repair and always allowed; a new piece also needs room in the owner's pieces for today.
function BuildPlan.canPlace(count: number, peak: number, placedToday: number, maxPieces: number): boolean
	if count >= maxPieces then
		return false
	end
	return count < peak or placedToday < maxPieces
end

-- The plan has as many pieces as this builder puts up.
function BuildPlan.full(count: number, maxPieces: number): boolean
	return count >= maxPieces
end

function BuildPlan.skip(skipped: { [any]: number }, id: any, now: number, seconds: number)
	skipped[id] = now + seconds
end

-- Pieces still being left alone right now, as a set; forgets the ones whose time is up.
function BuildPlan.skipping(skipped: { [any]: number }, now: number): { [any]: boolean }
	local set = {}
	for id, untilTime in skipped do
		if now >= untilTime then
			skipped[id] = nil
		else
			set[id] = true
		end
	end
	return set
end

return BuildPlan
