-- Prize chest loot and PA event picks. Pure: the systems pass in the settings, the random source
-- and a clear-floor check.
local Inventory = if script then require(script.Parent.Inventory) else require("./Inventory")
local Loot = if script then require(script.Parent.Loot) else require("./Loot")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local Prizes = {}

export type ChestLoot = { headline: { Loot.Entry }, fill: { Loot.Entry }, rolls: { number } }

-- 0..1: deeper, scarier and giant halls are worth more
function Prizes.value(settings: any, depth: number, kind: string?, giant: boolean?): number
	local bonus = (kind and settings.ScaryBonus[kind] or 0) + (if giant then settings.GiantBonus else 0)
	return math.clamp(depth + bonus, 0, 1)
end

-- One guaranteed headline find, then rolls from fill (more the higher the value)
function Prizes.roll(
	loot: ChestLoot,
	value: number,
	rng: Rng.Rng,
	items: any,
	slots: number
): { Inventory.Stack }
	local stacks = {}
	local headline = Loot.roll(loot.headline, value, rng)
	if headline then
		Inventory.add(stacks, items, headline.item, headline.count, slots)
	end
	local rolls = math.floor(loot.rolls[1] + (loot.rolls[2] - loot.rolls[1]) * value + rng:next())
	for _ = 1, rolls do
		local roll = Loot.roll(loot.fill, value, rng)
		if roll then
			Inventory.add(stacks, items, roll.item, roll.count, slots)
		end
	end
	return stacks
end

-- Seconds until the next PA event in this phase, or nil when the phase has none
function Prizes.gap(gaps: { [string]: { number } }, phase: string, rng: Rng.Rng): number?
	local range = gaps[phase]
	return if range then rng:range(range[1], range[2]) else nil
end

-- An event name by weight, from the ones that can happen right now
function Prizes.pickEvent(events: { [string]: any }, possible: { [string]: boolean }, rng: Rng.Rng): string?
	local weights = {}
	local any = false
	for name, event in events do
		if possible[name] and (event.weight or 0) > 0 then
			weights[name] = event.weight
			any = true
		end
	end
	return if any then rng:weighted(weights) else nil
end

function Prizes.line(text: string, spot: string?): string
	return (string.gsub(text, "{spot}", function()
		return spot or ""
	end))
end

-- Clear floor in a ring round x, z: tries random points from near to far, nil when all are blocked
function Prizes.clearNear(
	isClear: (number, number) -> boolean,
	x: number,
	z: number,
	near: number,
	far: number,
	tries: number,
	rng: Rng.Rng
): (number?, number?)
	for attempt = 1, tries do
		local radius = near + (far - near) * (attempt - 1) / math.max(tries - 1, 1)
		local angle = rng:range(0, math.pi * 2)
		local px, pz = x + math.cos(angle) * radius, z + math.sin(angle) * radius
		if isClear(px, pz) then
			return px, pz
		end
	end
	return nil, nil
end

return Prizes
