-- The save file: schema, versions and migration, cleaning up whatever comes back from the
-- DataStore, session locks, retry timing and locker rules. No Roblox here.
local Inventory = if script then require(script.Parent.Inventory) else require("./Inventory")
local SavesBlueprint = if script then require(script.Parent.SavesBlueprint) else require("./SavesBlueprint")

local Saves = {}

Saves.VERSION = 5

type Stack = Inventory.Stack

export type LaidOut = { job: string, day: number, at: number }
-- Daily mission streak: days counted and the last UTC day number that counted (Logic/Streak)
export type Streak = { days: number, lastDay: number }
-- Best nights in one life during week number `week` (Logic/Scores.weekOf)
export type Weekly = { week: number, nights: number }
-- Player audio sliders (0 to 1) and the gentler-scares toggle (client Controllers/AudioSettings)
export type Audio = { master: number, music: number, effects: number, voice: number, gentle: boolean }
-- The dog's rapport: highest trust stage reached (0-3) and the UTC day number it was last set (Logic/DogTrust)
export type DogRapport = { level: number, day: number }
export type Data = {
	version: number,
	locker: { Stack },
	blueprint: SavesBlueprint.Blueprint?,
	lastLaidOut: LaidOut?,
	stats: { [string]: number },
	cosmetics: { [string]: string },
	extras: { [string]: number },
	tokens: number,
	-- True until the first-day mission chain is finished; only brand-new saves start with it
	firstDay: boolean,
	streak: Streak,
	-- Ids of the 2029 Files found (Config.Files)
	files: { string },
	weekly: Weekly,
	audio: Audio,
	dog: DogRapport,
}
export type Rules = {
	items: Inventory.Items,
	stats: { string },
	cosmetics: { [string]: { { id: string } } },
	maxPieces: number,
	isKnownModel: (string) -> boolean,
}
export type Lock = { job: string, at: number }

local MAX_EXTRAS = 32
local MAX_KEY_LENGTH = 40
local MAX_FILES = 200

-- MIGRATIONS[n] turns a version n-1 save into version n. Version 0 is anything saved without a
-- version; its fields already match version 1, so it only gets stamped.
local MIGRATIONS: { [number]: (any) -> any } = {
	[1] = function(raw)
		raw.version = 1
		return raw
	end,
	-- Version 2 adds Tokens; everyone starts at zero and keeps their locker and stats
	[2] = function(raw)
		raw.tokens = 0
		raw.version = 2
		return raw
	end,
	-- Version 3 adds the first-day chain (only for brand-new saves, so everyone here skips it),
	-- the daily streak, the 2029 Files and the weekly longest life
	[3] = function(raw)
		raw.firstDay = false
		raw.streak = { days = 0, lastDay = 0 }
		raw.files = {}
		raw.weekly = { week = 0, nights = 0 }
		raw.version = 3
		return raw
	end,
	-- Version 4 adds the audio settings; everyone starts at full volume with normal scares
	[4] = function(raw)
		raw.audio = Saves.defaultAudio()
		raw.version = 4
		return raw
	end,
	-- Version 5 adds the dog's rapport; everyone starts a stranger to it
	[5] = function(raw)
		raw.dog = { level = 0, day = 0 }
		raw.version = 5
		return raw
	end,
}

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function wholeCount(value: any): number
	if not isFinite(value) then
		return 0
	end
	return math.max(0, math.floor(value))
end

function Saves.defaultAudio(): Audio
	return { master = 1, music = 1, effects = 1, voice = 1, gentle = false }
end

local function cleanLevel(value: any): number
	if not isFinite(value) then
		return 1
	end
	return math.clamp(value, 0, 1)
end

function Saves.cleanAudio(raw: any): Audio
	if type(raw) ~= "table" then
		return Saves.defaultAudio()
	end
	return {
		master = cleanLevel(raw.master),
		music = cleanLevel(raw.music),
		effects = cleanLevel(raw.effects),
		voice = cleanLevel(raw.voice),
		gentle = raw.gentle == true,
	}
end

function Saves.default(): Data
	return {
		version = Saves.VERSION,
		locker = {},
		blueprint = nil,
		lastLaidOut = nil,
		stats = {},
		cosmetics = {},
		extras = {},
		tokens = 0,
		firstDay = true,
		streak = { days = 0, lastDay = 0 },
		files = {},
		weekly = { week = 0, nights = 0 },
		audio = Saves.defaultAudio(),
		dog = { level = 0, day = 0 },
	}
end

-- Brings a raw save up to the current version. Returns nil and "newer" for a save from a newer
-- server build (mid-update), which this server must never overwrite.
function Saves.migrate(raw: { [any]: any }): ({ [any]: any }?, string?)
	local version = if isFinite(raw.version) then math.floor(raw.version) else 0
	if version > Saves.VERSION then
		return nil, "newer"
	end
	for target = version + 1, Saves.VERSION do
		raw = MIGRATIONS[target](raw)
	end
	return raw, nil
end

local function cleanLocker(raw: any, items: Inventory.Items): { Stack }
	local locker = {}
	if type(raw) ~= "table" then
		return locker
	end
	for _, entry in raw do
		if type(entry) == "table" and type(entry.id) == "string" and items[entry.id] then
			-- No slot cap here: shrinking Locker.Slots later must never delete anyone's stash
			Inventory.add(locker, items, entry.id, wholeCount(entry.count), math.huge)
		end
	end
	return locker
end

local function cleanStats(raw: any, keys: { string }): { [string]: number }
	local stats = {}
	for _, key in keys do
		stats[key] = if type(raw) == "table" then wholeCount(raw[key]) else 0
	end
	return stats
