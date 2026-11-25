-- Robots: a chore bot in every room near a player by day, hunters in the aisles by night.
-- By day Life sends calm chore bots out on errands near players (sendOnChore).
-- Brains live in Logic/RobotBrain; this file senses the world for them, moves the models and carries
-- out what they decide (steal, haul, take players down). Robots are anchored and moved with PivotTo,
-- so nothing here touches physics. Limbs are procedural until the real clips are imported in Studio.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local LoudnessLogic = require(ReplicatedStorage.Shared.Logic.Loudness)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local RobotBrain = require(ReplicatedStorage.Shared.Logic.RobotBrain)
local RobotChores = require(ReplicatedStorage.Shared.Logic.RobotChores)
local RobotPoses = require(ReplicatedStorage.Shared.Logic.RobotPoses)
local RobotRooms = require(ReplicatedStorage.Shared.Logic.RobotRooms)
local RobotSenses = require(ReplicatedStorage.Shared.Logic.RobotSenses)
local RobotWeapons = require(ReplicatedStorage.Shared.Logic.RobotWeapons)
local DayNight = require(script.Parent.DayNight)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Scores = require(script.Parent.Scores)
local Warehouse = require(script.Parent.Warehouse)

local settings = Config.Robots
local sense = settings.Sense
local chores = settings.Chores

type Carry = { instance: PVInstance, kind: "prop" | "pile", collide: { [BasePart]: boolean } }
type Loose = { instance: PVInstance, kind: "prop" | "pile", position: Vector3 }
export type Robot = {
	id: number,
	typeName: string,
	role: RobotBrain.Role,
	room: any?,
	home: Vector3,
	model: Model,
	brain: RobotBrain.Brain,
	night: boolean,
	pivotHeight: number,
	position: Vector3,
	facing: Vector3,
	speed: number,
	moving: boolean,
	stride: number,
	pose: string,
	face: Vector3?,
	goal: Vector3?,
	waypoints: { Vector3 },
	waypointIndex: number,
	pathFor: Vector3?,
	pathAt: number,
	pathBusy: boolean,
	studySpot: Vector3?,
	studyFace: Vector3?,
	studyUntil: number,
	wander: Vector3?,
	wanderAt: number,
	carrying: Carry?,
	choreBox: PVInstance?,
	loose: Loose?,
	looseAt: number,
	heardUpTo: number,
	ignore: { [Player]: number },
	lastPoses: { [string]: number },
	dead: boolean,
	-- the installation's corner robot: still and facing the wall until someone comes close
	corner: boolean,
	watching: boolean,
	stareSince: number?,
	lookAt: Vector3?,
}
type Alive = { player: Player, character: Model, root: BasePart, humanoid: Humanoid, position: Vector3 }

local Robots = {}

local folder: Folder
local stashFolder: Folder
local robots: { [number]: Robot } = {}
local byModel: { [Model]: Robot } = {}
local roomRobots: { [number]: { Robot } } = {}
local roomWant: { [number]: number } = {} -- robots a live room should have; one fewer per kill
local roomsById: { [number]: any } = {}
local roomPoints: { RobotRooms.Room } = {}
local activeRooms: { [number]: boolean } = {}
local destroyedRooms: { [number]: boolean } = {}
local stash: { [number]: { Model } } = {}
local claimed: { [Instance]: Robot } = {}
local pivotHeights: { [string]: number } = {}
local gunshots: { { position: Vector3, rank: number, time: number } } = {}
local nextId = 0
local pathTokens = settings.PathsPerSecond
local origin: Vector3
local floorY = 0
local random = Random.new()
local watcher = settings.Watcher

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function onFloor(v: Vector3): Vector3
	return Vector3.new(v.X, floorY, v.Z)
end

local function insideRoom(room: any, position: Vector3, pad: number): boolean
	local x, z = position.X - origin.X, position.Z - origin.Z
	return x > room.x0 + pad and x < room.x1 - pad and z > room.z0 + pad and z < room.z1 - pad
end

local function inAnyRoom(position: Vector3): boolean
	return Warehouse.roomAt(position) ~= nil
end

