return {
	-- Seconds per phase. Morning is instant: Night ends straight into Day.
	Lengths = { Day = 360, Siren = 45, Night = 240 },
	-- Debug: flip on for quick playtest loops.
	ShortCycle = false,
	ShortLengths = { Day = 40, Siren = 15, Night = 30 },

	-- Lighting per phase. Inside a closed warehouse, so the ambient does the work and the haze
	-- swallows the distance. Day is a dim old fluorescent store; night is dark and cold but never
	-- pitch black: emergency strips glow red, exit signs glow green, and the flashlight matters.
	-- Haze settings go on the Atmosphere named "Haze" in Lighting when it exists.
	Lighting = {
		Day = {
			Ambient = Color3.fromRGB(92, 98, 102),
			OutdoorAmbient = Color3.fromRGB(92, 98, 102),
			Brightness = 0.6,
			ClockTime = 14,
			ColorShift_Top = Color3.fromRGB(190, 205, 210),
			ColorShift_Bottom = Color3.fromRGB(30, 32, 34),
			FogColor = Color3.fromRGB(120, 124, 128),
			FogStart = 0,
			FogEnd = 400,
			Haze = { Density = 0.48, Color = Color3.fromRGB(124, 130, 134), Haze = 2.8 },
		},
		Night = {
			Ambient = Color3.fromRGB(16, 17, 24),
			OutdoorAmbient = Color3.fromRGB(16, 17, 24),
			Brightness = 0,
			ClockTime = 0,
			ColorShift_Top = Color3.fromRGB(30, 40, 60),
			ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
			FogColor = Color3.fromRGB(8, 9, 13),
			FogStart = 0,
			FogEnd = 200,
			Haze = { Density = 0.55, Color = Color3.fromRGB(12, 13, 18), Haze = 2 },
		},
	},
	-- Strip lights at night: most go dark, emergency ones glow a dim red
	Emergency = {
		Glow = Color3.fromRGB(150, 24, 20),
		Light = Color3.fromRGB(255, 50, 40),
		Brightness = 1.6,
		Range = 18, -- small pools: you see shapes against them, not the floor in front of you
	},
	DeadStripColor = Color3.fromRGB(60, 62, 64),
	FlickerRange = 160, -- only strips this close to the camera flicker
	-- Siren keeps the day lights and pulses the ambient toward red.
	SirenColor = Color3.fromRGB(170, 18, 18),
	SirenStrength = 0.6,
	SirenFlashRate = 1.2, -- flashes per second
	SirenBurst = { On = 4, Off = 6 }, -- seconds of wail, then seconds of quiet, until lights out
	SirenHint = "NIGHT IS COMING. Get somewhere safe before the lights go out.",
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
