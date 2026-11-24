-- One robot's mind as a state machine. The server feeds it what the robot sensed this tick and gets
-- back an intent (where to go, how fast, which pose, and any action). No Roblox here.
--
-- Chore bots by day: study -> suspicious -> chase -> return. Caught = catch, then return.
-- Everyone by night: sweep -> investigate / chase / carry. Caught at night = catch (the player goes down).
-- Hunters by day: stalled, harmless. Any robot hit by an EMP: disabled until it wears off.
local RobotSenses = if script then require(script.Parent.RobotSenses) else require("./RobotSenses")

local RobotBrain = {}

export type Role = "chore" | "hunter"
export type State =
	"study"
	| "suspicious"
	| "chase"
	| "return"
	| "carry"
	| "stalled"
	| "disabled"
	| "sweep"
	| "investigate"
export type Point = { x: number, z: number }
export type Brain = {
	role: Role,
	state: State,
	since: number,
	alert: number, -- 0..1, fills while a target is in view
	focus: Point?, -- last seen target or the sound it is checking out
	targetId: any?,
	lastSeenAt: number,
	arrivedAt: number?,
	disabledUntil: number,
}
export type Seen = { id: any, x: number, z: number, distance: number, range: number }
export type Loose = { id: any, distance: number }
export type Input = {
	phase: string, -- "Day" | "Siren" | "Night"
	dt: number,
	atHome: boolean,
	homeDistance: number,
	focusDistance: number?,
	carrying: boolean,
	seen: Seen?,
	heard: Point?,
	loose: Loose?,
}
export type Goal = "home" | "focus" | "loose" | "wander" | "study"
export type Intent = {
	goal: Goal?,
	speed: ("walk" | "chase")?,
	pose: string,
	face: Point?,
	catch: any?,
	pickup: any?,
	drop: boolean?,
	reveal: boolean?,
}

function RobotBrain.new(role: Role, phase: string, now: number): Brain
	local state: State = if phase == "Night" then "sweep" elseif role == "hunter" then "stalled" else "study"
	return {
		role = role,
		state = state,
		since = now,
		alert = 0,
		focus = nil,
		targetId = nil,
		lastSeenAt = -math.huge,
		arrivedAt = nil,
		disabledUntil = -math.huge,
	}
end

local function enter(brain: Brain, state: State, now: number)
	brain.state = state
	brain.since = now
	brain.arrivedAt = nil
end

local function calm(brain: Brain)
	brain.alert = 0
	brain.targetId = nil
end

-- By day a calm robot only sees inside its room; once chasing, or at night, it sees anywhere.
function RobotBrain.seesOutsideRoom(brain: Brain, phase: string): boolean
	return phase == "Night" or brain.state == "chase"
end

function RobotBrain.disable(brain: Brain, untilTime: number)
	brain.disabledUntil = math.max(brain.disabledUntil, untilTime)
end

-- Lights on: chore bots head home with whatever they carry. Lights out: everyone sweeps.
function RobotBrain.phaseChanged(brain: Brain, phase: string, now: number)
	if brain.state == "disabled" then
		return
	end
	if phase == "Night" then
		if brain.state ~= "carry" then
			calm(brain)
			enter(brain, "sweep", now)
		end
	elseif brain.role == "chore" and brain.state ~= "carry" and brain.state ~= "study" then
		calm(brain)
		enter(brain, "return", now)
	end
end

local function watch(brain: Brain, input: Input, settings: any, night: boolean)
	local sense = settings.Sense
	local seen = input.seen
	if seen then
		local seconds = if night then sense.NightNoticeSeconds else sense.NoticeSeconds
		brain.alert =
			math.min(1, brain.alert + RobotSenses.noticeRate(seen.distance, seen.range, seconds) * input.dt)
		brain.focus = { x = seen.x, z = seen.z }
	else
		brain.alert = math.max(0, brain.alert - sense.AlertDecay * input.dt)
	end
end

local function startChase(brain: Brain, seen: Seen, now: number)
	enter(brain, "chase", now)
	brain.targetId = seen.id
	brain.lastSeenAt = now
	brain.alert = 1
end

-- Shared by day and night. Returns the intent, or nil when the chase ended this tick.
local function chase(brain: Brain, input: Input, settings: any, now: number): (Intent?, boolean)
	local seen = input.seen
	if seen then
		brain.targetId = seen.id
		brain.lastSeenAt = now
		brain.focus = { x = seen.x, z = seen.z }
		if seen.distance <= settings.CatchRange then
			return { pose = "grab", face = brain.focus, catch = seen.id }, true
		end
	end
	if now - brain.lastSeenAt > settings.Sense.LoseSeconds then
		return nil, false
	end
	return { goal = "focus", speed = "chase", pose = "chase" }, false
end

