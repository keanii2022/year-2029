-- The rules behind aisle 40's secrets (server and client SmileAisle). The smile-check booth can't
-- tell a smile from a bow: stand on its mark and bow (crouch, stand) Bows times in a steady rhythm
-- and it lets you into the night manager's office. Also the aisle sign that reads 41 while nobody
-- is looking at it. No Roblox.
local SmileCheck = {}

export type Bows = { count: number, downAt: number?, upAt: number? }
export type BowRules = { Bows: number, DownMin: number, DownMax: number, GapMax: number }
export type Sign = { hiddenFor: number, flipped: boolean, seenFor: number, armed: boolean }
export type SignRules = { HiddenFor: number, Chance: number, SeenFor: number }

function SmileCheck.newBows(): Bows
	return { count = 0, downAt = nil, upAt = nil }
end

-- One look at a player: crouched now or not, standing on the mark or not, at time now (seconds).
-- A bow counts when the crouch is held between DownMin and DownMax; a bow too slow, too quick, or
-- too long after the last one starts the count again. Stepping off the mark forgets it all.
-- Returns true on the bow that completes the set (and starts a fresh count).
function SmileCheck.stepBows(
	state: Bows,
	rules: BowRules,
	now: number,
	crouched: boolean,
	onMark: boolean
): boolean
	if not onMark then
		state.count, state.downAt, state.upAt = 0, nil, nil
		return false
	end
	local upAt = state.upAt
	if upAt and state.downAt == nil and now - upAt > rules.GapMax then
		state.count, state.upAt = 0, nil
	end
	local downAt = state.downAt
	if crouched and downAt == nil then
		state.downAt = now
	elseif not crouched and downAt ~= nil then
		local held = now - downAt
		state.downAt = nil
		if held >= rules.DownMin and held <= rules.DownMax then
			state.count += 1
			state.upAt = now
		else
			state.count, state.upAt = 0, nil
		end
		if state.count >= rules.Bows then
			state.count, state.upAt = 0, nil
			return true
		end
	end
	return false
end

-- Flat point-in-rect, rect in the same space as (x, z)
function SmileCheck.inside(
	rect: { x0: number, z0: number, x1: number, z1: number },
	x: number,
	z: number
): boolean
	return x >= rect.x0 and x <= rect.x1 and z >= rect.z0 and z <= rect.z1
end

function SmileCheck.newSign(): Sign
	return { hiddenFor = 0, flipped = false, seenFor = 0, armed = true }
end

-- The aisle 40 sign, seen from one player. Once it has been off screen for HiddenFor seconds it
-- may (Chance, rolled once per look away) quietly read 41; when it comes back on screen it holds
-- 41 for SeenFor seconds, just long enough to doubt yourself, then snaps back.
-- Returns whether it reads the wrong number right now.
function SmileCheck.stepSign(
	state: Sign,
	rules: SignRules,
	onScreen: boolean,
	dt: number,
	roll: () -> number
): boolean
	if onScreen then
		state.hiddenFor = 0
		state.armed = true
		if state.flipped then
			state.seenFor += dt
			if state.seenFor >= rules.SeenFor then
				state.flipped, state.seenFor = false, 0
			end
		end
		return state.flipped
	end
	state.hiddenFor += dt
	if state.armed and not state.flipped and state.hiddenFor >= rules.HiddenFor then
		state.armed = false
		if roll() < rules.Chance then
			state.flipped, state.seenFor = true, 0
		end
	end
	return state.flipped
end

return SmileCheck
