-- The hotbar (Controllers/Hotbar, Logic/Hotbar, Logic/QuickSlots): HANDS and LIGHT plus the quick
-- slots the player fills from the bag, the selected slot in your hands, and the use/fire button
-- doing what that item does.
local function pose(x: number, y: number, z: number, pitch: number?, yaw: number?, roll: number?)
	return { x = x, y = y, z = z, pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

return {
	-- always slots lead the bar in this order; the rest are the groups a quick slot can hold.
	-- use: what the use/fire button does with it (a Hotbar.onUse name). kind: every supply of that
	-- quick-use kind (Config.Supplies.Uses) shares the slot. items: the inventory ids it holds.
	-- hold: what sits in your hand when there's no inventory item behind it.
	-- "Guns" gives every gun its use; each gun takes its own quick slot.
	Slots = {
		-- Empty hands: Fire grabs furniture. First, so 1 / Triangle get you there fast.
		{ id = "Hands", label = "HANDS", use = "Grab", always = true },
		{ id = "Flashlight", label = "LIGHT", use = "Flashlight", always = true, hold = "Flashlight" },
		{ id = "Guns", label = "GUN", use = "Fire" },
		{ id = "Food", label = "FOOD", use = "Eat", kind = "Eat" },
		{ id = "Drink", label = "DRINK", use = "Drink", kind = "Drink" },
		{ id = "Bandage", label = "BANDAGE", use = "Heal", kind = "Heal" },
		{ id = "Medkit", label = "MEDKIT", use = "Medkit", kind = "Medkit" },
		{ id = "Battery", label = "BATTERY", use = "Battery", items = { "FlashlightBattery" } },
		{ id = "Emp", label = "EMP", use = "Emp", items = { "EmpCharge" } },
		{ id = "Handcuffs", label = "CUFFS", use = "Cuffs", items = { "Handcuffs" } },
	},

	-- What the phone's big use button says for each use
	Verbs = {
		Grab = "GRAB",
		Fire = "FIRE",
		Eat = "EAT",
		Drink = "DRINK",
		Heal = "HEAL",
		Medkit = "HEAL",
		Flashlight = "LIGHT",
		Battery = "SWAP",
		Emp = "THROW",
		Cuffs = "CUFF",
	},

	-- Per gun: the uploaded viewmodel (ReplicatedStorage.Viewmodels), its slot label and its reload:
	-- "mag" drops the Mag part and a fresh one comes up, "drum" swings the revolver's drum out and
	-- spins it, "shells" keeps the Mag (the shotgun's shell holder) and racks the pump at the end.
	-- A gun model's Rear -> Muzzle line is the barrel, Muzzle is where shots leave, Grip takes the
	-- right glove and Foregrip (two-handed guns) the left one.
	Guns = {
		StarterBlaster = { model = "viewmodel_blaster", label = "BLASTER", reload = "mag" },
		Smg = { model = "smg", label = "SMG", reload = "mag" },
		Rifle = { model = "rifle", label = "RIFLE", reload = "mag" },
		Shotgun = { model = "shotgun", label = "SHOTGUN", reload = "shells" },
		Revolver = { model = "revolver", label = "REVOLVER", reload = "drum" },
		MarksmanRifle = { model = "marksman_rifle", label = "MARKSMAN", reload = "mag" },
		Disruptor = { model = "disruptor", label = "ZAP", reload = "mag" },
		NailGun = { model = "nail_gun", label = "NAILS", reload = "mag" },
		FlareGun = { model = "flare_gun", label = "FLARE", reload = "mag" },
		DartBlaster = { model = "dart_blaster", label = "DARTS", reload = "mag" },
	},

	-- How non-supply items look in your hand; supplies use Config.Hands.Items. Same fields as there,
	-- plus offset (grip to item centre, default Config.Hands.ItemOffset). An item's Lens marker
	-- points it forward and is where the flashlight beam starts.
	Held = {
		Flashlight = {
			model = "flashlight",
			shape = "Box",
			size = Vector3.new(0.12, 0.12, 0.55),
			color = Color3.fromRGB(40, 42, 46),
			offset = CFrame.new(0, 0.04, -0.12),
		},
		FlashlightBattery = {
			model = "battery",
			shape = "Can",
			size = Vector3.new(0.1, 0.22, 0.1),
			color = Color3.fromRGB(70, 70, 76),
		},
		EmpCharge = {
			model = "emp_charge",
			shape = "Can",
			size = Vector3.new(0.26, 0.2, 0.26),
			color = Color3.fromRGB(60, 120, 200),
		},
		Handcuffs = {
			model = "handcuffs",
			shape = "Box",
			size = Vector3.new(0.36, 0.06, 0.18),
			color = Color3.fromRGB(170, 172, 176),
		},
	},

	-- Right hand while holding something, and how long it takes to come up after a swap
	HoldPose = pose(0.3, -0.55, -1.1, 4, 0, 0),
	SwapTime = 0.2,

	-- Slots after HANDS and LIGHT that the player fills from the bag (number keys 3 and up)
	QuickSlots = 4,

	-- The bar
	SlotSize = 52,
	SlotGap = 6,
	Bottom = 8,
	LabelSize = 10, -- largest slot label; long ones shrink to fit
	TouchLabelSize = 13,
	-- Small phones: the bar's right edge sits this far from the screen's right, clear of
	-- TouchButtons' AIM and FIRE (laid out round Roblox's small jump button)
	TouchClearRight = 290,
}
