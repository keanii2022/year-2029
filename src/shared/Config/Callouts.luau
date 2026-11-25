-- Callouts (Q / Circle / CALL): Keani's recorded call, heard by players nearby from where you stand.
-- Robots hear it as a normal noise. Hold the button to switch to the next call.
return {
	Sounds = { "callout_0", "callout_1", "callout_2", "callout_3", "callout_4", "callout_5", "callout_6" },
	HearRange = 70, -- studs; only players this close get it
	Cooldown = 0.2, -- seconds between calls per player (server enforced); a new call cuts the last off
	HoldTime = 0.4, -- holding the button this long switches calls instead of calling

	Volume = 0.9,
	OwnVolume = 0.5, -- how loud your own call is to you
	RollOff = { 8, 70 },

	-- Small label naming the selected call, shown for a moment after switching
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
