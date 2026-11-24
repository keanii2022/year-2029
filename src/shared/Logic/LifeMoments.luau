-- Small pure helpers for the ambient moments in Life: which nearby things to animate, how far a
-- sign sways at a moment in time, and where a far figure may cross the player's sightline.
local LifeMoments = {}

export type Point = { x: number, z: number }

-- Indices of up to `count` points within min..max (flat) of x/z, nearest first.
function LifeMoments.nearest(
	points: { Point },
	x: number,
	z: number,
	min: number,
	max: number,
	count: number
): { number }
	local found = {}
	for index, point in points do
		local d = math.sqrt((point.x - x) ^ 2 + (point.z - z) ^ 2)
		if d >= min and d <= max then
			table.insert(found, { index = index, d = d })
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local picked = {}
	for n = 1, math.min(count, #found) do
		picked[n] = found[n].index
	end
	return picked
end

-- Tilt in radians round two axes at time t. Two slow sines with unrelated periods so a row of signs
-- never swings in step; seed shifts each sign's place in the cycle.
function LifeMoments.sway(
	t: number,
	seed: number,
	settings: { Angle: number, Period: number }
): (number, number)
	local amplitude = math.rad(settings.Angle)
	local tilt = amplitude * math.sin((t / settings.Period + seed) * math.pi * 2)
	local roll = amplitude * 0.4 * math.sin((t / (settings.Period * 1.7) + seed * 2.3) * math.pi * 2)
	return tilt, roll
end

-- How far down the sightline a figure can cross, given how far the view is clear. Nil when the
-- clear stretch is too short to be a far end.
function LifeMoments.glimpseDistance(
	clear: number,
	settings: { Near: number, Far: number, Margin: number }
): number?
	local distance = math.min(clear - settings.Margin, settings.Far)
	if distance < settings.Near then
		return nil
	end
	return distance
end

return LifeMoments
