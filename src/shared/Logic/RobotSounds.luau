-- Which robot sound to play, no Roblox here. A sound is one manifest name or a list where the first
-- name with an uploaded id wins, so a new pick falls back to the old sound until it's uploaded.
local RobotSounds = {}

export type Names = string | { string }

-- The id of the first name in names that lookup knows, or nil when none are uploaded.
function RobotSounds.id(names: Names, lookup: (string) -> string?): string?
	if type(names) == "string" then
		return lookup(names)
	end
	for _, name in names do
		local id = lookup(name)
		if id then
			return id
		end
	end
	return nil
end

-- The mimic plays the robot's own copy of callout index (0-based) at its natural pitch; until that
-- copy is uploaded, the original callout pitched slightly wrong.
function RobotSounds.mimic(
	index: number,
	callouts: { string },
	settings: { Copy: string, Pitch: number },
	lookup: (string) -> string?
): (string?, number)
	local copy = lookup(settings.Copy .. index)
	if copy then
		return copy, 1
	end
	local original = callouts[index + 1]
	return if original then lookup(original) else nil, settings.Pitch
end

return RobotSounds
