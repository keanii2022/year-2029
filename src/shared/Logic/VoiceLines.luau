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
	ChatterStates: { string },
}

-- Callouts are numbered 0..count-1; stepping past either end wraps round.
function VoiceLines.stepCallout(index: number, step: number, count: number): number
	return (index + step) % count
end

-- The callout a stick pushed toward (x, y) points at on the wheel: 0 at the top, going clockwise.
-- y is up. Returns nil for a stick near the centre.
function VoiceLines.calloutAt(x: number, y: number, count: number, deadZone: number): number?
	if x * x + y * y < deadZone * deadZone then
		return nil
	end
	local turn = math.atan2(x, y) / (2 * math.pi)
	return math.floor(turn * count + 0.5) % count
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
	elseif current == "chase" and previous ~= "chase" and previous ~= "suspicious" then
		-- skipped straight to the chase (up close, or any night robot): it still calls you out
		return lines.Notice
	elseif previous == "suspicious" and table.find(lines.CalmStates, current) then
		return lines.Resume
	end
	return nil
end

-- Calm work by day and patrols by night; never mid-chase or switched off.
function VoiceLines.chatters(state: string?, lines: RobotLines): boolean
	return state ~= nil and table.find(lines.ChatterStates, state) ~= nil
end

return VoiceLines