local function day(brain: Brain, input: Input, settings: any, now: number): Intent
	local state = brain.state
	if state == "sweep" or state == "investigate" then
		calm(brain)
		enter(brain, "return", now)
		state = "return"
	end

	if state == "study" or state == "suspicious" or state == "return" then
		watch(brain, input, settings, false)
		if input.seen and brain.alert >= 1 then
			startChase(brain, input.seen, now)
			state = "chase"
		elseif input.seen or input.heard then
			if input.heard and not input.seen then
				brain.focus = input.heard
			end
			if state ~= "suspicious" then
				enter(brain, "suspicious", now)
				state = "suspicious"
			elseif input.heard then
				brain.since = now
			end
		end
	end

	if state == "chase" then
		local intent, caught = chase(brain, input, settings, now)
		if intent and not caught and input.homeDistance <= settings.DayLeash then
			return intent
		end
		calm(brain)
		enter(brain, "return", now)
		if caught then
			return intent :: Intent
		end
		return { goal = "home", speed = "walk", pose = "walk" }
	elseif state == "suspicious" then
		if brain.alert <= 0 and now - brain.since >= settings.Sense.SuspiciousSeconds then
			enter(brain, if input.atHome then "study" else "return", now)
			return { goal = "study", speed = "walk", pose = "study" }
		end
		return { pose = "scan", face = brain.focus }
	elseif state == "carry" then
		if input.atHome or not input.carrying then
			enter(brain, "study", now)
			return { pose = "idle", drop = input.carrying }
		end
		return { goal = "home", speed = "walk", pose = "walk" }
	elseif state == "return" then
		if input.atHome then
			enter(brain, "study", now)
			return { goal = "study", speed = "walk", pose = "study" }
		end
		return { goal = "home", speed = "walk", pose = "walk" }
	end
	return { goal = "study", speed = "walk", pose = "study" }
end

local function night(brain: Brain, input: Input, settings: any, now: number): Intent
	local state = brain.state
	if state ~= "sweep" and state ~= "investigate" and state ~= "carry" and state ~= "chase" then
		enter(brain, "sweep", now)
		state = "sweep"
	end

	if state ~= "chase" then
		watch(brain, input, settings, true)
		if input.seen and brain.alert >= 1 then
			local carrying = input.carrying
			startChase(brain, input.seen, now)
			local intent = chase(brain, input, settings, now)
			if intent then
				intent.drop = carrying
				return intent
			end
		end
	end

	if state == "chase" then
		local intent, caught = chase(brain, input, settings, now)
		if caught then
			calm(brain)
			enter(brain, "sweep", now)
			return intent :: Intent
		elseif intent then
			return intent
		end
		-- lost them: go and look where they were last seen
		calm(brain)
		enter(brain, "investigate", now)
		state = "investigate"
	end

	if state == "carry" then
		if not input.carrying then
			enter(brain, "sweep", now)
			state = "sweep"
		elseif input.atHome then
			enter(brain, "sweep", now)
			return { pose = "idle", drop = true }
		else
			return { goal = "home", speed = "walk", pose = "walk" }
		end
	end

	if input.heard and (state == "sweep" or state == "investigate") then
		brain.focus = input.heard
		enter(brain, "investigate", now)
		state = "investigate"
	end

	if state == "investigate" then
		local focusDistance = input.focusDistance or math.huge
		if brain.arrivedAt == nil and focusDistance <= settings.ArriveRange then
			brain.arrivedAt = now
			return { pose = "scan", face = brain.focus, reveal = true }
		end
		if brain.arrivedAt then
			if now - brain.arrivedAt >= settings.Sense.InvestigateSeconds then
				enter(brain, "sweep", now)
				state = "sweep"
			else
				return { pose = "scan", face = brain.focus }
			end
		elseif now - brain.since > settings.Sense.InvestigateSeconds * 3 then
			enter(brain, "sweep", now) -- couldn't get there
			state = "sweep"
		else
			return { goal = "focus", speed = "walk", pose = "walk" }
		end
	end

	local loose = input.loose
	if loose and not input.carrying then
		if loose.distance <= settings.PickupRange then
			enter(brain, "carry", now)
			return { pose = "grab", pickup = loose.id }
		end
		return { goal = "loose", speed = "walk", pose = "walk" }
	end
	return { goal = "wander", speed = "walk", pose = "scan" }
end

function RobotBrain.update(brain: Brain, input: Input, settings: any, now: number): Intent
	local isNight = input.phase == "Night"
	if now < brain.disabledUntil then
		if brain.state ~= "disabled" then
			calm(brain)
			enter(brain, "disabled", now)
		end
		return { pose = "stall", drop = input.carrying }
	end
	if brain.state == "disabled" then
		enter(brain, if isNight then "sweep" elseif brain.role == "hunter" then "stalled" else "return", now)
	end

	if brain.role == "hunter" and not isNight then
		if brain.state ~= "stalled" then
			calm(brain)
			enter(brain, "stalled", now)
		end
		return { pose = if input.phase == "Siren" then "wake" else "stall", drop = input.carrying }
	end

	if isNight then
		return night(brain, input, settings, now)
	end
	return day(brain, input, settings, now)
end

return RobotBrain
