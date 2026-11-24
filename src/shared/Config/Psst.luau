-- Psst (Q / Circle / PSST): a quiet whisper to players nearby. Robots hear it as a quiet noise.
return {
	HearRange = 30, -- studs; only players this close get it
	Cooldown = 3, -- seconds between whispers per player (server enforced)

	Sound = "psst", -- manifest name, silent until uploaded
	Volume = 0.6,
	OwnVolume = 0.35, -- how loud your own whisper is to you
	RollOff = { 4, 30 },

	-- Faint arrow on the screen edge pointing toward the whisper
	MarkerTime = 1.6,
	MarkerFadeTime = 0.6,
	MarkerSize = 34,
	MarkerInset = 0.42, -- share of the screen from the centre to where the arrow sits
	MarkerColor = Color3.fromRGB(225, 222, 215),
	MarkerTransparency = 0.45,
}
