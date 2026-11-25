local AudioMix = require("../src/shared/Logic/AudioMix")
local expect = require("./expect")

local rules = {
	Master = 0.9,
	Groups = { Music = 0.5, SFX = 1, Scare = 0.8 },
	Sliders = { Music = "music", SFX = "effects", Scare = "effects" },
	Duck = { Groups = { Music = 0.4 } },
	Scare = { Gap = 9, Repeat = 0.4, Gentle = 0.5 },
}

local function audio(gentle: boolean?)
	return { master = 0.5, music = 0.5, effects = 1, voice = 1, gentle = gentle == true }
end

return {
	["master is the mix level times the slider"] = function()
		expect(AudioMix.masterVolume(rules, audio())).toBeNear(0.45)
	end,
	["groups combine their level, slider and ducking"] = function()
		expect(AudioMix.groupVolume(rules, audio(), "Music", false)).toBeNear(0.25)
		expect(AudioMix.groupVolume(rules, audio(), "Music", true)).toBeNear(0.1)
		expect(AudioMix.groupVolume(rules, audio(), "SFX", true)).toBeNear(1)
	end,
	["gentler scares halves the scare group only"] = function()
		expect(AudioMix.groupVolume(rules, audio(true), "Scare", false)).toBeNear(0.4)
		expect(AudioMix.groupVolume(rules, audio(true), "SFX", false)).toBeNear(1)
	end,
	["a sharp scare inside the gap comes in quieter"] = function()
		local state = AudioMix.newScareState()
		expect(AudioMix.scareScale(state, 100, "sharp", rules, false)).toBe(1)
		expect(AudioMix.scareScale(state, 104, "sharp", rules, false)).toBe(0.4)
		expect(AudioMix.scareScale(state, 110, "sharp", rules, false)).toBe(1)
	end,
	["spamming never stretches the gap"] = function()
		local state = AudioMix.newScareState()
		AudioMix.scareScale(state, 0, "sharp", rules, false)
		for t = 1, 8 do
			AudioMix.scareScale(state, t, "sharp", rules, false)
		end
		expect(AudioMix.scareScale(state, 9, "sharp", rules, false)).toBe(1)
	end,
	["a stinger inside the gap is skipped"] = function()
		local state = AudioMix.newScareState()
		expect(AudioMix.scareScale(state, 50, "stinger", rules, false)).toBe(1)
		expect(AudioMix.scareScale(state, 52, "stinger", rules, false)).toBe(0)
		expect(AudioMix.scareScale(state, 53, "sharp", rules, false)).toBe(0.4)
	end,
	["gentler scares drops stingers but keeps sharp ones"] = function()
		local state = AudioMix.newScareState()
		expect(AudioMix.scareScale(state, 0, "stinger", rules, true)).toBe(0)
		expect(AudioMix.scareScale(state, 1, "sharp", rules, true)).toBe(1)
	end,
}
