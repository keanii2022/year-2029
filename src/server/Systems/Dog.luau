-- The rare dog. One turns up each morning somewhere in the warehouse, wary of everyone. Feeding it over
-- a couple of days earns trust (Logic/DogTrust). Once it trusts a player it follows, guards a spot or
-- stays on their word, barks when a stranger touches what it guards and bites raiders and robots.
-- Anchored and moved with PivotTo like the robots; limbs are procedural until the clips are imported.
-- Trust goes out as the player's "DogTrust" attribute; the dog model carries Owner, Command and State,
-- plus Watching (the UserId a wary dog is sizing up) for the client's first-sight hint.
-- Before it trusts you it reads how you move (Logic/DogWary); untamed, it calls out now and then from
-- somewhere hard to pin down (Logic/DogCalls, played on clients through "DogCall"). Each player's
-- rapport is saved (Saves data.dog) so a returning player's next dog starts a little warmer.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogBrain = require(ReplicatedStorage.Shared.Logic.DogBrain)
local DogCalls = require(ReplicatedStorage.Shared.Logic.DogCalls)
local DogGuard = require(ReplicatedStorage.Shared.Logic.DogGuard)
local DogPoses = require(ReplicatedStorage.Shared.Logic.DogPoses)
local DogTrust = require(ReplicatedStorage.Shared.Logic.DogTrust)
local DogWary = require(ReplicatedStorage.Shared.Logic.DogWary)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Robots = require(script.Parent.Robots)
local Saves = require(script.Parent.Saves)
local Warehouse = require(script.Parent.Warehouse)

local settings = Config.Dog
local trustSettings = settings.Trust
local wary = settings.Wary
local calls = settings.Calls

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
	-- wary but willing
	spookedUntil: number,
	flinchUntil: number,
	calmPlayer: Player?,
	calmFor: number,
	stepUntil: number,
	stepGoal: Vector3?,
	tell: string?,
	tellAt: number,
	tellUntil: number,
	tellPlayed: boolean,
	nextCallAt: number,
	feedPrompt: ProximityPrompt,
	commandPrompt: ProximityPrompt,
}

local Dog = {}

local folder: Folder
local feedbackRemote: RemoteEvent
local callRemote: RemoteEvent
local paRemote: RemoteEvent
local dog: Dog? = nil
local records: { [number]: DogTrust.Record } = {}
-- trust each record started at (from saved rapport), so a head start alone doesn't keep a dog around
local startTrust: { [number]: number } = {}
local holdingFood: { [Player]: boolean } = {}
local rumorToken = 0
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

-- key is a Config.Dog.Sounds key; falls back per SoundFallbacks while a sound has no id yet
local function soundIdFor(key: string): string?
	for _, name in DogCalls.soundNames(key, settings.Sounds, settings.SoundFallbacks) do
		local id = ModelLibrary.soundId(name)
		if id then
			return id
		end
	end
	return nil
end

local function playSound(parent: Instance?, key: string, level: string)
	local id = soundIdFor(key)
	if not id or not parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	sound.Parent = parent
	Mix.route(sound, "SFX")
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

-- Rays that only see the world: not the dog, not players
local function worldRayParams(): RaycastParams
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function blocked(from: Vector3, to: Vector3): boolean
	return workspace:Raycast(from + Vector3.yAxis * 1.5, flat(to - from), worldRayParams()) ~= nil
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
	-- backing off or creeping up, it keeps its eyes on you
	local watchWhileMoving = (current.state == "backoff" or current.state == "creep") and current.face
	turnToward(current, if watchWhileMoving then current.face - current.position else offset, dt)
	return true
end

local function animate(now: number)
	local current = dog
	if not current then
		return
	end
	local showing = if now >= current.tellAt and now < current.tellUntil then current.tell else nil
	local limbs = DogPoses.limbs(current.state, current.stride, now, current.moving, current.wagging, showing)
	for part, t in limbs do
		local last = current.lastPoses[part]
		if last == nil or math.abs(last - t) > 0.02 then
			current.lastPoses[part] = t
			ModelRig.setPose(current.model, part, t)
		end
	end
