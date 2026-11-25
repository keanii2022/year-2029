local DawnScore = require("../src/shared/Logic/DawnScore")
local expect = require("./expect")

local rules = {
	NightBase = 10,
	MaxMultiplier = 5,
	BankedPerStack = 2,
	BankedCap = 10,
	FortPerPiece = 2,
	FortCap = 20,
	FortDogBonus = 5,
}

local items = {
	Gun = { id = "Gun", name = "Gun", value = 20, stackSize = 1 },
	Cells = { id = "Cells", name = "Cells", value = 1, stackSize = 60 },
	Medkit = { id = "Medkit", name = "Medkit", value = 40, stackSize = 2 },
}

local function night(nights: number, fortPieces: number?, dogAtFort: boolean?, bankedStacks: number?)
	return {
		nights = nights,
		fortPieces = fortPieces or 0,
		dogAtFort = dogAtFort == true,
		bankedStacks = bankedStacks or 0,
	}
end

return {
	["the multiplier grows with nights in one life and caps"] = function()
		expect(DawnScore.multiplier(1, rules)).toBe(1)
		expect(DawnScore.multiplier(3, rules)).toBe(3)
		expect(DawnScore.multiplier(9, rules)).toBe(5)
		expect(DawnScore.multiplier(0, rules)).toBe(1)
	end,
	["a long life pays more"] = function()
		expect(DawnScore.payout(night(1), rules).total).toBe(10)
		expect(DawnScore.payout(night(4), rules).total).toBe(40)
		expect(DawnScore.payout(night(12), rules).total).toBe(50)
	end,
	["fort pieces pay each, capped, with a dog bonus only when something stands"] = function()
		local paid = DawnScore.payout(night(1, 3, true), rules)
		expect(paid.fort).toBe(6)
		expect(paid.dog).toBe(5)
		expect(paid.total).toBe(21)
		expect(DawnScore.payout(night(1, 50), rules).fort).toBe(20)
		expect(DawnScore.payout(night(1, 0, true), rules).dog).toBe(0)
	end,
	["banking pays per stack, capped"] = function()
		expect(DawnScore.payout(night(1, 0, false, 2), rules).banked).toBe(4)
		expect(DawnScore.bankedPay(30, rules)).toBe(10)
	end,
	["banked counts only what was added since the siren"] = function()
		local before = { { id = "Gun", count = 1 }, { id = "Cells", count = 10 } }
		local after =
			{ { id = "Gun", count = 1 }, { id = "Cells", count = 25 }, { id = "Medkit", count = 1 } }
		local added = DawnScore.banked(before, after)
		expect(#added).toBe(2)
		expect(added[1].id).toBe("Cells")
		expect(added[1].count).toBe(15)
		expect(added[2].id).toBe("Medkit")
	end,
	["taking things out never counts as banking"] = function()
		local added = DawnScore.banked({ { id = "Gun", count = 2 } }, { { id = "Gun", count = 1 } })
		expect(#added).toBe(0)
	end,
	["top lines list the most valuable stacks first and skip unknown items"] = function()
		local lines = DawnScore.topLines({
			{ id = "Cells", count = 30 },
			{ id = "Medkit", count = 1 },
			{ id = "Nope", count = 9 },
			{ id = "Gun", count = 1 },
		}, items, 2)
		expect(#lines).toBe(2)
		expect(lines[1].name).toBe("Medkit")
		expect(lines[2].name).toBe("Cells")
	end,
}
