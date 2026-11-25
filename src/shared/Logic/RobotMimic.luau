-- The mimic, no Roblox here: a robot replays a callout someone made a little while ago from where it
-- stands, somewhere else, to draw people off. Picks the call and the robot, or nothing.
local RobotMimic = {}

export type Call = { speaker: any, index: number, x: number, z: number, time: number }
export type Candidate = { id: any, x: number, z: number }

-- Newest call first whose age is inside Delay; the robot nearest the call that is still at least
-- Offset[1] away from it (so the copy comes from the wrong place) and within Offset[2].
function RobotMimic.pick(
	calls: { Call },
	robots: { Candidate },
	now: number,
	settings: { Delay: { number }, Offset: { number } }
): (Call?, any?)
	for i = #calls, 1, -1 do
		local call = calls[i]
		local age = now - call.time
		if age < settings.Delay[1] or age > settings.Delay[2] then
			continue
		end
		local bestId, bestDistance = nil, math.huge
		for _, robot in robots do
			local d = math.sqrt((robot.x - call.x) ^ 2 + (robot.z - call.z) ^ 2)
			if d >= settings.Offset[1] and d <= settings.Offset[2] and d < bestDistance then
				bestId, bestDistance = robot.id, d
			end
		end
		if bestId ~= nil then
			return call, bestId
		end
	end
	return nil, nil
end

return RobotMimic
