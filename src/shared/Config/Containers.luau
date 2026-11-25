-- Storage: every drawer, cabinet, fridge, chest, crate and wardrobe holds items. Contents live on
-- the server per model and reset when the server restarts. Robots never take from them.
local FOOD = {
	"Snack",
	"Chips",
	"Apple",
	"Sandwich",
	"JuiceBox",
	"NoodleCup",
	"EnergyDrink",
	"Popcorn",
}
local HOUSEHOLD = { "Snack", "Chips", "JuiceBox", "Bandage", "FlashlightBattery", "BlasterCells" }
local OFFICE = { "Snack", "EnergyDrink", "FlashlightBattery", "BlasterCells", "Bandage" }
local BATHROOM = { "Bandage", "FlashlightBattery" }
local KIDS = { "Snack", "JuiceBox", "Chips", "Popcorn", "FlashlightBattery" }
local GEAR = { "BlasterCells", "Bandage", "FlashlightBattery", "EnergyDrink", "RationPack", "EmpCharge" }

return {
	-- By model name. slots: stacks it holds. lootChance: chance it starts with anything, then
	-- 1..lootRolls rolls from Config.Supplies.Loot at that depth, limited to the `only` items.
	Kinds = {
		nightstand = { slots = 4, lootChance = 0.35, lootRolls = 1, only = HOUSEHOLD },
		dresser = { slots = 8, lootChance = 0.4, lootRolls = 2, only = HOUSEHOLD },
		wardrobe = { slots = 10, lootChance = 0.35, lootRolls = 2, only = HOUSEHOLD },
		fridge = { slots = 6, lootChance = 0.6, lootRolls = 3, only = FOOD },
		pantry = { slots = 6, lootChance = 0.5, lootRolls = 2, only = FOOD },
		counter = { slots = 6, lootChance = 0.35, lootRolls = 2, only = FOOD },
		tv_stand = { slots = 4, lootChance = 0.25, lootRolls = 1, only = HOUSEHOLD },
		desk = { slots = 6, lootChance = 0.4, lootRolls = 2, only = OFFICE },
		filing_cabinet = { slots = 6, lootChance = 0.35, lootRolls = 2, only = OFFICE },
		sink_cabinet = { slots = 4, lootChance = 0.4, lootRolls = 1, only = BATHROOM },
		toy_chest = { slots = 6, lootChance = 0.4, lootRolls = 2, only = KIDS },
		loot_crate = { slots = 8, lootChance = 0.8, lootRolls = 3, only = GEAR },
		supply_locker = { slots = 8, lootChance = 0.6, lootRolls = 2, only = GEAR },
		locker = { slots = 8, lootChance = 0.4, lootRolls = 2, only = GEAR },
	},

	-- Shown on the panel instead of the model name
	Titles = {
		nightstand = "NIGHTSTAND",
		dresser = "DRESSER",
		wardrobe = "WARDROBE",
		fridge = "FRIDGE",
		pantry = "PANTRY",
		counter = "CUPBOARD",
		tv_stand = "TV STAND",
		desk = "DESK",
		filing_cabinet = "FILING CABINET",
		sink_cabinet = "UNDER THE SINK",
		toy_chest = "TOY CHEST",
		loot_crate = "CRATE",
		supply_locker = "SUPPLY LOCKER",
		locker = "LOCKER",
	},

	-- The crate in every installation (Config.Warehouse.InstallationStash): always full, rolled from
	-- Config.Supplies.InstallationLoot. Taking from it makes a takeLoudness sound the robots hear.
	InstallationStash = { rolls = { 3, 5 }, takeLoudness = "normal" },

	-- The spawn kit comes back every life, so stashing it would be free loot
	Blocked = { StarterBlaster = true },

	ReachSlack = 3, -- studs past Config.Interact.Reach before an open panel closes
	CheckEvery = 0.5, -- seconds between distance checks on open panels
}
