-- Server speed check (Systems/MoveCheck): catches clients moving faster than they can.
return {
	Enabled = true,
	Slack = 1.5, -- allowed speed as a multiple of the real max (sprint, carry, admin speed)
	BurstSeconds = 2, -- saved-up movement allowed at once, so lag spikes don't trip it
	BadlyOver = 30, -- studs past the budget in one step: pulled back straight away
	MaxStrikes = 5, -- smaller overruns this many times: pulled back
	StrikeDecay = 0.5, -- strikes forgiven per second of normal movement
	GraceSeconds = 2, -- no checks after server teleports and while anchored (hiding)
	SpawnGraceSeconds = 3, -- no checks right after a new character spawns
}
