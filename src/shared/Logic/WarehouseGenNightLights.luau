-- The lights that stay on when the power goes: battery path lights along the main cross aisles
-- (the ones the giant pillars stand on), the odd work lamp left standing at a crossing, exit
-- signs over every hall doorway, and battery lamps lying about that players can carry off.
-- Pools of light with real dark between them, so the paths read at night without raising the
-- ambient. Uses its own random source so adding it never reshuffles the rest of the layout.
local Installations = if script
	then require(script.Parent.WarehouseGenInstallations)
	else require("./WarehouseGenInstallations")
local Pieces = if script then require(script.Parent.WarehouseGenPieces) else require("./WarehouseGenPieces")
local Rng = if script then require(script.Parent.WarehouseGenRng) else require("./WarehouseGenRng")

local NightLights = {}

local piece = Pieces.piece

-- A knee-high battery post with a glowing head, and a short LED strip on the floor beside it
local function pathLight(layout: any, settings: any, x: number, z: number, alongX: boolean)
	piece(layout, {
		x = x,
		y = 0.55,
		z = z,
		sx = 0.5,
		sy = 1.1,
		sz = 0.5,
		style = "bollard",
		collide = false,
	})
	piece(layout, {
		x = x,
		y = 1.35,
		z = z,
		sx = 0.6,
		sy = 0.5,
		sz = 0.6,
		style = "path_glow",
		collide = false,
		lamp = settings.PathTone,
	})
	local strip = settings.StripLength
	piece(layout, {
		x = x,
		y = 0.06,
		z = z,
		sx = if alongX then strip else 0.25,
		sy = 0.06,
		sz = if alongX then 0.25 else strip,
		style = "path_glow",
		collide = false,
	})
end

-- A work lamp on a stand someone left switched on; some of them flicker
local function workLight(layout: any, settings: any, rng: Rng.Rng, x: number, z: number)
	local height = settings.WorkLightHeight
	piece(layout, {
		x = x,
		y = 0.1,
		z = z,
		sx = 1.6,
		sy = 0.2,
		sz = 1.6,
		style = "bollard",
		collide = false,
	})
	piece(layout, {
		x = x,
		y = height / 2,
		z = z,
		sx = 0.3,
		sy = height,
		sz = 0.3,
		style = "bollard",
		collide = false,
	})
	piece(layout, {
		x = x,
		y = height + 0.5,
		z = z,
		sx = 1.6,
		sy = 1,
		sz = 0.6,
		turn = rng:range(0, 180),
		style = "work_glow",
		collide = false,
		lamp = settings.WorkTone,
		flicker = rng:next() < settings.WorkFlickerChance,
	})
end

local function insideHall(layout: any, x: number, z: number): boolean
	for _, pocket in layout.pockets do
		if x > pocket.x0 - 1 and x < pocket.x1 + 1 and z > pocket.z0 - 1 and z < pocket.z1 + 1 then
			return true
		end
	end
	return false
end

-- Path posts down both main aisle directions, swapping sides every post, skipping blocked spots
local function addPathLights(layout: any, config: any, rng: Rng.Rng, isClear: any)
	local settings = config.NightLights
	local edge = config.BlockMargin - settings.EdgeInset
	local reach = layout.half - config.WallThickness - settings.Gap / 2
	for line = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
		local across = -layout.half + line * layout.blockSize
		local side = 1
		local along = -reach
		while along <= reach do
			local offset = across + side * edge
			for _, alongX in { true, false } do
				local x = if alongX then along else offset
				local z = if alongX then offset else along
				if not insideHall(layout, x, z) and isClear(layout, config, x, z, 0.5) then
					pathLight(layout, settings, x, z, alongX)
				end
			end
			side = -side
			along += settings.Gap + rng:range(-settings.Jitter, settings.Jitter)
		end
	end
end

-- A work lamp tucked into a corner of some main-aisle crossings, clear of the pillar
local function addWorkLights(layout: any, config: any, rng: Rng.Rng, isClear: any)
	local settings = config.NightLights
	local corner = config.BlockMargin - settings.EdgeInset
	for j = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
		for i = config.PillarEvery, layout.blocks - 1, config.PillarEvery do
			if rng:next() < settings.WorkLightChance then
				local cx = -layout.half + i * layout.blockSize
				local cz = -layout.half + j * layout.blockSize
				local sx = if rng:next() < 0.5 then -1 else 1
				local x = cx + sx * (config.PillarSize / 2 + 3)
				local z = cz + (if rng:next() < 0.5 then -corner else corner)
				if not insideHall(layout, x, z) and isClear(layout, config, x, z, 0.5) then
					workLight(layout, settings, rng, x, z)
				end
			end
		end
	end
end

-- A glowing EXIT box over the outside of every hall doorway, the way out of the dark
local function addHallExits(layout: any, config: any)
	local height = config.InstallationSpill.frameHeight + 1.6
	for _, pocket in layout.pockets do
		for _, door in pocket.doors or {} do
			local x, z, nx, nz = Installations.doorway(pocket, door)
			piece(layout, {
				x = x + nx * 0.4,
				y = height,
				z = z + nz * 0.4,
				sx = 4,
				sy = 1.6,
				sz = 0.3,
				turn = if nx ~= 0 then 90 else 0,
				style = "exit_green",
				collide = false,
				label = "EXIT",
				lamp = "exit",
			})
		end
	end
end

-- Battery lamps lying in the aisles, found like loot: the carry system picks them up like any prop
local function addCarryLights(layout: any, config: any, rng: Rng.Rng, isClear: any)
	local settings = config.NightLights
	local edge = config.BlockMargin - settings.EdgeInset - 2
	local placed, tries = 0, 0
	while placed < settings.CarryLightCount and tries < settings.CarryLightCount * 20 do
		tries += 1
		local line = rng:int(1, layout.blocks - 1)
		local across = -layout.half + line * layout.blockSize + rng:range(-edge, edge)
		local along = rng:range(-layout.half, layout.half)
		local alongX = rng:next() < 0.5
		local x = if alongX then along else across
		local z = if alongX then across else along
		if not insideHall(layout, x, z) and isClear(layout, config, x, z, 2) then
			Pieces.loose(layout, rng:pick(settings.CarryLights), x, z, rng:range(0, 360))
			placed += 1
		end
	end
end

function NightLights.fill(layout: any, config: any, isClear: any)
	local rng = Rng.new(layout.seed + 104729)
	addPathLights(layout, config, rng, isClear)
	addWorkLights(layout, config, rng, isClear)
	addHallExits(layout, config)
	addCarryLights(layout, config, rng, isClear)
end

return NightLights
