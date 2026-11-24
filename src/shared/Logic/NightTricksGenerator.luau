-- A generator: broken until fixed, pull start that can fail, burns fuel, sputters, dies.
local NightTricksGenerator = {}

export type State = { fixed: boolean, running: boolean, fuel: number, pulls: number }
export type PullResult = "started" | "failed" | "broken" | "empty" | "running"
export type TickEvent = "sputter" | "died" | nil

function NightTricksGenerator.new(fuel: number): State
	return { fixed = false, running = false, fuel = fuel, pulls = 0 }
end

function NightTricksGenerator.fix(state: State): State
	return { fixed = true, running = state.running, fuel = state.fuel, pulls = state.pulls }
end

-- Chance this pull catches. Each failed pull since the last start makes the next one likelier.
function NightTricksGenerator.pullChance(pulls: number, settings: any): number
	local chances = settings.PullChances
	return chances[math.min(pulls + 1, #chances)]
end

-- roll is in [0, 1).
function NightTricksGenerator.pull(state: State, roll: number, settings: any): (State, PullResult)
	if not state.fixed then
		return state, "broken"
	end
	if state.running then
		return state, "running"
	end
	if state.fuel <= 0 then
		return state, "empty"
	end
	if roll < NightTricksGenerator.pullChance(state.pulls, settings) then
		return { fixed = true, running = true, fuel = state.fuel, pulls = 0 }, "started"
	end
	return { fixed = true, running = false, fuel = state.fuel, pulls = state.pulls + 1 }, "failed"
end

function NightTricksGenerator.refuel(state: State, amount: number, settings: any): State
	return {
		fixed = state.fixed,
		running = state.running,
		fuel = math.min(settings.MaxFuel, state.fuel + amount),
		pulls = state.pulls,
	}
end

function NightTricksGenerator.isSputtering(state: State, settings: any): boolean
	return state.running and state.fuel <= settings.SputterAt
end

-- Burns fuel for dt. Reports "sputter" on the tick it starts running low and "died" when it runs dry.
function NightTricksGenerator.tick(state: State, dt: number, settings: any): (State, TickEvent)
	if not state.running then
		return state, nil
	end
	local fuel = math.max(0, state.fuel - settings.BurnPerSecond * dt)
	if fuel <= 0 then
		return { fixed = true, running = false, fuel = 0, pulls = 0 }, "died"
	end
	local nextState = { fixed = true, running = true, fuel = fuel, pulls = state.pulls }
	local startedSputtering = state.fuel > settings.SputterAt and fuel <= settings.SputterAt
	return nextState, if startedSputtering then "sputter" else nil
end

return NightTricksGenerator
