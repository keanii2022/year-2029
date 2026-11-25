-- The morning payout: the life streak multiplier, fort and banking bonuses, what goes on the card.
-- No Roblox here.
local Inventory = if script then require(script.Parent.Inventory) else require("./Inventory")

local DawnScore = {}

type Stack = Inventory.Stack

export type Rules = {
	NightBase: number,
	MaxMultiplier: number,
	BankedPerStack: number,
	BankedCap: number,
	FortPerPiece: number,
	FortCap: number,
	FortDogBonus: number,
	RobotBonus: number?, -- your robot companion made it through the night
}
export type Night = {
	nights: number,
	fortPieces: number,
	dogAtFort: boolean,
	bankedStacks: number,
	robotMadeIt: boolean?,
}
export type Payout = {
	multiplier: number,
	life: number,
	fort: number,
	dog: number,
	robot: number,
	banked: number,
	total: number,
}
export type Line = { name: string, count: number }

function DawnScore.multiplier(nights: number, rules: Rules): number
	return math.clamp(math.floor(nights), 1, rules.MaxMultiplier)
end

-- nights = nights survived in this life, counting the one that just ended
function DawnScore.payout(night: Night, rules: Rules): Payout
	local multiplier = DawnScore.multiplier(night.nights, rules)
	local life = rules.NightBase * multiplier
	local fort = math.min(night.fortPieces * rules.FortPerPiece, rules.FortCap)
	local dog = if night.dogAtFort and night.fortPieces > 0 then rules.FortDogBonus else 0
	local robot = if night.robotMadeIt then rules.RobotBonus or 0 else 0
	local banked = DawnScore.bankedPay(night.bankedStacks, rules)
	return {
		multiplier = multiplier,
		life = life,
		fort = fort,
		dog = dog,
		robot = robot,
		banked = banked,
		total = life + fort + dog + robot + banked,
	}
end

function DawnScore.bankedPay(stacks: number, rules: Rules): number
	return math.min(stacks * rules.BankedPerStack, rules.BankedCap)
end

-- What was added to the locker between two snapshots of its totals. Taking things out and putting
-- them back in the same window never counts twice.
function DawnScore.banked(before: { Stack }, after: { Stack }): { Stack }
	local had = {}
	for _, stack in before do
		had[stack.id] = (had[stack.id] or 0) + stack.count
	end
	local added = {}
	for _, stack in after do
		local extra = stack.count - (had[stack.id] or 0)
		if extra > 0 then
			table.insert(added, { id = stack.id, count = extra })
		end
	end
	return added
end

-- The most valuable stacks first (value x count), as names for the card
function DawnScore.topLines(stacks: { Stack }, items: Inventory.Items, shown: number): { Line }
	local known = {}
	for _, stack in stacks do
		if items[stack.id] then
			table.insert(known, stack)
		end
	end
	table.sort(known, function(a, b)
		local worthA, worthB = items[a.id].value * a.count, items[b.id].value * b.count
		if worthA ~= worthB then
			return worthA > worthB
		end
		return a.id < b.id
	end)
	local lines = {}
	for index = 1, math.min(shown, #known) do
		table.insert(lines, { name = items[known[index].id].name, count = known[index].count })
	end
	return lines
end

return DawnScore
