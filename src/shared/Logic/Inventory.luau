-- Pure inventory math on a list of stacks (one stack per slot). No Roblox here.
local Inventory = {}

export type Stack = { id: string, count: number }
export type ItemDef = { id: string, name: string, value: number, stackSize: number }
export type Items = { [string]: ItemDef }

local function definition(items: Items, id: string): ItemDef
	local def = items[id]
	assert(def, `Unknown item {id}`)
	return def
end

-- Adds up to count, filling existing stacks first, then free slots. Returns how many fit.
function Inventory.add(stacks: { Stack }, items: Items, id: string, count: number, maxSlots: number): number
	local stackSize = definition(items, id).stackSize
	local left = count
	for _, stack in stacks do
		if left <= 0 then
			break
		end
		if stack.id == id and stack.count < stackSize then
			local moved = math.min(left, stackSize - stack.count)
			stack.count += moved
			left -= moved
		end
	end
	while left > 0 and #stacks < maxSlots do
		local moved = math.min(left, stackSize)
		table.insert(stacks, { id = id, count = moved })
		left -= moved
	end
	return count - left
end

-- Takes up to count, newest stacks first so full stacks stay full. Returns how many were taken.
function Inventory.remove(stacks: { Stack }, id: string, count: number): number
	local left = count
	for index = #stacks, 1, -1 do
		if left <= 0 then
			break
		end
		local stack = stacks[index]
		if stack.id == id then
			local taken = math.min(left, stack.count)
			stack.count -= taken
			left -= taken
			if stack.count <= 0 then
				table.remove(stacks, index)
			end
		end
	end
	return count - left
end

function Inventory.count(stacks: { Stack }, id: string): number
	local total = 0
	for _, stack in stacks do
		if stack.id == id then
			total += stack.count
		end
	end
	return total
end

-- One entry per item id, in the order first carried.
function Inventory.totals(stacks: { Stack }): { Stack }
	local result: { Stack } = {}
	local byId: { [string]: Stack } = {}
	for _, stack in stacks do
		local entry = byId[stack.id]
		if entry then
			entry.count += stack.count
		else
			entry = { id = stack.id, count = stack.count }
			byId[stack.id] = entry
			table.insert(result, entry)
		end
	end
	return result
end

-- The single most valuable item carried; ties go to the earlier slot.
function Inventory.bestItem(stacks: { Stack }, items: Items): string?
	local bestId, bestValue = nil, -math.huge
	for _, stack in stacks do
		local value = definition(items, stack.id).value
		if value > bestValue then
			bestId, bestValue = stack.id, value
		end
	end
	return bestId
end

-- Empties the stacks and returns their totals (what a loot pile holds).
function Inventory.takeAll(stacks: { Stack }): { Stack }
	local result = Inventory.totals(stacks)
	table.clear(stacks)
	return result
end

-- Moves as much of `from` into `to` as fits; emptied entries leave `from`. Returns items moved.
function Inventory.moveAll(from: { Stack }, to: { Stack }, items: Items, maxSlots: number): number
	local moved = 0
	for index = #from, 1, -1 do
		local entry = from[index]
		local added = Inventory.add(to, items, entry.id, entry.count, maxSlots)
		entry.count -= added
		moved += added
		if entry.count <= 0 then
			table.remove(from, index)
		end
	end
	return moved
end

return Inventory
