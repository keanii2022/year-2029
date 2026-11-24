-- The rare dog. One turns up each morning somewhere in the warehouse, wary of everyone. Feeding it over
-- a couple of days earns trust (Logic/DogTrust). Once it trusts a player it follows, guards a spot or
-- stays on their word, barks when a stranger touches what it guards and bites raiders and robots.
-- Anchored and moved with PivotTo like the robots; limbs are procedural until the clips are imported.
-- Trust goes out as the player's "DogTrust" attribute; the dog model carries Owner, Command and State.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogBrain = require(ReplicatedStorage.Shared.Logic.DogBrain)
local DogGuard = require(ReplicatedStorage.Shared.Logic.DogGuard)
local DogPoses = require(ReplicatedStorage.Shared.Logic.DogPoses)
local DogTrust = require(ReplicatedStorage.Shared.Logic.DogTrust)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Robots = require(script.Parent.Robots)
local Warehouse = require(script.Parent.Warehouse)

local settings = Config.Dog
local trustSettings = settings.Trust
local sounds = settings.Sounds

local ACTIONS = { follow = "Follow me", guard = "Guard here", stay = "Stay" }
local DOING = { follow = "Following you", guard = "Guarding this spot", stay = "Staying" }
local STAGE_LINES = {
	wary = "It snatches the food and backs off, growling.",
	eats = "It eats while you watch.",
	wags = "Its tail wags.",
	follows = "It trusts you.",
}
local REFUSALS = {
	cooldown = "Easy. One at a time.",
	visit = "It's had enough for now. Give it some space.",
	day = "It needs time. Come back tomorrow.",
	full = "It already trusts you.",
}
local PATH_AGENT = { AgentRadius = 1.5, AgentHeight = 3, AgentCanJump = false }

type Alive = { player: Player, root: BasePart, humanoid: Humanoid }
type Target =
	{ position: Vector3, robot: Robots.Robot?, player: Player?, humanoid: Humanoid?, root: BasePart? }
type Dog = {
	model: Model,
	bowl: Model?,
	home: Vector3,
	position: Vector3,
	facing: Vector3,
	state: DogBrain.State,
	command: DogBrain.Command?,
	owner: Player?,
	guardSpot: Vector3?,
	target: Target?,
	eatingUntil: number,
	alarmUntil: number,
	biteReadyAt: number,
	nextBarkAt: number,
	nextGrowlAt: number,
	nextWhineAt: number,
	speed: number,
	stride: number,
	moving: boolean,
	wagging: boolean,
	goal: Vector3?,
	face: Vector3?,
	waypoints: { Vector3 },
	waypointIndex: number,
	pathFor: Vector3?,
	pathAt: number,
	pathBusy: boolean,
	wanderGoal: Vector3?,
	wanderAt: number,
	placedState: string?,
	lastPoses: { [string]: number },
	feedPrompt: ProximityPrompt,
	commandPrompt: ProximityPrompt,
}

local Dog = {}

local folder: Folder
local feedbackRemote: RemoteEvent
local dog: Dog? = nil
local records: { [number]: DogTrust.Record } = {}
local raiders: DogGuard.Memory = {}
local bittenRobots: DogGuard.Memory = {}
local watched: { [Instance]: RBXScriptConnection } = {}
local guardedPrompts: { [ProximityPrompt]: boolean } = {}
local pivotHeight = 0
local floorY = 0
local random = Random.new()

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function onFloor(v: Vector3): Vector3
	return Vector3.new(v.X, floorY, v.Z)
end

local function point(v: Vector3): DogGuard.Point
	return { x = v.X, z = v.Z }
end

