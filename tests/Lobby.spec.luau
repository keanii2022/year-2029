local Lobby = require("../src/shared/Logic/Lobby")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local SETTINGS = {
	Bots = { 15, 20 },
	BotsAt = 2080,
	SoloShare = 0.45,
	TrioShare = 0.2,
	Openings = { loot = 3, drag = 2, sneak = 1.5 },
}

local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function grid(n: number, gap: number): { Lobby.Spot }
	local spots = {}
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			table.insert(spots, { x = i * gap, z = j * gap })
		end
	end
	return spots
end

return {
	["Standard gets 15 to 20 bots, smaller maps fewer and bigger ones more"] = function()
		for seed = 1, 50 do
			local standard = Lobby.botCount(2080, config, SETTINGS, seeded(seed))
			expect(standard >= 15 and standard <= 20).toBeTruthy()
			local small = Lobby.botCount(1600, config, SETTINGS, seeded(seed))
			local medium = Lobby.botCount(2400, config, SETTINGS, seeded(seed))
			local large = Lobby.botCount(3200, config, SETTINGS, seeded(seed))
			expect(small >= 1 and small < standard and standard < medium and medium < large).toBeTruthy()
		end
	end,
	["groups are 1 to 3, add up, and mix solos with groups"] = function()
		local sizes = Lobby.groupSizes(24, SETTINGS, seeded(7))
		local total, solos, groups = 0, 0, 0
		for _, size in sizes do
			expect(size >= 1 and size <= 3).toBeTruthy()
			total += size
			if size == 1 then
				solos += 1
			else
				groups += 1
			end
		end
		expect(total).toBe(24)
		expect(solos > 0 and groups > 0).toBeTruthy()
	end,
	["spread spots never repeat until all are used, and stay far apart"] = function()
		local spots = grid(4, 100)
		local picked = Lobby.spreadSpots(spots, 4, seeded(3))
		expect(#picked).toBe(4)
		for i, a in picked do
			for j, b in picked do
				if i ~= j then
					expect(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 200).toBeTruthy()
				end
			end
		end
		local many = Lobby.spreadSpots(spots, 20, seeded(3))
		expect(#many).toBe(20)
		local seen = {}
		for index = 1, 16 do
			expect(seen[many[index]]).toBeFalsy()
			seen[many[index]] = true
		end
		expect(#Lobby.spreadSpots({}, 3, seeded(1))).toBe(0)
	end,
	["a plan seats everyone, each group busy with a lobby opening"] = function()
		local groups = Lobby.plan(22, grid(6, 300), SETTINGS, seeded(11))
		local total = 0
		for _, group in groups do
			total += group.size
			expect(SETTINGS.Openings[group.opening] ~= nil).toBeTruthy()
		end
		expect(total).toBe(22)
		expect(Lobby.opening(SETTINGS, 0)).toBe("drag")
		expect(Lobby.opening(SETTINGS, 0.999)).toBe("sneak")
	end,
}
