-- Tension peaks: where The Sweep lands. Noise is bucketed into square zones and the zone with the
-- most weight wins; its spot is the weighted middle of the noise inside it. No Roblox here.
export type Noise = { x: number, z: number, weight: number }
export type Point = { x: number, z: number }

local Tension = {}

-- Nil when there was no noise at all
function Tension.loudestZone(noises: { Noise }, cell: number): Point?
	local zones: { [string]: { weight: number, x: number, z: number } } = {}
	local best = nil
	for _, noise in noises do
		if noise.weight > 0 then
			local key = `{math.floor(noise.x / cell)},{math.floor(noise.z / cell)}`
			local zone = zones[key] or { weight = 0, x = 0, z = 0 }
			zones[key] = zone
			zone.weight += noise.weight
			zone.x += noise.x * noise.weight
			zone.z += noise.z * noise.weight
			-- Ties go to the zone that got there first, so the same noise always picks the same zone
			if not best or zone.weight > best.weight then
				best = zone
			end
		end
	end
	if not best then
		return nil
	end
	return { x = best.x / best.weight, z = best.z / best.weight }
end

return Tension