end

local function cleanCosmetics(raw: any, cosmetics: { [string]: { { id: string } } }): { [string]: string }
	local chosen = {}
	if type(raw) ~= "table" then
		return chosen
	end
	for slot, list in cosmetics do
		local id = raw[slot]
		for _, def in list do
			if def.id == id then
				chosen[slot] = id
			end
		end
	end
	return chosen
end

local function cleanExtras(raw: any): { [string]: number }
	local extras = {}
	if type(raw) ~= "table" then
		return extras
	end
	local kept = 0
	for key, value in raw do
		if kept >= MAX_EXTRAS then
			break
		end
		if type(key) == "string" and #key <= MAX_KEY_LENGTH and isFinite(value) then
			extras[key] = value
			kept += 1
		end
	end
	return extras
end

local function cleanLaidOut(raw: any): LaidOut?
	if type(raw) ~= "table" or type(raw.job) ~= "string" or not isFinite(raw.day) or not isFinite(raw.at) then
		return nil
	end
	return { job = raw.job, day = raw.day, at = raw.at }
end

local function cleanStreak(raw: any): Streak
	if type(raw) ~= "table" then
		return { days = 0, lastDay = 0 }
	end
	return { days = wholeCount(raw.days), lastDay = wholeCount(raw.lastDay) }
end

-- Unknown ids are kept, so a build that renames an entry never takes a find away
local function cleanFiles(raw: any): { string }
	local files = {}
	if type(raw) ~= "table" then
		return files
	end
	for _, id in raw do
		if #files >= MAX_FILES then
			break
		end
		if type(id) == "string" and #id <= MAX_KEY_LENGTH and not table.find(files, id) then
			table.insert(files, id)
		end
	end
	return files
end

local function cleanWeekly(raw: any): Weekly
	if type(raw) ~= "table" then
		return { week = 0, nights = 0 }
	end
	return { week = wholeCount(raw.week), nights = wholeCount(raw.nights) }
end

local DOG_MAX_LEVEL = 3

local function cleanDog(raw: any): DogRapport
	if type(raw) ~= "table" then
		return { level = 0, day = 0 }
	end
	return { level = math.min(DOG_MAX_LEVEL, wholeCount(raw.level)), day = wholeCount(raw.day) }
end

-- Keeps only fields and values this build understands. Never errors on bad input.
function Saves.sanitize(raw: { [any]: any }, rules: Rules): Data
	return {
		version = Saves.VERSION,
		locker = cleanLocker(raw.locker, rules.items),
		blueprint = SavesBlueprint.sanitize(raw.blueprint, rules.maxPieces, rules.isKnownModel),
		lastLaidOut = cleanLaidOut(raw.lastLaidOut),
		stats = cleanStats(raw.stats, rules.stats),
		cosmetics = cleanCosmetics(raw.cosmetics, rules.cosmetics),
		extras = cleanExtras(raw.extras),
		tokens = wholeCount(raw.tokens),
		firstDay = raw.firstDay == true,
		streak = cleanStreak(raw.streak),
		files = cleanFiles(raw.files),
		weekly = cleanWeekly(raw.weekly),
		audio = Saves.cleanAudio(raw.audio),
		dog = cleanDog(raw.dog),
	}
end

-- Raw DataStore value to clean data. The second value is "newer" (don't save over it),
-- "corrupt" (started fresh) or nil.
function Saves.load(raw: any, rules: Rules): (Data, string?)
	if raw == nil then
		return Saves.default(), nil
	end
	if type(raw) ~= "table" then
		return Saves.default(), "corrupt"
	end
	local migrated, problem = Saves.migrate(table.clone(raw))
	if not migrated then
		return Saves.default(), problem
	end
	return Saves.sanitize(migrated, rules), nil
end

-- Seconds to wait before retry number attempt (1-based): base, 2x, 4x ... capped at max.
function Saves.retryDelay(attempt: number, base: number, max: number): number
	return math.min(max, base * 2 ^ math.max(0, attempt - 1))
end

-- "ours" when this server holds the lock, "free" when nobody does (or the holder went quiet
-- for longer than expiry), else "taken".
function Saves.lockState(lock: any, job: string, now: number, expiry: number): "free" | "ours" | "taken"
	if type(lock) ~= "table" or type(lock.job) ~= "string" or not isFinite(lock.at) then
		return "free"
	end
	if lock.job == job then
		return "ours"
	end
	return if now - lock.at > expiry then "free" else "taken"
end

function Saves.canStore(
	id: string,
	items: Inventory.Items,
	blocked: { [string]: boolean }
): (boolean, string?)
	if not items[id] then
		return false, "unknown"
	end
	if blocked[id] then
		return false, "blocked"
	end
	return true, nil
end

-- Adds up to count to the locker within its slot limit. Returns how many fit.
function Saves.lockerAdd(
	locker: { Stack },
	items: Inventory.Items,
	id: string,
	count: number,
	slots: number
): number
	return Inventory.add(locker, items, id, wholeCount(count), slots)
end

function Saves.addTokens(data: Data, amount: number): number
	local added = wholeCount(amount)
	data.tokens += added
	return added
end

-- False (and nothing taken) when the amount isn't a positive whole number or there aren't enough
function Saves.spendTokens(data: Data, amount: number): boolean
	if not isFinite(amount) or amount <= 0 or amount ~= math.floor(amount) or data.tokens < amount then
		return false
	end
	data.tokens -= amount
	return true
end

return Saves
