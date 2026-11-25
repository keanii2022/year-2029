-- The hotbar's quick slots: which group of bag items sits in each. A group is a gun id or a
-- Config.Hotbar.Slots id (every food shares "Food"), so a slot keeps working as you eat through
-- different snacks. "" is an empty slot. A slot whose group you no longer carry remembers it:
-- pick that thing up again and it goes back there, though anything new may take the slot over.
local QuickSlots = {}

export type Quick = { string }
export type GroupDef = { id: string, kind: string?, items: { string }?, always: boolean? }
export type Stack = { id: string, count: number }

function QuickSlots.new(size: number): Quick
	return table.create(size, "")
end

-- The group an item belongs to, or nil when it can't go in a quick slot (cells, parts, valuables).
function QuickSlots.groupOf(
	id: string,
	defs: { GroupDef },
	uses: { [string]: { kind: string } },
	guns: { [string]: any }
): string?
	if guns[id] then
		return id
	end
	local use = uses[id]
	for _, def in defs do
		if not def.always then
			if def.kind and use and use.kind == def.kind then
				return def.id
			end
			if def.items and table.find(def.items, id) then
				return def.id
			end
		end
	end
	return nil
end

-- Every group with at least one item in the bag
function QuickSlots.carried(
	bag: { Stack },
	defs: { GroupDef },
	uses: { [string]: { kind: string } },
	guns: { [string]: any }
): { [string]: boolean }
	local groups = {}
	for _, stack in bag do
		local group = stack.count > 0 and QuickSlots.groupOf(stack.id, defs, uses, guns)
		if group then
			groups[group] = true
		end
	end
	return groups
end

function QuickSlots.find(quick: Quick, group: string): number?
	return table.find(quick, group)
end

-- Where a freshly picked-up group goes: its own slot if it has one, else the first empty slot,
-- else the first slot only remembering something you lost. Nil when every slot is in use.
function QuickSlots.autoAssign(quick: Quick, group: string, carried: { [string]: boolean }): number?
	local index = table.find(quick, group) or table.find(quick, "")
	if not index then
		for slot, held in quick do
			if not carried[held] then
				index = slot
				break
			end
		end
	end
	if index then
		quick[index] = group
	end
	return index
end

-- Puts a group in a slot. If it already sat in another slot, the two swap; whatever was in the
-- target before goes back to the bag. False for a slot number out of range.
function QuickSlots.put(quick: Quick, index: number, group: string): boolean
	if not quick[index] then
		return false
	end
	local from = table.find(quick, group)
	if from then
		quick[from] = quick[index]
	end
	quick[index] = group
	return true
end

-- Back to the bag: the slot goes empty
function QuickSlots.clear(quick: Quick, index: number): boolean
	if not quick[index] then
		return false
	end
	quick[index] = ""
	return true
end

-- What a slot shows: its group while you carry it, else "" (a remembered group looks empty).
function QuickSlots.showing(quick: Quick, index: number, carried: { [string]: boolean }): string
	local group = quick[index] or ""
	return if carried[group] then group else ""
end

return QuickSlots