local function randomIn(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- A spot keep studs short of goal, on the side we're coming from.
local function standOff(from: Vector3, goal: Vector3, keep: number): Vector3
	local away = flat(from - goal)
	if away.Magnitude < 0.1 then
		return onFloor(from)
	end
	return onFloor(goal + away.Unit * math.min(keep, away.Magnitude))
end

local function tell(player: Player, text: string)
	if player.Parent then
		feedbackRemote:FireClient(player, text)
	end
end

local function aliveOf(player: Player): Alive?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return { player = player, root = root, humanoid = humanoid }
	end
	return nil
end

local function alivePlayers(): { Alive }
	local alive = {}
	for _, player in Players:GetPlayers() do
		local entry = aliveOf(player)
		if entry then
			table.insert(alive, entry)
		end
	end
	return alive
end

local function playSound(parent: Instance?, name: string, level: string)
	local id = ModelLibrary.soundId(name)
	if not id or not parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function publishTrust(player: Player, record: DogTrust.Record?)
	player:SetAttribute(
		"DogTrust",
		if record and record.trust > 0 then math.floor(record.trust + 0.5) else nil
	)
end

local function sparks(position: Vector3)
	local holder = Instance.new("Part")
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(onFloor(position) + Vector3.yAxis * 2.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 120, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.12, 0)
	emitter.Lifetime = NumberRange.new(0.2, 0.5)
	emitter.Speed = NumberRange.new(8, 18)
	emitter.SpreadAngle = Vector2.new(120, 120)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = folder
	emitter:Emit(20)
	Debris:AddItem(holder, 1.5)
end

-- Model and placement ------------------------------------------------------------------------------

local function buildModel(): Model?
	local model = ModelLibrary.get(settings.Model)
	if not model then
		return nil
	end
	ModelRig.rig(model)
	local box, size = model:GetBoundingBox()
	pivotHeight = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	local greybox = model:GetAttribute("Greybox") == true
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if greybox then
				part.Color = settings.GreyboxColor
			end
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end

local function setDown(model: Model, position: Vector3)
	model:PivotTo(CFrame.new(position))
	local box, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(position + Vector3.yAxis * (floorY - (box.Position.Y - size.Y / 2))))
end

local function place(current: Dog)
	local drop, pitch = DogPoses.body(current.state)
	local pivot = current.position + Vector3.yAxis * (pivotHeight - drop)
	-- the art faces +z, lookAt points -z, so look away from the way we want to face; negative X tips the nose up
	current.model:PivotTo(
		CFrame.lookAt(pivot, pivot - current.facing) * CFrame.Angles(math.rad(-pitch), 0, 0)
	)
	current.placedState = current.state
end

