local Files = require("../src/shared/Logic/Files")
local expect = require("./expect")

local config = {
	Entries = {
		{ id = "tape_1", kind = "tape", title = "T1", text = "a" },
		{ id = "tape_2", kind = "tape", title = "T2", text = "b" },
		{ id = "tv_1", kind = "tv", title = "V1", text = "c" },
	},
}
local journals = { { id = "journal_3", title = "J3", text = "j" } }
local catalog = Files.catalog(config, journals)

return {
	["journals come first, then the config entries"] = function()
		expect(#catalog).toBe(4)
		expect(catalog[1].id).toBe("journal_3")
		expect(catalog[1].kind).toBe("journal")
		expect(catalog[4].id).toBe("tv_1")
	end,
	["a find only counts once and only for known ids"] = function()
		local found = {}
		expect(Files.add(found, catalog, "tape_1")).toBe(true)
		expect(Files.add(found, catalog, "tape_1")).toBe(false)
		expect(Files.add(found, catalog, "made_up")).toBe(false)
		expect(#found).toBe(1)
	end,
	["next unfound walks the kinds in order"] = function()
		expect(Files.nextOf(catalog, {}, { "tape", "tv" }).id).toBe("tape_1")
		expect(Files.nextOf(catalog, { "tape_1" }, { "tape", "tv" }).id).toBe("tape_2")
		expect(Files.nextOf(catalog, { "tape_1", "tape_2" }, { "tape", "tv" }).id).toBe("tv_1")
		expect(Files.nextOf(catalog, { "tape_1", "tape_2", "tv_1" }, { "tape", "tv" })).toBe(nil)
	end,
	["unknown saved ids don't count"] = function()
		expect(Files.count({ "tape_1", "old_id" }, catalog)).toBe(1)
	end,
	["a chapter opens every few finds"] = function()
		expect(Files.chaptersOpen(4, 5, 4)).toBe(0)
		expect(Files.chaptersOpen(5, 5, 4)).toBe(1)
		expect(Files.chaptersOpen(99, 5, 4)).toBe(4)
		expect(Files.nextChapterAt(7, 5, 4)).toBe(10)
		expect(Files.nextChapterAt(20, 5, 4)).toBe(nil)
	end,
}
