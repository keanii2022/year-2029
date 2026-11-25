-- Decision logic for simulated players: from what a bot sees, the time of day and the lobby mood,
-- pick what it does next and for how long. Flat numbers only, no Roblox.
local SimBrain = {}

export type Action =
	"wander"
	| "loot"
	| "sneak"
	| "drag"
	| "group"
	| "hide"
	| "flee"
	| "avoid"
	| "fight"
	| "freeze"

export type MoodSettings = {
	aggro: number, -- chance to start a fight with someone in range when picking a new action
	fightBack: number, -- chance to shoot back after being hit
	avoid: number, -- chance to back away from someone close
	freeze: number, -- chance to panic and stand still when a robot comes for it
	day: { [string]: number }, -- weights for the lights-on actions
}

export type Settings = {
	Moods: { [string]: MoodSettings },
	FleeRange: number,
	FightRange: number,
	AvoidRange: number,
	ActionTime: { [string]: { number } },
}

export type Seen = { id: any, distance: number }

export type Input = {
	phase: string, -- "Day" | "Siren" | "Night"
	mood: string,
	ammo: number,
	robot: { id: any, distance: number, chasing: boolean }?, -- nearest robot
	enemy: Seen?, -- nearest person in sight
	attacker: { id: any, distance: number, at: number }?, -- whoever last hit it, while in sight
	targetSeen: boolean, -- the current action's target is still in sight
}

export type Brain = {
	action: Action,
	target: any?,
	untilTime: number,
	phase: string?,
	answeredHit: number, -- time of the last hit it already reacted to
}

-- Fixed order so the same roll always lands on the same action.
local DAY_ACTIONS: { Action } = { "wander", "loot", "sneak", "drag", "group" }

function SimBrain.new(): Brain
	return { action = "wander", target = nil, untilTime = 0, phase = nil, answeredHit = -math.huge }
end

-- Walks the weights in DAY_ACTIONS order; roll is 0..1.
function SimBrain.pickWeighted(weights: { [string]: number }, roll: number): Action
	local total = 0
	for _, action in DAY_ACTIONS do
		total += math.max(weights[action] or 0, 0)
	end
	if total <= 0 then
		return "wander"
	end
	local point = roll * total
	for _, action in DAY_ACTIONS do
		point -= math.max(weights[action] or 0, 0)
		if point < 0 then
			return action
		end
	end
	return DAY_ACTIONS[#DAY_ACTIONS]
end

local function choose(
	brain: Brain,
	action: Action,
	target: any?,
	settings: Settings,
	now: number,
	random: () -> number
)
	local range = settings.ActionTime[action] or { 3, 6 }
	brain.action = action
	brain.target = target
	brain.untilTime = now + range[1] + (range[2] - range[1]) * random()
	return action
end

-- Updates the brain and returns its action. random() gives 0..1, passed in so tests can pin it.
function SimBrain.decide(
	brain: Brain,
	input: Input,
	settings: Settings,
	now: number,
	random: () -> number
): Action
	local mood = settings.Moods[input.mood] or settings.Moods.normal
	local night = input.phase == "Night"
	local busy = now < brain.untilTime
	local phaseChanged = brain.phase ~= input.phase
	brain.phase = input.phase

	-- Robots come first: one coming at it at night, or one chasing it by day.
	local robot = input.robot
	if robot and robot.distance <= settings.FleeRange and (night or robot.chasing) then
		if busy and (brain.action == "flee" or brain.action == "freeze") then
			return brain.action
		end
		return choose(
			brain,
			if random() < mood.freeze then "freeze" else "flee",
			robot.id,
			settings,
			now,
			random
		)
	end

	local armed = input.ammo > 0
	local attacker = input.attacker
	if attacker and attacker.at > brain.answeredHit then
		brain.answeredHit = attacker.at
		if armed and random() < mood.fightBack then
			return choose(brain, "fight", attacker.id, settings, now, random)
		end
		return choose(brain, "avoid", attacker.id, settings, now, random)
	end

	local stillValid = not phaseChanged
		and (brain.action ~= "fight" or (armed and input.targetSeen))
		and (brain.action ~= "flee" and brain.action ~= "freeze")
	if busy and stillValid then
		return brain.action
	end

	local enemy = input.enemy
	if enemy and armed and enemy.distance <= settings.FightRange and random() < mood.aggro then
		return choose(brain, "fight", enemy.id, settings, now, random)
	end
	if enemy and enemy.distance <= settings.AvoidRange and random() < mood.avoid then
		return choose(brain, "avoid", enemy.id, settings, now, random)
	end
	if input.phase == "Siren" or night then
		return choose(brain, "hide", nil, settings, now, random)
	end
	return choose(brain, SimBrain.pickWeighted(mood.day, random()), nil, settings, now, random)
end

-- A made-up gamer tag from word lists, e.g. "NeonPickle42", "sleepy_toaster" or "xXWaffleXx".
-- Drops a fresh bot straight into an action, as if it had been at it a while (a filled lobby)
function SimBrain.start(
	brain: Brain,
	action: Action,
	phase: string,
	settings: Settings,
	now: number,
	random: () -> number
): Action
	brain.phase = phase
	return choose(brain, action, nil, settings, now, random)
end

function SimBrain.gamerName(
	words: { Adjectives: { string }, Nouns: { string } },
	random: () -> number
): string
	local function pick(list: { string }): string
		return list[math.clamp(math.floor(random() * #list) + 1, 1, #list)]
	end
	local adjective, noun = pick(words.Adjectives), pick(words.Nouns)
	local style = math.floor(random() * 5)
	local number = math.floor(random() * 999) + 1
	if style == 0 then
		return `{adjective}{noun}{number}`
	elseif style == 1 then
		return `{string.lower(adjective)}_{string.lower(noun)}`
	elseif style == 2 then
		return `xX{noun}Xx`
	elseif style == 3 then
		return `{noun}{number}`
	end
	return `{adjective}{noun}`
end

return SimBrain
