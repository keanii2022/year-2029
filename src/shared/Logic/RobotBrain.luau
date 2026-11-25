-- One robot's mind as a state machine. The server feeds it what the robot sensed this tick and gets
-- back an intent (where to go, how fast, which pose, and any action). No Roblox here.
--
-- Chore bots by day: study -> suspicious -> chase -> return. Caught = catch, then return.
-- A calm chore bot can be sent on an errand by day: walk out, do the chore, walk home.
-- Everyone by night: sweep -> investigate / chase / carry. Caught at night = catch (the player goes down).
-- Hunters by day: stalled, harmless. Prowlers run the night machine by day too, with day eyes.
-- A hunter that loses you searches where it saw you last and a few spots round it; one that spots
-- you freezes and stares for a moment first, then calls the others, who rush to cut you off (answerCall).
-- Any robot hit by an EMP: disabled until it wears off.
-- A befriended robot (Systems/Companion) is in "companion": it ignores night, calls and errands and
-- goes where its order says until it's released.
local RobotChores = if script then require(script.Parent.RobotChores) else require("./RobotChores")
local RobotSenses = if script then require(script.Parent.RobotSenses) else require("./RobotSenses")

local RobotBrain = {}

export type Role = "chore" | "hunter" | "prowler"
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
	| "errand"
	| "companion"
export type Point = { x: number, z: number }
export type Errand = { x: number, z: number, face: Point?, chore: string, workSeconds: number }
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
	errand: Errand?, -- set from leaving on an errand until back home
	rushing: boolean, -- investigating at a run: answering a call or chasing down where you vanished
	searchesLeft: number, -- more spots to check near the last sighting before it gives up
	stareUntil: number, -- a hunter that just spotted you freezes and stares until then, then goes
	companion: boolean, -- befriended: driven by order, not by what it senses
	order: Order?,
}
-- What a befriended robot is told to do: walk to goal (or stand), in pose, facing face.
export type Order = { goal: Point?, speed: ("walk" | "chase")?, pose: string, face: Point? }
export type Seen = { id: any, x: number, z: number, distance: number, range: number }
export type Loose = { id: any, distance: number }
export type Input = {
	phase: string, -- "Day" | "Siren" | "Night"
	dt: number,
	atHome: boolean,
	homeDistance: number,
	focusDistance: number?,
	errandDistance: number?,
	carrying: boolean,
	seen: Seen?,
	heard: Point?,
	loose: Loose?,
	roll: number?, -- 0..1 from the caller, for how long a stare lasts
}
export type Goal = "home" | "focus" | "loose" | "wander" | "study" | "errand" | "order"
export type Intent = {
	goal: Goal?,
	speed: ("walk" | "chase")?,
	pose: string,
	face: Point?,
	catch: any?,
	pickup: any?,
	drop: boolean?,
	reveal: boolean?,
	search: boolean?, -- wants the server to point its focus at the next spot to check
}

function RobotBrain.new(role: Role, phase: string, now: number): Brain
	local state: State = if phase == "Night" or role == "prowler"
		then "sweep"
		elseif role == "hunter" then "stalled"
		else "study"
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
		errand = nil,
		rushing = false,
		searchesLeft = 0,
		stareUntil = -math.huge,
		companion = false,
		order = nil,
	}
end

local function enter(brain: Brain, state: State, now: number)
	brain.state = state
	brain.since = now
	brain.arrivedAt = nil
	if state == "study" or state == "sweep" then
		brain.errand = nil
		brain.rushing = false
		brain.searchesLeft = 0
	end
end

local function calm(brain: Brain)
	brain.alert = 0
	brain.targetId = nil
end

-- By day a calm robot only sees inside its room; once chasing, out on an errand, or at night, it
-- sees anywhere.
function RobotBrain.seesOutsideRoom(brain: Brain, phase: string): boolean
	return phase == "Night" or brain.role == "prowler" or brain.state == "chase" or brain.errand ~= nil
end

