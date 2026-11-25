-- The audio mix (Shared/Mix, Controllers/AudioSettings): group levels, ducking, the scare budget
-- and the master compressor. Dread first, not shock first: nothing should jump far above the rest.
return {
	-- Every group's level in one table, under the Master group. Music sits under effects.
	Master = 1,
	Groups = { Music = 0.75, Ambience = 0.85, SFX = 1, Voice = 1, Scare = 0.8, UI = 0.7 },
	-- Which player slider (Saves audio field) scales each group; "master" scales the Master group
	Sliders = {
		Music = "music",
		Ambience = "effects",
		SFX = "effects",
		Scare = "effects",
		UI = "effects",
		Voice = "voice",
	},
	-- No single sound above this before its group level
	VolumeCap = 1,

	-- Music and ambience dip under PA and voice lines, the Dawn moment and gunfights, then come back
	Duck = {
		Groups = { Music = 0.35, Ambience = 0.55 }, -- share of their level kept while ducked
		Down = 0.4, -- seconds to dip
		Up = 1.6, -- seconds to come back
		Gunfight = 2.5, -- seconds held after each shot heard
		Dawn = 7,
		VoiceTail = 0.5, -- held this long after a voice line ends
	},

	-- Scare sounds: "sharp" (screeches, lunges, alarm hits) always play but come in quieter inside
	-- the gap after the last one; "stinger" (pure jump sounds) are skipped inside it. Gentler scares
	-- halves the Scare group and drops stingers.
	Scare = {
		Gap = 9, -- seconds between sharp scares at full volume
		Repeat = 0.4, -- volume share for a sharp scare inside the gap
		Gentle = 0.5,
		FadeIn = { 0.05, 0.15 }, -- soft attack instead of a hard start
		-- Far scares are felt, not blasted: full volume only this close, tapering out after
		FullWithin = 12,
	},

	-- Two stages on the Master group: a gentle compressor that levels bursts, then a hard cap
	Compressor = { Threshold = -18, Ratio = 3, Attack = 0.01, Release = 0.3 },
	Limiter = { Threshold = -4, Ratio = 20, Attack = 0.002, Release = 0.12 },

	-- Settings panel
	SliderStep = 0.1,
}
