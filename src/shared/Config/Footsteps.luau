-- Player and sim bot footsteps (Footsteps controller). Sound names from the manifest; every step is
-- a 3D sound on the body, so RollOff is how far others hear it (studs, full volume to silent).
return {
	-- Enum.Material name -> floor sound; the rest sound like concrete
	Floors = {
		Metal = "metal",
		DiamondPlate = "metal",
		CorrodedMetal = "metal",
		Foil = "metal",
		Wood = "wood",
		WoodPlanks = "wood",
	},
	Walk = { Prefix = "walk_", Volume = 0.45, RollOff = { 6, 55 } },
	Sprint = { Prefix = "run_", Volume = 0.85, RollOff = { 8, 95 } },
	Crouch = { Sound = "crouch_step", Volume = 0.08, RollOff = { 2, 14 } },
	Land = { Sound = "land_thud", Volume = 0.75, RollOff = { 6, 70 } },
	PitchJitter = 0.08,
	Range = 120, -- other bodies farther than this from the camera make no steps at all
	FloorProbe = 5, -- studs down from the root to find the floor under a step
	-- Roblox's own RbxCharacterSounds plays these; muted so only ours are heard
	MutedDefaults = { "Running", "Landing" },
}
