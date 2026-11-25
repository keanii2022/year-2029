-- How much one curious robot trusts one player, and what that makes it do. Trust is 0-100, earned
-- through gifts, teaching, repairs and nights survived together, capped per in-game day so it takes
-- a couple of days, and it fades while the player stays away. Stages: curious, watching, learning,
-- bonded (bonded also needs one night survived together). No Roblox here.
export type Stage = "curious" | "watching" | "learning" | "bonded"
export type Mode =
	"down"
	| "home"
	| "wait"
	| "doorway"
	| "pack"
	| "trail"
	| "beside"
	| "follow"
	| "build"
	| "night"
export type Record = {
	trust: number,
	day: number,
	dayGain: number,
	gifts: { [string]: number }, -- item id -> the day it was given
	teachDay: number,
	teachCount: number,
	survivedNight: boolean,
	away: number, -- seconds in a row the player has been away from it
}
export type Settings = {
	Max: number,
	DayCap: number,
	DecayPerMinute: number,
	Stages: { Watching: number, Learning: number, Bonded: number },
	Gift: number,
	Teach: number,
	TeachPerDay: number,
	Repair: number,
	Hide: number,
	RapportDaySeconds: number,
	BondedGraceSeconds: number?,
}
export type Refusal = "day" | "full" | "given" | "lessons" | "own"
export type Point = { x: number, z: number }
export type Candidate = { id: any, stage: Stage, trust: number, free: boolean }
export type OwnerInput = {
	owner: any?,
	ownerStage: Stage?,
	ownerTrust: number,
	ownerGoneFor: number, -- seconds the owner has been away (or out of the server)
	lockedUntil: number, -- no switching before this
	now: number,
	goneSeconds: number,
	margin: number?, -- how much more trust than the owner a challenger needs (none when nil)
	candidates: { Candidate },
}
export type ModeInput = {
	owned: boolean,
	stage: Stage,
	phase: string, -- "Day" | "Siren" | "Night"
	down: boolean,
	homeBound: boolean,
	ownerHere: boolean, -- the owner is still in the server
	hasWork: boolean, -- a fort plan with a slot it can fill
}

local RobotTrust = {}

RobotTrust.STAGES = { "curious", "watching", "learning", "bonded" } :: { Stage }
local RANK: { [Stage]: number } = { curious = 1, watching = 2, learning = 3, bonded = 4 }
-- A bonded robot keeps its bond through a loot run or a death this long before it starts to fade
local DEFAULT_BONDED_GRACE = 900

function RobotTrust.new(trust: number?): Record
	return {
		trust = trust or 0,
		day = 0,
		dayGain = 0,
		gifts = {},
		teachDay = 0,
		teachCount = 0,
		survivedNight = false,
		away = 0,
	}
end

function RobotTrust.rank(stage: Stage): number
	return RANK[stage]
end

function RobotTrust.atLeast(stage: Stage, wanted: Stage): boolean
	return RANK[stage] >= RANK[wanted]
end

-- The trust a stage starts at.
function RobotTrust.floor(stage: Stage, settings: Settings): number
	if stage == "bonded" then
		return settings.Stages.Bonded
	elseif stage == "learning" then
		return settings.Stages.Learning
	elseif stage == "watching" then
		return settings.Stages.Watching
	end
	return 0
end

function RobotTrust.stage(record: Record, settings: Settings): Stage
	local trust, stages = record.trust, settings.Stages
	if trust >= stages.Bonded and record.survivedNight then
		return "bonded"
	elseif trust >= stages.Learning then
		return "learning"
	elseif trust >= stages.Watching then
		return "watching"
	end
	return "curious"
end

-- Adds up to amount within the day's cap. Returns what was added and why it fell short.
local function add(record: Record, amount: number, day: number, settings: Settings): (number, Refusal?)
	if record.day ~= day then
		record.day, record.dayGain = day, 0
	end
	if record.trust >= settings.Max then
		return 0, "full"
	end
	local room = math.min(settings.DayCap - record.dayGain, settings.Max - record.trust)
	if room <= 0 then
		return 0, "day"
	end
	local added = math.min(amount, room)
	record.trust += added
	record.dayGain += added
	return added, nil
end

