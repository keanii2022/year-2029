-- Storage rules: which objects hold items, what they start with, and when a move is allowed.
-- The stacks themselves use Logic/Inventory, so a container fills exactly like a bag.
local Inventory = if script then require(script.Parent.Inventory) else require("./Inventory")
local Loot = if script then require(script.Parent.Loot) else require("./Loot")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Container = {}

export type Rule = { slots: number, lootChance: number?, lootRolls: number?, only: { string }? }
export type MoveCheck = {
	alive: boolean,
	viewing: boolean,
	open: boolean,
	distance: number,
	reach: number,
}

-- A model holds items when it has a rule and the part being used opens or hides (a TV stand's
-- screen toggles, its doors open).
function Container.ruleFor(rules: { [string]: Rule }, modelName: string?, kind: string?): Rule?
	if not modelName or (kind ~= "open" and kind ~= "hide") then
		return nil
	end
	return rules[modelName]
end

function Container.startingLoot(
	rule: Rule,
	entries: { Loot.Entry },
	depth: number,
	rng: Rng.Rng,
	items: Inventory.Items
): { Inventory.Stack }
	local stacks = {}
	if (rule.lootRolls or 0) <= 0 or rng:next() >= (rule.lootChance or 0) then
		return stacks
	end
	local pool = entries
	if rule.only then
		pool = {}
		for _, entry in entries do
			if table.find(rule.only, entry.item) then
				table.insert(pool, entry)
			end
		end
	end
	for _ = 1, rng:int(1, rule.lootRolls :: number) do
		local roll = Loot.roll(pool, depth, rng)
		if roll then
			Inventory.add(stacks, items, roll.item, roll.count, rule.slots)
		end
	end
	return stacks
end

-- Open while any of its doors, drawers or lids is open, or while someone hides inside.
function Container.isOpen(openKeys: { [string]: boolean }?): boolean
	return openKeys ~= nil and next(openKeys) ~= nil
end

function Container.canMove(check: MoveCheck): (boolean, string?)
	if not check.alive then
		return false, "dead"
	end
	if not check.viewing then
		return false, "not viewing"
	end
	if not check.open then
		return false, "closed"
	end
	if check.distance > check.reach then
		return false, "too far"
	end
	return true, nil
end

-- A whole number from 1 to available, from whatever the client sent. Nil asks for everything.
function Container.moveCount(requested: any, available: number): number
	if available <= 0 then
		return 0
	end
	if type(requested) ~= "number" or requested ~= requested then
		return available
	end
	return math.clamp(math.floor(requested), 1, available)
end

return Container