local function spawnSpot(): Vector3?
	local all = Warehouse.rooms()
	local rooms = {}
	for _, room in all do
		local depth = Warehouse.depth(Warehouse.toWorld(room.cx, room.cz))
		if depth >= settings.SpawnDepth[1] and depth <= settings.SpawnDepth[2] then
			table.insert(rooms, room)
		end
	end
	if #rooms == 0 then
		rooms = all
	end
	local room = rooms[random:NextInteger(1, math.max(1, #rooms))]
	if not room then
		return nil
	end
	local pad = settings.RoomPad
	local x = random:NextNumber(room.x0 + pad, math.max(room.x0 + pad, room.x1 - pad))
	local z = random:NextNumber(room.z0 + pad, math.max(room.z0 + pad, room.z1 - pad))
	return onFloor(Warehouse.toWorld(x, z))
end

-- Moving -------------------------------------------------------------------------------------------

local function blocked(from: Vector3, to: Vector3): boolean
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(from + Vector3.yAxis * 1.5, flat(to - from), params) ~= nil
end

local function walkStraight(current: Dog, goal: Vector3)
	current.waypoints = { goal }
	current.waypointIndex = 1
	current.pathFor = goal
end

local function setGoal(current: Dog, goal: Vector3?, now: number)
	current.goal = goal
	if not goal then
		current.waypoints = {}
		return
	end
	if
		flatDistance(goal, current.position) < settings.StraightLineRange
		or not blocked(current.position, goal)
	then
		walkStraight(current, goal)
		return
	end
	local onPath = current.pathFor
		and flatDistance(current.pathFor, goal) < 4
		and current.waypoints[current.waypointIndex] ~= nil
	if onPath or current.pathBusy or now - current.pathAt < settings.PathRecompute then
		return
	end
	current.pathBusy = true
	current.pathAt = now
	task.spawn(function()
		local path = PathfindingService:CreatePath(PATH_AGENT)
		local ok =
			pcall(path.ComputeAsync, path, current.position + Vector3.yAxis * 2, goal + Vector3.yAxis * 2)
		current.pathBusy = false
		if dog ~= current or not current.goal or flatDistance(current.goal, goal) > 8 then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, onFloor(waypoint.Position))
			end
			current.waypoints = points
			current.waypointIndex = math.min(2, #points)
			current.pathFor = goal
		else
			-- no path: walk straight (it doesn't collide) rather than stand frozen
			walkStraight(current, goal)
		end
	end)
end

local function turnToward(current: Dog, direction: Vector3, dt: number): boolean
	local wanted = flat(direction)
	if wanted.Magnitude < 0.01 then
		return false
	end
	local blended = current.facing:Lerp(wanted.Unit, math.min(1, dt * 8))
	if blended.Magnitude < 0.01 or (blended.Unit - current.facing).Magnitude < 0.001 then
		return false
	end
	current.facing = blended.Unit
	return true
end

-- Returns whether the dog moved or turned this frame.
local function moveStep(current: Dog, dt: number): boolean
	local waypoint = current.waypoints[current.waypointIndex]
	if not current.goal or not waypoint or not DogBrain.moves(current.state) then
		current.moving = false
		return current.face ~= nil and turnToward(current, current.face - current.position, dt)
	end
	local offset = flat(waypoint - current.position)
	if offset.Magnitude < 0.5 then
		current.waypointIndex += 1
		if current.waypointIndex > #current.waypoints then
			current.moving = false
		end
		return false
	end
	local step = math.min(offset.Magnitude, current.speed * dt)
	current.position = onFloor(current.position + offset.Unit * step)
	current.stride += step * 1.4
	current.moving = true
	turnToward(current, offset, dt)
	return true
end

local function animate(now: number)
	local current = dog
	if not current then
		return
	end
	local limbs = DogPoses.limbs(current.state, current.stride, now, current.moving, current.wagging)
	for part, t in limbs do
		local last = current.lastPoses[part]
		if last == nil or math.abs(last - t) > 0.02 then
			current.lastPoses[part] = t
			ModelRig.setPose(current.model, part, t)
		end
	end
end

-- Barking, biting, guarding ------------------------------------------------------------------------

local function bark(current: Dog, now: number)
	current.nextBarkAt = now + settings.BarkInterval
	playSound(current.model.PrimaryPart, sounds.Bark, "loud")
	Loudness.emit(current.position, "loud", current.model)
end

local function bite(current: Dog, target: Target, now: number)
	current.biteReadyAt = now + settings.BiteCooldown
	playSound(current.model.PrimaryPart, sounds.Bite, "normal")
	Loudness.emit(current.position, "normal", current.model)
	if target.robot then
		-- a bite only stuns a robot; it can't wreck one
		Robots.disable(target.robot, settings.RobotStunSeconds)
		DogGuard.remember(bittenRobots, target.robot.id, now + settings.RobotRebiteSeconds)
		sparks(target.position)
	elseif target.humanoid then
		target.humanoid:TakeDamage(settings.BiteDamage)
		playSound(target.root, sounds.Yelp, "normal")
	end
end

local function raise(offender: Player)
	local current = dog
	if not current then
		return
	end
	local now = os.clock()
	DogGuard.remember(raiders, offender.UserId, now + settings.RaiderMemory)
	current.alarmUntil = now + settings.AlarmSeconds
	bark(current, now)
end

local function stopWatching()
	for _, connection in watched do
		connection:Disconnect()
	end
	table.clear(watched)
	table.clear(guardedPrompts)
end

local function onCarried(prop: PVInstance)
	local current = dog
	local by = prop:GetAttribute("CarriedBy")
	if not current or not current.guardSpot or type(by) ~= "number" then
		return
	end
	local ownerId = current.owner and current.owner.UserId
	local spot = point(current.guardSpot)
	if DogGuard.isOffence(by, ownerId, spot, point(prop:GetPivot().Position), settings.GuardRadius) then
		local player = Players:GetPlayerByUserId(by)
		if player then
			raise(player)
		end
	end
end

-- Hooks up every grabbable prop and loot pile near the guard spot. Runs every GuardScanInterval.
local function scanGuard()
	local current = dog
	if not current or current.command ~= "guard" or not current.guardSpot or not current.owner then
		stopWatching()
		return
	end
	local spot = point(current.guardSpot)
	local inside = {}
	for _, prop in CollectionService:GetTagged(Config.Grab.Tag) do
		if
			prop:IsA("PVInstance")
			and prop:IsDescendantOf(workspace)
			and DogGuard.inRadius(spot, point(prop:GetPivot().Position), settings.GuardRadius)
		then
			inside[prop] = true
			if not watched[prop] then
				watched[prop] = prop:GetAttributeChangedSignal("CarriedBy"):Connect(function()
					onCarried(prop)
				end)
			end
		end
	end
	for prop, connection in watched do
		if not inside[prop] and prop:GetAttribute("CarriedBy") == nil then
			connection:Disconnect()
			watched[prop] = nil
		end
	end
	-- Inventory may destroy a pile in the same moment it's looted, so remember its prompts ahead of time
	table.clear(guardedPrompts)
	for _, pile in CollectionService:GetTagged(Config.Guns.LootPileTag) do
		if
			pile:IsA("PVInstance")
			and DogGuard.inRadius(spot, point(pile:GetPivot().Position), settings.GuardRadius)
		then
			for _, descendant in pile:GetDescendants() do
				if descendant:IsA("ProximityPrompt") then
					guardedPrompts[descendant] = true
				end
			end
		end
	end
end

local function findThreat(current: Dog, owner: Alive?, alive: { Alive }, now: number): (Target?, number?)
	local protect = DogGuard.protectPoint(
		current.command,
		current.guardSpot and point(current.guardSpot),
		owner and point(owner.root.Position),
		point(current.position)
	)
	local candidates = {}
	local targets: { [string]: Target } = {}
	for _, robot in Robots.inRadius(Vector3.new(protect.x, floorY, protect.z), settings.ProtectRadius) do
		if not robot.dead and not DogGuard.remembers(bittenRobots, robot.id, now) then
			local id = `robot{robot.id}`
			targets[id] = { position = robot.position, robot = robot }
			table.insert(candidates, { id = id, distance = flatDistance(robot.position, current.position) })
		end
	end
	DogGuard.forget(raiders, now)
	DogGuard.forget(bittenRobots, now)
	for _, entry in alive do
		local position = entry.root.Position
		if
			entry.player ~= current.owner
			and DogGuard.remembers(raiders, entry.player.UserId, now)
			and DogGuard.inRadius(protect, point(position), settings.ChaseRadius)
		then
			local id = `player{entry.player.UserId}`
			targets[id] =
				{ position = position, player = entry.player, humanoid = entry.humanoid, root = entry.root }
			table.insert(candidates, { id = id, distance = flatDistance(position, current.position) })
		end
	end
	local id, distance = DogGuard.nearest(candidates)
	return (if id then targets[id] else nil), distance
end

-- Ownership and prompts ----------------------------------------------------------------------------

local function updatePrompts(current: Dog)
	local owner = current.owner
	current.model:SetAttribute("Owner", owner and owner.UserId)
	current.model:SetAttribute("Command", current.command)
	current.feedPrompt.ObjectText = if owner then "Dog" else "Stray dog"
	current.commandPrompt.ActionText = ACTIONS[DogBrain.nextCommand(current.command)]
	current.commandPrompt.ObjectText = if current.command then DOING[current.command] else "Dog"
end

local function setCommand(current: Dog, command: DogBrain.Command?)
	current.command = command
	current.guardSpot = if command == "guard" then current.position else nil
	current.alarmUntil = 0
	updatePrompts(current)
	if command == "guard" then
		scanGuard()
	else
		stopWatching()
	end
end

local function disown(current: Dog)
	current.owner = nil
	setCommand(current, nil)
end

local function onFeed(player: Player)
	local current = dog
	local body = aliveOf(player)
	if not current or not body or player:GetAttribute("Cuffed") == true then
		return
	end
	if flatDistance(body.root.Position, current.position) > settings.FeedReach + 2 then
		return
	end
	local food = DogTrust.pickFood(settings.Foods, function(id)
		return Inventory.count(player, id)
	end)
	if not food then
		tell(player, "You have nothing it would eat")
		return
	end
	local record = records[player.UserId] or DogTrust.new()
	records[player.UserId] = record
	local now = os.clock()
	local day = DayNight.day()
	local _, refusal = DogTrust.room(record, now, day, trustSettings)
	if refusal then
		tell(player, REFUSALS[refusal])
		return
	end
	if Inventory.remove(player, food, 1) < 1 then
		return
	end

	local before = DogTrust.stage(record.trust, trustSettings)
	DogTrust.feed(record, settings.FoodGain[food], now, day, trustSettings)
	local stage = DogTrust.stage(record.trust, trustSettings)
	publishTrust(player, record)
	playSound(current.model.PrimaryPart, sounds.Eat, "quiet")
	if stage ~= "wary" then
		current.eatingUntil = now + settings.EatSeconds
		current.face = body.root.Position
	end

	if stage == "follows" and not current.owner then
		current.owner = player
		setCommand(current, "follow")
		tell(player, "It trusts you now. It's yours.")
	elseif stage == "follows" and current.owner ~= player then
		tell(player, "It likes you, but it already has someone.")
	elseif stage ~= before or stage == "wary" then
		tell(player, STAGE_LINES[stage])
	end
end

local function onCommand(player: Player)
	local current = dog
	if not current or current.owner ~= player or not aliveOf(player) then
		return
	end
	local command = DogBrain.nextCommand(current.command)
	setCommand(current, command)
	tell(player, DOING[command])
end

local function addPrompt(
	parent: BasePart,
	name: string,
	action: string,
	reach: number,
	hold: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.MaxActivationDistance = reach
	prompt.HoldDuration = hold
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Spawning -----------------------------------------------------------------------------------------

local function despawn()
	local current = dog
	if not current then
		return
	end
	dog = nil
	stopWatching()
	current.model:Destroy()
	if current.bowl then
		current.bowl:Destroy()
	end
end

local function spawnDog()
	local spot = spawnSpot()
	local model = buildModel()
	local root = model and model.PrimaryPart
	if not spot or not model or not root then
		if model then
			model:Destroy()
		end
		warn("[Dog] couldn't place today's dog")
		return
	end
	local angle = random:NextNumber(0, math.pi * 2)
	local facing = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local now = os.clock()
	local current: Dog = {
		model = model,
		home = spot,
		position = spot,
		facing = facing,
		state = "wander",
		eatingUntil = 0,
		alarmUntil = 0,
		biteReadyAt = 0,
		nextBarkAt = 0,
		nextGrowlAt = 0,
		nextWhineAt = now + 2,
		speed = settings.WalkSpeed,
		stride = 0,
		moving = false,
		wagging = false,
		waypoints = {},
		waypointIndex = 1,
		pathAt = -math.huge,
		pathBusy = false,
		wanderAt = now + randomIn(settings.WanderPause),
		lastPoses = {},
		feedPrompt = addPrompt(root, "Feed", "Feed", settings.FeedReach, settings.FeedHold),
		commandPrompt = addPrompt(root, "Command", ACTIONS.follow, settings.CommandReach, 0),
	}
	current.feedPrompt.Triggered:Connect(onFeed)
	current.commandPrompt.Triggered:Connect(onCommand)
	updatePrompts(current)
	place(current)
	CollectionService:AddTag(model, settings.Tag)
	model.Parent = folder

	local bowl = ModelLibrary.get(settings.BowlModel)
	if bowl then
		for _, part in bowl:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		bowl.Parent = folder
		setDown(bowl, spot - facing * 2.5)
		current.bowl = bowl
	end
	dog = current
end

local function anyoneCares(): boolean
	local current = dog
	if current and current.owner then
		return true
	end
	for userId, record in records do
		if record.trust > 0 and Players:GetPlayerByUserId(userId) then
			return true
		end
	end
	return false
end

-- A dog nobody has started on wanders off overnight and a new one turns up somewhere else.
local function onMorning()
	if dog and anyoneCares() then
		return
	end
	despawn()
	table.clear(records)
	for _, player in Players:GetPlayers() do
		publishTrust(player, nil)
	end
	spawnDog()
end

-- Thinking -----------------------------------------------------------------------------------------

local function think(now: number, dt: number)
	local current = dog
	if not current then
		return
	end
	local alive = alivePlayers()
	local owner: Alive?, nearest: Alive?, nearestDistance: number? = nil, nil, nil
	for _, entry in alive do
		local distance = flatDistance(entry.root.Position, current.position)
		local record = records[entry.player.UserId]
		if record and record.trust > 0 then
			local shown = math.floor(record.trust + 0.5)
			DogTrust.decay(record, dt, distance <= trustSettings.NearDistance, trustSettings)
			if math.floor(record.trust + 0.5) ~= shown then
				publishTrust(entry.player, record)
			end
		end
		if entry.player == current.owner then
			owner = entry
		elseif not nearestDistance or distance < nearestDistance then
			nearest, nearestDistance = entry, distance
		end
	end
	local nearestRecord = nearest and records[nearest.player.UserId]
	local nearestStage = nearest and DogTrust.stage(nearestRecord and nearestRecord.trust or 0, trustSettings)

	local target, threatDistance = nil, nil
	if current.owner then
		target, threatDistance = findThreat(current, owner, alive, now)
	end
	current.target = target

	local night = DayNight.isNight()
	local state = DogBrain.decide({
		now = now,
		night = night,
		eatingUntil = current.eatingUntil,
		alarmUntil = current.alarmUntil,
		biteReadyAt = current.biteReadyAt,
		owned = current.owner ~= nil,
		command = current.command,
		ownerDistance = owner and flatDistance(owner.root.Position, current.position),
		guardDistance = current.guardSpot and flatDistance(current.guardSpot, current.position),
		nearestStage = nearestStage,
		nearestDistance = nearestDistance,
		threatDistance = threatDistance,
	}, settings)
	if state ~= current.state then
		if state == "flee" and now >= current.nextGrowlAt then
			current.nextGrowlAt = now + settings.GrowlCooldown
			playSound(current.model.PrimaryPart, sounds.Growl, "quiet")
		end
		current.state = state
		current.model:SetAttribute("State", state)
	end
	current.wagging = current.owner ~= nil
		or (nearestStage ~= nil and DogTrust.atLeast(nearestStage, "wags") and state ~= "wander")
	current.speed = if DogBrain.runs(state) then settings.RunSpeed else settings.WalkSpeed
	current.face = nil

	if state == "wander" then
		if not current.wanderGoal or now >= current.wanderAt then
			local angle = random:NextNumber(0, math.pi * 2)
			local reach = random:NextNumber(3, settings.WanderRadius)
			current.wanderGoal =
				onFloor(current.home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach)
			current.wanderAt = now + randomIn(settings.WanderPause)
		end
		setGoal(current, current.wanderGoal, now)
	elseif state == "flee" and nearest then
		local away = flat(current.position - nearest.root.Position)
		local direction = if away.Magnitude > 0.1 then away.Unit else current.facing
		setGoal(current, onFloor(current.position + direction * (settings.WaryDistance + 4)), now)
	elseif state == "approach" and nearest then
		setGoal(current, standOff(current.position, nearest.root.Position, settings.CloseDistance - 0.5), now)
	elseif state == "follow" and owner then
		local ownerAt = onFloor(owner.root.Position)
		local distance = flatDistance(ownerAt, current.position)
		if distance > settings.CatchUpDistance then
			-- lost track of its owner (respawn, long run): slip back in just behind them
			local back = flat(owner.root.CFrame.LookVector)
			current.position = ownerAt - (if back.Magnitude > 0.1 then back.Unit else Vector3.xAxis) * 4
			current.waypoints = {}
			place(current)
		end
		local keep = if night then settings.NightFollowDistance else settings.FollowDistance
		current.speed = if distance > keep * 2 then settings.RunSpeed else settings.WalkSpeed
		setGoal(current, standOff(current.position, ownerAt, keep - 1), now)
	elseif state == "guard" and current.guardSpot then
		setGoal(current, current.guardSpot, now)
	elseif state == "alert" or state == "bite" then
		if target then
			setGoal(current, standOff(current.position, target.position, settings.BiteRange * 0.6), now)
		else
			setGoal(current, nil, now)
		end
		if now >= current.nextBarkAt then
			bark(current, now)
		end
		if
			state == "bite"
			and target
			and flatDistance(target.position, current.position) <= settings.BiteRange
		then
			bite(current, target, now)
		end
	else
		setGoal(current, nil, now)
		local watching = owner or nearest
		current.face = watching and watching.root.Position
	end

	-- a soft whine helps players find a stray; at night it whimpers whoever it's with
	local calm = state == "wander" or state == "sit" or state == "hide"
	if calm and (not current.owner or night) and now >= current.nextWhineAt then
		current.nextWhineAt = now + randomIn(settings.WhineInterval)
		playSound(current.model.PrimaryPart, sounds.Whine, "quiet")
	end
end

function Dog.Init()
	folder = Instance.new("Folder")
	folder.Name = "Dog"
	folder.Parent = workspace
	feedbackRemote = Net.event("SupplyFeedback")
end

function Dog.Start()
	if not settings.Enabled then
		return
	end
	floorY = Warehouse.toWorld(0, 0).Y

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local current = dog
		if
			guardedPrompts[prompt]
			and current
			and DogGuard.isStranger(player.UserId, current.owner and current.owner.UserId)
		then
			raise(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local current = dog
		if current and current.owner == player then
			disown(current)
		end
	end)
	DayNight.onPhaseChanged(function(phase, previous)
		if phase == "Day" and previous ~= "Day" then
			task.spawn(onMorning)
		end
	end)
	spawnDog()

	RunService.Heartbeat:Connect(function(dt)
		local current = dog
		if current and (moveStep(current, dt) or current.placedState ~= current.state) then
			place(current)
		end
	end)
	task.spawn(function()
		local interval = 1 / settings.TickRate
		while true do
			local dt = task.wait(interval)
			think(os.clock(), dt)
		end
	end)
	task.spawn(function()
		local interval = 1 / settings.AnimRate
		while true do
			task.wait(interval)
			animate(os.clock())
		end
	end)
	task.spawn(function()
		while true do
			task.wait(settings.GuardScanInterval)
			scanGuard()
		end
	end)
end

return Dog
