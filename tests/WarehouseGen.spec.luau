local Rng = require("../src/shared/Logic/WarehouseGenRng")
local Rooms = require("../src/shared/Logic/WarehouseGenRooms")
local WarehouseGen = require("../src/shared/Logic/WarehouseGen")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local layout = WarehouseGen.generate(config, 2029)

local function sameValue(a: any, b: any, path: string)
	if type(a) ~= "table" or type(b) ~= "table" then
		if a ~= b then
			error(`differs at {path}: {a} vs {b}`)
		end
		return
	end
	for key, value in a do
		sameValue(value, b[key], `{path}.{key}`)
	end
	for key in b do
		if a[key] == nil then
			error(`extra key at {path}.{key}`)
		end
	end
end

local function count(kind: string): number
	local n = 0
	for _, zone in layout.zones do
		if zone.kind == kind then
			n += 1
		end
	end
	return n
end

return {
	["rng is repeatable and stays in range"] = function()
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 500 do
			local value = a:next()
			expect(value).toBe(b:next())
			expect(value >= 0 and value < 1).toBeTruthy()
		end
		local c = Rng.new(8)
		expect(Rng.new(7):next() == c:next()).toBeFalsy()
	end,
	["same seed builds the same warehouse"] = function()
		sameValue(layout, WarehouseGen.generate(config, 2029), "layout")
	end,
	["different seeds build different warehouses"] = function()
		local other = WarehouseGen.generate(config, 77)
		local same = true
		for index, zone in layout.zones do
			if other.zones[index].kind ~= zone.kind then
				same = false
			end
		end
		expect(same).toBeFalsy()
	end,
	["every zone kind shows up and the floor is packed"] = function()
		expect(#layout.zones).toBe(400)
		for kind in config.ZoneKinds do
			expect(count(kind) > 0).toBeTruthy()
		end
		expect(#layout.shelves > 800).toBeTruthy()
		expect(#layout.rooms >= 25).toBeTruthy()
		expect(#layout.lights > 400).toBeTruthy()
		expect(#layout.deptSigns >= count("showroom")).toBeTruthy()
	end,
	["special zones never sit right next to the same kind, and some installations are giant"] = function()
		local blocks = layout.blocks
		local giants = 0
		for index, zone in layout.zones do
			if config.ZoneSpread[zone.kind] then
				local left = if zone.i > 0 then layout.zones[index - 1] else nil
				local up = if zone.j > 0 then layout.zones[index - blocks] else nil
				for _, other in { left, up } do
					if other and other.kind == zone.kind then
						-- Only allowed when it's the same merged giant zone
						expect(other.x0 == zone.x0 and other.z0 == zone.z0).toBeTruthy()
					end
				end
			end
			if zone.x1 - zone.x0 > config.BlockSize then
				giants += 1
			end
		end
		expect(giants > 0).toBeTruthy()
		expect(count("neighborhood") > 0).toBeTruthy()
	end,
	["two installations of the same kind are never close together"] = function()
		local gap = config.InstallationRepeatGap * config.BlockSize
		for i, a in layout.rooms do
			for j, b in layout.rooms do
				if i ~= j and a.kind == b.kind then
					local far = math.abs(a.cx - b.cx) > gap * 0.9 or math.abs(a.cz - b.cz) > gap * 0.9
					expect(far).toBeTruthy()
				end
			end
		end
	end,
	["the zones by the entrance are store departments"] = function()
		local zone = WarehouseGen.zoneAt(layout, layout.entrance.x, layout.entrance.z - 40)
		expect(zone and zone.kind).toBe("showroom")
	end,
	["every installation kind shows up, each a robot room with furniture and a doorway"] = function()
		local seen = {}
		for _, room in layout.rooms do
			seen[room.kind] = true
			local zone = WarehouseGen.zoneAt(layout, room.cx, room.cz)
			expect(zone and zone.kind).toBe("installation")
			local inside = room.x0 >= zone.x0
				and room.x1 <= zone.x1
				and room.z0 >= zone.z0
				and room.z1 <= zone.z1
			expect(inside).toBeTruthy()
			expect(#room.doors >= 1).toBeTruthy()
			expect(#room.items >= 1).toBeTruthy()
		end
		for _, seed in { 4040, 77, 9001, 31337 } do
			for _, room in WarehouseGen.generate(config, seed).rooms do
				seen[room.kind] = true
			end
		end
		for kind in config.InstallationKinds do
			expect(seen[kind]).toBeTruthy()
		end
	end,
	["every installation spills its light out of each hall doorway and hides a stash"] = function()
		local Installations = require("../src/shared/Logic/WarehouseGenInstallations")
		local stashes = {}
		for _, item in layout.loose do
			if item.name == config.InstallationStash then
				table.insert(stashes, item)
			end
		end
		for index, room in layout.rooms do
			local pocket = layout.pockets[index]
			expect(pocket.kind).toBe(room.kind)
			expect(type(room.tone)).toBe("string")
			expect(room.stash ~= nil).toBeTruthy()
			expect(Rooms.contains(pocket, room.stash.x, room.stash.z, 0)).toBeTruthy()
			local found = false
			for _, item in stashes do
				found = found or (item.x == room.stash.x and item.z == room.stash.z)
			end
			expect(found).toBeTruthy()
			for _, door in pocket.doors do
				local x, z, nx, nz = Installations.doorway(pocket, door)
				local pool, frame = false, 0
				for _, spec in layout.pieces do
					if spec.spill and math.abs(spec.x - x) < 8 and math.abs(spec.z - z) < 8 then
						if spec.lamp == `spill_{room.tone}` then
							-- outside the hall, never inside the dark
							local out = (spec.x - x) * nx + (spec.z - z) * nz
							pool = pool or out > 0
						elseif spec.style == `spill_{room.tone}` then
							frame += 1
						end
					end
				end
				expect(pool).toBeTruthy()
				expect(frame).toBe(3)
			end
		end
	end,
	["pockets stay inside their zone"] = function()
		for _, pocket in layout.pockets do
			local zone = WarehouseGen.zoneAt(layout, (pocket.x0 + pocket.x1) / 2, (pocket.z0 + pocket.z1) / 2)
			expect(zone ~= nil).toBeTruthy()
			local inside = pocket.x0 >= zone.x0 - 0.01
				and pocket.x1 <= zone.x1 + 0.01
				and pocket.z0 >= zone.z0 - 0.01
				and pocket.z1 <= zone.z1 + 0.01
			expect(inside).toBeTruthy()
		end
	end,
	["doorways leave a gap in the walls"] = function()
		local room = layout.rooms[1]
		local door = room.doors[1]
		local x, z
		if door.side == "north" then
			x, z = room.x0 + door.at, room.z0 + 0.5
		elseif door.side == "south" then
			x, z = room.x0 + door.at, room.z1 - 0.5
		elseif door.side == "west" then
			x, z = room.x0 + 0.5, room.z0 + door.at
		else
			x, z = room.x1 - 0.5, room.z0 + door.at
		end
		for _, wall in room.walls do
			expect(x > wall.x0 and x < wall.x1 and z > wall.z0 and z < wall.z1).toBeFalsy()
		end
	end,
	["racks never cross a cross aisle or the outer wall"] = function()
		for _, shelf in layout.shelves do
			local zone = WarehouseGen.zoneAt(layout, (shelf.x0 + shelf.x1) / 2, shelf.z)
			expect(shelf.x0 >= zone.x0 and shelf.x1 <= zone.x1).toBeTruthy()
			expect(math.abs(shelf.z) < layout.half - config.WallThickness).toBeTruthy()
		end
	end,
	["lights hang below the roof and know their cable length"] = function()
		for _, light in layout.lights do
			expect(light.y < config.CeilingHeight).toBeTruthy()
			expect(light.cable).toBeNear(config.CeilingHeight - light.y)
			expect(light.state == "on" or light.state == "dead" or light.state == "flicker").toBeTruthy()
		end
	end,
	["pillars stand on the cross aisle corners"] = function()
		for _, pillar in layout.pillars do
			local onGrid = (pillar.x + layout.half) % (config.BlockSize * config.PillarEvery)
			expect(onGrid).toBeNear(0)
			expect(WarehouseGen.isClear(layout, config, pillar.x, pillar.z, 0)).toBeFalsy()
		end
	end,
	["spawns are spread out and standing in the clear"] = function()
		expect(#layout.spawns >= 20).toBeTruthy()
		for i, a in layout.spawns do
			expect(WarehouseGen.isClear(layout, config, a.x, a.z, config.SpawnClearance)).toBeTruthy()
			for j, b in layout.spawns do
				if i ~= j then
					expect(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= config.SpawnMinGap).toBeTruthy()
				end
			end
		end
	end,
	["isClear refuses racks, rooms and the outer wall"] = function()
		local shelf = layout.shelves[1]
		expect(WarehouseGen.isClear(layout, config, (shelf.x0 + shelf.x1) / 2, shelf.z, 0)).toBeFalsy()
		local room = layout.rooms[1]
		expect(WarehouseGen.isClear(layout, config, room.cx, room.cz, 0)).toBeFalsy()
		expect(WarehouseGen.isClear(layout, config, layout.half - 1, 0, 0)).toBeFalsy()
	end,
	["decals sit on a face and fit it"] = function()
		expect(#layout.decals > 800).toBeTruthy()
		for _, decal in layout.decals do
			expect(math.abs(decal.nx) + math.abs(decal.nz)).toBe(1)
			expect(decal.width > 0 and decal.height > 0).toBeTruthy()
		end
	end,
	["depth grows from the entrance"] = function()
		local near = WarehouseGen.depth(layout, 0, layout.half - 10)
		local far = WarehouseGen.depth(layout, -layout.half, -layout.half)
		expect(near < 0.05).toBeTruthy()
		expect(far > 0.9).toBeTruthy()
	end,
	["roomAt and pocketAt find what's around a point"] = function()
		local room = layout.rooms[1]
		expect(WarehouseGen.roomAt(layout, room.cx, room.cz)).toBe(room)
		expect(Rooms.contains(room, room.cx, room.cz, 0)).toBeTruthy()
		local pocket = layout.pockets[1]
		expect(WarehouseGen.pocketAt(layout, (pocket.x0 + pocket.x1) / 2, (pocket.z0 + pocket.z1) / 2)).toBe(
			pocket
		)
	end,
}