end

-- Wary but willing, far-off calls, rumors ----------------------------------------------------------

-- A bad move near an untamed dog: a flinch, then it bolts and won't settle for a while.
local function spook(current: Dog, now: number)
	if current.owner then
		return
	end
	if now >= current.spookedUntil then
		current.flinchUntil = now + wary.FlinchSeconds
		playSound(current.model.PrimaryPart, "Yelp", "quiet")
	end
	current.spookedUntil = now + wary.SpookSeconds
end

local function spookIfNear(position: Vector3)
	local current = dog
	if current and flatDistance(position, current.position) <= wary.SpookRadius then
		spook(current, os.clock())
	end
end

local function robotChasingNear(current: Dog): boolean
	for _, robot in Robots.inRadius(current.position, wary.ChaseRadius) do
		if not robot.dead and robot.brain.state == "chase" then
			return true
		end
	end
	return false
end

-- Small trust tell once it's done eating: a sneeze, a head tilt, sitting down.
local function queueTell(current: Dog, stage: DogTrust.Stage, now: number)
	local kind = wary.Tells[stage]
	if not kind then
		return
	end
	current.tell = kind
	current.tellAt = math.max(now, current.eatingUntil)
	current.tellUntil = current.tellAt + wary.TellSeconds
	current.tellPlayed = false
end

-- Where a call seems to come from: off toward a wall or down an aisle, never right on the dog.
local function bouncePoint(current: Dog): Vector3
	local params = worldRayParams()
	local origin = current.position + Vector3.yAxis * 1.5
	local reach = calls.Bounce[2]
	for _ = 1, calls.BounceTries do
		local angle = random:NextNumber(0, math.pi * 2)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local hit = workspace:Raycast(origin, direction * reach, params)
		local wall = hit and (hit.Position - origin).Magnitude
		if not wall or wall >= calls.Bounce[1] + calls.WallPad then
			return origin + direction * DogCalls.bounceDistance(wall, random:NextNumber(), calls)
		end
	end
	-- boxed in on every try: still never right on top of it
	local angle = random:NextNumber(0, math.pi * 2)
	return origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * calls.Bounce[1]
end

local function callOut(current: Dog, now: number, nearestDistance: number?)
	local phase = DayNight.phase()
	local left = DayNight.timeLeft()
	local length = Config.DayNight.Lengths[phase] or left
	local mood = DogCalls.mood(phase, math.max(0, length - left), left, calls.EdgeSeconds)
	local scared = now < current.spookedUntil or robotChasingNear(current)
	local gap = DogCalls.gap(mood, scared, random:NextNumber(), calls)
	if not gap then
		current.nextCallAt = now + calls.NightRecheck
		return
	end
	current.nextCallAt = now + gap
	if not DogCalls.shouldCall(nearestDistance, calls) then
		return
	end
	local call = DogCalls.pick(mood, scared, random:NextNumber(), calls)
	callRemote:FireAllClients(call, bouncePoint(current))
	-- and it moves on before the next one, so following the last call only gets you close
	current.wanderAt = now
end

local function zoneName(position: Vector3): string?
	local ok, room = pcall(Warehouse.roomAt, position)
	local installation = ok and room and Config.Missions.Places[room.kind]
	if installation then
		return installation
	end
	local relative = position - Config.Warehouse.Origin
	local zone = WarehouseGen.zoneAt(Warehouse.layout(), relative.X, relative.Z)
	return zone and settings.Rumor.Zones[zone.kind]
end