-- The item it wants: a big gain, once per item per day. A refused gift should not take the item.
function RobotTrust.gift(record: Record, item: string, day: number, settings: Settings): (number, Refusal?)
	if record.gifts[item] == day then
		return 0, "given"
	end
	local added, refusal = add(record, settings.Gift, day, settings)
	if added > 0 then
		record.gifts[item] = day
	end
	return added, refusal
end

function RobotTrust.canGift(record: Record, item: string, day: number): boolean
	return record.gifts[item] ~= day
end

-- Why a gift would be refused right now, without changing anything: checked before the item is
-- taken, so a refused gift keeps it.
function RobotTrust.giftRefusal(record: Record, item: string, day: number, settings: Settings): Refusal?
	if record.gifts[item] == day then
		return "given"
	elseif record.trust >= settings.Max then
		return "full"
	elseif record.day == day and record.dayGain >= settings.DayCap then
		return "day"
	end
	return nil
end

-- A bonded rapport from an earlier server: the first gift starts from at least this much trust.
function RobotTrust.headStart(record: Record, start: number)
	record.trust = math.max(record.trust, start)
end

-- A piece placed near it that stayed put and fortified: small, a few times a day.
function RobotTrust.teach(record: Record, day: number, settings: Settings): (number, Refusal?)
	if record.teachDay ~= day then
		record.teachDay, record.teachCount = day, 0
	end
	if record.teachCount >= settings.TeachPerDay then
		return 0, "lessons"
	end
	local added, refusal = add(record, settings.Teach, day, settings)
	if added > 0 then
		record.teachCount += 1
	end
	return added, refusal
end

-- Standing it back up after it was knocked down. Knocking it down yourself and fixing it pays nothing.
function RobotTrust.repair(
	record: Record,
	day: number,
	knockedItDown: boolean,
	settings: Settings
): (number, Refusal?)
	if knockedItDown then
		return 0, "own"
	end
	return add(record, settings.Repair, day, settings)
end

-- It ended the night with you or inside your fort.
function RobotTrust.hide(record: Record, day: number, settings: Settings): (number, Refusal?)
	return add(record, settings.Hide, day, settings)
end

function RobotTrust.decay(record: Record, dt: number, near: boolean, settings: Settings)
	dt = if dt == dt then math.max(0, dt) else 0
	if near then
		record.away = 0
		return
	end
	local away = (record.away or 0) + dt
	record.away = away
	local grace = if RobotTrust.stage(record, settings) == "bonded"
		then settings.BondedGraceSeconds or DEFAULT_BONDED_GRACE
		else 0
	local fading = math.min(dt, math.max(0, away - grace))
	record.trust = math.max(0, record.trust - settings.DecayPerMinute * fading / 60)
end

-- A whole stage lost (you shot it, or the pack took it for a night): back to the start of the stage
-- below. Bonded needs a fresh night together after that. Returns the new stage.
function RobotTrust.dropStage(record: Record, settings: Settings): Stage
	local rank = RANK[RobotTrust.stage(record, settings)]
	local below = RobotTrust.STAGES[math.max(1, rank - 1)]
	record.trust = math.min(record.trust, RobotTrust.floor(below, settings))
	if rank > 1 then
		record.survivedNight = false
	end
	return RobotTrust.stage(record, settings)
end

-- Kept through the night: within keepRadius of its owner or hidden inside their fort.
function RobotTrust.kept(ownerDistance: number?, hidden: boolean, keepRadius: number): boolean
	return hidden or (ownerDistance ~= nil and ownerDistance <= keepRadius)
end

-- Another player can win it over once its owner has been gone a while or trust has slipped below
-- bonded, and never while a fresh switch is still locked in.
function RobotTrust.canSwitch(
	ownerStage: Stage?,
	ownerGoneFor: number,
	lockedUntil: number,
	now: number,
	goneSeconds: number
): boolean
	if now < lockedUntil then
		return false
	end
	return ownerGoneFor >= goneSeconds or ownerStage == nil or RANK[ownerStage] < RANK.bonded
end

-- The same person: equal ids, or a rejoin (a new player object with the same user id).
local function personOf(id: any): any
	if typeof(id) == "Instance" then
		return (id :: any).UserId
	elseif type(id) == "table" and id.userId ~= nil then
		return id.userId
	end
	return id
end

local function samePerson(a: any, b: any): boolean
	return a == b or (a ~= nil and b ~= nil and personOf(a) == personOf(b))
