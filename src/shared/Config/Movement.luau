return {
	-- Speeds in studs per second
	WalkSpeed = 14,
	SprintSpeed = 22,
	CrouchSpeed = 7,
	SpeedEase = 45, -- how fast speed changes, studs/s per second
	JumpHeight = 5,

	-- Camera
	FieldOfView = 72,
	SprintFieldOfView = 80,
	FieldOfViewEase = 8,
	CrouchCameraDrop = 1.6,
	CrouchCameraEase = 12,

	-- Head bob: one full side-to-side cycle every BobStride studs walked
	BobStride = 7,
	BobSide = 0.08,
	BobUp = 0.06,
	BobRoll = 0.6, -- degrees
	BobMaxAmount = 1.6,
	BobEase = 10,

	-- Sway: camera rolls into turns
	SwayPerTurn = 1.8, -- degrees of roll per radian/second of turning
	SwayMax = 4,
	SwayEase = 8,

	-- Stance changes are mirrored to the server; ignore anything faster than this
	StanceMinInterval = 0.1,

	-- Gamepad L3 sprint turns itself off once the stick is this close to centre
	SprintStopMove = 0.2,
}
