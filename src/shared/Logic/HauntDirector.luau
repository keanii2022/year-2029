-- Picks who gets a private scare and which one. Only players alone get scared, night weighs more,
-- every scare has a per-player cooldown, some are capped per server per night, and a player alone
-- at night long enough without a scare is guaranteed a visual one. No Roblox here.
local HauntDirector = {}

export type Point = { X: number, Y: number, Z: number }
export type Scare = {
	weight: number,
	cooldown: number,
	phases: { [string]: boolean }?,
	nightBudget: number?,
	visual: boolean?,
	hiddenOk: boolean?,
}
export type PlayerState = { lastScare: number?, aloneSince: number?, lastKind: { [string]: number } }
export type ServerState = { used: { [string]: number } }
export type Settings = {
	ChancePerMinute: number,
	PhaseWeight: { [string]: number },
	MinGap: number,
	GuaranteeAfter: number,
	Scares: { [string]: Scare },
}
export type Moment = {
	now: number,
	dt: number,
	phase: string,
	alone: boolean,
	hidden: boolean,
	roll: number, -- [0, 1): does a scare happen
	pick: number, -- [0, 1): which one
}

function HauntDirector.newPlayer(): PlayerState
	return { lastKind = {} }
end

function HauntDirector.newServer(): ServerState
	return { used = {} }
end

-- Budgets refill when a new night starts.
function HauntDirector.newNight(server: ServerState)
	table.clear(server.used)
end

function HauntDirector.isAlone(me: Point, others: { Point }, radius: number): boolean
	for _, other in others do
		local dx, dy, dz = other.X - me.X, other.Y - me.Y, other.Z - me.Z
		if dx * dx + dy * dy + dz * dz <= radius * radius then
			return false
		end
	end
	return true
end

function HauntDirector.ready(
	name: string,
	scare: Scare,
	moment: Moment,
	player: PlayerState,
	server: ServerState
): boolean
	if scare.phases and not scare.phases[moment.phase] then
		return false
	end
	if moment.hidden and not scare.hiddenOk then
		return false
	end
	local last = player.lastKind[name]
	if last and moment.now - last < scare.cooldown then
		return false
	end
	if scare.nightBudget and (server.used[name] or 0) >= scare.nightBudget then
		return false
	end
	return true
end

-- The chance a scare fires this tick, before the guarantee.
function HauntDirector.chance(settings: Settings, phase: string, dt: number): number
	local weight = settings.PhaseWeight[phase] or 0
	return math.clamp(settings.ChancePerMinute * weight * dt / 60, 0, 1)
end

-- Alone at night long enough since the last scare (or since being alone, whichever is later).
function HauntDirector.overdue(settings: Settings, moment: Moment, player: PlayerState): boolean
	if moment.phase ~= "Night" or moment.hidden or not player.aloneSince then
		return false
	end
	local since = math.max(player.aloneSince, player.lastScare or -math.huge)
	return moment.now - since >= settings.GuaranteeAfter
end

-- Returns the scare to send now, or nil. Updates when the player started being alone.
function HauntDirector.decide(
	settings: Settings,
	moment: Moment,
	player: PlayerState,
	server: ServerState
): string?
	if not moment.alone then
		player.aloneSince = nil
		return nil
	end
	player.aloneSince = player.aloneSince or moment.now
	if (settings.PhaseWeight[moment.phase] or 0) <= 0 then
		return nil
	end
	if player.lastScare and moment.now - player.lastScare < settings.MinGap then
		return nil
	end

	local forced = HauntDirector.overdue(settings, moment, player)
	if not forced and moment.roll >= HauntDirector.chance(settings, moment.phase, moment.dt) then
		return nil
	end

	local names = {}
	local total = 0
	for name, scare in settings.Scares do
		if (not forced or scare.visual) and HauntDirector.ready(name, scare, moment, player, server) then
			table.insert(names, name)
			total += scare.weight
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(names) -- stable order so the same pick always lands on the same scare
	local target = moment.pick * total
	for _, name in names do
		target -= settings.Scares[name].weight
		if target < 0 then
			return name
		end
	end
	return names[#names]
end

function HauntDirector.record(player: PlayerState, server: ServerState, name: string, now: number)
	player.lastScare = now
	player.lastKind[name] = now
	server.used[name] = (server.used[name] or 0) + 1
end

return HauntDirector
