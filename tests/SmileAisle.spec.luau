local SmileCheck = require("../src/shared/Logic/SmileCheck")
local WarehouseGen = require("../src/shared/Logic/WarehouseGen")
local WarehouseSizes = require("../src/shared/Logic/WarehouseSizes")
local config = require("./WarehouseConfig")
local expect = require("./expect")

local SIZES = { "Small", "Standard", "Medium", "Large" }
local SEEDS = { 2029, 77, 40 }
local BOWS = { Bows = 3, DownMin = 0.15, DownMax = 1.5, GapMax = 2.5 }

local function overlaps(a: any, b: any): boolean
	return a.x0 < b.x1 and a.x1 > b.x0 and a.z0 < b.z1 and a.z1 > b.z0
end

-- Crouch at t for `down` seconds; returns true if that bow completed the set
local function bow(state: any, t: number, down: number): boolean
	SmileCheck.stepBows(state, BOWS, t, true, true)
	return SmileCheck.stepBows(state, BOWS, t + down, false, true)
end

local function checkLayout(name: string, seed: number)
	local sized = WarehouseSizes.configFor(name, config)
	local layout = WarehouseGen.generate(sized, seed)
	local plan = layout.smileAisle
	expect(plan ~= nil).toBeTruthy()
	assert(plan, "no aisle 40")

	-- Exactly one 40, and it's the one the plan hangs off
	local forties = 0
	for _, sign in layout.signs do
		if sign.number == config.SmileAisle.Number then
			forties += 1
			expect(sign).toBe(plan.sign)
		end
	end
	expect(forties).toBe(1)

	-- The office sits in the far end of the aisle's zone, clear of every rack, and is solid
	local office = plan.office
	expect(office.x1 - office.x0).toBe(config.SmileAisle.OfficeLength)
	for _, shelf in layout.shelves do
		local rack = {
			x0 = shelf.x0,
			x1 = shelf.x1,
			z0 = shelf.z - shelf.depth / 2,
			z1 = shelf.z + shelf.depth / 2,
		}
		expect(overlaps(rack, office)).toBeFalsy()
	end
	local cx, cz = (office.x0 + office.x1) / 2, (office.z0 + office.z1) / 2
	expect(WarehouseGen.isClear(layout, sized, cx, cz, 0)).toBeFalsy()

	-- The lane is open floor next to the office wall; the doorway and the mark are on it
	local lane = plan.lane
	expect(lane.z1).toBe(office.z0)
	expect(lane.z1 - lane.z0).toBe(config.RackPitch - config.RackDepth)
	expect(SmileCheck.inside(lane, plan.mark.x, plan.mark.z)).toBeTruthy()
	expect(plan.panel.x - plan.panel.width / 2 > office.x0).toBeTruthy()
	expect(WarehouseGen.isClear(layout, sized, plan.mark.x, plan.mark.z, 0)).toBeTruthy()

	-- Propaganda stays on the aisle's two rack faces
	local posters = 0
	for _, item in plan.decor do
		expect(item.x >= lane.x0 and item.x <= lane.x1).toBeTruthy()
		expect(item.z >= lane.z0 and item.z <= lane.z1).toBeTruthy()
		if item.kind == "poster" then
			posters += 1
		end
	end
	expect(posters >= 6).toBeTruthy()

	-- The lost and found box is just inside the doors
	local box = layout.lostFound
	expect(box ~= nil).toBeTruthy()
	assert(box, "no lost and found")
	expect(layout.half - box.z < config.SmileAisle.LostFoundSearch + 20).toBeTruthy()
end

return {
	["every map size has exactly one aisle 40 with the office behind it"] = function()
		for _, name in SIZES do
			for _, seed in SEEDS do
				checkLayout(name, seed)
			end
		end
	end,

	["the same seed plans the same aisle 40"] = function()
		local a = WarehouseGen.generate(config, 9001).smileAisle
		local b = WarehouseGen.generate(config, 9001).smileAisle
		assert(a and b, "no aisle 40")
		expect(a.office.x0).toBe(b.office.x0)
		expect(a.office.z0).toBe(b.office.z0)
	end,

	["three steady bows on the mark pass the smile check"] = function()
		local state = SmileCheck.newBows()
		expect(bow(state, 0, 0.4)).toBeFalsy()
		expect(bow(state, 1, 0.4)).toBeFalsy()
		expect(bow(state, 2, 0.4)).toBeTruthy()
		expect(state.count).toBe(0)
	end,

	["a sloppy bow starts the count again"] = function()
		local state = SmileCheck.newBows()
		bow(state, 0, 0.4)
		bow(state, 1, 0.05) -- too quick
		expect(state.count).toBe(0)
		bow(state, 2, 0.4)
		bow(state, 3, 3) -- held too long
		expect(state.count).toBe(0)
	end,

	["waiting too long between bows starts the count again"] = function()
		local state = SmileCheck.newBows()
		bow(state, 0, 0.4)
		bow(state, 1, 0.4)
		SmileCheck.stepBows(state, BOWS, 5, false, true)
		expect(state.count).toBe(0)
		expect(bow(state, 6, 0.4)).toBeFalsy()
	end,

	["stepping off the mark forgets the bows"] = function()
		local state = SmileCheck.newBows()
		bow(state, 0, 0.4)
		bow(state, 1, 0.4)
		SmileCheck.stepBows(state, BOWS, 1.6, false, false)
		expect(state.count).toBe(0)
		expect(bow(state, 2, 0.4)).toBeFalsy()
	end,

	["the sign only reads 41 after you look away, then snaps back"] = function()
		local rules = { HiddenFor = 2, Chance = 1, SeenFor = 0.5 }
		local state = SmileCheck.newSign()
		local always = function()
			return 0
		end
		expect(SmileCheck.stepSign(state, rules, true, 1, always)).toBeFalsy()
		expect(SmileCheck.stepSign(state, rules, false, 1, always)).toBeFalsy()
		expect(SmileCheck.stepSign(state, rules, false, 1.5, always)).toBeTruthy()
		expect(SmileCheck.stepSign(state, rules, true, 0.3, always)).toBeTruthy()
		expect(SmileCheck.stepSign(state, rules, true, 0.3, always)).toBeFalsy()
	end,

	["a failed roll waits for the next look away"] = function()
		local rules = { HiddenFor = 1, Chance = 0.5, SeenFor = 0.5 }
		local state = SmileCheck.newSign()
		local rolls = { 0.9, 0.1 }
		local n = 0
		local roll = function()
			n += 1
			return rolls[n]
		end
		expect(SmileCheck.stepSign(state, rules, false, 2, roll)).toBeFalsy()
		expect(SmileCheck.stepSign(state, rules, false, 2, roll)).toBeFalsy()
		expect(n).toBe(1)
		SmileCheck.stepSign(state, rules, true, 0.1, roll)
		expect(SmileCheck.stepSign(state, rules, false, 2, roll)).toBeTruthy()
	end,
}