local function rumor(token: number)
	local current = dog
	if token ~= rumorToken or not current or current.owner or DayNight.isNight() then
		return
	end
	local rumors = settings.Rumor
	local name = zoneName(current.position)
	local text = rumors.Vague
	if name then
		text = string.gsub(rumors.Lines[random:NextInteger(1, #rumors.Lines)], "{spot}", function()
			return name
		end)
	end
	paRemote:FireAllClients({ text = text, rumor = true })
end

local function scheduleRumor()
	rumorToken += 1
	if random:NextNumber() >= settings.Rumor.Chance then
		return
	end
	task.delay(randomIn(settings.Rumor.Delay), rumor, rumorToken)
end

-- Rapport ------------------------------------------------------------------------------------------

local function today(): number
	return os.time() // 86400
end

local function rapportOf(player: Player): number
	local data = Saves.data(player)
	return if data then DogTrust.rapportNow(data.dog, today()) else 0
end

local function raiseRapport(player: Player, stage: DogTrust.Stage)
	local data = Saves.data(player)
	if not data or DogTrust.rank(stage) <= DogTrust.rapportNow(data.dog, today()) then
		return
	end
	data.dog = DogTrust.raiseRapport(data.dog, stage, today())
	Saves.markDirty(player)
end

-- A new record starts warmer for someone the dog's kind already knows
local function recordFor(player: Player): DogTrust.Record
	local record = records[player.UserId]
	if not record then
		record = DogTrust.new()
		record.trust = DogTrust.startTrust(rapportOf(player), settings.RapportStart)
		records[player.UserId] = record
		startTrust[player.UserId] = record.trust
		publishTrust(player, record)
	end
	return record
end

local function hasDogFood(player: Player): boolean
	return DogTrust.pickFood(settings.Foods, function(id)
		return Inventory.count(player, id)
	end) ~= nil
end

-- Barking, biting, guarding ------------------------------------------------------------------------

local function bark(current: Dog, now: number)
	current.nextBarkAt = now + settings.BarkInterval
	playSound(current.model.PrimaryPart, "Bark", "loud")
	Loudness.emit(current.position, "loud", current.model)
end

local function bite(current: Dog, target: Target, now: number)
	current.biteReadyAt = now + settings.BiteCooldown
	playSound(current.model.PrimaryPart, "Bite", "normal")
	Loudness.emit(current.position, "normal", current.model)
	if target.robot then
		-- a bite only stuns a robot; it can't wreck one
		Robots.disable(target.robot, settings.RobotStunSeconds)
		DogGuard.remember(bittenRobots, target.robot.id, now + settings.RobotRebiteSeconds)
		sparks(target.position)
	elseif target.humanoid then
		-- For the down screen (Combat): what got you
		local body = target.humanoid.Parent :: Instance
		body:SetAttribute("HurtBy", "Bitten by a dog")
		body:SetAttribute("HurtAt", workspace:GetServerTimeNow())
		target.humanoid:TakeDamage(settings.BiteDamage)
		playSound(target.root, "Yelp", "normal")
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
	local ownerId = current.owner and current.owner.UserId
	for _, robot in Robots.inRadius(Vector3.new(protect.x, floorY, protect.z), settings.ProtectRadius) do
		if
			not robot.dead
			and not DogGuard.remembers(bittenRobots, robot.id, now)
			and DogGuard.biteable(robot.ownerId, ownerId, robot.brain.companion)
		then
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
	local record = recordFor(player)
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
	playSound(current.model.PrimaryPart, "Eat", "quiet")
	if stage ~= "wary" then
		current.eatingUntil = now + settings.EatSeconds
		current.face = body.root.Position
	end
	if DogTrust.rank(stage) > DogTrust.rank(before) then
		queueTell(current, stage, now)
		raiseRapport(player, stage)
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
		spookedUntil = 0,
		flinchUntil = 0,
		calmFor = 0,
		stepUntil = 0,
		tellAt = 0,
		tellUntil = 0,
		tellPlayed = true,
		nextCallAt = now + randomIn(calls.Gap),
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
		if record.trust > (startTrust[userId] or 0) and Players:GetPlayerByUserId(userId) then
			return true
		end
	end
	return false
end

-- A dog nobody has started on wanders off overnight and a new one turns up somewhere else.
local function onMorning()
	if dog and anyoneCares() then
		scheduleRumor()
		return
	end
	despawn()
	table.clear(records)
	table.clear(startTrust)
	for _, player in Players:GetPlayers() do
		publishTrust(player, nil)
	end
	spawnDog()
	scheduleRumor()
end

-- Thinking -----------------------------------------------------------------------------------------

-- How a stray reacts to the nearest player it doesn't trust yet, from how they're moving.
local function wariness(
	current: Dog,
	nearest: Alive,
	stage: DogTrust.Stage,
	distance: number,
	now: number,
	dt: number
): DogWary.Reaction
	local velocity = flat(nearest.root.AssemblyLinearVelocity)
	local toward = flat(current.position - nearest.root.Position)
	local stance = nearest.root.Parent and nearest.root.Parent:GetAttribute("Stance")
	local input: DogWary.Input = {
		stage = stage,
		distance = distance,
		stance = if type(stance) == "string" then stance else nil,
		speed = velocity.Magnitude,
		closing = if toward.Magnitude > 0.1 then velocity:Dot(toward.Unit) else 0,
		holdingFood = holdingFood[nearest.player] == true and hasDogFood(nearest.player),
		spooked = now < current.spookedUntil,
		calmFor = 0,
	}
	if not input.spooked and DogWary.isBadMove(input, settings) then
		spook(current, now)
		input.spooked = true
	end
	if current.calmPlayer ~= nearest.player then
		current.calmPlayer = nearest.player
		current.calmFor = 0
	end
	local slow = input.stance == "Crouch" and input.speed <= wary.SlowSpeed
	current.calmFor = if slow and not input.spooked then current.calmFor + dt else 0
	input.calmFor = current.calmFor

	local reaction = DogWary.react(input, settings)
	if now < current.stepUntil and (reaction == "stay" or reaction == "sniff" or reaction == "creep") then
		return "creep"
	end
	current.stepGoal = nil
	if reaction == "creep" and not input.holdingFood and toward.Magnitude > 0.1 then
		-- one careful step toward you, then back to sniffing
		local step = math.clamp(distance - DogWary.closest(stage, settings), 0, wary.StepDistance)
		current.stepGoal = onFloor(current.position - toward.Unit * step)
		current.stepUntil = now + wary.StepDistance / wary.CreepSpeed
		current.calmFor = wary.SniffAfter
	end
	return reaction
end

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
	local noticed = nearest and nearestDistance and nearestDistance <= settings.NoticeRange
	local nearestRecord = if nearest and noticed
		then recordFor(nearest.player)
		else nearest and records[nearest.player.UserId]
	local nearestStage = nearest and DogTrust.stage(nearestRecord and nearestRecord.trust or 0, trustSettings)

	local reaction: DogWary.Reaction? = nil
	if not current.owner then
		if robotChasingNear(current) then
			spook(current, now)
		end
		if nearest and noticed and nearestStage and not DogTrust.atLeast(nearestStage, "wags") then
			reaction = wariness(current, nearest, nearestStage, nearestDistance :: number, now, dt)
		end
		if now >= current.nextCallAt then
			callOut(current, now, nearestDistance)
		end
	end
	current.model:SetAttribute("Watching", if reaction and nearest then nearest.player.UserId else nil)

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
		reaction = reaction,
		flinchUntil = current.flinchUntil,
	}, settings)
	local telling = current.tell ~= nil and now >= current.tellAt and now < current.tellUntil
	if telling and not current.tellPlayed then
		current.tellPlayed = true
		if current.tell == "sneeze" then
			playSound(current.model.PrimaryPart, "Sneeze", "quiet")
		end
	end
	if telling and current.tell == "sit" and not DogBrain.moves(state) and state ~= "eat" then
		state = "sit"
	end
	if state ~= current.state then
		if state == "flee" and now >= current.nextGrowlAt then
			current.nextGrowlAt = now + settings.GrowlCooldown
			playSound(current.model.PrimaryPart, "Growl", "quiet")
		elseif state == "settle" and now >= current.nextWhineAt then
			-- low, unsure: it wants to trust you
			current.nextWhineAt = now + randomIn(settings.WhineInterval)
			playSound(current.model.PrimaryPart, "WhineLow", "quiet")
		end
		current.state = state
		current.model:SetAttribute("State", state)
	end
	-- a befriended robot nobody has bonded with yet gets a low growl
	if now >= current.nextGrowlAt then
		for _, robot in Robots.inRadius(current.position, settings.WaryDistance * 2) do
			if DogGuard.growlsAt(robot.brain.companion, robot.bonded) then
				current.nextGrowlAt = now + settings.GrowlCooldown
				playSound(current.model.PrimaryPart, "Growl", "quiet")
				break
			end
		end
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
	elseif state == "backoff" and nearest then
		-- a few steps back, still facing you
		local away = flat(current.position - nearest.root.Position)
		local direction = if away.Magnitude > 0.1 then away.Unit else -current.facing
		current.speed = settings.WalkSpeed * 0.6
		current.face = nearest.root.Position
		setGoal(current, onFloor(current.position + direction * 3), now)
	elseif state == "creep" and nearest then
		current.speed = wary.CreepSpeed
		current.face = nearest.root.Position
		setGoal(
			current,
			current.stepGoal or standOff(current.position, nearest.root.Position, wary.FoodDistance),
			now
		)
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

	-- up close a stray whines softly (far off it's callOut); at night it whimpers whoever it's with
	local calm = state == "wander" or state == "sit" or state == "hide"
	local listener = if current.owner then night else noticed
	if calm and listener and now >= current.nextWhineAt then
		current.nextWhineAt = now + randomIn(settings.WhineInterval)
		playSound(current.model.PrimaryPart, "Whine", "quiet")
	end
end

-- A robot companion guarding its owner's fort chirped an alarm at position: the owner's dog, when
-- it's following or guarding close by, barks along.
function Dog.backUp(owner: Player, position: Vector3)
	local current = dog
	if
		not current
		or current.owner ~= owner
		or (current.command ~= "follow" and current.command ~= "guard")
	then
		return
	end
	local now = os.clock()
	if flatDistance(current.position, position) <= settings.ChaseRadius and now >= current.nextBarkAt then
		bark(current, now)
	end
end

function Dog.Init()
	folder = Instance.new("Folder")
	folder.Name = "Dog"
	folder.Parent = workspace
	feedbackRemote = Net.event("SupplyFeedback")
	callRemote = Net.event("DogCall")
	paRemote = Net.event("PaEvent")
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
		holdingFood[player] = nil
	end)
	-- Shots near an untamed dog spook it (Combat validates the shot; this only reads where it was)
	Net.event("GunFire").OnServerEvent:Connect(function(player)
		local body = aliveOf(player)
		if body then
			spookIfNear(body.root.Position)
		end
	end)
	Loudness.onSound(function(event)
		if event.level == "loud" and not (event.source and event.source:IsDescendantOf(folder)) then
			spookIfNear(event.position)
		end
	end)
	-- The hotbar's selection is client-side; the client says when its food slot is in hand
	Net.event("DogHoldingFood").OnServerEvent:Connect(function(player, holding)
		holdingFood[player] = holding == true or nil
	end)
	-- Rapport fades a stage per real day away; settle it on join so the clock runs from today
	Saves.onLoaded(function(player, data)
		local level = DogTrust.rapportNow(data.dog, today())
		if level ~= data.dog.level or data.dog.day ~= today() then
			data.dog = { level = level, day = today() }
			Saves.markDirty(player)
		end
	end)
	DayNight.onPhaseChanged(function(phase, previous)
		if phase == "Day" and previous ~= "Day" then
			task.spawn(onMorning)
		end
	end)
	spawnDog()
	scheduleRumor()

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