-- Only a chore bot studying quietly at home, by day, takes an errand.
function RobotBrain.sendOnErrand(brain: Brain, errand: Errand, phase: string, now: number): boolean
	if brain.role ~= "chore" or phase ~= "Day" or brain.state ~= "study" or now < brain.disabledUntil then
		return false
	end
	enter(brain, "errand", now)
	brain.errand = errand
	return true
end

-- Befriended: from now on it does what its order says.
function RobotBrain.befriend(brain: Brain, now: number)
	calm(brain)
	brain.companion = true
	brain.errand = nil
	brain.order = nil
	if brain.state ~= "disabled" then
		enter(brain, "companion", now)
	end
end

-- Let go again: back to its own mind, hunting if it's night.
function RobotBrain.release(brain: Brain, phase: string, now: number)
	brain.companion = false
	brain.order = nil
	calm(brain)
	if brain.state ~= "disabled" then
		local awake = phase == "Night" or brain.role == "prowler"
		enter(brain, if awake then "sweep" else "return", now)
	end
end

function RobotBrain.steer(brain: Brain, order: Order?)
	brain.order = order
end

function RobotBrain.disable(brain: Brain, untilTime: number)
	brain.disabledUntil = math.max(brain.disabledUntil, untilTime)
end

-- Lights on: chore bots head home with whatever they carry. Lights out: everyone sweeps.
function RobotBrain.phaseChanged(brain: Brain, phase: string, now: number)
	if brain.state == "disabled" or brain.companion then
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

-- Another robot spotted someone and called it in: run to point and search round it. Only a robot
-- already on the hunt answers (sweeping or checking something), never one hauling or out cold.
function RobotBrain.answerCall(brain: Brain, point: Point, searches: number, now: number): boolean
	if now < brain.disabledUntil or (brain.state ~= "sweep" and brain.state ~= "investigate") then
		return false
	end
	enter(brain, "investigate", now)
	brain.focus = { x = point.x, z = point.z }
	brain.rushing = true
	brain.searchesLeft = searches
	return true
end

local function loseSeconds(settings: any, night: boolean): number
	local hunt = settings.Hunt
	return if night and hunt then hunt.NightLoseSeconds else settings.Sense.LoseSeconds
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

-- Something made it angry (it got shot): it goes straight for seen, no slow notice first.
function RobotBrain.provoke(brain: Brain, seen: Seen, now: number)
	if
		now < brain.disabledUntil
		or brain.state == "disabled"
		or brain.state == "stalled"
		or brain.companion
	then
		return
	end
	startChase(brain, seen, now)
end

-- Shared by day and night. Returns the intent, or nil when the chase ended this tick.
local function chase(
	brain: Brain,
	input: Input,
	settings: any,
	now: number,
	night: boolean
): (Intent?, boolean)
	local seen = input.seen
	if seen then
		brain.targetId = seen.id
		brain.lastSeenAt = now
		brain.focus = { x = seen.x, z = seen.z }
		if seen.distance <= settings.CatchRange then
			return { pose = "grab", face = brain.focus, catch = seen.id }, true
		end
	end
	if now - brain.lastSeenAt > loseSeconds(settings, night) then
		return nil, false
	end
	if now < brain.stareUntil then
		return { pose = "stare", face = brain.focus }, false
	end
	return { goal = "focus", speed = "chase", pose = "chase" }, false
end

