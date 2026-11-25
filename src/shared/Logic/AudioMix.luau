-- Audio mix maths: group volumes from the mix table, player sliders and ducking, and the scare
-- budget. No Roblox here (Shared/Mix applies it).
local AudioMix = {}

export type Audio = { master: number, music: number, effects: number, voice: number, gentle: boolean }
export type MixRules = {
	Master: number,
	Groups: { [string]: number },
	Sliders: { [string]: string },
	Duck: { Groups: { [string]: number } },
	Scare: { Gap: number, Repeat: number, Gentle: number },
}
export type ScareKind = "sharp" | "stinger"
export type ScareState = { lastSharp: number }

function AudioMix.masterVolume(rules: MixRules, audio: Audio): number
	return rules.Master * audio.master
end

function AudioMix.groupVolume(rules: MixRules, audio: Audio, group: string, ducked: boolean): number
	local slider = rules.Sliders[group]
	local volume = (rules.Groups[group] or 1) * (if slider then (audio :: any)[slider] else 1)
	if ducked then
		volume *= rules.Duck.Groups[group] or 1
	end
	if group == "Scare" and audio.gentle then
		volume *= rules.Scare.Gentle
	end
	return volume
end

function AudioMix.newScareState(): ScareState
	return { lastSharp = -math.huge }
end

-- Volume share for a scare sound played now: 1 at full, less inside the gap, 0 to skip it.
-- Only a full-volume scare restarts the gap, so spamming never stretches it.
function AudioMix.scareScale(
	state: ScareState,
	now: number,
	kind: ScareKind,
	rules: MixRules,
	gentle: boolean
): number
	if kind == "stinger" and gentle then
		return 0
	end
	if now - state.lastSharp < rules.Scare.Gap then
		return if kind == "stinger" then 0 else rules.Scare.Repeat
	end
	state.lastSharp = now
	return 1
end

return AudioMix
