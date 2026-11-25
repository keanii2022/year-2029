-- Simulated players: R15 bots with gamer tags that loot, build, hide and fight like a lobby would,
-- so a fake full server shows whether the game turns chaotic. Nothing exists until spawn() is called.
-- Decisions live in Logic/SimBrain; this file senses the world for it and carries out the action.
-- Bots walk with Humanoid:MoveTo along PathfindingService paths, shared out by a token bucket.
-- Their bags live in Inventory under a stand-in "player" (see newHandle), so robots can rob them and
-- a downed bot drops a real loot pile. Robots and Combat find bots by the Config.SimPlayers.Tag tag.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local CombatModes = require(ReplicatedStorage.Shared.Logic.CombatModes)
local Config = require(ReplicatedStorage.Shared.Config)
local InteractKinds = require(ReplicatedStorage.Shared.Logic.InteractKinds)
local Lobby = require(ReplicatedStorage.Shared.Logic.Lobby)
local Net = require(ReplicatedStorage.Shared.Net)
local SimBrain = require(ReplicatedStorage.Shared.Logic.SimBrain)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Warehouse = require(script.Parent.Warehouse)

local settings = Config.SimPlayers
local lobby = settings.Lobby
local guns = Config.Guns
local movement = Config.Movement

-- Inventory and Robots key everything by Player. A bot passes this stand-in instead: it has no
-- Parent, so Inventory never tries to message it, and attributes read through to the bot's model.
type Handle = { Name: string, Character: Model?, GetAttribute: (Handle, string) -> any }

type Person = { model: Model, root: BasePart, humanoid: Humanoid, position: Vector3 }
type RobotSeen = { model: Model, position: Vector3, chasing: boolean }

type Bot = {
	id: number,
	name: string,
	home: Vector3?,
	opening: string?, -- action a lobby-fill bot is already busy with when it first appears
	handle: Handle,
	brain: SimBrain.Brain,
	generation: number,
	alive: boolean,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	path: Path?,
	thinkAt: number,
	goal: Vector3?,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathFor: Vector3?,
	pathAt: number,
	pathBusy: boolean,
	lastMovedAt: number,
	lastPosition: Vector3,
	action: string?,
	spot: Vector3?,
	thing: Instance?,
	workUntil: number?,
	looted: { [Instance]: boolean },
	dragging: PVInstance?,
	fortSpot: Vector3?,
	fightTarget: Model?,
	strafeAt: number,
	nextShotAt: number,
	burstLeft: number,
	mag: number,
	attacker: Model?,
	hitAt: number,
	lastHealth: number,
	tracks: { [string]: AnimationTrack },
	playing: string?,
	flashlight: SpotLight?,
}

local SimPlayers = {}

local bots: { [number]: Bot } = {}
local byModel: { [Model]: Bot } = {}
local freeHandles: { Handle } = {}
local dragClaims: { [Instance]: Bot } = {}
local hideClaims: { [Instance]: Bot } = {}
local mood = settings.DefaultMood
local nextId = 0
local pathTokens = settings.PathsPerSecond
local random = Random.new()
local folder: Folder
local fxRemote: UnreliableRemoteEvent
local whizRemote: UnreliableRemoteEvent

local spotsAt = -math.huge
local spawnSpots: { Vector3 } = {}
local hideSpots: { Model } = {}
local installationSpots: { Vector3 } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

