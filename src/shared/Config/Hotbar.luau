-- The hotbar (Controllers/Hotbar, Logic/Hotbar): what's in your bag along the bottom of the
-- screen, the selected slot in your hands, and the use/fire button doing what that item does.
local function pose(x: number, y: number, z: number, pitch: number?, yaw: number?, roll: number?)
	return { x = x, y = y, z = z, pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

return {
	-- Slots in bar order; only slots you have something for show up (always: shown regardless).
	-- use: what the use/fire button does with it (a Hotbar.onUse name). kind: every supply of that
	-- quick-use kind (Config.Supplies.Uses) shares the slot. items: the inventory ids it holds.
	-- hold: what sits in your hand when there's no inventory item behind it.
	-- The "Guns" slot becomes one slot per gun you carry, best first (Config.Guns.Blasters rank).
	Slots = {
		{ id = "Flashlight", label = "LIGHT", use = "Flashlight", always = true, hold = "Flashlight" },
		{ id = "Guns", label = "GUN", use = "Fire" },
		{ id = "Food", label = "FOOD", use = "Eat", kind = "Eat" },
		{ id = "Drink", label = "DRINK", use = "Drink", kind = "Drink" },
		{ id = "Bandage", label = "BANDAGE", use = "Heal", kind = "Heal" },
		{ id = "Battery", label = "BATTERY", use = "Flashlight", items = { "FlashlightBattery" } },
		{ id = "Emp", label = "EMP", use = "Emp", items = { "EmpCharge" } },
		{ id = "Disruptor", label = "ZAP", use = "Disruptor", items = { "Disruptor" } },
		{ id = "Handcuffs", label = "CUFFS", use = "Cuffs", items = { "Handcuffs" } },
	},

	-- What the phone's big use button says for each use
	Verbs = {
		Fire = "FIRE",
		Eat = "EAT",
		Drink = "DRINK",
		Heal = "HEAL",
		Flashlight = "LIGHT",
		Emp = "THROW",
		Disruptor = "ZAP",
		Cuffs = "CUFF",
	},

	-- Per gun: the uploaded viewmodel (ReplicatedStorage.Viewmodels) and its slot label. A gun
	-- model's Muzzle marker is where shots leave, Grip takes the right glove and Foregrip (two-handed
	-- guns) the left one.
	Guns = {
		StarterBlaster = { model = "viewmodel_blaster", label = "BLASTER" },
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
		Disruptor = {
			model = "disruptor",
			shape = "Box",
			size = Vector3.new(0.2, 0.26, 0.6),
			color = Color3.fromRGB(120, 60, 160),
			offset = CFrame.new(0, 0.08, -0.15),
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

	-- The bar
	SlotSize = 52,
	SlotGap = 6,
	Bottom = 8,
}
