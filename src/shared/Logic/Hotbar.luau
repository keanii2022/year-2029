-- Hotbar slots from what you carry, and moving the selection along them.
local Needs = if script then require(script.Parent.Needs) else require("./Needs")

export type SlotDef = {
	id: string,
	label: string,
	use: string,
	kind: string?,
	items: { string }?,
	always: boolean?,
	hold: string?,
}
-- item: what shows in your hand (an inventory id, or the slot's hold for always-there slots)
export type Slot = { id: string, label: string, use: string, count: number, item: string? }
export type Gun = { rank: number, label: string? }

local Hotbar = {}

-- With nothing missing the server would refuse, but the hand still shows the biggest one.
local ALL_MISSING: Needs.Missing = { hunger = math.huge, energy = math.huge, health = math.huge }

local function gunSlots(def: SlotDef, counts: { [string]: number }, guns: { [string]: Gun }): { Slot }
	local owned = {}
	for id in guns do
		if (counts[id] or 0) > 0 then
			table.insert(owned, id)
		end
	end
	table.sort(owned, function(a, b)
		if guns[a].rank ~= guns[b].rank then
			return guns[a].rank > guns[b].rank
		end
		return a < b
	end)
	local slots = {}
	for _, id in owned do
		table.insert(
			slots,
			{ id = id, label = guns[id].label or def.label, use = def.use, count = 1, item = id }
		)
	end
	return slots
end

-- The bar in order. kind slots show the item the server would use for that kind right now.
function Hotbar.slots(
	defs: { SlotDef },
	bag: { Needs.Stack },
	uses: { [string]: Needs.Use },
	guns: { [string]: Gun },
	missing: Needs.Missing
): { Slot }
	local counts: { [string]: number } = {}
	for _, stack in bag do
		counts[stack.id] = (counts[stack.id] or 0) + stack.count
	end
	local slots: { Slot } = {}
	for _, def in defs do
		if def.id == "Guns" then
			for _, slot in gunSlots(def, counts, guns) do
				table.insert(slots, slot)
			end
		elseif def.kind then
			local total = 0
			for id, count in counts do
				if uses[id] and uses[id].kind == def.kind then
					total += count
				end
			end
			if total > 0 then
				local item = Needs.pick(def.kind, bag, uses, missing)
					or Needs.pick(def.kind, bag, uses, ALL_MISSING)
				table.insert(
					slots,
					{ id = def.id, label = def.label, use = def.use, count = total, item = item }
				)
			end
		else
			local total, first = 0, nil
			for _, id in def.items or {} do
				if (counts[id] or 0) > 0 then
					total += counts[id]
					first = first or id
				end
			end
			if total > 0 or def.always then
				table.insert(
					slots,
					{ id = def.id, label = def.label, use = def.use, count = total, item = first or def.hold }
				)
			end
		end
	end
	return slots
end

function Hotbar.find(slots: { Slot }, id: string?): (Slot?, number?)
	for index, slot in slots do
		if slot.id == id then
			return slot, index
		end
	end
	return nil, nil
end

-- What's in hand when nothing is picked yet or the picked slot ran out: the best gun, else the first slot.
function Hotbar.default(slots: { Slot }): string?
	for _, slot in slots do
		if slot.use == "Fire" then
			return slot.id
		end
	end
	return if slots[1] then slots[1].id else nil
end

function Hotbar.keep(slots: { Slot }, id: string?): string?
	if Hotbar.find(slots, id) then
		return id
	end
	return Hotbar.default(slots)
end

-- Next (step 1) or previous (step -1) slot, wrapping round the ends.
function Hotbar.cycle(slots: { Slot }, id: string?, step: number): string?
	local count = #slots
	if count == 0 then
		return nil
	end
	local _, index = Hotbar.find(slots, id)
	local nextIndex = if index then (index - 1 + step) % count + 1 elseif step > 0 then 1 else count
	return slots[nextIndex].id
end

-- The slot a number key picks, or nil when there's no slot that far along.
function Hotbar.atNumber(slots: { Slot }, number: number): string?
	local slot = slots[number]
	return if slot then slot.id else nil
end

return Hotbar
