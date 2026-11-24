-- Logic/ holds pure modules: no Roblox services or Instances, so Lune can test them.
local Clamp = {}

function Clamp.approach(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

return Clamp
