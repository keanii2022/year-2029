-- Hunger and energy math, picking what to eat/drink/heal with, and the HUD shopping list.
-- Pure: the server feeds it attributes and inventory totals, Config/Supplies feeds the numbers.
local Needs = {}

export type State = { hunger: number, energy: number, exhausted: boolean }
export type Activity = { sprinting: boolean }
export type Use = {
	kind: string,
	hunger: number?,
	energy: number?,
	health: number?,
	time: number,
	loudness: string,
	sound: string?,
	opens: { { id: string, count: number } }?,
}
export type Stack = { id: string, count: number }
export type Missing = { hunger: number, energy: number, health: number }
export type ListRow = { label: string, have: number, want: number, low: boolean }

-- Advances needs by dt seconds. Returns the new state and the starving damage to deal.
function Needs.step(state: State, dt: number, activity: Activity, config: any): (State, number)
	local hungerDrain = config.HungerDrain * (if activity.sprinting then config.HungerSprintMultiplier else 1)
	local hunger = math.max(0, state.hunger - hungerDrain * dt)

	local energy = state.energy
	if activity.sprinting and not state.exhausted then
		energy = math.max(0, energy - (config.EnergyDrain + config.EnergySprintDrain) * dt)
	elseif energy < config.EnergyRestCap then
		energy = math.min(config.EnergyRestCap, energy + config.EnergyRestRegen * dt)
	else
		energy = math.max(config.EnergyRestCap, energy - config.EnergyDrain * dt)
	end

	local exhausted = if state.exhausted then energy < config.ExhaustedRecover else energy <= 0
	local damage = if state.hunger <= 0 then config.StarveDamage * dt else 0
	return { hunger = hunger, energy = energy, exhausted = exhausted }, damage
end

-- Applies an item's refill, clamped to Max. Refilling energy can end exhaustion.
function Needs.refill(state: State, use: Use, config: any): State
	local hunger = math.clamp(state.hunger + (use.hunger or 0), 0, config.Max)
	local energy = math.clamp(state.energy + (use.energy or 0), 0, config.Max)
	return {
		hunger = hunger,
		energy = energy,
		exhausted = state.exhausted and energy < config.ExhaustedRecover,
	}
end

-- "ok", "low" or "empty", for the HUD.
function Needs.status(value: number, config: any): string
	if value <= 0 then
		return "empty"
	elseif value < config.LowAt then
		return "low"
	end
	return "ok"
end

local function amountFor(kind: string, use: Use): number
	if kind == "Eat" then
		return use.hunger or 0
	elseif kind == "Drink" then
		return use.energy or 0
	end
	return use.health or 0
end

local function missingFor(kind: string, missing: Missing): number
	if kind == "Eat" then
		return missing.hunger
	elseif kind == "Drink" then
		return missing.energy
	end
	return missing.health
end

-- Which carried item a quick-use button should use. Prefers the smallest one that covers what's
-- missing (else the biggest), and only unpacks a box when nothing ready to eat is left.
-- Returns nil plus a reason ("full" or "none").
function Needs.pick(
	kind: string,
	bag: { Stack },
	uses: { [string]: Use },
	missing: Missing
): (string?, string?)
	local need = missingFor(kind, missing)
	if need <= 0 then
		return nil, "full"
	end
	local best: string?, bestAmount = nil, 0
	local opener: string? = nil
	for _, stack in bag do
		local use = uses[stack.id]
		if use and use.kind == kind and stack.count > 0 then
			if use.opens then
				if not opener or stack.id < opener then
					opener = stack.id
				end
			else
				local amount = amountFor(kind, use)
				local covers, bestCovers = amount >= need, bestAmount >= need
				local better = if not best
					then true
					elseif covers ~= bestCovers then covers
					elseif covers then amount < bestAmount or (amount == bestAmount and stack.id < best)
					else amount > bestAmount or (amount == bestAmount and stack.id < best)
				if better and amount > 0 then
					best, bestAmount = stack.id, amount
				end
			end
		end
	end
	if best then
		return best, nil
	end
	if opener then
		return opener, nil
	end
	return nil, "none"
end

-- How many of each shopping-list kind the bag holds, and whether it's under what feels safe.
-- A need that's already low marks its row low too.
function Needs.shoppingList(
	list: { any },
	bag: { Stack },
	uses: { [string]: Use },
	state: State,
	config: any
): { ListRow }
	local rows = {}
	for _, entry in list do
		local have = 0
		for _, stack in bag do
			local use = uses[stack.id]
			if (entry.item and stack.id == entry.item) or (entry.kind and use and use.kind == entry.kind) then
				have += stack.count
			end
		end
		local needLow = (entry.kind == "Eat" and state.hunger < config.LowAt)
			or (entry.kind == "Drink" and state.energy < config.LowAt)
		table.insert(
			rows,
			{ label = entry.label, have = have, want = entry.want, low = have < entry.want or needLow }
		)
	end
	return rows
end

return Needs
