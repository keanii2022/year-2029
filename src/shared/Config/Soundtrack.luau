-- Keani's soundtrack: four loops from art/sounds/music/, one at a time, crossfading.
return {
	Loops = {
		Day = "music_day_loop",
		Night = "music_night_loop",
		Installation = "music_installation_loop",
		Dawn = "music_dawn_loop",
	},
	-- A quiet bed under the game sounds; the installation and dawn loops sit a little louder. Night
	-- stays barely there so the hum, far clanks and robot sounds carry the dread.
	Volume = { Day = 0.22, Night = 0.07, Installation = 0.38, Dawn = 0.32 },
	SirenDuck = 0.5, -- the lights-on music drops to this share of its volume while the siren goes
	CrossfadeSeconds = 2,
	RotateSeconds = 48, -- with the lights on, the day and dawn loops swap after one full pass each
	InstallationPadding = 12, -- studs outside an installation's dark hall where its music starts
}
