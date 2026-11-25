local Installations = require("../src/shared/Logic/WarehouseGenInstallations")
local Rng = require("../src/shared/Logic/WarehouseGenRng")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local function build(size: number, seed: number)
	local layout: any = { seed = seed, pieces = {}, rooms = {}, loose = {}, junk = {}, pockets = {} }
	layout.addSolid = function() end
	Installations.build(layout, config, Rng.new(seed), { x0 = 0, z0 = 0, x1 = size, z1 = size }, "light_grid")
	return layout, layout.rooms[1]
end

local function itemNamed(room: any, name: string): any
	for _, thing in room.items do
		if thing.name == name then
			return thing
		end
	end
	return nil
end

local function doorPoint(room: any): (number, number)
	return Installations.doorway(room, room.doors[1])
end

local CASES = { { 160, 1 }, { 160, 7 }, { 160, 42 }, { 320, 3 }, { 320, 99 } }

return {
	["light grid puts its prize chest deepest in the hall, facing the way in"] = function()
		for _, case in CASES do
			local _, room = build(case[1], case[2])
			local chest = itemNamed(room, "toy_chest")
			expect(chest ~= nil).toBeTruthy()
			local dx, dz = doorPoint(room)
			local chestGap = math.sqrt((chest.x - dx) ^ 2 + (chest.z - dz) ^ 2)
			local roomDepth = math.max(room.x1 - room.x0, room.z1 - room.z0)
			expect(chestGap > roomDepth * 0.6).toBeTruthy()
			-- facing back toward the doorway
			expect((dx - chest.x) * chest.nx + (dz - chest.z) * chest.nz > 0).toBeTruthy()
		end
	end,
	["the island is dry, lit and reached by a walkway from the doorway"] = function()
		for _, case in CASES do
			local layout, room = build(case[1], case[2])
			local chest = itemNamed(room, "toy_chest")
			local lit, dry, walk = false, true, false
			local dx, dz = doorPoint(room)
			for _, spec in layout.pieces do
				if spec.style == "water_dark" then
					local covers = math.abs(spec.x - chest.x) < spec.sx / 2
						and math.abs(spec.z - chest.z) < spec.sz / 2
					dry = dry and not covers
				end
				if
					spec.lamp == "panel"
					and math.abs(spec.x - chest.x) < 16
					and math.abs(spec.z - chest.z) < 16
				then
					lit = true
				end
				if spec.style == "tile_white" and spec.y == 0.5 then
					walk = walk
						or (
							math.abs(spec.x - dx) <= spec.sx / 2 + 1.5
							and math.abs(spec.z - dz) <= spec.sz / 2 + 1.5
						)
				end
			end
			expect(dry).toBeTruthy()
			expect(lit).toBeTruthy()
			expect(walk).toBeTruthy()
			expect(room.tone).toBe("panel")
		end
	end,
	["light grid has blinking ceiling squares and stays phone sized"] = function()
		for _, case in CASES do
			local layout = build(case[1], case[2])
			local blinking = 0
			for _, spec in layout.pieces do
				if spec.flicker and spec.style == "panel" then
					blinking += 1
				end
			end
			expect(blinking >= 1).toBeTruthy()
			expect(#layout.pieces < 500).toBeTruthy()
		end
	end,
}
