-- Daily missions: picking a varied list each morning and checking it against what the server sees.
-- No Roblox here; the server passes in facts about the player and a roll() in [0, 1).
local Items = if script then require(script.Parent.InventoryItems) else require("./InventoryItems")

export type Reward = { item: string, count: number }
export type Mission = {
	kind: string,
	text: string,
	reward: Reward,
	done: boolean,
	item: string?,
	place: string?,
	depth: number?,
	seconds: number?,
	-- find: the fewest of the item seen since the list was made, so picking one up counts
	low: number?,
	-- hide: seconds hidden in a row
	hiddenFor: number?,
	-- Part of the first-day chain: only the first unfinished step is live
	chain: boolean?,
	-- Where the screen-edge arrow points (a Vector3 the server fills in), if anywhere
	target: any?,
}
-- An installation that exists this server and how deep its middle is
export type Place = { kind: string, depth: number }
export type Context = { places: { Place }, canSurvive: boolean }
export type Facts = {
	count: (itemId: string) -> number,
	place: string?,
	depth: number,
	hidden: boolean,
	hauling: boolean,
	-- loot: inside a robot room, and how many items are in the bag
	inRoom: boolean?,
	carried: number?,
	-- bank: how many items are in the locker
	banked: number?,
	-- lore: read today's lore piece
	readLore: boolean?,
}

local Missions = {}

local function pickIndex(count: number, roll: () -> number): number
	return math.clamp(math.floor(roll() * count) + 1, 1, count)
end

