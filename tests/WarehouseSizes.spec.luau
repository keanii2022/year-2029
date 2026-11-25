local WarehouseGen = require("../src/shared/Logic/WarehouseGen")
local WarehouseSizes = require("../src/shared/Logic/WarehouseSizes")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local SEEDS = { 2029, 77, 9001 }

local function distinct(list: { any }, key: string): number
	local seen, n = {}, 0
	for _, entry in list do
		if not seen[entry[key]] then
			seen[entry[key]] = true
			n += 1
		end
	end
	return n
end

local function checkLayout(name: string, seed: number)
	local sized = WarehouseSizes.configFor(name, config)
	local layout = WarehouseGen.generate(sized, seed)
	local half = config.Sizes[name] / 2
	expect(layout.size).toBe(config.Sizes[name])
	expect(#layout.zones).toBe(layout.blocks * layout.blocks)
	for _, zone in layout.zones do
		expect(zone.x0 >= -half and zone.x1 <= half and zone.z0 >= -half and zone.z1 <= half).toBeTruthy()
	end
	local entrance = WarehouseGen.zoneAt(layout, layout.entrance.x, layout.entrance.z - 40)
	expect(entrance and entrance.kind).toBe("showroom")

	-- A good mix even on the smallest floor: most zone kinds and plenty of different installations
	expect(distinct(layout.zones, "kind") >= 6).toBeTruthy()
	expect(#layout.rooms >= 8).toBeTruthy()
	expect(distinct(layout.rooms, "kind") >= 6).toBeTruthy()
	for _, room in layout.rooms do
		local zone = WarehouseGen.zoneAt(layout, room.cx, room.cz)
		expect(zone and zone.kind).toBe("installation")
		expect(#room.doors >= 1).toBeTruthy()
	end

	-- Spawns: about the scaled count, spread out, inside the walls and clear
	local wanted = WarehouseSizes.scaled(layout.size, config.SpawnCount, config)
	expect(#layout.spawns >= math.ceil(wanted * 0.75)).toBeTruthy()
	expect(#layout.spawns <= wanted).toBeTruthy()
	for i, a in layout.spawns do
		expect(math.abs(a.x) < half and math.abs(a.z) < half).toBeTruthy()
		expect(WarehouseGen.isClear(layout, sized, a.x, a.z, config.SpawnClearance)).toBeTruthy()
		for j, b in layout.spawns do
			if i ~= j then
				expect(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= config.SpawnMinGap).toBeTruthy()
			end
		end
	end
end

return {
	["counts are untouched at the tuned size and shrink by area on smaller ones"] = function()
		expect(WarehouseSizes.scale(3200, config)).toBe(1)
		expect(WarehouseSizes.scaled(3200, 40, config)).toBe(40)
		local small = WarehouseSizes.scaled(1600, 40, config)
		local medium = WarehouseSizes.scaled(2400, 40, config)
		-- a bit denser than straight area (10 and 22.5)
		expect(small > 10 and small < medium and medium > 22 and medium < 40).toBeTruthy()
		expect(WarehouseSizes.scaled(1600, 1, config)).toBe(1)
		expect(WarehouseSizes.scaled(1600, 0, config)).toBe(0)
	end,
	["stored choices are checked and fall back to the default"] = function()
		local good = WarehouseSizes.parseChoice({ size = "Small", publicLobby = true }, config)
		expect(good.size).toBe("Small")
		expect(good.publicLobby).toBe(true)
		local junk = WarehouseSizes.parseChoice({ size = "Huge", publicLobby = "yes" }, config)
		expect(junk.size).toBe(config.DefaultSize)
		expect(junk.publicLobby).toBe(false)
		expect(WarehouseSizes.parseChoice(nil, config).size).toBe(config.DefaultSize)
		expect(WarehouseSizes.studs(nil, config)).toBe(config.Sizes[config.DefaultSize])
	end,
	["configFor swaps the size without touching the shared config"] = function()
		local sized = WarehouseSizes.configFor("Medium", config)
		expect(sized.Size).toBe(2400)
		expect(config.Size).toBe(3200)
	end,
	["every preset plans a valid warehouse"] = function()
		for name in config.Sizes do
			for _, seed in SEEDS do
				checkLayout(name, seed)
			end
		end
	end,
	["smaller presets hold fewer installations and props"] = function()
		local small = WarehouseGen.generate(WarehouseSizes.configFor("Small", config), 2029)
		local medium = WarehouseGen.generate(WarehouseSizes.configFor("Medium", config), 2029)
		local large = WarehouseGen.generate(WarehouseSizes.configFor("Large", config), 2029)
		expect(#small.rooms < #medium.rooms and #medium.rooms < #large.rooms).toBeTruthy()
		expect(#small.decals < #large.decals).toBeTruthy()
		expect(#small.spawns < #large.spawns).toBeTruthy()
	end,
}