local function randomIn(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function alivePlayers(): { Alive }
	local alive = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(alive, {
				player = player,
				character = character :: Model,
				root = root,
				humanoid = humanoid,
				position = root.Position,
			})
		end
	end
	return alive
end

local function boxOf(instance: PVInstance): (CFrame, Vector3)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	end
	local part = instance :: BasePart
	return part.CFrame, part.Size
end

local function partsOf(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Sets an object down with the bottom of its box on the floor at position.
local function setDown(instance: PVInstance, position: Vector3)
	local box, size = boxOf(instance)
	local pivotFromBox = box:ToObjectSpace(instance:GetPivot())
	local turn = box - box.Position
	instance:PivotTo(CFrame.new(onFloor(position) + Vector3.yAxis * size.Y / 2) * turn * pivotFromBox)
end

local function spotIsClear(position: Vector3, size: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	params.RespectCanCollide = true
	local box = CFrame.new(onFloor(position) + Vector3.new(0, size.Y / 2 + 0.5, 0))
	return #workspace:GetPartBoundsInBox(box, size, params) == 0
end

local function randomRoomPoint(room: any, pad: number): Vector3
	local x = random:NextNumber(room.x0 + pad, math.max(room.x0 + pad, room.x1 - pad))
	local z = random:NextNumber(room.z0 + pad, math.max(room.z0 + pad, room.z1 - pad))
	return Warehouse.toWorld(x, z)
end

local function nearestRoom(position: Vector3): any?
	local best, bestDistance = nil, math.huge
	for _, point in roomPoints do
		local d = (point.cx - position.X) ^ 2 + (point.cz - position.Z) ^ 2
		if d < bestDistance then
			best, bestDistance = roomsById[point.id], d
		end
	end
	return best
end

-- Stolen and robot-held items -------------------------------------------------------------------

local function itemName(itemId: string): string
	local item = Inventory.Items[itemId]
	return if item then item.name else itemId
end

local function stashLabel(prompt: ProximityPrompt, itemId: string, count: number)
	prompt.ObjectText = if count > 1 then `{itemName(itemId)} x{count}` else itemName(itemId)
end

local function removeStash(roomKey: number, pickup: Model)
	local list = stash[roomKey]
	local index = list and table.find(list, pickup)
	if index then
		table.remove(list, index)
	end
	pickup:Destroy()
end

-- A small crate holding items, with a Take prompt. roomKey 0 = not in any room (a wreck).
local function placeStash(roomKey: number, itemId: string, count: number, position: Vector3): Model
	local pickup = Instance.new("Model")
	pickup.Name = "RobotStash"
	local crate = Instance.new("Part")
	crate.Name = "Crate"
	crate.Size = Vector3.new(1.6, 1.2, 1.6)
	crate.CFrame = CFrame.new(position + Vector3.yAxis * crate.Size.Y / 2)
		* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	crate.Anchored = true
	crate.CanCollide = false
	crate.CanTouch = false
	crate.Color = settings.StashColor
	crate.Material = Enum.Material.Metal
	crate.Parent = pickup
	pickup.PrimaryPart = crate
	pickup:SetAttribute("ItemId", itemId)
	pickup:SetAttribute("Count", count)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.HoldDuration = settings.StashPickupHold
	prompt.MaxActivationDistance = settings.StashPickupRange
	prompt.RequiresLineOfSight = false
	stashLabel(prompt, itemId, count)
	prompt.Parent = crate
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local left = pickup:GetAttribute("Count") :: number
		if not humanoid or humanoid.Health <= 0 or not Inventory.Items[itemId] then
			return
		end
		left -= Inventory.add(player, itemId, left)
		-- lifting it off the shelf is a quiet sound: the room's robot hears it
		Loudness.emit(crate.Position, "quiet", pickup)
		if left <= 0 then
			for key, list in stash do
				if table.find(list, pickup) then
					removeStash(key, pickup)
					return
				end
			end
			pickup:Destroy()
		else
			pickup:SetAttribute("Count", left)
			stashLabel(prompt, itemId, left)
		end
	end)

	pickup.Parent = stashFolder
	stash[roomKey] = stash[roomKey] or {}
	table.insert(stash[roomKey], pickup)
	return pickup
end

-- A shelf spot: on top of a piece of furniture against the room's wall.
local function shelfSpot(room: any): Vector3
	local items = room.items
	if #items == 0 then
		return randomRoomPoint(room, 4) + Vector3.yAxis * settings.StashHeight
	end
	local item = items[random:NextInteger(1, #items)]
	local spot = Warehouse.toWorld(item.x + item.nx * 0.5, item.z + item.nz * 0.5)
	return spot + Vector3.yAxis * settings.StashHeight
end

-- Models ------------------------------------------------------------------------------------------

local function makeModel(name: string): (Model?, number)
	local model = ModelLibrary.get(name)
	if not model then
		return nil, 0
	end
	ModelRig.rig(model)
	local height = pivotHeights[name]
	if not height then
		local box, size = model:GetBoundingBox()
		height = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
		pivotHeights[name] = height
	end
	for _, part in partsOf(model) do
		part.CanCollide = false
		part.CanTouch = false
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model, height
end

local function holdInFront(robot: Robot, instance: PVInstance)
	local box, size = boxOf(instance)
	local held = robot.position + robot.facing * (2 + size.Z / 2) + Vector3.yAxis * (robot.pivotHeight + 1)
	local pivotFromBox = box:ToObjectSpace(instance:GetPivot())
	instance:PivotTo(CFrame.lookAt(held, held - robot.facing) * pivotFromBox)
end

local function place(robot: Robot)
	local pivot = robot.position + Vector3.yAxis * robot.pivotHeight
	-- the art faces +z, lookAt points -z, so look away from the way we want to face
	local cframe = CFrame.lookAt(pivot, pivot - robot.facing)
	robot.model:PivotTo(cframe)
	if robot.carrying then
		holdInFront(robot, robot.carrying.instance)
	end
	if robot.choreBox then
		holdInFront(robot, robot.choreBox)
	end
end

local function makeChoreBox(): PVInstance
	local box: PVInstance
	local model = ModelLibrary.uploaded(chores.BoxModel) and ModelLibrary.get(chores.BoxModel)
	if model then
		box = model
	else
		local part = Instance.new("Part")
		part.Size = chores.BoxSize
		part.Color = chores.BoxColor
		part.Material = Enum.Material.Cardboard
		box = part
	end
	box.Name = "ChoreBox"
	for _, part in partsOf(box) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end
	return box
end

-- The box a carrier brings out on its errand: in its hands only while the pose says so.
local function holdChoreBox(robot: Robot, holding: boolean)
	if holding and not robot.choreBox then
		local box = makeChoreBox()
		robot.choreBox = box
		holdInFront(robot, box)
		box.Parent = folder -- inside the robots folder, so sight rays pass through it
	elseif not holding and robot.choreBox then
		robot.choreBox:Destroy()
		robot.choreBox = nil
	end
end

local function dress(robot: Robot)
	local model = robot.model
	local eyes = model:FindFirstChild(settings.EyePart, true)
	if eyes and eyes:IsA("BasePart") then
		if robot.night then
			eyes.Material = Enum.Material.Neon
			eyes.Color = settings.NightEyeColor
		elseif robot.role == "hunter" then
			eyes.Material = Enum.Material.SmoothPlastic
			eyes.Color = settings.NightEyeColor:Lerp(Color3.new(), 0.55)
		else
			eyes.Material = Enum.Material.Neon
			eyes.Color = settings.DayEyeColor
		end
	end
	if robot.night then
		local head = model:FindFirstChild("Head", true)
		if head and head:IsA("BasePart") then
			local scanner = Instance.new("SpotLight")
			scanner.Name = "Scanner"
			scanner.Face = Enum.NormalId.Back -- the art's front is +z
			scanner.Color = settings.ScannerColor
			scanner.Range = settings.ScannerRange
			scanner.Angle = settings.ScannerAngle
			scanner.Brightness = settings.ScannerBrightness
			scanner.Shadows = false
			scanner.Parent = head
		end
	end
	model:SetAttribute("RobotId", robot.id)
	model:SetAttribute("RobotType", robot.typeName)
	model:SetAttribute("Role", robot.role)
	model:SetAttribute("Night", robot.night)
	model:SetAttribute("State", robot.brain.state)
	model:SetAttribute("Pose", robot.pose)
end

local function modelName(typeName: string, night: boolean): string
	return if night then typeName .. settings.NightSuffix else typeName
end

local function spawnRobot(typeName: string, room: any?, position: Vector3, facing: Vector3): Robot?
	local info = settings.Types[typeName]
	local night = DayNight.isNight()
	local model, height = makeModel(modelName(typeName, night))
	if not info or not model then
		return nil
	end
	nextId += 1
	local now = os.clock()
	local robot: Robot = {
		id = nextId,
		typeName = typeName,
		role = info.role,
		room = room,
		home = if room then Warehouse.toWorld(room.cx, room.cz) else onFloor(position),
		model = model,
		brain = RobotBrain.new(info.role, DayNight.phase(), now),
		night = night,
		pivotHeight = height,
		position = onFloor(position),
		facing = if flat(facing).Magnitude > 0.01 then flat(facing).Unit else Vector3.zAxis,
		speed = 0,
		moving = false,
		stride = 0,
		pose = "idle",
		face = nil,
		goal = nil,
		waypoints = {},
		waypointIndex = 1,
		pathFor = nil,
		pathAt = -math.huge,
		pathBusy = false,
		studySpot = nil,
		studyFace = nil,
		studyUntil = 0,
		wander = nil,
		wanderAt = 0,
		carrying = nil,
		choreBox = nil,
		loose = nil,
		looseAt = 0,
		heardUpTo = now,
		ignore = {},
		lastPoses = {},
		dead = false,
		corner = false,
		watching = false,
		stareSince = nil,
		lookAt = nil,
	}
	model.Name = typeName
	dress(robot)
	place(robot)
	model.Parent = folder
	robots[robot.id] = robot
	byModel[model] = robot
	return robot
end

local function swapModel(robot: Robot, night: boolean)
	if robot.night == night then
		return
	end
	local model, height = makeModel(modelName(robot.typeName, night))
	if not model then
		return
	end
	byModel[robot.model] = nil
	robot.model:Destroy()
	robot.model = model
	robot.pivotHeight = height
	robot.night = night
	robot.lastPoses = {}
	model.Name = robot.typeName
	dress(robot)
	place(robot)
	model.Parent = folder
	byModel[model] = robot
end

-- Carrying ----------------------------------------------------------------------------------------

local function dropCarried(robot: Robot, position: Vector3)
	local carry = robot.carrying
	if not carry then
		return
	end
	robot.carrying = nil
	claimed[carry.instance] = nil
	if not carry.instance:IsDescendantOf(workspace) then
		return
	end
	setDown(carry.instance, position)
	for part, collide in carry.collide do
		part.CanCollide = collide
	end
	if carry.kind == "prop" then
		CollectionService:AddTag(carry.instance, Config.Grab.Tag)
	end
end

local function pickUp(robot: Robot, loose: Loose)
	local instance = loose.instance
	if claimed[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local collide = {}
	for _, part in partsOf(instance) do
		collide[part] = part.CanCollide
		part.CanCollide = false
	end
	-- untagged while held, so a player can't grab it out of the robot's hands mid-haul
	if loose.kind == "prop" then
		CollectionService:RemoveTag(instance, Config.Grab.Tag)
	end
	claimed[instance] = robot
	robot.carrying = { instance = instance, kind = loose.kind, collide = collide }
	robot.loose = nil
end

local function grabbableOf(part: BasePart): PVInstance?
	local tag = Config.Grab.Tag
	if CollectionService:HasTag(part, tag) then
		return part
	end
	local parent = part.Parent
	while parent and parent ~= workspace do
		if parent:IsA("Model") and CollectionService:HasTag(parent, tag) then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end

local function isLoose(instance: PVInstance, position: Vector3): boolean
	if claimed[instance] or inAnyRoom(position) then
		return false
	end
	local _, size = boxOf(instance)
	if math.max(size.X, size.Y, size.Z) > settings.MaxHaulSize then
		return false
	end
	return instance:GetAttribute("CarriedBy") == nil
end

local function findLoose(robot: Robot): Loose?
	local best: Loose? = nil
	local bestDistance = settings.LooseSearchRadius
	for _, pile in CollectionService:GetTagged(Config.Guns.LootPileTag) do
		if pile:IsA("Model") and pile:IsDescendantOf(workspace) and not claimed[pile] then
			local position = pile:GetPivot().Position
			local d = flatDistance(position, robot.position)
			if d < bestDistance and not inAnyRoom(position) then
				best, bestDistance = { instance = pile, kind = "pile", position = position }, d
			end
		end
	end
	if best then
		return best
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, stashFolder }
	local checked = {}
	for _, part in workspace:GetPartBoundsInRadius(robot.position, settings.LooseSearchRadius, params) do
		local prop = grabbableOf(part)
		if prop and not checked[prop] then
			checked[prop] = true
			local position = prop:GetPivot().Position
			local d = flatDistance(position, robot.position)
			if d < bestDistance and isLoose(prop, position) then
				best, bestDistance = { instance = prop, kind = "prop", position = position }, d
			end
		end
	end
	return best
end

-- Movement ----------------------------------------------------------------------------------------

local agentParams: { [string]: any } = {}

local function pathParams(typeName: string): any
	local params = agentParams[typeName]
	if not params then
		params = {
			AgentRadius = settings.AgentRadius,
			AgentHeight = settings.Types[typeName].agentHeight,
			AgentCanJump = false,
		}
		agentParams[typeName] = params
	end
	return params
end

local function walkStraight(robot: Robot, goal: Vector3)
	robot.waypoints = { goal }
	robot.waypointIndex = 1
	robot.pathFor = goal
end

local function setGoal(robot: Robot, goal: Vector3?, now: number)
	robot.goal = goal
	if not goal then
		robot.waypoints = {}
		return
	end
	local distance = flatDistance(goal, robot.position)
	local sameRoom = robot.room
		and insideRoom(robot.room, goal, 0)
		and insideRoom(robot.room, robot.position, 0)
	if distance < 6 or (sameRoom and distance < settings.StraightLineRange) then
		walkStraight(robot, goal)
		return
	end
	local fresh = robot.pathFor and flatDistance(robot.pathFor, goal) < 4
	if fresh and now - robot.pathAt < settings.PathRecompute * 4 then
		return
	end
	if robot.pathBusy or now - robot.pathAt < settings.PathRecompute or pathTokens < 1 then
		if not robot.pathFor then
			walkStraight(robot, goal)
		end
		return
	end
	pathTokens -= 1
	robot.pathBusy = true
	robot.pathAt = now
	task.spawn(function()
		local path = PathfindingService:CreatePath(pathParams(robot.typeName))
		local ok =
			pcall(path.ComputeAsync, path, robot.position + Vector3.yAxis * 2, goal + Vector3.yAxis * 2)
		robot.pathBusy = false
		if robot.dead or not robot.goal or flatDistance(robot.goal, goal) > 8 then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, onFloor(waypoint.Position))
			end
			robot.waypoints = points
			robot.waypointIndex = math.min(2, #points)
			robot.pathFor = goal
		else
			-- no path (blocked or off the navmesh): walk straight rather than stand frozen
			walkStraight(robot, goal)
		end
	end)
end

local function turnToward(robot: Robot, direction: Vector3, dt: number)
	local wanted = flat(direction)
	if wanted.Magnitude < 0.01 then
		return
	end
	local blended = robot.facing:Lerp(wanted.Unit, math.min(1, dt * 8))
	if blended.Magnitude > 0.01 then
		robot.facing = blended.Unit
	end
end

local function moveStep(robot: Robot, dt: number)
	local waypoint = robot.waypoints[robot.waypointIndex]
	if not robot.goal or robot.speed <= 0 or not waypoint then
		robot.moving = false
		if robot.face then
			turnToward(robot, robot.face - robot.position, dt)
			place(robot)
		end
		return
	end
	local offset = flat(waypoint - robot.position)
	if offset.Magnitude < 1 then
		robot.waypointIndex += 1
		if robot.waypointIndex > #robot.waypoints then
			robot.moving = false
		end
		return
	end
	local step = math.min(offset.Magnitude, robot.speed * dt)
	robot.position = onFloor(robot.position + offset.Unit * step)
	robot.stride += step * 0.9
	robot.moving = true
	turnToward(robot, offset, dt)
	place(robot)
end

-- Head turn (in pose units) that points a still robot's face at target, as far as the neck goes
local function headTurn(robot: Robot, target: Vector3): number
	local away = robot.model:GetPivot():VectorToObjectSpace(flat(target - robot.position))
	local degrees =
		math.clamp(math.deg(math.atan2(away.X, away.Z)), -watcher.MaxHeadTurn, watcher.MaxHeadTurn)
	return degrees / Config.Models.MoverDegrees
end

local function animate(now: number)
	for _, robot in robots do
		local limbs = RobotPoses.limbs(robot.pose, robot.stride, now, robot.moving)
		if robot.lookAt then
			limbs.Head = headTurn(robot, robot.lookAt)
		end
		for part, t in limbs do
			local last = robot.lastPoses[part]
			if last == nil or math.abs(last - t) > 0.02 then
				robot.lastPoses[part] = t
				ModelRig.setPose(robot.model, part, t)
			end
		end
	end
end

-- Senses ------------------------------------------------------------------------------------------

local function lineOfSight(robot: Robot, target: Alive): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, stashFolder, target.character }
	local eye = robot.position + Vector3.yAxis * sense.EyeHeight
	local head = target.position + Vector3.yAxis * 1.5
	return workspace:Raycast(eye, head - eye, params) == nil
end

local function sameRoomAs(robot: Robot, position: Vector3): boolean
	return robot.room ~= nil and insideRoom(robot.room, position, 0)
end

local function senseRobot(
	robot: Robot,
	phase: string,
	alive: { Alive },
	now: number
): (RobotBrain.Seen?, Vector3?)
	local night = phase == "Night"
	local roomOnly = not RobotBrain.seesOutsideRoom(robot.brain, phase)
	local info = settings.Types[robot.typeName]
	local outOnErrand = robot.brain.errand ~= nil and robot.brain.state ~= "chase"
	local sightRange = if outOnErrand then math.min(info.sightRange, chores.SightRange) else info.sightRange
	local eye = {
		x = robot.position.X,
		z = robot.position.Z,
		fx = robot.facing.X,
		fz = robot.facing.Z,
		range = sightRange,
	}
	local reach = math.max(info.sightRange * 1.5, sense.BeamRange, sense.FootstepRadius.Sprint)
	local seen: RobotBrain.Seen? = nil
	local heard: { any } = {}

	for _, target in alive do
		local ignoredUntil = robot.ignore[target.player]
		local d = flatDistance(target.position, robot.position)
		if (ignoredUntil and ignoredUntil > now) or d > reach then
			continue
		end
		local view = {
			x = target.position.X,
			z = target.position.Z,
			stance = target.character:GetAttribute("Stance"),
			hidden = Interact.isHidden(target.player),
			sameRoom = sameRoomAs(robot, target.position),
		}
		local visible = RobotSenses.canSee(eye, view, sense, night, roomOnly) and lineOfSight(robot, target)
		if not visible and night and not view.hidden and target.player:GetAttribute("FlashlightOn") then
			local look = target.root.CFrame.LookVector
			visible = RobotSenses.beamHits(view.x, view.z, look.X, look.Z, eye.x, eye.z, sense)
				and lineOfSight(robot, target)
		end
		if visible then
			if not seen or d < seen.distance then
				seen = { id = target.player, x = view.x, z = view.z, distance = d, range = sightRange }
			end
		elseif RobotSenses.hearsSteps(eye.x, eye.z, view, sense, roomOnly) then
			local rank = if view.stance == "Sprint" then 2 else 1
			table.insert(heard, { position = target.position, rank = rank, time = now })
		end
	end

	for _, event in Loudness.recent(robot.position) do
		local fromRobot = event.source and event.source:IsDescendantOf(folder)
		if
			event.time > robot.heardUpTo
			and not fromRobot
			and (not roomOnly or sameRoomAs(robot, event.position))
		then
			table.insert(
				heard,
				{ position = event.position, rank = LoudnessLogic.rank(event.level), time = event.time }
			)
		end
	end
	local gunRange = Config.Interact.Loudness.Levels.loud.robots
	for _, shot in gunshots do
		local inRange = flatDistance(shot.position, robot.position) <= gunRange
		if shot.time > robot.heardUpTo and inRange and (not roomOnly or sameRoomAs(robot, shot.position)) then
			table.insert(heard, shot)
		end
	end
	robot.heardUpTo = now
	local loudest = RobotSenses.loudest(heard)
	return seen, loudest and loudest.position
end

-- Acting on the brain -----------------------------------------------------------------------------

local function catch(robot: Robot, player: Player, alive: { Alive }, now: number)
	local target
	for _, entry in alive do
		if entry.player == player then
			target = entry
		end
	end
	if not target then
		return
	end
	if DayNight.isNight() then
		-- caught at night counts as going down: Combat drops their bag when the Humanoid dies
		Net.event("RobotCaught"):FireClient(player, "night", nil)
		target.humanoid.Health = 0
		return
	end
	robot.ignore[player] = now + settings.CaughtGraceSeconds
	local itemId = Inventory.bestItem(player)
	if not itemId or not robot.room then
		return
	end
	local taken = Inventory.remove(player, itemId, Inventory.count(player, itemId))
	if taken > 0 then
		placeStash(robot.room.id, itemId, taken, shelfSpot(robot.room))
		local item = Inventory.Items[itemId]
		Net.event("RobotCaught"):FireClient(player, "day", if item then item.name else itemId)
	end
end

local function tryReveal(robot: Robot, alive: { Alive })
	for _, target in alive do
		local spot = Interact.isHidden(target.player) and Interact.hidingSpot(target.player)
		if spot and flatDistance(spot:GetPivot().Position, robot.position) <= settings.RevealRange then
			local chance = settings.RevealChance
			if target.player:GetAttribute("HoldingBreath") == true then
				chance *= settings.HoldingBreathRevealFactor
			end
			if random:NextNumber() < chance then
				Interact.reveal(spot)
			end
		end
	end
end

local function pickWander(robot: Robot, alive: { Alive }): Vector3
	local anchor = robot.home
	local nearest = math.huge
	for _, target in alive do
		local d = flatDistance(target.position, robot.position)
		if d < nearest and d < settings.SweepRadius * 4 then
			anchor, nearest = target.position, d
		end
	end
	local candidate = anchor
	for _ = 1, 6 do
		local angle = random:NextNumber(0, math.pi * 2)
		local point = anchor
			+ Vector3.new(math.cos(angle), 0, math.sin(angle))
				* random:NextNumber(10, settings.SweepRadius)
		candidate = onFloor(point)
		local farEnough = flatDistance(candidate, robot.position) >= settings.SweepMinStep
		if farEnough and not inAnyRoom(candidate) and spotIsClear(candidate, Vector3.new(4, 6, 4)) then
			break
		end
	end
	return candidate
end

local function studyTarget(robot: Robot, now: number): (Vector3?, boolean)
	local room = robot.room
	if not room or #room.items == 0 then
		return nil, false
	end
	local spot = robot.studySpot
	local arrived = spot ~= nil and flatDistance(spot, robot.position) <= settings.ArriveRange
	if not spot or (arrived and now >= robot.studyUntil) then
		local item = room.items[random:NextInteger(1, #room.items)]
		robot.studySpot =
			Warehouse.toWorld(item.x + item.nx * settings.StudyReach, item.z + item.nz * settings.StudyReach)
		robot.studyFace = Warehouse.toWorld(item.x, item.z)
		robot.studyUntil = math.huge
		return robot.studySpot, false
	end
	if arrived and robot.studyUntil == math.huge then
		robot.studyUntil = now + randomIn(settings.StudySeconds)
	end
	return spot, arrived
end

local function act(robot: Robot, intent: RobotBrain.Intent, alive: { Alive }, now: number, inView: boolean)
	local brain = robot.brain
	local info = settings.Types[robot.typeName]
	if intent.drop and robot.carrying then
		local atHome = robot.room and insideRoom(robot.room, robot.position, 0)
		dropCarried(
			robot,
			if atHome then randomRoomPoint(robot.room, 4) else robot.position + robot.facing * 3
		)
	end
	if intent.pickup and robot.loose then
		pickUp(robot, robot.loose)
	end
	if intent.catch then
		catch(robot, intent.catch, alive, now)
	end
	if intent.reveal then
		tryReveal(robot, alive)
	end

	robot.pose = intent.pose
	holdChoreBox(robot, robot.pose == "carry")
	robot.face = if intent.face then onFloor(Vector3.new(intent.face.x, 0, intent.face.z)) else nil
	robot.speed = if intent.speed == "chase"
		then info.chaseSpeed
		elseif intent.speed == "walk" then info.walkSpeed
		else 0

	local goal: Vector3? = nil
	if intent.goal == "home" then
		goal = robot.home
	elseif intent.goal == "focus" and brain.focus then
		goal = onFloor(Vector3.new(brain.focus.x, 0, brain.focus.z))
	elseif intent.goal == "errand" and brain.errand then
		goal = onFloor(Vector3.new(brain.errand.x, 0, brain.errand.z))
	elseif intent.goal == "loose" and robot.loose then
		goal = onFloor(robot.loose.position)
	elseif intent.goal == "wander" then
		local reached = robot.wander and flatDistance(robot.wander, robot.position) <= settings.ArriveRange
		if not robot.wander or reached or now - robot.wanderAt > 15 then
			robot.wander = pickWander(robot, alive)
			robot.wanderAt = now
		end
		goal = robot.wander
	elseif intent.goal == "study" then
		local spot, arrived = studyTarget(robot, now)
		goal = spot
		if arrived then
			robot.speed = 0
			robot.face = robot.studyFace
		end
	end
	if robot.speed <= 0 then
		goal = nil
	end
	-- chasing someone in plain view: the raycast already showed the way is clear
	if goal and inView and brain.state == "chase" then
		robot.goal = goal
		walkStraight(robot, goal)
	else
		setGoal(robot, goal, now)
	end

	local model = robot.model
	if model:GetAttribute("State") ~= brain.state then
		model:SetAttribute("State", brain.state)
	end
	if model:GetAttribute("Pose") ~= robot.pose then
		model:SetAttribute("Pose", robot.pose)
	end
end

-- A corner robot holds still, facing the wall; its head follows the nearest player in LookRange.
-- True while it keeps watching, false once it wakes (stared long enough, too close, or noticed).
local function keepWatching(robot: Robot, alive: { Alive }, noticed: boolean, now: number): boolean
	local nearest, nearestDistance = nil, math.huge
	for _, target in alive do
		local d = flatDistance(target.position, robot.position)
		if d < nearestDistance then
			nearest, nearestDistance = target, d
		end
	end
	if not nearest or nearestDistance > watcher.LookRange then
		robot.lookAt, robot.stareSince = nil, nil
		return not noticed
	end
	robot.lookAt = nearest.position
	robot.stareSince = robot.stareSince or now
	local stared = now - robot.stareSince >= watcher.StareSeconds
	if noticed or stared or nearestDistance <= watcher.WakeRange then
		robot.watching, robot.lookAt, robot.stareSince = false, nil, nil
		return false
	end
	return true
end

local function despawn(robot: Robot)
	dropCarried(robot, robot.position)
	holdChoreBox(robot, false)
	robot.dead = true
	robots[robot.id] = nil
	byModel[robot.model] = nil
	local list = robot.room and roomRobots[robot.room.id]
	local index = list and table.find(list, robot)
	if index then
		table.remove(list, index)
	end
	robot.model:Destroy()
end

local function tick(dt: number)
	local now = os.clock()
	local phase = DayNight.phase()
	local alive = alivePlayers()
	pathTokens = math.min(settings.PathsPerSecond, pathTokens + settings.PathsPerSecond * dt)
	for i = #gunshots, 1, -1 do
		if now - gunshots[i].time > 3 then
			table.remove(gunshots, i)
		end
	end

	for _, robot in robots do
		local seen, heard = nil, nil
		if robot.role == "chore" or phase == "Night" then -- stalled hunters sense nothing
			seen, heard = senseRobot(robot, phase, alive, now)
		end
		if robot.watching and keepWatching(robot, alive, seen ~= nil or heard ~= nil, now) then
			continue
		end
		local state = robot.brain.state
		local hunting = phase == "Night" and (state == "sweep" or state == "investigate")
		if hunting and not robot.carrying and now >= robot.looseAt then
			robot.looseAt = now + settings.LooseSearchEvery
			robot.loose = findLoose(robot)
		end
		local loose = robot.loose
		if loose and (claimed[loose.instance] or not loose.instance:IsDescendantOf(workspace)) then
			robot.loose = nil
			loose = nil
		end
		if robot.carrying and not robot.carrying.instance:IsDescendantOf(workspace) then
			-- someone emptied the loot pile out of its hands
			claimed[robot.carrying.instance] = nil
			robot.carrying = nil
		end
		local focus = robot.brain.focus
		local errand = robot.brain.errand
		local input: RobotBrain.Input = {
			phase = phase,
			dt = dt,
			atHome = robot.room ~= nil and insideRoom(robot.room, robot.position, 2),
			homeDistance = flatDistance(robot.home, robot.position),
			focusDistance = if focus
				then flatDistance(Vector3.new(focus.x, 0, focus.z), robot.position)
				else nil,
			errandDistance = if errand
				then flatDistance(Vector3.new(errand.x, 0, errand.z), robot.position)
				else nil,
			carrying = robot.carrying ~= nil,
			seen = seen,
			heard = if heard then { x = heard.X, z = heard.Z } else nil,
			loose = if loose
				then { id = loose.instance, distance = flatDistance(loose.position, robot.position) }
				else nil,
		}
		act(robot, RobotBrain.update(robot.brain, input, settings, now), alive, now, seen ~= nil)
	end
end

-- Waking and sleeping -----------------------------------------------------------------------------

local function spawnChoreBot(room: any, corner: boolean)
	local typeName = RobotRooms.botFor(room.kind, settings.RoomBots, "cleaner")
	local position = randomRoomPoint(room, 5)
	local facing = Vector3.new(random:NextNumber(-1, 1), 0, 1)
	if corner then
		local pad = watcher.CornerPad
		local east, south = random:NextNumber() < 0.5, random:NextNumber() < 0.5
		local x = if east then room.x1 - pad else room.x0 + pad
		local z = if south then room.z1 - pad else room.z0 + pad
		position = Warehouse.toWorld(x, z)
		facing = if random:NextNumber() < 0.5
			then Vector3.new(if east then 1 else -1, 0, 0)
			else Vector3.new(0, 0, if south then 1 else -1)
	end
	local robot = spawnRobot(typeName, room, position, facing)
	if robot then
		robot.corner, robot.watching = corner, corner
		roomRobots[room.id] = roomRobots[room.id] or {}
		table.insert(roomRobots[room.id], robot)
	end
end

local function liveChoreBots(): number
	local count = 0
	for _, list in roomRobots do
		count += #list
	end
	return count
end

local function robotsFor(room: any): number
	local range = if room.giant then settings.GiantInstallationBots else settings.InstallationBots
	return random:NextInteger(range[1], range[2])
end

local nightStartedAt = 0

local function spawnHunter(near: Vector3)
	local typeName = settings.HunterTypes[random:NextInteger(1, #settings.HunterTypes)]
	for _ = 1, 8 do
		local angle = random:NextNumber(0, math.pi * 2)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = onFloor(near + direction * randomIn(settings.HunterSpawnDistance))
		if not inAnyRoom(spot) and spotIsClear(spot, Vector3.new(4, 7, 4)) then
			spawnRobot(typeName, nearestRoom(spot), spot, -direction)
			return
		end
	end
end

local function calmState(state: string): boolean
	return state == "study"
		or state == "return"
		or state == "suspicious"
		or state == "stalled"
		or state == "errand"
end

local function activate()
	local alive = alivePlayers()
	local points = {}
	for _, target in alive do
		table.insert(points, { id = target.player, x = target.position.X, z = target.position.Z })
	end

	local wanted = RobotRooms.active(roomPoints, points, activeRooms, settings, destroyedRooms)
	for id, list in roomRobots do
		if wanted[id] then
			continue
		end
		local busy = false
		for _, robot in list do
			local far = RobotRooms.distanceToNearest(robot.position.X, robot.position.Z, points)
				> settings.ChoreDespawnRadius
			busy = busy or not (calmState(robot.brain.state) or far)
		end
		if busy then
			wanted[id] = true -- one is out hunting near someone: keep the room until it calms down
		else
			for _, robot in table.clone(list) do
				despawn(robot)
			end
			roomRobots[id], roomWant[id] = nil, nil
		end
	end
	-- Nearest rooms first, so the cap leaves the far ones short rather than the one you're in
	local order = {}
	for id in wanted do
		table.insert(order, id)
	end
	local distance = {}
	for _, point in roomPoints do
		distance[point.id] = RobotRooms.distanceToNearest(point.cx, point.cz, points)
	end
	table.sort(order, function(a, b)
		return distance[a] < distance[b]
	end)
	local live = liveChoreBots()
	for _, id in order do
		local room = roomsById[id]
		roomWant[id] = roomWant[id] or robotsFor(room)
		local list = roomRobots[id] or {}
		local hasCorner = false
		for _, robot in list do
			hasCorner = hasCorner or robot.corner
		end
		for _ = #list + 1, roomWant[id] do
			if live >= settings.MaxLiveChoreBots then
				break
			end
			spawnChoreBot(room, not hasCorner)
			hasCorner = true
			live += 1
		end
	end
	activeRooms = wanted

	local hunters = {}
	for _, robot in robots do
		if robot.role == "hunter" then
			local d = RobotRooms.distanceToNearest(robot.position.X, robot.position.Z, points)
			if d > settings.HunterDespawnRadius then
				despawn(robot)
			else
				table.insert(hunters, { x = robot.position.X, z = robot.position.Z })
			end
		end
	end
	-- A quiet stretch after lights out, then hunters start far off and work their way in
	if DayNight.isNight() and os.clock() - nightStartedAt >= settings.HunterGrace then
		local need = RobotRooms.needHunters(points, hunters, settings.HunterNearRadius, settings.MaxHunters)
		for _, player in need do
			for _, target in alive do
				if target.player == player then
					spawnHunter(target.position)
				end
			end
		end
	end
end

local function onPhaseChanged(phase: string)
	local now = os.clock()
	if phase == "Night" then
		nightStartedAt = now
	end
	if phase == "Day" then
		table.clear(destroyedRooms)
		table.clear(roomWant) -- rooms you thinned out overnight fill back up
	end
	for _, robot in robots do
		RobotBrain.phaseChanged(robot.brain, phase, now)
		robot.wander = nil
		robot.studySpot = nil
		if phase == "Night" then
			swapModel(robot, true)
		elseif phase == "Day" then
			swapModel(robot, false)
		end
	end
end

-- Public ------------------------------------------------------------------------------------------

function Robots.fromPart(part: Instance): Robot?
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		local robot = byModel[model]
		if robot then
			return robot
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- Live robots within radius of position (floor distance).
function Robots.inRadius(position: Vector3, radius: number): { Robot }
	local spots = {}
	for id, robot in robots do
		table.insert(spots, { id = id, x = robot.position.X, z = robot.position.Z })
	end
	local found = {}
	for _, id in RobotWeapons.inBlast(position.X, position.Z, radius, spots) do
		table.insert(found, robots[id])
	end
	return found
end

local function errandsOut(): number
	local count = 0
	for _, robot in robots do
		if robot.brain.errand then
			count += 1
		end
	end
	return count
end

-- Chore bots near position: how many are out on errands, and the calm ones at home that could go,
-- nearest first.
function Robots.choresNear(position: Vector3, radius: number): (number, { Robot })
	local out, idle = 0, {}
	for _, robot in Robots.inRadius(position, radius) do
		if robot.role ~= "chore" or not robot.room or robot.watching then
			continue
		end
		if robot.brain.errand then
			out += 1
		elseif robot.brain.state == "study" and not robot.carrying then
			table.insert(idle, robot)
		end
	end
	table.sort(idle, function(a, b)
		return flatDistance(a.position, position) < flatDistance(b.position, position)
	end)
	return out, idle
end

-- Sends a calm chore bot out to work at goal (facing face), then home. Day only, live robots only,
-- at most Chores.MaxErrands at once. False if it can't go right now.
function Robots.sendOnChore(robot: Robot, goal: Vector3, face: Vector3?): boolean
	if robot.dead or not robot.room or robot.carrying or errandsOut() >= chores.MaxErrands then
		return false
	end
	local errand: RobotBrain.Errand = {
		x = goal.X,
		z = goal.Z,
		face = if face then { x = face.X, z = face.Z } else nil,
		chore = RobotChores.choreFor(robot.typeName, chores.ChoreFor),
		workSeconds = randomIn(chores.WorkSeconds),
	}
	if not RobotBrain.sendOnErrand(robot.brain, errand, DayNight.phase(), os.clock()) then
		return false
	end
	robot.studySpot = nil
	return true
end

function Robots.disable(robot: Robot, seconds: number)
	RobotBrain.disable(robot.brain, os.clock() + seconds)
end

-- Puts items on a shelf in a robot room (for loot spawning). False if the room doesn't exist.
function Robots.addToRoom(roomId: number, itemId: string, count: number): boolean
	local room = roomsById[roomId]
	if not room then
		return false
	end
	placeStash(roomId, itemId, count, shelfSpot(room))
	return true
end

local function wreck(position: Vector3)
	local pile = ModelLibrary.get(settings.WreckModel)
	if pile then
		pile.Parent = stashFolder
		setDown(pile, position)
	end
	local oil = Instance.new("Part")
	oil.Name = "Oil"
	oil.Shape = Enum.PartType.Cylinder
	oil.Size = Vector3.new(0.05, 6, 6)
	oil.CFrame = CFrame.new(onFloor(position) + Vector3.yAxis * 0.03) * CFrame.Angles(0, 0, math.rad(90))
	oil.Anchored = true
	oil.CanCollide = false
	oil.CanQuery = false
	oil.CanTouch = false
	oil.Color = settings.OilColor
	oil.Material = Enum.Material.Glass
	oil.Reflectance = 0.25
	oil.Parent = stashFolder

	local sparks = Instance.new("Part")
	sparks.Transparency = 1
	sparks.Anchored = true
	sparks.CanCollide = false
	sparks.CanQuery = false
	sparks.Size = Vector3.one
	sparks.CFrame = CFrame.new(onFloor(position) + Vector3.yAxis * 4)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 120, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.15, 0)
	emitter.Lifetime = NumberRange.new(0.3, 0.8)
	emitter.Speed = NumberRange.new(12, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = sparks
	sparks.Parent = stashFolder
	emitter:Emit(60)
	Debris:AddItem(sparks, 2)
end

-- Destroys a robot for good: wreck, its room's loot spills out where it fell, and the robot-only
-- reward goes to whoever did it. The room stays empty until the next morning.
function Robots.destroy(robot: Robot, byPlayer: Player?)
	if robot.dead then
		return
	end
	local position = robot.position
	if byPlayer then
		Scores.add(byPlayer, "RobotKills", 1)
	end
	despawn(robot)
	wreck(position)
	Loudness.emit(position, "loud", stashFolder)

	local room = robot.room
	if room and robot.role == "chore" and roomWant[room.id] then
		roomWant[room.id] -= 1
	end
	-- the last one down: the room's loot spills out where it fell
	if room and robot.role == "chore" and (roomWant[room.id] or 0) <= 0 then
		destroyedRooms[room.id] = true
		for _, pickup in table.clone(stash[room.id] or {}) do
			local angle = random:NextNumber(0, math.pi * 2)
			setDown(
				pickup,
				position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(2, 5)
			)
		end
		for _, pile in CollectionService:GetTagged(Config.Guns.LootPileTag) do
			if pile:IsA("Model") and insideRoom(room, pile:GetPivot().Position, 0) then
				local angle = random:NextNumber(0, math.pi * 2)
				setDown(
					pile,
					position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(2, 5)
				)
			end
		end
	end

	local known, unknown = RobotWeapons.knownRewards(settings.DestroyReward, Inventory.Items)
	for _, reward in known do
		local left = reward.count - (if byPlayer then Inventory.add(byPlayer, reward.id, reward.count) else 0)
		if left > 0 then
			placeStash(0, reward.id, left, onFloor(position))
		end
	end
	if #unknown > 0 then
		warn(`[Robots] rewards not in the item list yet: {table.concat(unknown, ", ")}`)
	end
end

function Robots.Init()
	folder = Instance.new("Folder")
	folder.Name = "Robots"
	folder.Parent = workspace
	stashFolder = Instance.new("Folder")
	stashFolder.Name = "RobotStash"
	stashFolder.Parent = workspace
end

function Robots.Start()
	if not settings.Enabled then
		return
	end
	origin = Warehouse.toWorld(0, 0)
	floorY = origin.Y
	for _, room in Warehouse.rooms() do
		roomsById[room.id] = room
		local center = Warehouse.toWorld(room.cx, room.cz)
		table.insert(roomPoints, { id = room.id, cx = center.X, cz = center.Z })
	end

	-- night models may load from InsertService the first time, so swapping must not hold up DayNight
	DayNight.onPhaseChanged(function(phase)
		task.spawn(onPhaseChanged, phase)
	end)
	-- Made up front so clients waiting on it don't hang until the first catch
	Net.event("RobotCaught")
	Net.event("GunFire").OnServerEvent:Connect(function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(
				gunshots,
				{ position = root.Position, rank = LoudnessLogic.rank("loud"), time = os.clock() }
			)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, robot in robots do
			moveStep(robot, dt)
		end
	end)
	task.spawn(function()
		local interval = 1 / settings.TickRate
		while true do
			tick(task.wait(interval))
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
			activate()
			task.wait(settings.ActivationInterval)
		end
	end)
end

return Robots
