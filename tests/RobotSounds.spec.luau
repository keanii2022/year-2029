local Manifest = require("../src/shared/Logic/Manifest")
local ManifestData = require("../src/shared/Logic/ManifestData")
local RobotSounds = require("../src/shared/Logic/RobotSounds")
local expect = require("./expect")

local index = Manifest.index(ManifestData :: any)
local CALLOUTS = { "callout_0", "callout_1", "callout_2", "callout_3", "callout_4", "callout_5", "callout_6" }
local MIMIC = { Copy = "robot_copy_callout_", Pitch = 0.92 }

local function lookupOf(ids: { [string]: string }): (string) -> string?
	return function(name)
		return ids[name]
	end
end

return {
	["the first uploaded name wins, else the fallback, else nothing"] = function()
		local both = lookupOf({ new = "id_new", old = "id_old" })
		local oldOnly = lookupOf({ old = "id_old" })
		expect(RobotSounds.id({ "new", "old" }, both)).toBe("id_new")
		expect(RobotSounds.id({ "new", "old" }, oldOnly)).toBe("id_old")
		expect(RobotSounds.id({ "new" }, oldOnly)).toBe(nil)
		expect(RobotSounds.id("old", oldOnly)).toBe("id_old")
	end,
	["the mimic plays its own copy of the call, or the original pitched wrong"] = function()
		local copied = lookupOf({ robot_copy_callout_2 = "copy2", callout_2 = "orig2" })
		local id, pitch = RobotSounds.mimic(2, CALLOUTS, MIMIC, copied)
		expect(id).toBe("copy2")
		expect(pitch).toBe(1)
		id, pitch = RobotSounds.mimic(2, CALLOUTS, MIMIC, lookupOf({ callout_2 = "orig2" }))
		expect(id).toBe("orig2")
		expect(pitch).toBe(0.92)
	end,
	["every picked robot sound and callout copy is in the manifest"] = function()
		local names = {
			"robot_wet_servo_breath",
			"robot_neck_crank",
			"robot_lens_focus",
			"robot_broken_welcome",
			"robot_smile_glitch",
			"robot_floor_scrape_drag",
			"robot_skitter_burst",
			"robot_ceiling_tick",
			"robot_order_bell",
			"robot_reboot_gasp",
			"robot_scanner_sweep",
			"robot_pack_chatter",
			"robot_knockdown_sputter",
		}
		for i = 0, #CALLOUTS - 1 do
			table.insert(names, MIMIC.Copy .. i)
		end
		for _, name in names do
			expect(index.sounds[name] ~= nil).toBe(true)
		end
	end,
}
