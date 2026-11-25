-- Every item a player can carry. value decides the "best item" robots go after; stackSize is per slot.
export type ItemDef = { id: string, name: string, value: number, stackSize: number }

local items: { [string]: ItemDef } = {
	StarterBlaster = { id = "StarterBlaster", name = "Starter Blaster", value = 20, stackSize = 1 },
	BlasterCells = { id = "BlasterCells", name = "Blaster Cells", value = 1, stackSize = 60 },
	Handcuffs = { id = "Handcuffs", name = "Handcuffs", value = 30, stackSize = 1 },

	-- Supplies (step 9). What each one does when used lives in Config/Supplies.
	Snack = { id = "Snack", name = "Snack Bar", value = 3, stackSize = 10 },
	Chips = { id = "Chips", name = "Chips", value = 4, stackSize = 5 },
	Apple = { id = "Apple", name = "Apple", value = 2, stackSize = 10 },
	Sandwich = { id = "Sandwich", name = "Sandwich", value = 6, stackSize = 5 },
	JuiceBox = { id = "JuiceBox", name = "Juice Box", value = 3, stackSize = 10 },
	PizzaBox = { id = "PizzaBox", name = "Pizza Box", value = 12, stackSize = 1 },
	PizzaSlice = { id = "PizzaSlice", name = "Pizza Slice", value = 4, stackSize = 8 },
	Popcorn = { id = "Popcorn", name = "Popcorn", value = 5, stackSize = 5 },
	NoodleCup = { id = "NoodleCup", name = "Noodle Cup", value = 7, stackSize = 5 },
	Watermelon = { id = "Watermelon", name = "Watermelon", value = 10, stackSize = 1 },
	WatermelonSlice = { id = "WatermelonSlice", name = "Watermelon Slice", value = 3, stackSize = 8 },
	Lunchbox = { id = "Lunchbox", name = "Lunchbox", value = 12, stackSize = 1 },
	RationPack = { id = "RationPack", name = "Ration Pack", value = 18, stackSize = 3 },
	EnergyDrink = { id = "EnergyDrink", name = "Energy Drink", value = 8, stackSize = 5 },
	Bandage = { id = "Bandage", name = "Bandage", value = 10, stackSize = 5 },
	FlashlightBattery = { id = "FlashlightBattery", name = "Flashlight Battery", value = 6, stackSize = 6 },
	EmpCharge = { id = "EmpCharge", name = "EMP Charge", value = 200, stackSize = 3 },
	Disruptor = { id = "Disruptor", name = "Disruptor", value = 300, stackSize = 1 },
	Medkit = { id = "Medkit", name = "Medkit", value = 40, stackSize = 2 },

	-- Guns found in the warehouse (how each one fires lives in Config.Guns) and their own ammo.
	Smg = { id = "Smg", name = "SMG", value = 60, stackSize = 1 },
	Rifle = { id = "Rifle", name = "Rifle", value = 90, stackSize = 1 },
	Shotgun = { id = "Shotgun", name = "Shotgun", value = 80, stackSize = 1 },
	Revolver = { id = "Revolver", name = "Revolver", value = 70, stackSize = 1 },
	MarksmanRifle = { id = "MarksmanRifle", name = "Marksman Rifle", value = 110, stackSize = 1 },
	NailGun = { id = "NailGun", name = "Nail Gun", value = 50, stackSize = 1 },
	FlareGun = { id = "FlareGun", name = "Flare Gun", value = 35, stackSize = 1 },
	DartBlaster = { id = "DartBlaster", name = "Dart Blaster", value = 120, stackSize = 1 },
	Shells = { id = "Shells", name = "Shotgun Shells", value = 2, stackSize = 24 },
	Flares = { id = "Flares", name = "Flares", value = 4, stackSize = 6 },
	Darts = { id = "Darts", name = "Darts", value = 5, stackSize = 12 },
}

return table.freeze(items)
