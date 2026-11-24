-- Blueprints: a fort's layout (which props, where, turned how) relative to an anchor at the
-- drawer's feet. Saves the layout, never the props. Plus the once-per-day lay-out rule and
-- which ghost slot a dropped prop snaps into. No Roblox here.
local SavesBlueprint = {}

-- Position in studs and orientation in degrees (Roblox YXZ order), relative to the anchor.
export type Piece = { model: string, x: number, y: number, z: number, rx: number, ry: number, rz: number }
export type Blueprint = { pieces: { Piece } }
export type Slot = { model: string, x: number, y: number, z: number, filled: boolean }
export type When = { job: string, day: number, at: number }

local POSITION_STEP = 0.05
local ANGLE_STEP = 0.5
local MAX_NAME_LENGTH = 60

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function round(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

local function cleanPiece(raw: any, isKnownModel: (string) -> boolean): Piece?
	if type(raw) ~= "table" or type(raw.model) ~= "string" or #raw.model > MAX_NAME_LENGTH then
		return nil
	end
	for _, key in { "x", "y", "z", "rx", "ry", "rz" } do
		if not isFinite(raw[key]) then
			return nil
		end
	end
	if not isKnownModel(raw.model) then
		return nil
	end
	return {
		model = raw.model,
		x = round(raw.x, POSITION_STEP),
		y = round(raw.y, POSITION_STEP),
		z = round(raw.z, POSITION_STEP),
		rx = round(raw.rx, ANGLE_STEP),
		ry = round(raw.ry, ANGLE_STEP),
		rz = round(raw.rz, ANGLE_STEP),
	}
end

local function distance(piece: Piece): number
	return math.sqrt(piece.x * piece.x + piece.y * piece.y + piece.z * piece.z)
end

-- Turns props near the drawer (already relative to the anchor) into a blueprint: unknown or
-- broken entries dropped, only those within radius, nearest first, at most maxPieces.
-- Nil when nothing is left to draw.
function SavesBlueprint.capture(
	candidates: { any },
	radius: number,
	maxPieces: number,
	isKnownModel: (string) -> boolean
): Blueprint?
	local pieces = {}
	for _, raw in candidates do
		local piece = cleanPiece(raw, isKnownModel)
		if piece and distance(piece) <= radius then
			table.insert(pieces, piece)
		end
	end
	table.sort(pieces, function(a, b)
		return distance(a) < distance(b)
	end)
	while #pieces > maxPieces do
		table.remove(pieces)
	end
	return if #pieces > 0 then { pieces = pieces } else nil
end

-- A blueprint loaded from a save, cleaned. Nil if there's nothing usable in it.
function SavesBlueprint.sanitize(raw: any, maxPieces: number, isKnownModel: (string) -> boolean): Blueprint?
	if type(raw) ~= "table" or type(raw.pieces) ~= "table" then
		return nil
	end
	local pieces = {}
	for _, entry in raw.pieces do
		if #pieces >= maxPieces then
			break
		end
		local piece = cleanPiece(entry, isKnownModel)
		if piece then
			table.insert(pieces, piece)
		end
	end
	return if #pieces > 0 then { pieces = pieces } else nil
end

-- Facing in degrees snapped to the nearest quarter turn, so a fort lays out square to the aisles.
function SavesBlueprint.snapYaw(degrees: number): number
	return (round(degrees, 90) % 360)
end

-- Once per day, daytime only. Same server: the day counter must have moved on. A different
-- server has its own counter, so there it takes a full day-night cycle of real time instead.
function SavesBlueprint.canLayOut(
	last: When?,
	now: When,
	phase: string,
	cycleSeconds: number
): (boolean, string?)
	if phase ~= "Day" then
		return false, "day only"
	end
	if not last then
		return true, nil
	end
	local waited = if last.job == now.job then now.day > last.day else now.at - last.at >= cycleSeconds
	if not waited then
		return false, "once per day"
	end
	return true, nil
end

-- The nearest empty slot for this model within snapDistance of (x, y, z), or nil.
function SavesBlueprint.matchSlot(
	slots: { Slot },
	model: string,
	x: number,
	y: number,
	z: number,
	snapDistance: number
): number?
	local best, bestDistance = nil, snapDistance
	for index, slot in slots do
		if not slot.filled and slot.model == model then
			local dx, dy, dz = slot.x - x, slot.y - y, slot.z - z
			local gap = math.sqrt(dx * dx + dy * dy + dz * dz)
			if gap <= bestDistance then
				best, bestDistance = index, gap
			end
		end
	end
	return best
end

function SavesBlueprint.remaining(slots: { Slot }): number
	local left = 0
	for _, slot in slots do
		if not slot.filled then
			left += 1
		end
	end
	return left
end

return SavesBlueprint
