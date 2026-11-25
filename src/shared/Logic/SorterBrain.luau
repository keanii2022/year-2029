-- What a Sorter does each tick: freeze while seen, creep at night toward a nearby player, grab when
-- close, go home by day, and stay down for a while after being shot. Pure: the Sorters system feeds
-- it what the server sees and moves the model.
local SorterBrain = {}

export type Point = { X: number, Y: number, Z: number }
export type Mode = "still" | "creep" | "down"
export type State = { mode: Mode, downUntil: number?, caughtAt: number? }
export type Input = {
	now: number,
	dt: number,
	night: boolean,
	seen: boolean,
	position: Point,
	home: Point,
	target: Point?, -- nearest player it may hunt, if any
}
export type Action =
	{ kind: "hold" }
	| { kind: "stand" }
	| { kind: "home" }
	| { kind: "catch" }
	| { kind: "move", x: number, z: number }

export type Settings = {
	HuntRange: number,
	Leash: number,
	Speed: number,
	CatchDistance: number,
	CatchCooldown: number,
}

local function flat(a: Point, b: Point): number
	local dx, dz = b.X - a.X, b.Z - a.Z
	return math.sqrt(dx * dx + dz * dz)
end
SorterBrain.flatDistance = flat

function SorterBrain.new(): State
	return { mode = "still" }
end

-- Moves at most maxStep along the floor from `from` toward `to`, stopping stopShort away.
function SorterBrain.stepToward(from: Point, to: Point, maxStep: number, stopShort: number): (number, number)
	local distance = flat(from, to)
	local room = distance - stopShort
	if room <= 0 or distance < 1e-6 then
		return from.X, from.Z
	end
	local step = math.min(maxStep, room)
	return from.X + (to.X - from.X) / distance * step, from.Z + (to.Z - from.Z) / distance * step
end

function SorterBrain.knockDown(state: State, now: number, seconds: number)
	state.mode = "down"
	state.downUntil = now + seconds
end

function SorterBrain.decide(settings: Settings, state: State, input: Input): Action
	if state.mode == "down" then
		if input.now < (state.downUntil or 0) or input.seen then
			return { kind = "hold" }
		end
		state.mode = "still"
		state.downUntil = nil
		return { kind = "stand" }
	end
	if input.seen then
		return { kind = "hold" }
	end

	local target = input.target
	local huntable = input.night
		and target ~= nil
		and flat(input.position, target) <= settings.HuntRange
		and flat(input.home, target) <= settings.Leash
	if huntable and target then
		state.mode = "creep"
		if flat(input.position, target) <= settings.CatchDistance then
			if state.caughtAt and input.now - state.caughtAt < settings.CatchCooldown then
				return { kind = "hold" }
			end
			state.caughtAt = input.now
			return { kind = "catch" }
		end
		local x, z = SorterBrain.stepToward(
			input.position,
			target,
			settings.Speed * input.dt,
			settings.CatchDistance * 0.8
		)
		return { kind = "move", x = x, z = z }
	end

	state.mode = "still"
	if flat(input.position, input.home) > 1 then
		return { kind = "home" }
	end
	return { kind = "hold" }
end

-- Splits points into displays: each point joins the first group with a member within radius.
function SorterBrain.groupNear(points: { Point }, radius: number): { { number } }
	local groups: { { number } } = {}
	for index, point in points do
		local joined = false
		for _, group in groups do
			for _, member in group do
				if flat(points[member], point) <= radius then
					table.insert(group, index)
					joined = true
					break
				end
			end
			if joined then
				break
			end
		end
		if not joined then
			table.insert(groups, { index })
		end
	end
	return groups
end

return SorterBrain
