-- Stats, nights survived, cosmetic unlocks and what a player is allowed to wear. No Roblox here.
local Scores = {}

export type Unlock = { stat: string, at: number }
export type Cosmetic = { id: string, label: string, unlock: Unlock? }
export type Cosmetics = { [string]: { Cosmetic } }
export type StatDef = { key: string, label: string, minutes: boolean? }

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function isStat(defs: { StatDef }, key: string): boolean
	for _, def in defs do
		if def.key == key then
			return true
		end
	end
	return false
end

-- Adds a whole, positive amount to a known stat. Returns the new value, or nil if refused.
function Scores.add(stats: { [string]: number }, defs: { StatDef }, key: string, amount: number): number?
	if not isStat(defs, key) or not isFinite(amount) or amount < 1 then
		return nil
	end
	stats[key] = (stats[key] or 0) + math.floor(amount)
	return stats[key]
end

-- Sets a known stat to value when that beats what's there (best-of stats like BestHaul).
-- Returns true when it went up.
function Scores.raise(stats: { [string]: number }, defs: { StatDef }, key: string, value: number): boolean
	if not isStat(defs, key) or not isFinite(value) or math.floor(value) <= (stats[key] or 0) then
		return false
	end
	stats[key] = math.floor(value)
	return true
end

-- Week number for weekly boards: weeks since the Unix epoch, starting Mondays at 00:00 UTC.
-- Day 0 (1 Jan 1970) was a Thursday, so the first Monday is day 4.
function Scores.weekOf(unixSeconds: number): number
	return math.floor((math.floor(unixSeconds / 86400) + 3) / 7)
end

export type Weekly = { week: number, nights: number }

-- Keeps this week's best nights-in-one-life; a new week starts again from this life.
-- Returns true when the record changed.
function Scores.recordWeekLife(weekly: Weekly, week: number, nights: number): boolean
	if weekly.week ~= week then
		weekly.week = week
		weekly.nights = 0
	end
	if nights <= weekly.nights then
		return false
	end
	weekly.nights = math.floor(nights)
	return true
end

-- This week's best, or 0 when the saved record is from another week
function Scores.weekValue(weekly: Weekly, week: number): number
	return if weekly.week == week then weekly.nights else 0
end

-- OrderedDataStore name suffix for a board: weekly boards get the week number, so each week is a
-- fresh store and the old ones simply stop being read
function Scores.boardKey(stat: string, weekly: boolean?, week: number): string
	return if weekly then `{stat}_W{week}` else stat
end

-- Keeps the longest life (seconds) on record. Returns true if this one beat it.
function Scores.recordLife(stats: { [string]: number }, seconds: number): boolean
	if not isFinite(seconds) or seconds <= (stats.LongestLife or 0) then
		return false
	end
	stats.LongestLife = math.floor(seconds)
	return true
end

-- A night counts when the same life was already going when the night started.
function Scores.survivedNight(lifeStartedAt: number?, nightStartedAt: number?): boolean
	return lifeStartedAt ~= nil and nightStartedAt ~= nil and lifeStartedAt <= nightStartedAt
end

function Scores.isUnlocked(def: Cosmetic, stats: { [string]: number }): boolean
	local unlock = def.unlock
	return unlock == nil or (stats[unlock.stat] or 0) >= unlock.at
end

local function find(list: { Cosmetic }, id: string?): Cosmetic?
	for _, def in list do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- id nil takes the slot off. Otherwise it has to exist and be unlocked.
function Scores.canEquip(
	cosmetics: Cosmetics,
	slot: string,
	id: string?,
	stats: { [string]: number }
): boolean
	local list = cosmetics[slot]
	if not list then
		return false
	end
	if id == nil then
		return true
	end
	local def = find(list, id)
	return def ~= nil and Scores.isUnlocked(def, stats)
end

-- What actually gets worn: saved picks that are still unlocked. A slot with nothing picked
-- falls back to its first free option (so everyone has a colour).
function Scores.wearing(
	cosmetics: Cosmetics,
	chosen: { [string]: string },
	stats: { [string]: number }
): { [string]: string }
	local result = {}
	for slot, list in cosmetics do
		local def = find(list, chosen[slot])
		if def and Scores.isUnlocked(def, stats) then
			result[slot] = def.id
		elseif chosen[slot] == nil then
			for _, option in list do
				if option.unlock == nil then
					result[slot] = option.id
					break
				end
			end
		end
	end
	return result
end

-- Labels of cosmetics unlocked by going from `before` to `after` stats.
function Scores.newUnlocks(
	cosmetics: Cosmetics,
	before: { [string]: number },
	after: { [string]: number }
): { string }
	local labels = {}
	for _, list in cosmetics do
		for _, def in list do
			if def.unlock and not Scores.isUnlocked(def, before) and Scores.isUnlocked(def, after) then
				table.insert(labels, def.label)
			end
		end
	end
	table.sort(labels)
	return labels
end

function Scores.formatStat(value: number, minutes: boolean?): string
	if minutes then
		return `{math.floor(value / 60)} min`
	end
	return tostring(math.floor(value))
end

-- "Nights survived 3/5" for a locked cosmetic.
function Scores.unlockHint(unlock: Unlock, defs: { StatDef }, stats: { [string]: number }): string
	for _, def in defs do
		if def.key == unlock.stat then
			local have = Scores.formatStat(math.min(stats[unlock.stat] or 0, unlock.at), def.minutes)
			return `{def.label} {have}/{Scores.formatStat(unlock.at, def.minutes)}`
		end
	end
	return unlock.stat
end

return Scores
