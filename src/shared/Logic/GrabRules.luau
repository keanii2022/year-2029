-- Who may grab what, and where a carried prop may be placed. Returns ok plus a reason when denied.
local GrabRules = {}

export type GrabCheck = {
	alive: boolean,
	alreadyCarrying: boolean,
	carriedByOther: boolean,
	distance: number,
	reach: number,
}

export type PlaceCheck = {
	groundFound: boolean,
	distance: number,
	reach: number,
	heightAboveFeet: number,
	maxHeightAboveFeet: number,
	blocked: boolean,
}

function GrabRules.canGrab(check: GrabCheck): (boolean, string?)
	if not check.alive then
		return false, "dead"
	end
	if check.alreadyCarrying then
		return false, "hands full"
	end
	if check.carriedByOther then
		return false, "taken"
	end
	if check.distance > check.reach then
		return false, "too far"
	end
	return true, nil
end

function GrabRules.canPlace(check: PlaceCheck): (boolean, string?)
	if not check.groundFound then
		return false, "no ground"
	end
	if check.distance > check.reach then
		return false, "too far"
	end
	if check.heightAboveFeet > check.maxHeightAboveFeet then
		return false, "too high"
	end
	if check.blocked then
		return false, "blocked"
	end
	return true, nil
end

return GrabRules
