-- What the dog does next. The server senses the world, this picks the state, the server moves it.
local DogTrust = if script then require(script.Parent.DogTrust) else require("./DogTrust")
local DogWary = if script then require(script.Parent.DogWary) else require("./DogWary")

export type State =
	"wander"
	| "approach"
	| "flee"
	| "eat"
	| "follow"
	| "guard"
	| "alert"
	| "bite"
	| "sit"
	| "hide"
	-- a stray that doesn't trust the nearest player yet (Logic/DogWary)
	| "watch"
	| "backoff"
	| "settle"
	| "sniff"
	| "creep"
	| "flinch"
export type Command = "follow" | "guard" | "stay"
export type Input = {
	now: number,
	night: boolean,
	eatingUntil: number,
	alarmUntil: number,
	biteReadyAt: number,
	owned: boolean,
	command: Command?,
	ownerDistance: number?, -- nil while the owner is gone or down
	guardDistance: number?, -- from the guard spot
	nearestStage: DogTrust.Stage?, -- closest player that isn't the owner
	nearestDistance: number?,
	threatDistance: number?, -- closest robot or raider near what it protects
	reaction: DogWary.Reaction?, -- how a stray reacts to the nearest player before it trusts them
	flinchUntil: number?,
}
export type Settings = {
	NoticeRange: number,
	WaryDistance: number,
	CautiousDistance: number,
	CloseDistance: number,
	FollowDistance: number,
	NightFollowDistance: number,
	GuardSlack: number,
	BiteRange: number,
}

local DogBrain = {}

DogBrain.Commands = table.freeze({ "follow", "guard", "stay" })

-- The owner's prompt steps through follow -> guard -> stay -> follow.
function DogBrain.nextCommand(command: Command?): Command
	local index = command and table.find(DogBrain.Commands, command) or 0
	return DogBrain.Commands[index % #DogBrain.Commands + 1] :: Command
end

local function owned(input: Input, settings: Settings): State
	if input.threatDistance then
		if input.threatDistance <= settings.BiteRange and input.now >= input.biteReadyAt then
			return "bite"
		end
		return "alert"
	end
	if input.now < input.alarmUntil then
		return "alert"
	end
	if input.command == "guard" then
		if input.guardDistance and input.guardDistance > settings.GuardSlack then
			return "guard"
		end
		return "sit"
	elseif input.command == "stay" then
		return "sit"
	end
	if not input.ownerDistance then
		return "sit"
	end
	local keep = if input.night then settings.NightFollowDistance else settings.FollowDistance
	if input.ownerDistance > keep then
		return "follow"
	end
	return if input.night then "hide" else "sit"
end

local REACTION_STATES: { [DogWary.Reaction]: State } = {
	run = "flee",
	backoff = "backoff",
	watch = "watch",
	stay = "settle",
	sniff = "sniff",
	creep = "creep",
}

local function stray(input: Input, settings: Settings): State
	if input.now < (input.flinchUntil or 0) then
		return "flinch"
	end
	if input.night then
		return "hide"
	end
	local stage, distance = input.nearestStage, input.nearestDistance
	if not stage or not distance or distance > settings.NoticeRange then
		return "wander"
	end
	if input.reaction and not DogTrust.atLeast(stage, "wags") then
		return REACTION_STATES[input.reaction]
	end
	if stage == "wary" then
		return if distance < settings.WaryDistance then "flee" else "sit"
	elseif stage == "eats" then
		return if distance < settings.CautiousDistance then "flee" else "sit"
	end
	return if distance > settings.CloseDistance then "approach" else "sit"
end

function DogBrain.decide(input: Input, settings: Settings): State
	if input.now < input.eatingUntil then
		return "eat"
	end
	if input.owned then
		return owned(input, settings)
	end
	return stray(input, settings)
end

-- States where the dog is on the move toward something.
function DogBrain.moves(state: State): boolean
	return state == "wander"
		or state == "approach"
		or state == "flee"
		or state == "follow"
		or state == "guard"
		or state == "alert"
		or state == "bite"
		or state == "backoff"
		or state == "creep"
end

function DogBrain.runs(state: State): boolean
	return state == "flee" or state == "alert" or state == "bite"
end

return DogBrain
