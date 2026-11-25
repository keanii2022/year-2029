-- Callouts (Q / Circle / CALL): Keani's recorded call, heard by players nearby from where you stand.
-- Robots hear it as a normal noise. Hold the button to open the call wheel and pick one by name.
return {
	Sounds = { "callout_0", "callout_1", "callout_2", "callout_3", "callout_4", "callout_5", "callout_6" },
	-- What the wheel and the label call each sound, same order as Sounds
	Names = { "Waddup twin", "Yyyyo", "Yyyyyoooooo", "Whisper hey", "HEY", "Hey.....", "Whistle" },
	HearRange = 120, -- studs; only players this close get it
	Cooldown = 0.2, -- seconds between calls per player (server enforced); a new call cuts the last off
	HoldTime = 0.4, -- holding the button this long opens the call wheel instead of calling

	Volume = 1,
	OwnVolume = 0.6, -- how loud your own call is to you
	RollOff = { 20, 120 },

	-- The call wheel: names in a ring round the screen centre
	WheelRadius = 130,
	StickDeadZone = 0.5, -- how far the stick has to lean before it points at a call

	-- Small label naming the selected call, shown for a moment after picking
	LabelTime = 2.5,
	LabelFadeTime = 0.6,

	-- Faint arrow on the screen edge pointing toward the call
	MarkerTime = 1.6,
	MarkerFadeTime = 0.6,
	MarkerSize = 34,
	MarkerInset = 0.42, -- share of the screen from the centre to where the arrow sits
	MarkerColor = Color3.fromRGB(225, 222, 215),
	MarkerTransparency = 0.45,
}
