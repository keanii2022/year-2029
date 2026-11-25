-- The hotbar: the always-there slots (hands, light) then the quick slots, and moving the selection.
local Needs = if script then require(script.Parent.Needs) else require("./Needs")
local QuickSlots = if script then require(script.Parent.QuickSlots) else require("./QuickSlots")

export type SlotDef = {
	id: string,
	label: string,
	use: string,
	kind: string?,
	items: { string }?,
	always: boolean?,
	hold: string?,
}
-- item: what shows in your hand (an inventory id, or the slot's hold for always-there slots).
-- empty: a quick slot with nothing in it; it shows on the bar but can't be picked.
export type Slot = { id: string, label: string, use: string, count: number, item: string?, empty: boolean? }
export type Gun = { rank: number, label: string? }

local Hotbar = {}

-- With nothing missing the server would refuse, but the hand still shows the biggest one.
local ALL_MISSING: Needs.Missing = { hunger = math.huge, energy = math.huge, health = math.huge }

local function groupSlot(
	def: SlotDef,
	counts: { [string]: number },
	bag: { Needs.Stack },
	uses: { [string]: Needs.Use },
	missing: Needs.Missing
): Slot
	if def.kind then
		local total = 0
		for id, count in counts do
			if uses[id] and uses[id].kind == def.kind then
				total += count
			end
		end
		local item = Needs.pick(def.kind, bag, uses, missing) or Needs.pick(def.kind, bag, uses, ALL_MISSING)
		return { id = def.id, label = def.label, use = def.use, count = total, item = item }
	end
	local total, first = 0, nil
	for _, id in def.items or {} do
		if (counts[id] or 0) > 0 then
			total += counts[id]
			first = first or id
		end
	end
	return { id = def.id, label = def.label, use = def.use, count = total, item = first or def.hold }
end

-- The bar in order: always slots, then one per quick slot (Quick1.. when empty). Kind slots show
-- the item the server would use for that kind right now. The "Guns" def gives guns their use.
function Hotbar.slots(
	defs: { SlotDef },
	bag: { Needs.Stack },
	uses: { [string]: Needs.Use },
	guns: { [string]: Gun },
	missing: Needs.Missing,
	quick: QuickSlots.Quick
): { Slot }
	local counts: { [string]: number } = {}
	for _, stack in bag do
		counts[stack.id] = (counts[stack.id] or 0) + stack.count
	end
	local byId: { [string]: SlotDef } = {}
	local slots: { Slot } = {}
	for _, def in defs do
		byId[def.id] = def
		if def.always then
			table.insert(slots, groupSlot(def, counts, bag, uses, missing))
		end
	end
	local carried = QuickSlots.carried(bag, defs, uses, guns)
	for index in quick do
		local group = QuickSlots.showing(quick, index, carried)
		local gunDef = byId.Guns
		if guns[group] and gunDef then
			local label = guns[group].label or gunDef.label
			table.insert(slots, { id = group, label = label, use = gunDef.use, count = 1, item = group })
		elseif byId[group] then
			table.insert(slots, groupSlot(byId[group], counts, bag, uses, missing))
		else
			table.insert(slots, { id = `Quick{index}`, label = "", use = "", count = 0, empty = true })
		end
	end
	return slots
end

function Hotbar.find(slots: { Slot }, id: string?): (Slot?, number?)
	for index, slot in slots do
		if slot.id == id and not slot.empty then
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
	return if slots[1] and not slots[1].empty then slots[1].id else nil
end

function Hotbar.keep(slots: { Slot }, id: string?): string?
	if Hotbar.find(slots, id) then
		return id
	end
	return Hotbar.default(slots)
end

-- Next (step 1) or previous (step -1) filled slot, wrapping round the ends.
function Hotbar.cycle(slots: { Slot }, id: string?, step: number): string?
	local filled = {}
	for _, slot in slots do
		if not slot.empty then
			table.insert(filled, slot)
		end
	end
	local count = #filled
	if count == 0 then
		return nil
	end
	local _, index = Hotbar.find(filled, id)
	local nextIndex = if index then (index - 1 + step) % count + 1 elseif step > 0 then 1 else count
	return filled[nextIndex].id
end

-- The slot a number key picks, or nil when there's no slot that far along.
function Hotbar.atNumber(slots: { Slot }, number: number): string?
	local slot = slots[number]
	return if slot and not slot.empty then slot.id else nil
end

return Hotbar
