-- Rules for pressing things: who may use what, which behaviour a hit part picks, next channel,
-- hiding, cushion finds and the timing of spinning parts. No Roblox here.
local InteractKinds = if script then require(script.Parent.InteractKinds) else require("./InteractKinds")

type Behaviour = InteractKinds.Behaviour

local Interact = {}

export type UseCheck = {
	alive: boolean,
	carrying: boolean,
	distance: number,
	reach: number,
	cooling: boolean,
}

export type HideAction = "enter" | "leave" | "reveal"

function Interact.canUse(check: UseCheck): (boolean, string?)
	if not check.alive then
		return false, "dead"
	end
	if check.carrying then
		return false, "hands full"
	end
	if check.distance > check.reach then
		return false, "too far"
	end
	if check.cooling then
		return false, "busy"
	end
	return true, nil
end

-- Distance from a point to a box, both in the box's own space (box centered on the origin).
function Interact.distanceToBox(
	x: number,
	y: number,
	z: number,
	halfX: number,
	halfY: number,
	halfZ: number
): number
	local dx = math.max(math.abs(x) - halfX, 0)
	local dy = math.max(math.abs(y) - halfY, 0)
	local dz = math.max(math.abs(z) - halfZ, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Picks what a press does: a byPart override, one drawer of an `each` set, or the whole object.
-- key names the state slot ("" for the whole object), parts are the ones that move.
function Interact.resolve(behaviour: Behaviour, partName: string?): (Behaviour, string, { string })
	local byPart = behaviour.byPart
	if partName and byPart and byPart[partName] then
		local sub = byPart[partName]
		return sub, partName, sub.parts or {}
	end
	local parts = behaviour.parts or {}
	if partName and behaviour.each and table.find(parts, partName) then
		return behaviour, partName, { partName }
	end
	return behaviour, "", parts
end

-- Attribute the server sets on the model so clients can show "Open" or "Close".
function Interact.stateAttribute(key: string): string
	return if key == "" then "On" else `On_{key}`
end

function Interact.verb(behaviour: Behaviour, on: boolean, hidden: boolean): string
	if hidden then
		return "Get out"
	end
	local kind = behaviour.kind
	if kind == "open" then
		return if on then "Close" else "Open"
	elseif kind == "toggle" then
		return if on then "Turn off" else "Turn on"
	elseif kind == "hide" then
		return "Hide"
	elseif kind == "channel" then
		return if behaviour.canTurnOff then "Change channel" else "Next picture"
	elseif kind == "cycle" then
		return "Start"
	elseif kind == "vend" then
		return "Buy a snack"
	elseif kind == "sit" then
		return if behaviour.search then "Sit and search" else "Sit"
	elseif kind == "phone" then
		return if on then "Answer" else "Dial"
	end
	return "Press"
end

-- 0 is off. With canTurnOff the dial runs off, 1..count, off again; without it, it loops 1..count.
function Interact.nextChannel(index: number, count: number, canTurnOff: boolean?): number
	if count <= 0 then
		return 0
	end
	local nextIndex = index + 1
	if nextIndex > count then
		return if canTurnOff then 0 else 1
	end
	return nextIndex
end

-- occupant and user are any ids (players on the server).
function Interact.hideAction(occupant: any?, user: any): HideAction
	if occupant == nil then
		return "enter"
	end
	if occupant == user then
		return "leave"
	end
	return "reveal"
end

-- Two rolls in [0, 1): one for whether there's anything, one for how much.
function Interact.cushionFind(
	findRoll: number,
	amountRoll: number,
	chance: number,
	min: number,
	max: number
): number
	if findRoll >= chance then
		return 0
	end
	return math.clamp(min + math.floor(amountRoll * (max - min + 1)), min, max)
end

-- Spinning parts: t is the share of a full turn.
function Interact.spinT(elapsed: number, turnsPerSecond: number): number
	return (elapsed * turnsPerSecond) % 1
end

-- Drifting parts (lava lamp blobs): smooth 0 -> 1 -> 0 over one period.
function Interact.bobT(elapsed: number, period: number): number
	return (1 - math.cos(elapsed / period * 2 * math.pi)) / 2
end

function Interact.pick<T>(list: { T }, roll: number): T?
	if #list == 0 then
		return nil
	end
	return list[math.clamp(math.floor(roll * #list) + 1, 1, #list)]
end

return Interact
