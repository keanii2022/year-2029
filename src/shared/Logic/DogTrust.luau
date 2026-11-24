-- How much the dog trusts one player. Feeding builds it, capped per visit and per in-game day so it
-- takes a couple of days; it fades slowly while the player stays away.
export type Stage = "wary" | "eats" | "wags" | "follows"
export type Record = {
	trust: number,
	lastFeed: number,
	visitGain: number,
	day: number,
	dayGain: number,
}
export type Settings = {
	Max: number,
	VisitCap: number,
	VisitGap: number,
	DayCap: number,
	FeedCooldown: number,
	DecayPerMinute: number,
	Stages: { Eats: number, Wags: number, Follows: number },
}
export type Refusal = "cooldown" | "full" | "visit" | "day"

local DogTrust = {}

local STAGE_RANK = { wary = 0, eats = 1, wags = 2, follows = 3 }

function DogTrust.new(): Record
	return { trust = 0, lastFeed = -math.huge, visitGain = 0, day = 0, dayGain = 0 }
end

local function caps(record: Record, now: number, day: number, settings: Settings): (number, number)
	local visitGain = if now - record.lastFeed > settings.VisitGap then 0 else record.visitGain
	local dayGain = if day ~= record.day then 0 else record.dayGain
	return visitGain, dayGain
end

-- How much one feeding could still add right now, or why it can't.
function DogTrust.room(record: Record, now: number, day: number, settings: Settings): (number, Refusal?)
	if now - record.lastFeed < settings.FeedCooldown then
		return 0, "cooldown"
	end
	if record.trust >= settings.Max then
		return 0, "full"
	end
	local visitGain, dayGain = caps(record, now, day, settings)
	local dayRoom = settings.DayCap - dayGain
	if dayRoom <= 0 then
		return 0, "day"
	end
	local visitRoom = settings.VisitCap - visitGain
	if visitRoom <= 0 then
		return 0, "visit"
	end
	return math.min(dayRoom, visitRoom, settings.Max - record.trust), nil
end

-- Feeds one item worth gain. Returns how much trust it added (0 when refused) and the refusal.
function DogTrust.feed(
	record: Record,
	gain: number,
	now: number,
	day: number,
	settings: Settings
): (number, Refusal?)
	local room, refusal = DogTrust.room(record, now, day, settings)
	if room <= 0 then
		return 0, refusal
	end
	local visitGain, dayGain = caps(record, now, day, settings)
	local added = math.min(gain, room)
	record.trust += added
	record.visitGain = visitGain + added
	record.dayGain = dayGain + added
	record.day = day
	record.lastFeed = now
	return added, nil
end

function DogTrust.decay(record: Record, dt: number, near: boolean, settings: Settings)
	if near then
		return
	end
	record.trust = math.max(0, record.trust - settings.DecayPerMinute * dt / 60)
end

function DogTrust.stage(trust: number, settings: Settings): Stage
	local stages = settings.Stages
	if trust >= stages.Follows then
		return "follows"
	elseif trust >= stages.Wags then
		return "wags"
	elseif trust >= stages.Eats then
		return "eats"
	end
	return "wary"
end

function DogTrust.atLeast(stage: Stage, wanted: Stage): boolean
	return STAGE_RANK[stage] >= STAGE_RANK[wanted]
end

-- Filled hearts out of count: one per stage passed, the last one fills at Follows.
function DogTrust.hearts(trust: number, settings: Settings, count: number): number
	return math.clamp(math.floor(trust / settings.Stages.Follows * count), 0, count)
end

-- First food in the preference list the player has any of.
function DogTrust.pickFood(foods: { string }, countOf: (string) -> number): string?
	for _, food in foods do
		if countOf(food) > 0 then
			return food
		end
	end
	return nil
end

return DogTrust