end

-- The most trusting free candidate with more than `above` and at least `atLeast`; on a tie, the
-- current owner first, then whoever comes first.
local function best(candidates: { Candidate }, above: number, atLeast: number, owner: any?): Candidate?
	local found: Candidate? = nil
	for _, candidate in candidates do
		local trust = candidate.trust
		if
			candidate.free
			and RANK[candidate.stage] >= RANK.watching
			and trust > above
			and trust >= atLeast
		then
			if
				not found
				or trust > found.trust
				or (trust == found.trust and owner ~= nil and samePerson(candidate.id, owner))
			then
				found = candidate
			end
		end
	end
	return found
end

-- Who owns it after this tick, and whether that was a switch from one owner to another (which
-- locks the new owner in for a day). free = the candidate owns no other robot.
function RobotTrust.chooseOwner(input: OwnerInput): (any?, boolean)
	local owner = input.owner
	local ownerStage = input.ownerStage
	if owner ~= nil and ownerStage ~= nil and RANK[ownerStage] < RANK.watching then
		owner = nil -- trust slipped back to curious: it belongs to nobody again
	end
	if owner == nil then
		local first = best(input.candidates, -math.huge, -math.huge, input.owner)
		return if first then first.id else nil, false
	end
	for _, candidate in input.candidates do
		if candidate.id ~= owner and samePerson(candidate.id, owner) then
			owner = candidate.id -- the owner rejoined: same person, new player object
			break
		end
	end
	local challenger = best(input.candidates, input.ownerTrust, input.ownerTrust + (input.margin or 0), owner)
	if
		challenger
		and not samePerson(challenger.id, owner)
		and RobotTrust.canSwitch(
			ownerStage,
			input.ownerGoneFor,
			input.lockedUntil,
			input.now,
			input.goneSeconds
		)
	then
		return challenger.id, true
	end
	return owner, false
end

-- What it should be doing right now.
function RobotTrust.mode(input: ModeInput): Mode
	if input.down then
		return "down"
	elseif input.homeBound then
		return "home"
	elseif not input.owned then
		return if input.phase == "Night" then "pack" else "doorway"
	elseif not input.ownerHere then
		return "wait"
	elseif input.phase == "Night" then
		return "night"
	end
	local stage = input.stage
	if stage == "bonded" then
		return if input.hasWork and input.phase == "Day" then "build" else "follow"
	elseif stage == "learning" then
		return if input.phase == "Day" then "beside" else "follow"
	end
	return if input.phase == "Day" then "trail" else "follow"
end

-- Where to walk to stay keep studs from target, coming from `from`; nil when already close enough.
function RobotTrust.approach(from: Point, target: Point, keep: number, slack: number): Point?
	local dx, dz = from.x - target.x, from.z - target.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance <= keep + slack then
		return nil
	end
	if distance < 1e-3 then
		return { x = target.x, z = target.z }
	end
	return { x = target.x + dx / distance * keep, z = target.z + dz / distance * keep }
end

-- A spot off the target's right shoulder, given which way they face.
function RobotTrust.beside(target: Point, look: Point, distance: number): Point
	local length = math.sqrt(look.x * look.x + look.z * look.z)
	if length < 1e-3 then
		return { x = target.x + distance, z = target.z }
	end
	local rx, rz = -look.z / length, look.x / length
	return { x = target.x + rx * distance, z = target.z + rz * distance }
end

-- Saved rapport (the highest stage rank reached) after time away: one stage lost per real day.
function RobotTrust.rapport(rank: number, savedAt: number, now: number, settings: Settings): number
	local away = math.max(0, now - savedAt)
	return math.max(RANK.curious, rank - math.floor(away / settings.RapportDaySeconds))
end

-- Where a new robot's trust in you starts: a bonded rapport lets it skip straight to watching.
function RobotTrust.startTrust(rapportRank: number, settings: Settings): number
	return if rapportRank >= RANK.bonded then settings.Stages.Watching else 0
end

-- The next wanted item in the rotation after `current`.
function RobotTrust.nextWant(list: { string }, current: string?, offset: number): string?
	if #list == 0 then
		return nil
	end
	local index = if current then table.find(list, current) else nil
	if index then
		return list[index % #list + 1]
	end
	return list[(offset % #list) + 1]
end

return RobotTrust
