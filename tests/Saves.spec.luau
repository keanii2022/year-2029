local Saves = require("../src/shared/Logic/Saves")
local expect = require("./expect")

local items = {
	Gun = { id = "Gun", name = "Gun", value = 20, stackSize = 1 },
	Cells = { id = "Cells", name = "Cells", value = 1, stackSize = 10 },
}

local rules = {
	items = items,
	stats = { "NightsSurvived", "Downs" },
	cosmetics = { Hat = { { id = "Cap" } }, Colour = { { id = "Grey" }, { id = "Red" } } },
	maxPieces = 5,
	isKnownModel = function(name)
		return name == "crate"
	end,
}

return {
	["nothing saved loads the defaults"] = function()
		local data, problem = Saves.load(nil, rules)
		expect(problem).toBe(nil)
		expect(data.version).toBe(Saves.VERSION)
		expect(#data.locker).toBe(0)
		expect(data.blueprint).toBe(nil)
	end,
	["a non-table save starts fresh and says corrupt"] = function()
		local data, problem = Saves.load("garbage", rules)
		expect(problem).toBe("corrupt")
		expect(#data.locker).toBe(0)
	end,
	["an unversioned save migrates to the current version"] = function()
		local data, problem = Saves.load({ locker = { { id = "Gun", count = 1 } } }, rules)
		expect(problem).toBe(nil)
		expect(data.version).toBe(Saves.VERSION)
		expect(data.locker[1].id).toBe("Gun")
	end,
	["a save from a newer build is flagged so it never gets overwritten"] = function()
		local _, problem = Saves.load({ version = Saves.VERSION + 1 }, rules)
		expect(problem).toBe("newer")
	end,
	["sanitize drops unknown items, bad counts and unknown fields"] = function()
		local data = Saves.load({
			version = 1,
			locker = {
				{ id = "Nope", count = 3 },
				{ id = "Cells", count = -4 },
				{ id = "Cells", count = 12.7 },
				"junk",
			},
			lock = { job = "x", at = 1 },
			hacked = true,
		}, rules)
		expect(#data.locker).toBe(2)
		expect(data.locker[1].count + data.locker[2].count).toBe(12)
		expect((data :: any).lock).toBe(nil)
		expect((data :: any).hacked).toBe(nil)
	end,
	["sanitize keeps a stash bigger than the slot limit"] = function()
		local stash = {}
		for _ = 1, 30 do
			table.insert(stash, { id = "Gun", count = 1 })
		end
		local data = Saves.load({ version = 1, locker = stash }, rules)
		expect(#data.locker).toBe(30)
	end,
	["stats become whole non-negative numbers for every known key"] = function()
		local data =
			Saves.load({ version = 1, stats = { NightsSurvived = 4.9, Downs = -2, Fake = 9 } }, rules)
		expect(data.stats.NightsSurvived).toBe(4)
		expect(data.stats.Downs).toBe(0)
		expect(data.stats.Fake).toBe(nil)
	end,
	["cosmetic picks must exist in their slot"] = function()
		local data =
			Saves.load({ version = 1, cosmetics = { Hat = "Cap", Colour = "Gold", Shoes = "Boot" } }, rules)
		expect(data.cosmetics.Hat).toBe("Cap")
		expect(data.cosmetics.Colour).toBe(nil)
		expect(data.cosmetics.Shoes).toBe(nil)
	end,
	["extras keep only short string keys with real numbers"] = function()
		local data = Saves.load({ version = 1, extras = { DogTrust = 3, [5] = 1, Bad = 0 / 0 } }, rules)
		expect(data.extras.DogTrust).toBe(3)
		expect(data.extras.Bad).toBe(nil)
	end,
	["retry delay doubles and caps"] = function()
		expect(Saves.retryDelay(1, 1, 16)).toBe(1)
		expect(Saves.retryDelay(3, 1, 16)).toBe(4)
		expect(Saves.retryDelay(10, 1, 16)).toBe(16)
	end,
	["lock state: free, ours, taken, and stale locks free up"] = function()
		expect(Saves.lockState(nil, "a", 100, 60)).toBe("free")
		expect(Saves.lockState({ job = "a", at = 90 }, "a", 100, 60)).toBe("ours")
		expect(Saves.lockState({ job = "b", at = 90 }, "a", 100, 60)).toBe("taken")
		expect(Saves.lockState({ job = "b", at = 10 }, "a", 100, 60)).toBe("free")
	end,
	["blocked and unknown items can't go in the locker"] = function()
		expect(Saves.canStore("Gun", items, {})).toBe(true)
		expect(select(2, Saves.canStore("Gun", items, { Gun = true }))).toBe("blocked")
		expect(select(2, Saves.canStore("Nope", items, {}))).toBe("unknown")
	end,
	["locker add respects slots"] = function()
		local locker = {}
		expect(Saves.lockerAdd(locker, items, "Cells", 25, 2)).toBe(20)
		expect(Saves.lockerAdd(locker, items, "Gun", 1, 2)).toBe(0)
	end,
	["a version 1 save migrates to 2 keeping locker and stats, with zero tokens"] = function()
		local data, problem = Saves.load({
			version = 1,
			locker = { { id = "Gun", count = 1 }, { id = "Cells", count = 7 } },
			stats = { NightsSurvived = 6, Downs = 2 },
			extras = { DogTrust = 3 },
		}, rules)
		expect(problem).toBe(nil)
		expect(data.version).toBe(2)
		expect(#data.locker).toBe(2)
		expect(data.locker[2].count).toBe(7)
		expect(data.stats.NightsSurvived).toBe(6)
		expect(data.extras.DogTrust).toBe(3)
		expect(data.tokens).toBe(0)
	end,
	["tokens become a whole non-negative number"] = function()
		expect(Saves.load({ version = 2, tokens = 41.8 }, rules).tokens).toBe(41)
		expect(Saves.load({ version = 2, tokens = -5 }, rules).tokens).toBe(0)
		expect(Saves.load({ version = 2, tokens = "lots" }, rules).tokens).toBe(0)
	end,
	["spending tokens needs enough and a positive whole amount"] = function()
		local data = Saves.default()
		Saves.addTokens(data, 10)
		expect(Saves.spendTokens(data, 4)).toBe(true)
		expect(data.tokens).toBe(6)
		expect(Saves.spendTokens(data, 7)).toBe(false)
		expect(Saves.spendTokens(data, -1)).toBe(false)
		expect(Saves.spendTokens(data, 1.5)).toBe(false)
		expect(data.tokens).toBe(6)
	end,
}
