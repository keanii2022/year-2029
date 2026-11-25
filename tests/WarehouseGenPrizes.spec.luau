local WarehouseGen = require("../src/shared/Logic/WarehouseGen")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local layout = WarehouseGen.generate(config, 2029)
local settings = config.PrizeSpots

local function installations(): { any }
	local list = {}
	for _, room in layout.rooms do
		if room.installation then
			table.insert(list, room)
		end
	end
	return list
end

local function doorDistance(room: any, x: number, z: number): number
	local best = math.huge
	for _, door in room.doors do
		local dx, dz
		if door.side == "north" then
			dx, dz = room.x0 + door.at, room.z0
		elseif door.side == "south" then
			dx, dz = room.x0 + door.at, room.z1
		elseif door.side == "west" then
			dx, dz = room.x0, room.z0 + door.at
		else
			dx, dz = room.x1, room.z0 + door.at
		end
		best = math.min(best, math.sqrt((dx - x) ^ 2 + (dz - z) ^ 2))
	end
	return best
end

return {
	["every installation gets 1 to 3 prize spots inside its set"] = function()
		local rooms = installations()
		expect(#rooms > 0).toBeTruthy()
		for _, room in rooms do
			local prizes = room.prizes or {}
			expect(#prizes >= settings.Count[1] and #prizes <= settings.Count[2]).toBeTruthy()
			for _, spot in prizes do
				expect(spot.x > room.x0 and spot.x < room.x1).toBeTruthy()
				expect(spot.z > room.z0 and spot.z < room.z1).toBeTruthy()
			end
		end
	end,
	["prizes keep clear of doorways, furniture and each other"] = function()
		for _, room in installations() do
			for index, spot in room.prizes do
				if spot.plinth then
					expect(doorDistance(room, spot.x, spot.z) >= settings.DoorClearance).toBeTruthy()
					for _, thing in room.items do
						local gap = math.sqrt((thing.x - spot.x) ^ 2 + (thing.z - spot.z) ^ 2)
						expect(gap >= settings.Radius + 3 - 0.01).toBeTruthy()
					end
				end
				for other = index + 1, #room.prizes do
					local b = room.prizes[other]
					expect(math.sqrt((b.x - spot.x) ^ 2 + (b.z - spot.z) ^ 2) >= settings.MinGap - 0.01).toBeTruthy()
				end
			end
		end
	end,
	["the catwalk void puts its chest up on the walkway"] = function()
		local found = false
		for _, seed in { 2029, 7, 99 } do
			for _, room in WarehouseGen.generate(config, seed).rooms do
				if room.kind == "catwalk_void" then
					found = true
					expect(#room.prizes).toBe(1)
					expect(room.prizes[1].y > 5).toBeTruthy()
					expect(room.prizes[1].plinth).toBe(false)
				end
			end
		end
		expect(found).toBeTruthy()
	end,
	["prizes come out the same for the same seed"] = function()
		local again = WarehouseGen.generate(config, 2029)
		for index, room in layout.rooms do
			for n, spot in room.prizes or {} do
				local other = again.rooms[index].prizes[n]
				expect(other.x).toBe(spot.x)
				expect(other.z).toBe(spot.z)
			end
		end
	end,
}
