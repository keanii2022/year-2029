-- Robot-only gear rules: who an EMP blast catches, disruptor cooldown, and which rewards exist yet.
local RobotWeapons = {}

export type Spot = { id: any, x: number, z: number }
export type Stack = { id: string, count: number }

-- Ids of the robots within radius of the blast centre on the floor plane.
function RobotWeapons.inBlast(cx: number, cz: number, radius: number, robots: { Spot }): { any }
	local hit = {}
	for _, robot in robots do
		if (robot.x - cx) ^ 2 + (robot.z - cz) ^ 2 <= radius * radius then
			table.insert(hit, robot.id)
		end
	end
	return hit
end

function RobotWeapons.ready(lastUsedAt: number?, now: number, cooldown: number): boolean
	return lastUsedAt == nil or now - lastUsedAt >= cooldown
end

-- Splits rewards into ones the item list knows and ones it doesn't (added by a later step).
function RobotWeapons.knownRewards(rewards: { Stack }, items: { [string]: any }): ({ Stack }, { string })
	local known, unknown = {}, {}
	for _, reward in rewards do
		if items[reward.id] then
			table.insert(known, { id = reward.id, count = reward.count })
		else
			table.insert(unknown, reward.id)
		end
	end
	return known, unknown
end

return RobotWeapons
