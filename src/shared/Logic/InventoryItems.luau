-- Every item a player can carry. value decides the "best item" robots go after; stackSize is per slot.
export type ItemDef = { id: string, name: string, value: number, stackSize: number }

local items: { [string]: ItemDef } = {
	StarterBlaster = { id = "StarterBlaster", name = "Starter Blaster", value = 20, stackSize = 1 },
	BlasterCells = { id = "BlasterCells", name = "Blaster Cells", value = 1, stackSize = 60 },
	Handcuffs = { id = "Handcuffs", name = "Handcuffs", value = 30, stackSize = 1 },
}

return table.freeze(items)
