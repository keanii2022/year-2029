-- Keani's soundtrack: four loops from art/sounds/music/, one at a time, crossfading.
return {
	Loops = {
		Day = "music_day_loop",
		Night = "music_night_loop",
		Installation = "music_installation_loop",
		Dawn = "music_dawn_loop",
	},
	-- A quiet bed under the game sounds; the installation and dawn loops sit a little louder
	Volume = { Day = 0.22, Night = 0.22, Installation = 0.38, Dawn = 0.32 },
	SirenDuck = 0.5, -- the day loop drops to this share of its volume while the siren goes
	CrossfadeSeconds = 2,
	DawnSeconds = 48, -- one pass of the dawn loop after a night, then the day loop takes over
	InstallationPadding = 12, -- studs outside an installation's dark hall where its music starts
}
