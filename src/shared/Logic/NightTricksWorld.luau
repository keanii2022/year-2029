-- World side of the night: which aisle sign a player is nearest, what the PA says, and the reverb.
local NightTricksWorld = {}

export type Sign = { x: number, z: number, number: number }
export type Announcement = { text: string, voice: string? }

function NightTricksWorld.nearestSign(signs: { Sign }, x: number, z: number): Sign?
	local best, bestDistance = nil, math.huge
	for _, sign in signs do
		local distance = (sign.x - x) ^ 2 + (sign.z - z) ^ 2
		if distance < bestDistance then
			best, bestDistance = sign, distance
		end
	end
	return best
end

-- The aisle line. The voice says it without a number ("Shopper, please remain still"); the subtitle
-- names the aisle, so it's never text only.
function NightTricksWorld.aisleLine(aisle: number, settings: any): Announcement
	return {
		text = string.format(settings.AisleLine, aisle),
		voice = settings.AisleVoice,
	}
end

-- Picks a night announcement. realAisle is a real player's nearest aisle (nil when nobody is out).
-- next() rolls in [0, 1).
function NightTricksWorld.announcement(realAisle: number?, next: () -> number, settings: any): Announcement
	if realAisle and next() < settings.RightChance then
		return NightTricksWorld.aisleLine(realAisle, settings)
	end
	local count = #settings.Lines + 1 -- +1 for the recorded aisle line
	local index = math.min(count, math.floor(next() * count) + 1)
	if index == count then
		return NightTricksWorld.aisleLine(settings.RecordedAisle, settings)
	end
	local line = settings.Lines[index]
	return { text = line.text, voice = line.voice }
end

-- Reverb preset name: muffled while hidden, tight in a room, stony inside an installation's hall,
-- a big echo in the aisles.
function NightTricksWorld.reverb(
	hidden: boolean,
	inRoom: boolean,
	inInstallation: boolean,
	settings: any
): string
	if hidden then
		return settings.Hidden
	elseif inRoom then
		return settings.Room
	end
	return if inInstallation then settings.Installation else settings.Aisle
end

function NightTricksWorld.between(range: { number }, roll: number): number
	return range[1] + (range[2] - range[1]) * roll
end

return NightTricksWorld
