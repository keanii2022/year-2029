-- The new-player funnel: the moments that show where first-time players give up, logged once each
-- per player per session, in order. Pure: the Funnel system feeds it and does the logging.
local Funnel = {}

export type Step = { name: string }
export type Progress = { [number]: boolean }

-- The step number for a moment name, or nil if it isn't a funnel step
function Funnel.stepOf(steps: { Step }, name: string): number?
	for index, step in steps do
		if step.name == name then
			return index
		end
	end
	return nil
end

-- Steps to log now that `name` happened: it and any earlier steps the player skipped past (so the
-- funnel never shows someone surviving the night without having joined), each only once.
function Funnel.reach(progress: Progress, steps: { Step }, name: string): { number }
	local target = Funnel.stepOf(steps, name)
	local toLog = {}
	if not target then
		return toLog
	end
	for index = 1, target do
		if not progress[index] then
			progress[index] = true
			table.insert(toLog, index)
		end
	end
	return toLog
end

return Funnel