local function pickFrom<T>(list: { T }, roll: () -> number): T
	return list[pickIndex(#list, roll)]
end

local function weighted<T>(entries: { T }, weightOf: (T) -> number, roll: () -> number): T?
	local total = 0
	for _, entry in entries do
		total += weightOf(entry)
	end
	if total <= 0 then
		return nil
	end
	local target = roll() * total
	for _, entry in entries do
		target -= weightOf(entry)
		if target < 0 then
			return entry
		end
	end
	return entries[#entries]
end

local function fill(text: string, values: { [string]: string }): string
	return (string.gsub(text, "{(%w+)}", function(key)
		return values[key]
	end))
end

function Missions.itemName(itemId: string): string
	local def = Items[itemId]
	return if def then def.name else itemId
end

function Missions.placeName(config: any, kind: string): string
	return config.Places[kind] or (string.gsub(kind, "_", " "))
end

function Missions.rewardText(config: any, reward: Reward): string
	return fill(config.RewardLine, { count = tostring(reward.count), item = Missions.itemName(reward.item) })
end

function Missions.pickReward(config: any, roll: () -> number): Reward
	if roll() < config.RareChance then
		return { item = config.RareReward.item, count = config.RareReward.count }
	end
	local entry = weighted(config.Rewards, function(e: any)
		return e.weight
	end, roll) :: any
	return { item = entry.item, count = entry.count }
end

-- Farther installations first; any installation if none are deep enough
function Missions.pickPlace(config: any, places: { Place }, roll: () -> number): Place?
	if #places == 0 then
		return nil
	end
	local far = {}
	for _, place in places do
		if place.depth >= config.VisitMinDepth then
			table.insert(far, place)
		end
	end
	return pickFrom(if #far > 0 then far else places, roll)
end

local function available(kind: string, context: Context): boolean
	if kind == "visit" then
		return #context.places > 0
	elseif kind == "survive" then
		return context.canSurvive
	end
	return true
end

local function build(config: any, kind: string, context: Context, roll: () -> number): Mission
	local def = config.Kinds[kind]
	local mission: Mission =
		{ kind = kind, text = "", reward = Missions.pickReward(config, roll), done = false }
	local values: { [string]: string } = {}
	if kind == "find" then
		mission.item = pickFrom(def.items, roll)
		values.item = Missions.itemName(mission.item :: string)
	elseif kind == "visit" then
		local place = Missions.pickPlace(config, context.places, roll) :: Place
		mission.place = place.kind
		values.place = Missions.placeName(config, place.kind)
	elseif kind == "deep" then
		mission.depth = pickFrom(def.depths, roll)
	elseif kind == "hide" then
		mission.seconds = pickFrom(def.seconds, roll)
		values.seconds = tostring(mission.seconds)
	end
	mission.text = fill(pickFrom(def.texts, roll), values)
	return mission
end

-- config.PerDay missions, never two of the same kind
function Missions.pick(config: any, context: Context, roll: () -> number): { Mission }
	local kinds = {}
	for kind in config.Kinds do
		if available(kind, context) then
			table.insert(kinds, kind)
		end
	end
	-- Pairs order isn't stable, and the same roll should give the same list
	table.sort(kinds)
	local list = {}
	while #list < config.PerDay and #kinds > 0 do
		local kind = weighted(kinds, function(k: string)
			return config.Kinds[k].weight
		end, roll) :: string
		table.remove(kinds, table.find(kinds, kind) :: number)
		table.insert(list, build(config, kind, context, roll))
	end
	return list
end

-- The first-day chain from config.FirstDay.Steps, in order, with fixed rewards
function Missions.firstDay(config: any): { Mission }
	local list = {}
	for _, step in config.FirstDay.Steps do
		table.insert(list, {
			kind = step.kind,
			text = step.text,
			reward = { item = step.reward.item, count = step.reward.count },
			done = false,
			chain = true,
		})
	end
	return list
end

-- The mission that points at today's lore piece
function Missions.lore(config: any, roll: () -> number): Mission
	return {
		kind = "lore",
		text = pickFrom(config.Lore.texts, roll),
		reward = Missions.pickReward(config, roll),
		done = false,
	}
end

-- The missions to check right now: a chain's first unfinished step, or every unfinished one
function Missions.active(list: { Mission }): { Mission }
	local live = {}
	for _, mission in list do
		if not mission.done then
			table.insert(live, mission)
			if mission.chain then
				break
			end
		end
	end
	return live
end

-- Counts going up from the lowest seen since the mission started (find, bank)
local function rose(mission: Mission, count: number): boolean
	local low = mission.low
	if low == nil or count < low then
		mission.low = count
		return false
	end
	return count > low
end

-- Moves one mission forward by dt seconds of facts. True the moment it's done.
-- survive is only finished by Missions.dawn.
function Missions.check(mission: Mission, facts: Facts, dt: number): boolean
	if mission.done then
		return false
	end
	local kind = mission.kind
	local done = false
	if kind == "find" then
		done = rose(mission, facts.count(mission.item :: string))
	elseif kind == "loot" then
		-- Only what goes into the bag while standing in a robot room counts
		local carried = facts.carried or 0
		if facts.inRoom then
			done = rose(mission, carried)
		else
			mission.low = carried
		end
	elseif kind == "bank" then
		done = rose(mission, facts.banked or 0)
	elseif kind == "lore" then
		done = facts.readLore == true
	elseif kind == "visit" then
		done = facts.place == mission.place
	elseif kind == "deep" then
		done = facts.depth >= (mission.depth :: number)
	elseif kind == "hide" then
		mission.hiddenFor = if facts.hidden then (mission.hiddenFor or 0) + dt else 0
		done = (mission.hiddenFor :: number) >= (mission.seconds :: number)
	elseif kind == "haul" then
		done = facts.hauling
	end
	mission.done = done
	return done
end

-- At dawn: finishes survive missions for someone who made it. Returns the ones just finished.
function Missions.dawn(list: { Mission }, survived: boolean): { Mission }
	local finished = {}
	if not survived then
		return finished
	end
	for _, mission in list do
		if mission.kind == "survive" and not mission.done then
			mission.done = true
			table.insert(finished, mission)
		end
	end
	return finished
end

function Missions.allDone(list: { Mission }): boolean
	for _, mission in list do
		if not mission.done then
			return false
		end
	end
	return #list > 0
end

export type Row = { text: string, done: boolean, reward: string, waiting: boolean, target: any? }

-- What the client draws: text, done, reward line, whether it's a chain step not reached yet, and
-- the arrow target of the live ones
function Missions.snapshot(config: any, list: { Mission }): { Row }
	local live = Missions.active(list)
	local rows = {}
	for _, mission in list do
		local isLive = table.find(live, mission) ~= nil
		table.insert(rows, {
			text = mission.text,
			done = mission.done,
			reward = Missions.rewardText(config, mission.reward),
			waiting = not mission.done and not isLive,
			target = if isLive then mission.target else nil,
		})
	end
	return rows
end

return Missions
