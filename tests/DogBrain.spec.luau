local DogBrain = require("../src/shared/Logic/DogBrain")
local expect = require("./expect")

local SETTINGS = {
	NoticeRange = 45,
	WaryDistance = 10,
	CautiousDistance = 5,
	CloseDistance = 3.5,
	FollowDistance = 6,
	NightFollowDistance = 3.5,
	GuardSlack = 3,
	BiteRange = 3.5,
}

local function input(overrides: { [string]: any }?): DogBrain.Input
	local base = {
		now = 100,
		night = false,
		eatingUntil = 0,
		alarmUntil = 0,
		biteReadyAt = 0,
		owned = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base :: any
end

local function decide(overrides: { [string]: any }): string
	return DogBrain.decide(input(overrides), SETTINGS)
end

return {
	["alone it wanders"] = function()
		expect(decide({})).toBe("wander")
		expect(decide({ nearestStage = "wary", nearestDistance = 80 })).toBe("wander")
	end,
	["a wary dog backs off when you get close"] = function()
		expect(decide({ nearestStage = "wary", nearestDistance = 6 })).toBe("flee")
		expect(decide({ nearestStage = "wary", nearestDistance = 20 })).toBe("sit")
	end,
	["each stage lets you closer"] = function()
		expect(decide({ nearestStage = "eats", nearestDistance = 6 })).toBe("sit")
		expect(decide({ nearestStage = "eats", nearestDistance = 3 })).toBe("flee")
		expect(decide({ nearestStage = "wags", nearestDistance = 10 })).toBe("approach")
		expect(decide({ nearestStage = "wags", nearestDistance = 2 })).toBe("sit")
	end,
	["eating beats everything"] = function()
		expect(decide({ eatingUntil = 110, nearestStage = "wary", nearestDistance = 2 })).toBe("eat")
	end,
	["a stray hides at night"] = function()
		expect(decide({ night = true })).toBe("hide")
	end,
	["it follows its owner and sits when close"] = function()
		expect(decide({ owned = true, command = "follow", ownerDistance = 12 })).toBe("follow")
		expect(decide({ owned = true, command = "follow", ownerDistance = 3 })).toBe("sit")
		expect(decide({ owned = true, command = "follow" })).toBe("sit")
	end,
	["at night it stays tight to its owner"] = function()
		expect(decide({ owned = true, night = true, command = "follow", ownerDistance = 3 })).toBe("hide")
		expect(decide({ owned = true, night = true, command = "follow", ownerDistance = 5 })).toBe("follow")
	end,
	["guarding walks back to the spot then sits"] = function()
		expect(decide({ owned = true, command = "guard", guardDistance = 8 })).toBe("guard")
		expect(decide({ owned = true, command = "guard", guardDistance = 1 })).toBe("sit")
	end,
	["stay just sits"] = function()
		expect(decide({ owned = true, command = "stay", ownerDistance = 50 })).toBe("sit")
	end,
	["threats get barked at, then bitten when close and ready"] = function()
		expect(decide({ owned = true, command = "guard", threatDistance = 10 })).toBe("alert")
		expect(decide({ owned = true, command = "guard", threatDistance = 2 })).toBe("bite")
		expect(decide({ owned = true, command = "guard", threatDistance = 2, biteReadyAt = 101 })).toBe(
			"alert"
		)
	end,
	["an alarm keeps it barking for a moment"] = function()
		expect(decide({ owned = true, command = "guard", guardDistance = 0, alarmUntil = 104 })).toBe("alert")
	end,
	["commands cycle follow, guard, stay"] = function()
		expect(DogBrain.nextCommand(nil)).toBe("follow")
		expect(DogBrain.nextCommand("follow")).toBe("guard")
		expect(DogBrain.nextCommand("guard")).toBe("stay")
		expect(DogBrain.nextCommand("stay")).toBe("follow")
	end,
	["moving and running states"] = function()
		expect(DogBrain.moves("sit")).toBeFalsy()
		expect(DogBrain.moves("follow")).toBeTruthy()
		expect(DogBrain.runs("flee")).toBeTruthy()
		expect(DogBrain.runs("wander")).toBeFalsy()
		expect(DogBrain.moves("backoff")).toBeTruthy()
		expect(DogBrain.moves("creep")).toBeTruthy()
		expect(DogBrain.moves("sniff")).toBeFalsy()
	end,
	["a wary stray shows how it reads you"] = function()
		local function with(reaction: string): string
			return decide({ nearestStage = "wary", nearestDistance = 12, reaction = reaction })
		end
		expect(with("watch")).toBe("watch")
		expect(with("backoff")).toBe("backoff")
		expect(with("run")).toBe("flee")
		expect(with("stay")).toBe("settle")
		expect(with("sniff")).toBe("sniff")
		expect(with("creep")).toBe("creep")
	end,
	["a dog that wags ignores wary reactions"] = function()
		expect(decide({ nearestStage = "wags", nearestDistance = 10, reaction = "watch" })).toBe("approach")
	end,
	["a flinch comes first, even at night"] = function()
		expect(decide({ night = true, flinchUntil = 101 })).toBe("flinch")
		expect(decide({ night = true, flinchUntil = 99 })).toBe("hide")
	end,
}
