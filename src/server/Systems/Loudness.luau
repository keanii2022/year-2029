-- Every sound that matters to robots goes through here: Loudness.emit(position, level, source).
-- Robots (step 8) subscribe with onSound or ask recent(position) for what they could have heard.
-- Players hear the real 3D Sound; this is only the game's record of the noise.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LoudnessLogic = require(ReplicatedStorage.Shared.Logic.Loudness)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Interact.Loudness

export type Event = {
	position: Vector3,
	level: LoudnessLogic.Level,
	source: Instance?,
	time: number,
}

local Loudness = {}

local events: { Event } = {}
local listeners: { (Event) -> () } = {}

local function sameRoom(a: Vector3, b: Vector3): boolean
	local ok, roomA = pcall(Warehouse.roomAt, a)
	if not ok or not roomA then
		return false
	end
	local _, roomB = pcall(Warehouse.roomAt, b)
	return roomA == roomB
end

function Loudness.emit(position: Vector3, level: LoudnessLogic.Level, source: Instance?): Event?
	if not LoudnessLogic.isLevel(level) then
		warn(`[Loudness] unknown level {level}`)
		return nil
	end
	local now = os.clock()
	local event: Event = { position = position, level = level, source = source, time = now }
	table.insert(events, event)
	events = LoudnessLogic.prune(events, now, Settings.RecentSeconds, Settings.MaxRecent)
	for _, listener in table.clone(listeners) do
		task.spawn(listener, event)
	end
	return event
end

-- Calls fn(event) for every sound from now on. Returns a function that unsubscribes.
function Loudness.onSound(fn: (Event) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local index = table.find(listeners, fn)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Recent events, oldest first. With a radius: everything within it. Without: what a robot standing
-- at position could have heard (quiet sounds only from inside its own room).
function Loudness.recent(position: Vector3, radius: number?): { Event }
	events = LoudnessLogic.prune(events, os.clock(), Settings.RecentSeconds, Settings.MaxRecent)
	local found = {}
	for _, event in events do
		local distance = (event.position - position).Magnitude
		local heard = if radius
			then distance <= radius
			else LoudnessLogic.hears(
				Settings.Levels,
				event.level,
				"robot",
				distance,
				Settings.Levels[event.level].robotsInRoom and sameRoom(event.position, position)
			)
		if heard then
			table.insert(found, event)
		end
	end
	return found
end

-- RollOffMinDistance and RollOffMaxDistance for a Sound of this level.
function Loudness.rollOff(level: LoudnessLogic.Level): (number, number)
	return LoudnessLogic.rollOff(Settings.Levels, level, Settings.RollOffMinFraction)
end

return Loudness
