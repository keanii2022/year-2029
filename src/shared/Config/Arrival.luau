-- Where you land on your first spawn in a server (server Arrival system) and the faint friend mark
-- (client Friends controller). Studs and seconds.
return {
	-- A Roblox friend already playing here: you spawn this far behind them
	FriendGap = 5,
	-- Otherwise a first-timer (first-day save) spawns this far out in front of the nearest locker
	LockerGap = 6,
	-- How long a first spawn waits for the save to say whether this is a first-timer
	SaveWait = 10,

	-- Friends see a faint mark over each other within Range. Strangers never get one: the player
	-- list stays hidden on purpose. Damage is still free-for-all.
	FriendMark = {
		Range = 40,
		Size = 14,
		Height = 2.6, -- studs above the head
		Transparency = 0.55,
		CheckEvery = 0.25,
		-- IsFriendsWith is a web call; ask again this often in case they friend mid-session
		RecheckEvery = 120,
	},
}
