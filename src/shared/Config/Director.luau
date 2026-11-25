-- The hidden event director (Systems/Director, Logic/Director): PA events, bait drops and rumors
-- land where they make separate groups of players cross paths. Nobody is ever told. Studs and seconds.
return {
	SampleSeconds = 5, -- how often it looks at where everyone is
	FortSeconds = 20, -- how often it rescans placed props for forts
	ClusterRadius = 45, -- players this close (chained) count as one group
	FortRadius = 25, -- placed props this close count as one fort
	FortMinProps = 3, -- fewer props than this is a dropped crate, not a fort
	MeetRange = 110, -- two groups this close have met: they can see and shoot each other

	-- Event clock: Config.Prizes.Pa.Gap ticks at this pace. Groups already together slow it to
	-- BackOff; after NudgeAfter seconds apart it speeds up, reaching NudgeMax NudgeRamp seconds later.
	BackOff = 0.5,
	NudgeAfter = 90,
	NudgeRamp = 180,
	NudgeMax = 2,

	-- Spot picking
	MinGap = 160, -- groups closer than this don't need help meeting
	MaxGap = 1400, -- nor groups so far apart nobody would walk it
	BetweenSlack = 0.35, -- an installation counts as "between" two groups within this extra walk share
	PastFort = 45, -- how far beyond a fort, on the far side from the group it pulls
	GroupClearance = 70, -- never this close to any group (or lone player)
	FortClearance = 40, -- nor this close to a fort
	Jitter = 25, -- the spot drifts up to this far, so it never looks aimed
	RandomShare = 0.3, -- this share of events ignore the director and go anywhere
	Weights = { midpoint = 3, pastFort = 2, installation = 2 },
	SnapSearch = { 0, 40 }, -- ring searched round the director's spot for clear aisle floor

	-- How strongly each event pulls the sim bots (times the mood's lure chance), and how far away they
	-- still care. Rumors are quieter, so fewer bots act on them.
	BotPull = { bait = 1, delivery = 0.7, open = 0.5, lost = 0.4, rumor = 0.35 },
	BotLureRange = 900,
}
