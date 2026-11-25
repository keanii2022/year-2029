-- Who may use the admin panel in a live game, plus the small rules its commands share.
-- Studio is always admin; the server glue checks that, not this module.
export type Rules = {
	userIds: { number },
	userNames: { string },
	resolvedIds: { number }, -- userNames turned into ids by the server at start
	creatorId: number?,
	creatorIsUser: boolean,
}

local AdminAccess = {}

function AdminAccess.isAdmin(userId: number, name: string, rules: Rules): boolean
	if table.find(rules.userIds, userId) or table.find(rules.resolvedIds, userId) then
		return true
	end
	if rules.creatorIsUser and rules.creatorId == userId then
		return true
	end
	-- Name match is the fallback for when the name lookup failed at start
	local lowered = string.lower(name)
	for _, allowed in rules.userNames do
		if string.lower(allowed) == lowered then
			return true
		end
	end
	return false
end

-- The step after index in a list of count, wrapping back to 1
function AdminAccess.nextIndex(index: number, count: number): number
	return index % count + 1
end

-- A whole number from 1 to max, or nil for anything else a client might send
function AdminAccess.count(value: unknown, max: number): number?
	if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > max then
		return nil
	end
	return value
end

return AdminAccess
