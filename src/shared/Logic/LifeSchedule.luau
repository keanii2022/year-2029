-- Timing for warehouse life: when the next thing happens, which thing, PA lines without repeats,
-- machine flicker patterns and how loud the room tone is. roll() returns 0..1.
local LifeSchedule = {}

export type Range = { Min: number, Max: number }
-- phases: true for full weight, or a number to scale the weight in that phase
export type Event = { weight: number, phases: { [string]: boolean | number } }
export type Bag = { order: { number }, last: number? }
export type Blink = { lit: boolean, seconds: number }

local function between(low: number, high: number, roll: () -> number): number
	return low + (high - low) * roll()
end

-- Seconds until the next event. A lower phase rate means longer gaps; rate 0 means never (nil).
function LifeSchedule.gap(range: Range, rate: number?, roll: () -> number): number?
	if not rate or rate <= 0 then
		return nil
	end
	return between(range.Min, range.Max, roll) / rate
end

local function weightIn(event: Event, phase: string): number
	local scale = event.phases[phase]
	if scale == true then
		return event.weight
	elseif type(scale) == "number" then
		return event.weight * scale
	end
	return 0
end

-- Weighted pick among events allowed in this phase. Names are sorted so a seed always gives the same pick.
function LifeSchedule.pick(events: { [string]: Event }, phase: string, roll: () -> number): string?
	local names, total = {}, 0
	for name, event in events do
		if weightIn(event, phase) > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in names do
		total += weightIn(events[name], phase)
	end
	if total <= 0 then
		return nil
	end
	local target = roll() * total
	for _, name in names do
		target -= weightIn(events[name], phase)
		if target < 0 then
			return name
		end
	end
	return names[#names]
end

function LifeSchedule.newBag(): Bag
	return { order = {}, last = nil }
end

-- Next index 1..count: each comes once before any repeats, and a refill never starts with the last one.
function LifeSchedule.draw(bag: Bag, count: number, roll: () -> number): number
	if #bag.order == 0 then
		for n = 1, count do
			bag.order[n] = n
		end
		for n = count, 2, -1 do
			local swap = math.min(n, math.floor(roll() * n) + 1)
			bag.order[n], bag.order[swap] = bag.order[swap], bag.order[n]
		end
		if count > 1 and bag.order[#bag.order] == bag.last then
			bag.order[1], bag.order[#bag.order] = bag.order[#bag.order], bag.order[1]
		end
	end
	local index = table.remove(bag.order) :: number
	bag.last = index
	return index
end

-- A machine flicker: quick dark blinks, sometimes one long dark beat, always ending lit.
function LifeSchedule.flicker(
	settings: { Blinks: { number }, Short: { number }, Dark: { number } },
	roll: () -> number
): { Blink }
	local blinks = math.floor(between(settings.Blinks[1], settings.Blinks[2] + 1 - 1e-9, roll))
	local longAt = if roll() < 0.5 then math.floor(roll() * blinks) + 1 else nil
	local pattern = {}
	for n = 1, blinks do
		local dark = if n == longAt then settings.Dark else settings.Short
		table.insert(pattern, { lit = false, seconds = between(dark[1], dark[2], roll) })
		table.insert(pattern, { lit = true, seconds = between(settings.Short[1], settings.Short[2], roll) })
	end
	return pattern
end

-- Room tone volume from how far rays travel round the player: tight aisle quiet, open floor loud.
function LifeSchedule.roomTone(
	distances: { number },
	settings: { Min: number, Max: number, Near: number, Far: number }
): number
	if #distances == 0 then
		return settings.Min
	end
	local sum = 0
	for _, d in distances do
		sum += math.clamp(d, settings.Near, settings.Far)
	end
	local open = (sum / #distances - settings.Near) / (settings.Far - settings.Near)
	return settings.Min + (settings.Max - settings.Min) * open
end

return LifeSchedule
