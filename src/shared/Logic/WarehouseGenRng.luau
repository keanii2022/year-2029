-- Small seeded random source (xorshift32). Roblox's Random isn't available under Lune, and the
-- layout must come out identical for the same seed everywhere.
local WarehouseGenRng = {}
WarehouseGenRng.__index = WarehouseGenRng

export type Rng = typeof(setmetatable({} :: { state: number }, WarehouseGenRng))

function WarehouseGenRng.new(seed: number): Rng
	local state = bit32.bxor(math.floor(math.abs(seed)) % 4294967296, 0x9E3779B9)
	if state == 0 then
		state = 0x6D2B79F5
	end
	local self = setmetatable({ state = state }, WarehouseGenRng)
	for _ = 1, 8 do
		self:next()
	end
	return self
end

-- Uniform in [0, 1)
function WarehouseGenRng.next(self: Rng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x / 4294967296
end

function WarehouseGenRng.range(self: Rng, low: number, high: number): number
	return low + (high - low) * self:next()
end

-- Whole number in [low, high]
function WarehouseGenRng.int(self: Rng, low: number, high: number): number
	return math.min(high, low + math.floor((high - low + 1) * self:next()))
end

function WarehouseGenRng.pick<T>(self: Rng, list: { T }): T
	return list[self:int(1, #list)]
end

-- Weights table { name = weight }; names are sorted so the pick is the same on every run
function WarehouseGenRng.weighted(self: Rng, weights: { [string]: number }): string
	local names = {}
	local total = 0
	for name, weight in weights do
		table.insert(names, name)
		total += weight
	end
	table.sort(names)
	local roll = self:next() * total
	for _, name in names do
		roll -= weights[name]
		if roll < 0 then
			return name
		end
	end
	return names[#names]
end

function WarehouseGenRng.shuffle<T>(self: Rng, list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = self:int(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

return WarehouseGenRng
