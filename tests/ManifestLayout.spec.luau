local ManifestLayout = require("../src/shared/Logic/ManifestLayout")
local expect = require("./expect")

local OPTIONS = { spacing = 2, rowGap = 10, maxRowWidth = 20 }

local function item(name: string, width: number, depth: number)
	return { name = name, size = { width, 1, depth } }
end

return {
	["models line up along a row with spacing between them"] = function()
		local plan =
			ManifestLayout.plan({ { name = "food", models = { item("a", 4, 2), item("b", 6, 3) } } }, OPTIONS)
		expect(plan.spots[1].x).toBe(2)
		expect(plan.spots[2].x).toBe(4 + 2 + 3)
		expect(plan.spots[1].z).toBe(1.5)
		expect(plan.width).toBe(12)
		expect(plan.depth).toBe(3)
	end,
	["each group starts its own labelled row"] = function()
		local plan = ManifestLayout.plan({
			{ name = "dog", models = { item("dog", 2, 4) } },
			{ name = "food", models = { item("apple", 1, 1) } },
		}, OPTIONS)
		expect(#plan.labels).toBe(2)
		expect(plan.labels[2].group).toBe("food")
		expect(plan.labels[2].z).toBe(4 + 10)
		expect(plan.spots[2].z).toBe(14.5)
	end,
	["a long group wraps onto the next row"] = function()
		local plan = ManifestLayout.plan({
			{ name = "furniture", models = { item("a", 10, 2), item("b", 10, 2), item("c", 10, 2) } },
		}, { spacing = 2, rowGap = 10, maxRowWidth = 22 })
		expect(plan.spots[2].z).toBe(1)
		expect(plan.spots[3].x).toBe(5)
		expect(plan.spots[3].z).toBe(2 + 10 + 1)
	end,
	["an item wider than a row still gets placed"] = function()
		local plan = ManifestLayout.plan({ { name = "lab", models = { item("wall", 50, 1) } } }, OPTIONS)
		expect(plan.spots[1].x).toBe(25)
		expect(plan.width).toBe(50)
	end,
}
