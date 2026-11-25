-- The Sorter: one real robot hiding in each store display of mannequins. It only moves while nobody
-- is looking at it, and only hunts at night. Distances in studs, times in seconds.
return {
	Every = 0.2, -- brain tick; it only moves unseen, so nobody sees the steps
	PoseEvery = 3,
	GroupRadius = 12, -- models this close together are one display

	-- Seeing it: a player's view cone with nothing in the way
	ViewHalfAngle = 60,
	ViewRange = 140,

	-- Night hunt
	HuntRange = 45, -- starts creeping when a player is this close
	Leash = 80, -- never strays farther than this from its display
	Speed = 16, -- studs per second while nobody looks
	CatchDistance = 3.5,
	CatchDamage = 55,
	CatchCooldown = 8,
	StepHeight = 3, -- the most floor height it climbs or drops in one step

	-- Shooting the real one knocks it flat; it gets up once nobody is watching
	DownSeconds = 20,
	KnockdownTokens = 3, -- once per sorter per day

	-- Pose swaps while nobody looks: decoys and the real one alike, so posing gives nothing away
	PoseChance = { Day = 0.15, Siren = 0.35, Night = 0.6 },
	NearPlayer = 90,
	FaceTurn = 0.6,
	CreepPose = "reach",
	Poses = {
		stand = {},
		reach = { UpperArm = 3, Forearm = 1, LeftUpperArm = 3, LeftForearm = 1 },
		turn = { Head = 3 },
		crouch = { Thigh = 3, LeftThigh = 3, Shin = -3, LeftShin = -3 },
		face = { Head = -1, UpperArm = 1, LeftUpperArm = 1 },
	},

	-- The red lens behind its chipped face plate, only at night
	Lens = { Range = 6, Brightness = 0.6, Color = Color3.fromRGB(255, 30, 30) },

	Sounds = {
		Snap = "servo_whirr_2", -- quiet, when it changes pose
		Down = "robot_error",
		Catch = "servo_whirr_1",
	},
	Volume = 0.5,
	HurtBy = "Grabbed by a mannequin",
}
