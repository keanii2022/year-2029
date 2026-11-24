return {
	ItemId = "Handcuffs",

	-- Who can be cuffed: from behind, or anyone this low on health.
	Range = 6, -- studs between root parts
	BehindDot = 0.35, -- how far behind: 0 is side-on, 1 is dead behind
	LowHealthFraction = 0.35,
	TargetCooldown = 180, -- seconds before the same person can be cuffed again, by anyone

	-- How long it lasts, and how much mashing helps.
	Duration = 20,
	MinDuration = 5, -- mashing can't get you out sooner than this
	MashSeconds = 0.25, -- each press takes this much off
	MashMinInterval = 0.08, -- presses closer together than this don't count

	RobRange = 10, -- the cuffer has to stay this close to take things
	UncuffHold = 2, -- seconds another player holds the prompt to free someone

	-- Testing: every spawn gets a pair of cuffs.
	DebugGiveCuffs = false,
}