local function randomIn(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

local function botCount(): number
	local n = 0
	for _ in bots do
		n += 1
	end
	return n
end

-- World scan ---------------------------------------------------------------------------------------

-- One pass over the workspace for spawns and hiding spots; slow, so only every SpotsRefresh seconds.
local function refreshSpots(now: number)
	spotsAt = now
	spawnSpots, hideSpots, installationSpots = {}, {}, {}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			table.insert(spawnSpots, descendant.Position)
		elseif descendant:IsA("Model") then
			local behaviour = InteractKinds.get(descendant:GetAttribute("ModelName"))
			if behaviour and behaviour.kind == "hide" then
				table.insert(hideSpots, descendant)
			end
		end
	end
	for _, room in Warehouse.rooms() do
		if room.installation then
			table.insert(installationSpots, Warehouse.toWorld(room.cx, room.cz))
		end
	end
end

local function sizeOf(instance: PVInstance): Vector3
	if instance:IsA("Model") then
		local _, size = instance:GetBoundingBox()
		return size
	end
	return (instance :: BasePart).Size
end

-- Nearest instance with any of the tags, within range, that skip() doesn't rule out.
local function nearestTagged(
	tags: { string },
	position: Vector3,
	range: number,
	skip: (Instance) -> boolean
): PVInstance?
	local best, bestDistance = nil, range
	for _, tag in tags do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("PVInstance") and instance:IsDescendantOf(workspace) and not skip(instance) then
				local d = flatDistance(instance:GetPivot().Position, position)
				if d < bestDistance then
					best, bestDistance = instance, d
				end
			end
		end
	end
	return best
end

-- Bodies -----------------------------------------------------------------------------------------

local function describe(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = pick(settings.SkinTones)
	local shirt, pants = pick(settings.ClothesColors), pick(settings.ClothesColors)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	description.HeightScale = random:NextNumber(0.94, 1.06)
	description.WidthScale = random:NextNumber(0.94, 1.06)
	return description
end

local function blockPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Plain stand-in when Roblox can't build a rig from a description.
local function blockRig(): Model
	local model = Instance.new("Model")
	local root = blockPart("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(), model)
	root.Transparency = 1
	local torso = blockPart("UpperTorso", Vector3.new(2, 2, 1), pick(settings.ClothesColors), model)
	local head = blockPart("Head", Vector3.new(1.2, 1.2, 1.2), pick(settings.SkinTones), model)
	for _, part in { torso, head } do
		part.CanCollide = false
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = if part == head then CFrame.new(0, 1.6, 0) else CFrame.identity
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildRig(): Model
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn(`[SimPlayers] falling back to block rigs: {model}`)
	return blockRig()
end

local function animationId(model: Model, kind: string): string
	local animate = model:FindFirstChild("Animate")
	local slot = animate and animate:FindFirstChild(kind)
	local animation = slot and slot:FindFirstChildOfClass("Animation")
	return if animation and animation.AnimationId ~= ""
		then animation.AnimationId
		else settings.Animations[kind]
end

local function loadTracks(bot: Bot, model: Model, humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	bot.tracks = {}
	bot.playing = nil
	for kind in settings.Animations do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId(model, kind)
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			track.Priority = if kind == "idle"
				then Enum.AnimationPriority.Idle
				else Enum.AnimationPriority.Movement
			bot.tracks[kind] = track
		end
	end
end

local function animate(bot: Bot, root: BasePart)
	local speed = flat(root.AssemblyLinearVelocity).Magnitude
	local kind = if speed > settings.RunAbove then "run" elseif speed > 0.5 then "walk" else "idle"
	local track = bot.tracks[kind]
	if kind ~= bot.playing and track then
		local old = bot.playing and bot.tracks[bot.playing]
		if old then
			old:Stop(0.2)
		end
		track:Play(0.2)
		bot.playing = kind
	end
	if track and kind ~= "idle" then
		track:AdjustSpeed(math.max(speed / movement.WalkSpeed, 0.4))
	end
end

local function setStance(bot: Bot, stance: string)
	local model, humanoid = bot.model, bot.humanoid
	if not model or not humanoid then
		return
	end
	if model:GetAttribute("Stance") ~= stance then
		model:SetAttribute("Stance", stance)
	end
	local speed = if stance == "Sprint"
		then movement.SprintSpeed
		elseif stance == "Crouch" then movement.CrouchSpeed
		else movement.WalkSpeed
	humanoid.WalkSpeed = if bot.dragging then math.min(speed, settings.DragSpeed) else speed
end

local function setFlashlight(bot: Bot, on: boolean)
	local model = bot.model
	local head = model and model:FindFirstChild("Head")
	if on and not bot.flashlight and head then
		local light = Instance.new("SpotLight")
		light.Angle = 50
		light.Range = 45
		light.Brightness = 2.5
		light.Face = Enum.NormalId.Front
		light.Parent = head
		bot.flashlight = light
	elseif not on and bot.flashlight then
		bot.flashlight:Destroy()
		bot.flashlight = nil
	end
	if model then
		model:SetAttribute("FlashlightOn", if bot.flashlight then true else nil)
	end
end

-- Bags and guns ------------------------------------------------------------------------------------

local function newHandle(name: string): Handle
	local handle = table.remove(freeHandles)
	if handle then
		handle.Name = name
		return handle
	end
	return {
		Name = name,
		Character = nil,
		GetAttribute = function(self: Handle, attribute: string): any
			return self.Character and self.Character:GetAttribute(attribute)
		end,
	}
end

local function emptyBag(handle: Handle)
	local player = handle :: any
	for _, stack in Inventory.list(player) do
		Inventory.remove(player, stack.id, stack.count)
	end
end

-- Best gun it carries with ammo left (higher rank is the better gun).
local function bestGun(bot: Bot): (string?, number)
	local player = bot.handle :: any
	local bestId, bestRank, ammo = nil, -math.huge, 0
	for id, gun in guns.Blasters do
		if gun.rank > bestRank and Inventory.has(player, id) then
			local count = Inventory.count(player, gun.ammo)
			if count > 0 then
				bestId, bestRank, ammo = id, gun.rank, count
			end
		end
	end
	return bestId, ammo
end

-- Walking -----------------------------------------------------------------------------------------

local function stop(bot: Bot)
	bot.goal = nil
	bot.waypoints = {}
	if bot.humanoid and bot.root then
		bot.humanoid:MoveTo(bot.root.Position)
	end
end

-- Straight line, no pathfinding: fleeing, strafing and backing off need to react now.
local function walkStraight(bot: Bot, goal: Vector3)
	bot.goal = goal
	bot.waypoints = {}
	bot.pathFor = nil
end

local function setGoal(bot: Bot, goal: Vector3, now: number)
	bot.goal = goal
	local reuse = bot.pathFor ~= nil
		and flatDistance(bot.pathFor, goal) <= settings.PathReuseDistance
		and now - bot.pathAt < settings.PathMaxAge
	if reuse or bot.pathBusy or pathTokens < 1 or not bot.root or not bot.path then
		return
	end
	pathTokens -= 1
	bot.pathBusy = true
	bot.pathFor = goal
	bot.pathAt = now
	local path, start, generation = bot.path, bot.root.Position, bot.generation
	task.spawn(function()
		local ok = pcall(path.ComputeAsync, path, start, goal)
		bot.pathBusy = false
		if bot.generation ~= generation or bot.goal ~= goal then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			bot.waypoints = path:GetWaypoints()
			bot.waypointIndex = 2 -- the first waypoint is where it already stands
		else
			-- unreachable: drop the target so the next think picks a new one
			bot.waypoints = {}
			bot.spot = nil
			if bot.thing then
				bot.looted[bot.thing] = true
				bot.thing = nil
			end
		end
	end)
end

local function steer(bot: Bot, humanoid: Humanoid, root: BasePart, now: number)
	local position = root.Position
	if (position - bot.lastPosition).Magnitude > 1 then
		bot.lastPosition = position
		bot.lastMovedAt = now
	end
	local goal = bot.goal
	if not goal then
		bot.lastMovedAt = now
		return
	end
	if flatDistance(position, goal) <= settings.ArriveRange then
		stop(bot)
		return
	end
	local waypoint = bot.waypoints[bot.waypointIndex]
	while waypoint and flatDistance(position, waypoint.Position) <= settings.WaypointReach do
		bot.waypointIndex += 1
		waypoint = bot.waypoints[bot.waypointIndex]
	end
	if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end
	-- Re-issued every step, so MoveTo's own 8 second timeout never kicks in.
	humanoid:MoveTo(if waypoint then waypoint.Position else goal)
	if now - bot.lastMovedAt > settings.StuckSeconds then
		humanoid.Jump = true
		bot.lastMovedAt = now
		bot.pathFor = nil
		bot.waypoints = {}
	end
end

-- Furniture and hiding ----------------------------------------------------------------------------

local function releaseDrag(bot: Bot)
	local prop = bot.dragging
	if prop then
		dragClaims[prop] = nil
		bot.dragging = nil
	end
end

local function releaseHide(bot: Bot)
	local spot = bot.thing
	if spot and hideClaims[spot] == bot then
		hideClaims[spot] = nil
	end
end

local function startDrag(bot: Bot, prop: PVInstance)
	for _, part in if prop:IsA("BasePart") then { prop } else prop:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true -- Grab freezes dropped props too; the drag just moves the pivot
		end
	end
	dragClaims[prop] = bot
	bot.dragging = prop
end

-- Pulls the prop along behind the bot at its original height. Every frame, so watchers see it slide.
local function dragStep()
	for _, bot in bots do
		local prop, root = bot.dragging, bot.root
		if not prop or not root then
			continue
		end
		if not prop:IsDescendantOf(workspace) or prop:GetAttribute("CarriedBy") ~= nil then
			releaseDrag(bot) -- a real player grabbed it, or it's gone
			continue
		end
		local pivot = prop:GetPivot()
		local back = sizeOf(prop).Magnitude / 2 + settings.DragGap
		local behind = root.Position - flat(root.CFrame.LookVector).Unit * back
		prop:PivotTo(pivot.Rotation + Vector3.new(behind.X, pivot.Position.Y, behind.Z))
	end
end

-- Senses ------------------------------------------------------------------------------------------

local function gatherPeople(): { Person }
	local people = {}
	local function add(model: Model?)
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if model and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(
				people,
				{ model = model, root = root, humanoid = humanoid, position = root.Position }
			)
		end
	end
	for _, player in Players:GetPlayers() do
		add(player.Character)
	end
	for _, bot in bots do
		if bot.alive then
			add(bot.model)
		end
	end
	return people
end

local function gatherRobots(): { RobotSeen }
	local list = {}
	local robotsFolder = workspace:FindFirstChild("Robots")
	if robotsFolder then
		for _, model in robotsFolder:GetChildren() do
			if model:IsA("Model") then
				table.insert(list, {
					model = model,
					position = model:GetPivot().Position,
					chasing = model:GetAttribute("State") == "chase",
				})
			end
		end
	end
	return list
end

local function canSee(from: Model, eye: Vector3, target: Person): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { from, target.model }
	local head = target.position + Vector3.yAxis * 1.5
	return workspace:Raycast(eye, head - eye, params) == nil
end

local function personByModel(people: { Person }, model: Instance?): Person?
	for _, person in people do
		if person.model == model then
			return person
		end
	end
	return nil
end

-- Shooting ----------------------------------------------------------------------------------------

-- The humanoid a shot hit, only if it belongs to a player or a bot (robots have their own damage).
local function personHit(part: Instance): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local person = Players:GetPlayerFromCharacter(model) ~= nil
				or CollectionService:HasTag(model, settings.Tag)
			return if person and humanoid.Health > 0 then humanoid else nil
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Same as Combat: players the shot flew past hear it whiz by.
local function sendWhizzes(target: Model, origin: Vector3, hitPosition: Vector3)
	local shot = hitPosition - origin
	local length = shot.Magnitude
	if length <= 0 then
		return
	end
	local aim = shot / length
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = character and character ~= target and character:FindFirstChild("Head") :: BasePart?
		if head then
			local along = (head.Position - origin):Dot(aim)
			local closest = origin + aim * math.clamp(along, 0, length)
			local miss = (head.Position - closest).Magnitude
			if CombatFeel.whizzes(along, length, miss, guns.WhizRadius, guns.WhizMinDistance) then
				whizRemote:FireClient(player, closest)
			end
		end
	end
end

local function face(root: BasePart, point: Vector3)
	local position = root.Position
	if flatDistance(position, point) > 0.1 then
		root.CFrame = CFrame.lookAt(position, Vector3.new(point.X, position.Y, point.Z))
	end
end

-- What Combat does for a player's shot, with the bot's head as the gun: rays, damage, the shot
-- effect and sound every client plays for someone else's shot, whizzes, and the bang robots hear.
local function shoot(bot: Bot, model: Model, root: BasePart, target: Person, now: number)
	if now < bot.nextShotAt then
		return
	end
	local gunId = bestGun(bot)
	local gun = gunId and guns.Blasters[gunId]
	if not gunId or not gun then
		return
	end
	if bot.mag <= 0 then
		bot.mag = gun.magSize or 12
		bot.nextShotAt = now + (gun.reloadTime or 1.5)
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else root.Position + Vector3.yAxis * 1.5
	local aimPoint = target.position + Vector3.yAxis * 0.6
	face(root, aimPoint)
	local aim = settings.Aim
	local spread = aim.Spread + aim.SpreadPerStud * (aimPoint - origin).Magnitude
	local look = CFrame.lookAt(origin, aimPoint)
		* CFrame.Angles(
			math.rad(random:NextNumber(-spread, spread)),
			math.rad(random:NextNumber(-spread, spread)),
			0
		)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }

	local damageTo: { [Humanoid]: number } = {}
	local robotDamage: { [any]: { damage: number, at: Vector3 } } = {}
	local centreHit = origin + look.LookVector * gun.range
	for index, offset in CombatModes.pelletOffsets(gun.pellets or 1, gun.spread or 0) do
		local pelletAim = (look * CFrame.Angles(math.rad(offset.y), math.rad(-offset.x), 0)).LookVector
		local result = workspace:Raycast(origin, pelletAim * gun.range, params)
		local hitPosition = if result then result.Position else origin + pelletAim * gun.range
		local victim = result and personHit(result.Instance)
		if victim then
			damageTo[victim] = (damageTo[victim] or 0)
				+ CombatLogic.damageAt(gun, (hitPosition - origin).Magnitude)
		elseif result then
			-- Required here, not at the top: Robots requires SimPlayers, so a top-level require loops.
			local Robots = require(script.Parent.Robots) :: any
			local robot = Robots.fromPart(result.Instance)
			if robot then
				local hit = robotDamage[robot] or { damage = 0, at = hitPosition }
				hit.damage += CombatLogic.damageAt(gun, (hitPosition - origin).Magnitude)
				robotDamage[robot] = hit
			end
		end
		if index == 1 then
			centreHit = hitPosition
		end
		fxRemote:FireAllClients(
			model,
			origin,
			hitPosition,
			result and result.Normal,
			victim ~= nil,
			gunId,
			index
		)
	end
	for victim, damage in damageTo do
		local victimBot = byModel[victim.Parent :: Model]
		if victimBot then
			victimBot.attacker = model
			victimBot.hitAt = now
		end
		victim:TakeDamage(damage)
	end
	if next(robotDamage) then
		local Robots = require(script.Parent.Robots) :: any
		for robot, hit in robotDamage do
			Robots.shot(robot, bot.handle, hit.damage, origin, hit.at)
		end
	end
	sendWhizzes(target.model, origin, centreHit)
	Loudness.emit(origin, "loud", model)
	Inventory.remove(bot.handle :: any, gun.ammo, 1)
	bot.mag -= 1
	bot.burstLeft -= 1
	local gap = math.max(gun.fireInterval, randomIn(aim.ShotGap))
	if bot.burstLeft <= 0 then
		bot.burstLeft = random:NextInteger(aim.BurstShots[1], aim.BurstShots[2])
		gap += randomIn(aim.BurstPause)
	end
	bot.nextShotAt = now + gap
end

-- Acting ------------------------------------------------------------------------------------------

local function wanderPoint(position: Vector3): Vector3
	if #installationSpots + #spawnSpots > 0 and random:NextNumber() < 0.35 then
		local spots = if random:NextNumber() < 0.5 and #spawnSpots > 0 then spawnSpots else installationSpots
		if #spots > 0 then
			return pick(spots)
		end
	end
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(15, settings.WanderRange)
	return position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
end

local function wander(bot: Bot, position: Vector3, now: number)
	if not bot.spot or flatDistance(bot.spot, position) <= settings.ArriveRange then
		bot.spot = wanderPoint(position)
	end
	setStance(bot, "Walk")
	setGoal(bot, bot.spot :: Vector3, now)
end

local function loot(bot: Bot, position: Vector3, now: number)
	if bot.workUntil then
		if now >= bot.workUntil then
			local thing = bot.thing
			local item = thing and thing:GetAttribute("SupplyItem")
			if type(item) == "string" and random:NextNumber() < settings.LootItemChance then
				Inventory.add(bot.handle :: any, item, 1)
			end
			if thing then
				bot.looted[thing] = true
			end
			bot.thing, bot.workUntil = nil, nil
			setStance(bot, "Walk")
		end
		return
	end
	local thing = bot.thing
	if not thing or not thing:IsDescendantOf(workspace) then
		thing = nearestTagged(
			{ Config.Supplies.PickupTag, guns.LootPileTag },
			position,
			settings.LootSearchRange,
			function(instance)
				return bot.looted[instance] == true
			end
		)
		bot.thing = thing
	end
	if not thing then
		wander(bot, position, now)
		return
	end
	local at = (thing :: PVInstance):GetPivot().Position
	if flatDistance(at, position) <= settings.ArriveRange then
		stop(bot)
		setStance(bot, "Crouch")
		bot.workUntil = now + randomIn(settings.LootTime)
	else
		setStance(bot, "Walk")
		setGoal(bot, at, now)
	end
end

local function sneak(bot: Bot, position: Vector3, now: number)
	if not bot.spot then
		local best, bestDistance = nil, math.huge
		for _, spot in installationSpots do
			local d = flatDistance(spot, position)
			if d < bestDistance then
				best, bestDistance = spot, d
			end
		end
		if not best then
			wander(bot, position, now)
			return
		end
		bot.spot = best
	end
	local spot = bot.spot :: Vector3
	if flatDistance(spot, position) <= settings.ArriveRange then
		-- creep around inside instead of standing on the centre
		local angle = random:NextNumber(0, math.pi * 2)
		bot.spot = spot + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(6, 12)
	end
	setStance(bot, "Crouch")
	setGoal(bot, bot.spot :: Vector3, now)
end

local function drag(bot: Bot, position: Vector3, now: number)
	local fort = bot.fortSpot or position
	if bot.dragging then
		if flatDistance(fort, position) <= settings.ArriveRange then
			releaseDrag(bot)
			stop(bot)
			bot.thing = nil
			return
		end
		setStance(bot, "Walk")
		setGoal(bot, fort, now)
		return
	end
	local prop = bot.thing
	if not prop or not prop:IsDescendantOf(workspace) or dragClaims[prop] then
		prop = nearestTagged({ Config.Grab.Tag }, position, settings.DragSearchRange, function(instance)
			local size = sizeOf(instance :: PVInstance)
			local tooBig = math.max(size.X, size.Y, size.Z) > settings.DragMaxSize
			return tooBig
				or dragClaims[instance] ~= nil
				or bot.looted[instance] == true
				or instance:GetAttribute("CarriedBy") ~= nil
				or flatDistance((instance :: PVInstance):GetPivot().Position, fort)
					<= settings.ArriveRange * 2
		end)
		bot.thing = prop
	end
	if not prop then
		wander(bot, position, now)
		return
	end
	local at = (prop :: PVInstance):GetPivot().Position
	if flatDistance(at, position) <= settings.ArriveRange + sizeOf(prop :: PVInstance).Magnitude / 2 then
		startDrag(bot, prop :: PVInstance)
		bot.looted[prop] = true -- don't keep hauling the same piece back and forth
	else
		setStance(bot, "Walk")
		setGoal(bot, at, now)
	end
end

local function group(bot: Bot, position: Vector3, now: number)
	local friend, bestDistance = nil, settings.GroupRange
	for _, other in bots do
		if other ~= bot and other.alive and other.root then
			local d = flatDistance(other.root.Position, position)
			if d < bestDistance then
				friend, bestDistance = other, d
			end
		end
	end
	if not friend or not friend.root then
		wander(bot, position, now)
		return
	end
	if bestDistance <= settings.GroupCloseness then
		stop(bot)
		if bot.root then
			face(bot.root, friend.root.Position)
		end
		return
	end
	setStance(bot, "Walk")
	setGoal(bot, friend.root.Position, now)
end

local function hide(bot: Bot, position: Vector3, now: number)
	local spot = bot.thing
	if not spot or not spot:IsDescendantOf(workspace) then
		local best, bestDistance = nil, settings.HideSearchRange
		for _, model in hideSpots do
			local claim = hideClaims[model]
			local d = flatDistance(model:GetPivot().Position, position)
			if (claim == nil or claim == bot) and d < bestDistance and not bot.looted[model] then
				best, bestDistance = model, d
			end
		end
		spot = best
		bot.thing = spot
		if spot then
			hideClaims[spot] = bot
		end
	end
	local at = if spot then (spot :: Model):GetPivot().Position else bot.fortSpot or position
	if flatDistance(at, position) <= settings.ArriveRange then
		stop(bot)
		setStance(bot, "Crouch")
	else
		-- quiet once the lights are out, hurried while the siren still wails
		setStance(bot, if DayNight.phase() == "Siren" then "Sprint" else "Crouch")
		setGoal(bot, at, now)
	end
end

local function runFrom(bot: Bot, position: Vector3, from: Vector3, stance: string)
	local away = flat(position - from)
	if away.Magnitude < 0.1 then
		away = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	end
	setStance(bot, stance)
	walkStraight(bot, position + away.Unit * settings.FleeDistance)
end

local function fight(bot: Bot, root: BasePart, target: Person?, now: number)
	bot.fightTarget = if target then target.model else nil
	if not target then
		return
	end
	setStance(bot, "Walk")
	if now >= bot.strafeAt then
		bot.strafeAt = now + randomIn(settings.Aim.StrafeEvery)
		local toward = flat(target.position - root.Position)
		local side = if toward.Magnitude > 0.1 then toward.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
		local sign = if random:NextNumber() < 0.5 then -1 else 1
		walkStraight(bot, root.Position + side * sign * settings.Aim.StrafeDistance)
	end
end

local function resetAction(bot: Bot, action: string)
	if action ~= "drag" then
		releaseDrag(bot)
	end
	releaseHide(bot)
	bot.action = action
	bot.spot, bot.thing, bot.workUntil = nil, nil, nil
	bot.fightTarget = nil
	if bot.humanoid then
		bot.humanoid.AutoRotate = action ~= "fight"
	end
	if action == "fight" then
		bot.burstLeft = random:NextInteger(settings.Aim.BurstShots[1], settings.Aim.BurstShots[2])
		bot.nextShotAt = math.max(bot.nextShotAt, os.clock() + random:NextNumber(0.2, 0.6)) -- reaction time
	end
end

local function think(
	bot: Bot,
	model: Model,
	root: BasePart,
	now: number,
	people: { Person },
	robots: { RobotSeen }
)
	local position = root.Position
	local eye = position + Vector3.yAxis * 1.5

	local robot: RobotSeen? = nil
	local robotDistance = settings.RobotSightRange
	for _, entry in robots do
		local d = flatDistance(entry.position, position)
		if d < robotDistance then
			robot, robotDistance = entry, d
		end
	end

	local nearest: Person? = nil
	local nearestDistance = settings.SightRange
	for _, person in people do
		local d = flatDistance(person.position, position)
		if person.model ~= model and d < nearestDistance then
			nearest, nearestDistance = person, d
		end
	end
	if nearest and not canSee(model, eye, nearest) then
		nearest = nil
	end

	local brain = bot.brain
	local target = personByModel(people, brain.target)
	local targetSeen = target ~= nil
		and flatDistance(target.position, position) <= settings.SightRange
		and (target == nearest or canSee(model, eye, target))

	local attacker = personByModel(people, bot.attacker)
	local fresh = attacker
		and now - bot.hitAt <= settings.HitMemory
		and flatDistance(attacker.position, position) <= settings.SightRange

	local _, ammo = bestGun(bot)
	local action = SimBrain.decide(
		brain,
		{
			phase = DayNight.phase(),
			mood = mood,
			ammo = ammo,
			robot = if robot
				then { id = robot.model, distance = robotDistance, chasing = robot.chasing }
				else nil,
			enemy = if nearest then { id = nearest.model, distance = nearestDistance } else nil,
			attacker = if fresh and attacker
				then {
					id = attacker.model,
					distance = flatDistance(attacker.position, position),
					at = bot.hitAt,
				}
				else nil,
			targetSeen = targetSeen,
		},
		settings,
		now,
		function()
			return random:NextNumber()
		end
	)
	if action ~= bot.action then
		resetAction(bot, action)
	end
	target = personByModel(people, brain.target)

	if action == "wander" then
		wander(bot, position, now)
	elseif action == "loot" then
		loot(bot, position, now)
	elseif action == "sneak" then
		sneak(bot, position, now)
	elseif action == "drag" then
		drag(bot, position, now)
	elseif action == "group" then
		group(bot, position, now)
	elseif action == "hide" then
		hide(bot, position, now)
	elseif action == "flee" then
		runFrom(bot, position, if robot then robot.position else position - root.CFrame.LookVector, "Sprint")
	elseif action == "avoid" then
		runFrom(bot, position, if target then target.position else position - root.CFrame.LookVector, "Walk")
	elseif action == "fight" then
		fight(bot, root, target, now)
	else -- freeze
		setStance(bot, "Walk")
		stop(bot)
	end
end

-- Life and death ----------------------------------------------------------------------------------

local function spawnSpot(bot: Bot): Vector3
	-- Admin-spawned bots appear around whoever spawned them, so the lobby is in view straight away
	if bot.home then
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(6, 18)
		local spot = bot.home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances =
			{ workspace.Terrain, workspace:FindFirstChild("Warehouse") or workspace }
		local hit = workspace:Raycast(spot + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), params)
		return if hit then hit.Position else bot.home
	end
	if #spawnSpots > 0 then
		return pick(spawnSpots)
	end
	return Warehouse.toWorld(0, 0)
end

local onDied: (Bot, number) -> ()

local function spawnBody(bot: Bot)
	bot.generation += 1
	local generation = bot.generation
	local model = buildRig()
	if bots[bot.id] ~= bot or bot.generation ~= generation then
		model:Destroy() -- cleared while the rig was being built
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.Name = bot.name
	humanoid.DisplayName = bot.name
	humanoid.MaxHealth = guns.MaxHealth
	humanoid.Health = guns.MaxHealth
	local at = spawnSpot(bot) + Vector3.new(random:NextNumber(-3, 3), 3.5, random:NextNumber(-3, 3))
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("Stance", "Walk")
	CollectionService:AddTag(model, settings.Tag)
	model.Parent = folder
	pcall(root.SetNetworkOwner, root, nil) -- the server walks them, not whoever stands nearest

	bot.model, bot.humanoid, bot.root = model, humanoid, root
	bot.handle.Character = model
	byModel[model] = bot
	bot.alive = true
	bot.brain = SimBrain.new()
	if bot.opening then
		local phase = DayNight.phase()
		local action = if phase == "Day" then bot.opening else "hide"
		SimBrain.start(bot.brain, action :: any, phase, settings, os.clock(), function()
			return random:NextNumber()
		end)
		bot.opening = nil
	end
	bot.action = nil
	bot.goal, bot.waypoints, bot.waypointIndex = nil, {}, 1
	bot.pathFor, bot.pathBusy = nil, false
	bot.lastPosition, bot.lastMovedAt = root.Position, os.clock()
	bot.attacker, bot.hitAt, bot.lastHealth = nil, -math.huge, humanoid.Health
	bot.looted = setmetatable({}, { __mode = "k" }) :: any
	bot.fortSpot = bot.fortSpot
		or at + Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * settings.FortRange
	bot.path = bot.path
		or PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	for _, item in guns.StartingLoadout do
		Inventory.add(bot.handle :: any, item.id, item.count)
	end
	local gunId = bestGun(bot)
	local gun = gunId and guns.Blasters[gunId]
	bot.mag = if gun then gun.magSize else 0
	bot.flashlight = nil
	setFlashlight(bot, DayNight.isNight() and random:NextNumber() < settings.FlashlightChance)
	loadTracks(bot, model, humanoid)

	humanoid.HealthChanged:Connect(function(health)
		local now = os.clock()
		if health < bot.lastHealth and now - bot.hitAt > 0.1 then
			-- not a bot's shot (those mark themselves): blame the nearest player
			local best, bestDistance = nil, settings.SightRange
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local d = character and flatDistance(character:GetPivot().Position, root.Position)
				if character and d and d < bestDistance then
					best, bestDistance = character, d
				end
			end
			if best then
				bot.attacker, bot.hitAt = best, now
			end
		end
		bot.lastHealth = health
	end)
	humanoid.Died:Connect(function()
		onDied(bot, generation)
	end)
end

function onDied(bot: Bot, generation: number)
	if bot.generation ~= generation or not bot.alive then
		return
	end
	bot.alive = false
	releaseDrag(bot)
	releaseHide(bot)
	setFlashlight(bot, false)
	bot.goal = nil
	local model = bot.model
	local root = bot.root
	Inventory.dropAll(
		bot.handle :: any,
		if root then root.Position elseif model then model:GetPivot().Position else Vector3.zero
	)
	task.delay(settings.RespawnDelay, function()
		if bots[bot.id] ~= bot or bot.generation ~= generation then
			return
		end
		if model then
			byModel[model] = nil
			model:Destroy()
		end
		spawnBody(bot)
	end)
end

local function removeBot(bot: Bot)
	bots[bot.id] = nil
	bot.generation += 1
	releaseDrag(bot)
	releaseHide(bot)
	if bot.model then
		byModel[bot.model] = nil
		bot.model:Destroy()
	end
	emptyBag(bot.handle)
	bot.handle.Character = nil
	table.insert(freeHandles, bot.handle)
end

local function uniqueName(): string
	local taken = {}
	for _, bot in bots do
		taken[bot.name] = true
	end
	local name = ""
	for _ = 1, 8 do
		name = SimBrain.gamerName(settings.Names, function()
			return random:NextNumber()
		end)
		if not taken[name] then
			break
		end
	end
	return name
end

-- Loops -------------------------------------------------------------------------------------------

local function step(dt: number)
	pathTokens = math.min(settings.PathsPerSecond, pathTokens + settings.PathsPerSecond * dt)
	if next(bots) == nil then
		return
	end
	local now = os.clock()
	if now - spotsAt > settings.SpotsRefresh then
		refreshSpots(now)
	end
	local people, robots
	for _, bot in bots do
		local model, humanoid, root = bot.model, bot.humanoid, bot.root
		if not bot.alive or not model or not humanoid or not root then
			continue
		end
		if now >= bot.thinkAt then
			bot.thinkAt = now + 1 / settings.ThinkRate
			people = people or gatherPeople()
			robots = robots or gatherRobots()
			think(bot, model, root, now, people, robots)
		end
		steer(bot, humanoid, root, now)
		if bot.action == "fight" and bot.fightTarget then
			people = people or gatherPeople()
			local target = personByModel(people, bot.fightTarget)
			if target then
				shoot(bot, model, root, target, now)
			end
		end
		animate(bot, root)
	end
end

-- Public ------------------------------------------------------------------------------------------

local function addBot(home: Vector3?, opening: string?)
	nextId += 1
	local name = uniqueName()
	local bot: Bot = {
		id = nextId,
		name = name,
		handle = newHandle(name),
		brain = SimBrain.new(),
		generation = 0,
		alive = false,
		thinkAt = os.clock() + random:NextNumber(0, 1 / settings.ThinkRate),
		waypoints = {},
		waypointIndex = 1,
		pathAt = 0,
		pathBusy = false,
		lastMovedAt = 0,
		lastPosition = Vector3.zero,
		looted = {},
		strafeAt = 0,
		nextShotAt = 0,
		burstLeft = 0,
		mag = 0,
		hitAt = -math.huge,
		lastHealth = 0,
		tracks = {},
		home = home,
		opening = opening,
	}
	bots[bot.id] = bot
	task.spawn(spawnBody, bot)
end

-- Adds up to count bots, never past Config.SimPlayers.Max. Bodies build on their own threads.
function SimPlayers.spawn(count: number, near: Vector3?)
	local room = settings.Max - botCount()
	for _ = 1, math.clamp(math.floor(tonumber(count) or 0), 0, room) do
		addBot(near)
	end
end

-- A public server that was already running: replaces any bots with count of them (default scaled
-- to the warehouse size) spread over the warehouse spawns in solos and small groups, busy from the
-- first second. Returns how many it made.
function SimPlayers.fillLobby(count: number?): number
	SimPlayers.clear()
	SimPlayers.setMood(lobby.Mood)
	local layout = Warehouse.layout()
	local function roll(): number
		return random:NextNumber()
	end
	local total = math.min(count or Lobby.botCount(layout.size, Config.Warehouse, lobby, roll), settings.Max)
	for _, squad in Lobby.plan(total, layout.spawns, lobby, roll) do
		local home = Warehouse.toWorld(squad.spot.x, squad.spot.z)
		for member = 1, squad.size do
			addBot(home, if member == 1 then squad.opening else "group")
		end
	end
	return botCount()
end

function SimPlayers.setMood(newMood: string)
	if settings.Moods[newMood] then
		mood = newMood
	else
		warn(`[SimPlayers] unknown mood {newMood}`)
	end
end

function SimPlayers.clear()
	for _, bot in table.clone(bots) do
		removeBot(bot)
	end
end

function SimPlayers.count(): number
	return botCount()
end

-- For Robots: every live bot shaped like its own player entries, with the bot's stand-in as player.
function SimPlayers.alive(): { any }
	local list = {}
	for _, bot in bots do
		local humanoid, root = bot.humanoid, bot.root
		if bot.alive and humanoid and root and humanoid.Health > 0 then
			table.insert(list, {
				player = bot.handle,
				character = bot.model,
				root = root,
				humanoid = humanoid,
				position = root.Position,
			})
		end
	end
	return list
end

function SimPlayers.Init()
	folder = Instance.new("Folder")
	folder.Name = settings.FolderName
	folder.Parent = workspace
	fxRemote = Net.unreliable("GunFx")
	whizRemote = Net.unreliable("GunWhiz")
end

function SimPlayers.Start()
	DayNight.onPhaseChanged(function(phase)
		for _, bot in bots do
			if bot.alive then
				setFlashlight(bot, phase == "Night" and random:NextNumber() < settings.FlashlightChance)
			end
		end
	end)
	RunService.Heartbeat:Connect(dragStep)
	task.spawn(function()
		local interval = 1 / settings.MoveRate
		while true do
			step(task.wait(interval))
		end
	end)
end

return SimPlayers
