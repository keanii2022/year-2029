-- Prying a piece out of someone else's fort: who has to pry, how far along it is, and whether
-- the server should let the carry start.
local GrabPry = {}

export type PryCheck = {
	started: boolean,
	samePiece: boolean,
	elapsed: number,
	duration: number,
	grace: number,
	distance: number,
	reach: number,
}

-- Only the placer grabs instantly. World furniture has no placer and stays instant for everyone.
function GrabPry.needsPry(placedBy: number?, userId: number): boolean
	return placedBy ~= nil and placedBy ~= userId
end

function GrabPry.progress(elapsed: number, duration: number): number
	if duration <= 0 then
		return 1
	end
	return math.clamp(elapsed / duration, 0, 1)
end

-- True when a repeating effect (noise, owner warning) should fire again.
function GrabPry.due(last: number?, now: number, interval: number): boolean
	return last == nil or now - last >= interval
end

-- The client finishes its timer one trip ahead of the server, so a small grace covers jitter.
function GrabPry.canFinish(check: PryCheck): (boolean, string?)
	if not check.started or not check.samePiece then
		return false, "not prying"
	end
	if check.distance > check.reach then
		return false, "too far"
	end
	if check.elapsed + check.grace < check.duration then
		return false, "too soon"
	end
	return true, nil
end

return GrabPry
