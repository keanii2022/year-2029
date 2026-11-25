-- When Keani's recorded voice lines play: which callout comes next, which ghost kid line a step
-- closer earns, and which robot line a state change or a nearby player earns. No Roblox.
local VoiceLines = {}

export type KidCue = { distance: number, sound: string }
export type RobotLines = {
	Notice: string,
	Resume: string,
	Error: string,
	ErrorStates: { string },
	CalmStates: { string },
}

-- Callouts are numbered 0..count-1; holding the button steps to the next one and wraps round.
function VoiceLines.nextCallout(index: number, count: number): number
	return (index + 1) % count
end

function VoiceLines.validCallout(index: unknown, count: number): boolean
	return type(index) == "number" and index == math.floor(index) and index >= 0 and index < count
end

-- cues run from farthest to closest. Returns the index of the closest cue the player has stepped
-- inside that hasn't played yet, or nil. Playing it also covers the farther ones, so a sprint
-- straight at the kid gets the one line that fits, not three on top of each other.
function VoiceLines.kidCue(cues: { KidCue }, distance: number, played: number): number?
	local due = nil
	for index = played + 1, #cues do
		if distance <= cues[index].distance then
			due = index
		end
	end
	return due
end

-- The line a robot says when its state changes from previous to current, if any.
function VoiceLines.robotStateLine(previous: string?, current: string, lines: RobotLines): string?
	if table.find(lines.ErrorStates, current) and not table.find(lines.ErrorStates, previous or "") then
		return lines.Error
	elseif current == "suspicious" and previous ~= "suspicious" then
		return lines.Notice
	elseif previous == "suspicious" and table.find(lines.CalmStates, current) then
		return lines.Resume
	end
	return nil
end

function VoiceLines.isCalm(state: string?, lines: RobotLines): boolean
	return state ~= nil and table.find(lines.CalmStates, state) ~= nil
end

return VoiceLines
