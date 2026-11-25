-- How hard a night is, no Roblox here. Robots learn a little every night a server survives: a longer
-- sight range, another hunter every few nights, a touch more chase speed, all capped. Every HardEvery-th
-- night is a hard night with extra hunters on top.
local RobotNights = {}

export type Threat = { night: number, sight: number, hunters: number, speed: number, hard: boolean }

function RobotNights.threat(night: number, settings: any): Threat
	local steps = math.max(0, night - 1)
	local hard = settings.HardEvery > 0 and night > 0 and night % settings.HardEvery == 0
	local hunters = 1 + math.min(settings.HunterMax, steps // settings.HunterEvery)
	if hard then
		hunters += settings.HardHunters
	end
	return {
		night = night,
		sight = 1 + math.min(settings.SightMax, steps * settings.SightStep),
		hunters = hunters,
		speed = math.min(settings.SpeedMax, steps * settings.SpeedStep),
		hard = hard,
	}
end

-- Chase speed for one robot type: hunters at night run at nightChaseSpeed plus the night's bonus,
-- everyone else at chaseSpeed.
function RobotNights.chaseSpeed(
	info: { chaseSpeed: number, nightChaseSpeed: number? },
	night: boolean,
	bonus: number
): number
	if night and info.nightChaseSpeed then
		return info.nightChaseSpeed + bonus
	end
	return info.chaseSpeed
end

-- What the siren says about tonight, or nil on the first night.
function RobotNights.sirenLine(threat: Threat, settings: { LearnLine: string, HardLine: string }): string?
	if threat.hard then
		return string.format(settings.HardLine, threat.night)
	elseif threat.night > 1 then
		return string.format(settings.LearnLine, threat.night)
	end
	return nil
end

return RobotNights
