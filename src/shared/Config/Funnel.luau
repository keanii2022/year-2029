-- New-player funnel steps, in order (Systems/Funnel logs them to Roblox's onboarding funnel in the
-- Creator Dashboard, so you can see where first-time players give up)
return {
	Steps = {
		{ name = "Joined" },
		{ name = "FirstLoot" },
		{ name = "FirstGrab" },
		{ name = "HeardSiren" },
		{ name = "SurvivedNight" },
	},
}
