return {
	-- Seconds per phase. Morning is instant: Night ends straight into Day.
	Lengths = { Day = 360, Siren = 60, Night = 240 },
	-- Debug: flip on for quick playtest loops.
	ShortCycle = false,
	ShortLengths = { Day = 40, Siren = 15, Night = 30 },

	-- Lighting per phase. Day is a dim old fluorescent store, night is near black and cold.
	-- Haze settings go on the Atmosphere named "Haze" in Lighting when it exists.
	Lighting = {
		Day = {
			Ambient = Color3.fromRGB(112, 116, 104),
			OutdoorAmbient = Color3.fromRGB(118, 122, 110),
			Brightness = 1.4,
			ClockTime = 14,
			ColorShift_Top = Color3.fromRGB(205, 215, 195),
			ColorShift_Bottom = Color3.fromRGB(40, 42, 38),
			FogColor = Color3.fromRGB(150, 152, 140),
			FogStart = 0,
			FogEnd = 800,
			Haze = { Density = 0.35, Color = Color3.fromRGB(190, 195, 180), Haze = 1.5 },
		},
		Night = {
			Ambient = Color3.fromRGB(7, 9, 15),
			OutdoorAmbient = Color3.fromRGB(5, 7, 13),
			Brightness = 0,
			ClockTime = 0,
			ColorShift_Top = Color3.fromRGB(20, 30, 50),
			ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
			FogColor = Color3.fromRGB(4, 5, 9),
			FogStart = 0,
			FogEnd = 180,
			Haze = { Density = 0.55, Color = Color3.fromRGB(18, 22, 32), Haze = 2.5 },
		},
	},
	-- Siren keeps the day lights and pulses the ambient toward red.
	SirenColor = Color3.fromRGB(170, 18, 18),
	SirenStrength = 0.6,
	SirenFlashRate = 1.2, -- flashes per second
	-- Lights out flicker: alternating off/on seconds, starting off. Ends dark.
	FlickerPattern = { 0.08, 0.1, 0.06, 0.25, 0.1, 0.06, 0.35 },

	-- Sound names from the manifest (ModelLibrary.soundId). Missing ids just stay silent.
	Sounds = {
		Siren = "siren",
		Jingle = "store_jingle",
		Chime = "pa_chime",
		LightsOut = "lights_out_clunk",
		NightHum = "distant_hum_loop",
		NightAmbience = "night_ambience_loop",
		FlashlightClick = "flashlight_click",
	},
	-- Keani picks the day music (creepily joyful elevator music). Paste its rbxassetid:// here.
	DayMusicId = nil :: string?,

	Volume = {
		DayMusic = 0.35,
		NightHum = 0.5,
		NightAmbience = 0.4,
		Siren = 0.8,
		Stinger = 0.8,
		Announcer = 0.9,
	},

	-- Voice lines from art/sounds/VOICE_LINES.md, keyed by file name. Not recorded yet:
	-- add "rbxassetid://..." here once uploaded (or add them to the manifest).
	VoiceLineIds = {} :: { [string]: string },
	MorningLines = { "announcer_welcome", "announcer_welcome_2" },
	DayLines = { "announcer_welcome", "announcer_welcome_2" },
	CountdownLine = "announcer_countdown",
	CountdownLead = 11, -- seconds the countdown line runs before lights out
	LightsOutLines = { "announcer_lights_out", "announcer_lights_out_2" },
	AnnouncementGap = { Min = 75, Max = 150 }, -- seconds between daytime PA announcements

	Flashlight = {
		Brightness = 3,
		Range = 60,
		Angle = 45,
		Color = Color3.fromRGB(255, 240, 215),
		Shadows = true,
		ToggleCooldown = 0.2,
	},
}