local function day(brain: Brain, input: Input, settings: any, now: number): Intent
	local state = brain.state
	if state == "sweep" or state == "investigate" then
		calm(brain)
		enter(brain, "return", now)
		state = "return"
	elseif state == "errand" and input.phase ~= "Day" then
		enter(brain, "return", now)
		state = "return"
	end

	if state == "study" or state == "suspicious" or state == "return" or state == "errand" then
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
		local intent, caught = chase(brain, input, settings, now, false)
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
	elseif state == "errand" then
		local errand = brain.errand :: Errand
		local outPose, workPose = RobotChores.poses(errand.chore)
		if brain.arrivedAt == nil then
			if (input.errandDistance or math.huge) <= settings.ArriveRange then
				brain.arrivedAt = now
			elseif now - brain.since > settings.Chores.GiveUpSeconds then
				enter(brain, "return", now) -- couldn't get there
				return { goal = "home", speed = "walk", pose = "walk" }
			else
				return { goal = "errand", speed = "walk", pose = outPose }
			end
		end
		if now - (brain.arrivedAt :: number) >= errand.workSeconds then
			enter(brain, "return", now)
			return { goal = "home", speed = "walk", pose = "walk" }
		end
		return { pose = workPose, face = errand.face }
	elseif state == "return" then
		if input.atHome then
			enter(brain, "study", now)
			return { goal = "study", speed = "walk", pose = "study" }
		end
		return { goal = "home", speed = "walk", pose = "walk" }
	end
	return { goal = "study", speed = "walk", pose = "study" }
end

-- The hunt: night for everyone, all day for prowlers. isNight picks the eyes (faster notice, longer
-- chase); a prowler by day hunts the same way, just slower to be sure it saw you.
local function hunt(brain: Brain, input: Input, settings: any, now: number, isNight: boolean): Intent
	local state = brain.state
	if state ~= "sweep" and state ~= "investigate" and state ~= "carry" and state ~= "chase" then
		enter(brain, "sweep", now)
		state = "sweep"
	end

	if state ~= "chase" then
		watch(brain, input, settings, isNight)
		if input.seen and brain.alert >= 1 then
			local carrying = input.carrying
			startChase(brain, input.seen, now)
			local stare = settings.Hunt and settings.Hunt.Stare
			if stare then
				brain.stareUntil = now + stare[1] + (stare[2] - stare[1]) * (input.roll or 0.5)
			end
			local intent = chase(brain, input, settings, now, isNight)
			if intent then
				intent.drop = carrying
				return intent
			end
		end
	end

	if state == "chase" then
		local intent, caught = chase(brain, input, settings, now, isNight)
		if caught then
			calm(brain)
			enter(brain, "sweep", now)
			return intent :: Intent
		elseif intent then
			return intent
		end
		-- lost them: run to where they were last seen and check round it
		calm(brain)
		enter(brain, "investigate", now)
		brain.rushing = true
		brain.searchesLeft = if settings.Hunt then settings.Hunt.Searches else 0
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
				if brain.searchesLeft > 0 then
					brain.searchesLeft -= 1
					brain.arrivedAt = nil
					brain.since = now
					return { pose = "scan", face = brain.focus, search = true }
				end
				enter(brain, "sweep", now)
				state = "sweep"
			else
				return { pose = "scan", face = brain.focus }
			end
		elseif now - brain.since > settings.Sense.InvestigateSeconds * 3 then
			enter(brain, "sweep", now) -- couldn't get there
			state = "sweep"
		else
			if brain.rushing then
				return { goal = "focus", speed = "chase", pose = "chase" }
			end
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
		local awake = isNight or brain.role == "prowler"
		enter(brain, if awake then "sweep" elseif brain.role == "hunter" then "stalled" else "return", now)
	end

	if brain.companion then
		if brain.state ~= "companion" then
			enter(brain, "companion", now)
		end
		local order = brain.order
		if not order then
			return { pose = "idle" }
		end
		return {
			goal = if order.goal then "order" else nil,
			speed = if order.goal then order.speed or "walk" else nil,
			pose = order.pose,
			face = order.face,
		}
	end

	if brain.role == "hunter" and not isNight then
		if brain.state ~= "stalled" then
			calm(brain)
			enter(brain, "stalled", now)
		end
		return { pose = if input.phase == "Siren" then "wake" else "stall", drop = input.carrying }
	end

	if isNight or brain.role == "prowler" then
		return hunt(brain, input, settings, now, isNight)
	end
	return day(brain, input, settings, now)
end

return RobotBrain
