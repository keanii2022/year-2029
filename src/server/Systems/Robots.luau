-- Robots: a chore bot in every room near a player by day, hunters in the aisles by night.
-- By day Life sends calm chore bots out on errands near players (sendOnChore).
-- Brains live in Logic/RobotBrain; this file senses the world for them, moves the models and carries
-- out what they decide (steal, haul, take players down). Robots are anchored and moved with PivotTo,
-- so nothing here touches physics. Limbs are procedural until the real clips are imported in Studio.
-- Guns hurt them too (Robots.shot): each hit staggers one, enough knock it down for a while, and it
-- wakes up hunting whoever shot it. Only the EMP, disruptor and Robots.destroy end one for good.
-- Dread: heads turn smoothly (clients animate LookAt), walking hunters hold still then burst, a hunter
-- stares before it chases, nights get harder (Logic/RobotNights), some drop off racks, and now and
-- then one sneaks into cover, goes dark and plays back a player's callout to lure them in (the mimic).
-- Companions: Systems/Companion befriends a few chore bots (Robots.befriend) and drives them with
-- orders. A befriended robot keeps its room spot in the count but is never despawned, never answers
-- the pack, never runs errands, never holds a grudge, and won't walk through walls.
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
local RobotHunt = require(ReplicatedStorage.Shared.Logic.RobotHunt)
local RobotMimic = require(ReplicatedStorage.Shared.Logic.RobotMimic)
local RobotMotion = require(ReplicatedStorage.Shared.Logic.RobotMotion)
local RobotNights = require(ReplicatedStorage.Shared.Logic.RobotNights)
local RobotPoses = require(ReplicatedStorage.Shared.Logic.RobotPoses)
local RobotRacks = require(ReplicatedStorage.Shared.Logic.RobotRacks)
local RobotRooms = require(ReplicatedStorage.Shared.Logic.RobotRooms)
local RobotSenses = require(ReplicatedStorage.Shared.Logic.RobotSenses)
local RobotWeapons = require(ReplicatedStorage.Shared.Logic.RobotWeapons)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local DayNight = require(script.Parent.DayNight)
local Grab = require(script.Parent.Grab)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Scores = require(script.Parent.Scores)
local SimPlayers = require(script.Parent.SimPlayers)
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
	straight: boolean, -- walking straight at its goal with no computed path round walls
	pathAt: number,
	pathBusy: boolean,
	studySpot: Vector3?,
	studyFace: Vector3?,
	studyUntil: number,
	wander: Vector3?,
	wanderAt: number,
	carrying: Carry?,
	choreBox: PVInstance?,
	boxPlaced: boolean, -- this errand's box is already on the shelf
	broom: Model?,
	sweepSide: number, -- which way the broom last swung, so dust puffs at each end of a stroke
	loose: Loose?,
	looseAt: number,
	-- a brute pulling a fortified piece loose: since when, last frame at it, next creak, which creak
	pry: { instance: PVInstance, since: number, lastAt: number, noiseAt: number, sound: number }?,
	heardUpTo: number,
	ignore: { [Player]: number },
	lastPoses: { [string]: number },
	dead: boolean,
	-- the installation's corner robot: still and facing the wall until someone comes close
	corner: boolean,
	watching: boolean,
	stareSince: number?,
	lookAt: Vector3?,
	studyPose: string, -- what it does at the thing it walked up to: look it over or poke at it
	-- getting shot
	damage: number,
	lastHitAt: number,
	staggerUntil: number,
	knockedUntil: number?,
	shooter: any?,
	grudge: any?,
	grudgeUntil: number,
	-- the installation's stash keeper: back to the room, glancing toward the door now and then
	guard: { spot: Vector3, face: Vector3, glance: Vector3?, offset: number }?,
	-- hunting as a pack
	callAt: number, -- no new alert before this
	shareAt: number, -- next time it tells the others where its target is
	lastTarget: any?, -- who it last chased, for searching hiding spots after losing them
	searchFrom: Vector3?, -- where it lost them; its searches circle this spot
	lungeUntil: number, -- bursting forward at Hunt.Lunge.Speed until then
	lungeReadyAt: number,
	-- dread
	burst: RobotMotion.Burst?, -- walking hunters: still or bursting until when
	staring: boolean, -- froze to stare last tick
	watch: RobotMotion.Watch, -- a studying robot being stared at
	silent: boolean, -- tonight's silent hunter: no steps or hum until it lunges
	perch: { dropAt: number, land: Vector3, dropping: boolean }?, -- on top of a rack, about to drop
	publishedLook: Vector3?,
	-- companions (Systems/Companion)
	ownerId: number?, -- the player it's bonded to, while befriended
	bonded: boolean,
	wants: string?, -- the item id it's asking for
	ghost: Model?, -- the wanted item it holds up
	badge: Model?, -- worn on its head once bonded
	lookFor: Vector3?, -- where its order says to look
	blockedAt: number, -- last time a wall stopped its step
	carryFn: ((Robot) -> ())?, -- holds a piece it's hauling for a fort, called whenever it's placed
	headPart: BasePart?,
	lure: Lure?,
}
type Alive = { player: Player, character: Model, root: BasePart, humanoid: Humanoid, position: Vector3 }
-- the mimic sneaking to cover (waiting false) or lying in wait there with its copied call
type Lure = {
	spot: Vector3,
	face: Vector3,
	index: number,
	waiting: boolean,
	untilAt: number,
	repeats: number,
	nextCallAt: number,
	lock: RobotMimic.Lock?,
	distances: { [Player]: number },
	answered: { [Player]: boolean },
}

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
local shotListeners: { (Robot, any, boolean) -> () } = {}
local pathTokens = settings.PathsPerSecond
local origin: Vector3
local floorY = 0
local random = Random.new()
local watcher = settings.Watcher
local shot = settings.Shot
local prowl = settings.Prowl
local hunt = settings.Hunt
local catchFeel = settings.Catch
local motion = settings.Motion
local racks = settings.Racks
local mimic = settings.Mimic
local threat = RobotNights.threat(1, settings.Nights)
local mimicRemote: RemoteEvent
local calls: { RobotMimic.Call } = {}
local mimicReadyAt = 0
local lurer: Robot? = nil -- only one robot lures at a time
local huntersTonight = 0
local silentPick = 0
local fxRemote: RemoteEvent

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function onFloor(v: Vector3): Vector3
	return Vector3.new(v.X, floorY, v.Z)
end

-- Robots are anchored, so they follow the ground themselves: up slopes and hills, down drops.
-- A rise steeper than MaxStepUp in one step is a wall, not a slope, and they stay level.
local MAX_STEP_UP = 2.5
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.RespectCanCollide = true

local function onGround(v: Vector3, fromY: number): Vector3
	local warehouse = workspace:FindFirstChild("Warehouse")
	if not warehouse then
		return onFloor(v)
	end
	groundParams.FilterDescendantsInstances = { warehouse }
	local hit = workspace:Raycast(
		Vector3.new(v.X, fromY + MAX_STEP_UP + 0.5, v.Z),
		Vector3.new(0, -60, 0),
		groundParams
	)
	if not hit then
		return Vector3.new(v.X, fromY, v.Z)
	end
	local y = hit.Position.Y
	if y > fromY + MAX_STEP_UP then
		y = fromY
	end
	return Vector3.new(v.X, math.max(y, floorY), v.Z)
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
		-- SpawnGrace (Combat): freshly spawned players aren't targets yet
		local inGrace = player:GetAttribute("SpawnGrace") == true
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not inGrace then
			table.insert(alive, {
				player = player,
				character = character :: Model,
				root = root,
				humanoid = humanoid,
				position = root.Position,
			})
		end
	end
	-- simulated players count as players; their "player" is a stand-in table, not a Player
	for _, bot in SimPlayers.alive() do
		table.insert(alive, bot)
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

-- Inside the warehouse's outer walls with room to stand. A spot past the wall still finds "floor"
-- out there, and a robot spawned in it walked in through the wall.
local function insideWarehouse(position: Vector3, pad: number): boolean
	local layout = Warehouse.layout()
	local reach = layout.half - Config.Warehouse.WallThickness - pad
	local here = position - origin
	return math.abs(here.X) < reach and math.abs(here.Z) < reach
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
-- A room's shelf crates merge by item and are capped, so catches and loot spawns can't pile up.
local function placeStash(roomKey: number, itemId: string, count: number, position: Vector3): Model
	local shelf = stash[roomKey]
	if roomKey ~= 0 and shelf then
		for _, existing in shelf do
			local prompt = existing:FindFirstChildWhichIsA("ProximityPrompt", true)
			if existing:GetAttribute("ItemId") == itemId and prompt then
				local total = (existing:GetAttribute("Count") :: number) + count
				existing:SetAttribute("Count", total)
				stashLabel(prompt, itemId, total)
				return existing
			end
		end
		while #shelf >= settings.StashPerRoom do
			removeStash(roomKey, shelf[1])
		end
	end
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
	prompt.RequiresLineOfSight = true -- no taking it through a wall
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

-- Seconds since a working chore bot reached its spot, or nil while it isn't working there.
local function workElapsed(robot: Robot, now: number): number?
	local arrivedAt = robot.brain.arrivedAt
	return if arrivedAt and robot.brain.state == "errand" then now - arrivedAt else nil
end

-- The body turn a working robot adds on the spot: a sweeper swings with its broom, a stocker shifts
-- its weight between reaches. Zero while walking.
local function bodyYaw(robot: Robot, now: number): number
	if robot.moving then
		return 0
	elseif robot.pose == "sweep" then
		return chores.SweepYaw * RobotPoses.sweepSwing(now)
	elseif robot.pose == "restock" or (robot.pose == "shelve" and robot.boxPlaced) then
		return chores.RestockYaw * math.sin(now * 1.3)
	end
	return 0
end

-- Slides the carried box from its hands onto the shelf in front, then leaves it there.
local function shelveBox(robot: Robot, box: PVInstance, now: number)
	local elapsed = workElapsed(robot, now) or 0
	local progress, placed = RobotChores.shelve(elapsed, chores.ShelveLift, chores.ShelveSlide)
	holdInFront(robot, box)
	local held = box:GetPivot()
	local shelf = robot.position + robot.facing * chores.ShelfReach + Vector3.yAxis * chores.ShelfHeight
	local eased = progress * progress * (3 - 2 * progress)
	box:PivotTo(held:Lerp(held.Rotation + shelf, eased))
	if placed then
		robot.choreBox = nil
		robot.boxPlaced = true
		Debris:AddItem(box, chores.BoxStays)
	end
end

-- The broom hangs from its grip at chest height, bristles on the floor ahead, swinging side to side.
local function holdBroom(robot: Robot, broom: Model, now: number)
	local side = robot.facing:Cross(Vector3.yAxis)
	local sweeping = robot.pose == "sweep" and not robot.moving
	local swing = if sweeping then RobotPoses.sweepSwing(now) else 0
	local grip = robot.position + robot.facing * 1.2 + Vector3.yAxis * 3.2
	local bristles = robot.position + robot.facing * 3.4 + side * (1.4 * swing) + Vector3.yAxis * 0.3
	local up = (grip - bristles).Unit
	local across = (side - up * side:Dot(up)).Unit
	broom:PivotTo(CFrame.fromMatrix(grip, across, up))
	local direction = math.sign(math.cos(now * 3))
	if sweeping and direction ~= robot.sweepSide then
		local dust = broom:FindFirstChild("Dust", true)
		if dust and dust:IsA("ParticleEmitter") then
			dust:Emit(chores.DustPuff)
		end
	end
	robot.sweepSide = direction
end

local function place(robot: Robot)
	local now = os.clock()
	local pivot = robot.position + Vector3.yAxis * robot.pivotHeight
	local facing = CFrame.Angles(0, bodyYaw(robot, now), 0):VectorToWorldSpace(robot.facing)
	-- the art faces +z, lookAt points -z, so look away from the way we want to face
	local cframe = CFrame.lookAt(pivot, pivot - facing)
	if robot.knockedUntil then
		-- powered off: tipped over backwards around its feet
		local feet = CFrame.lookAt(robot.position, robot.position - facing)
		cframe = feet * CFrame.Angles(math.rad(-shot.DownTilt), 0, 0) * CFrame.new(0, robot.pivotHeight, 0)
	end
	robot.model:PivotTo(cframe)
	if robot.carrying then
		holdInFront(robot, robot.carrying.instance)
	end
	if robot.choreBox then
		if robot.pose == "shelve" then
			shelveBox(robot, robot.choreBox, now)
		else
			holdInFront(robot, robot.choreBox)
		end
	end
	if robot.broom then
		holdBroom(robot, robot.broom, now)
	end
	local top = robot.position + Vector3.yAxis * (settings.Types[robot.typeName].agentHeight + 0.6)
	local head = robot.headPart
	if head and head.Parent then
		top = head.Position + Vector3.yAxis * (head.Size.Y / 2 + 0.4)
	end
	if robot.badge then
		robot.badge:PivotTo(CFrame.lookAt(top, top - facing))
	end
	if robot.ghost then
		-- held up over its head, a little out front, turning slowly so you can tell what it is
		local held = top + facing * 0.8 + Vector3.yAxis * (if robot.badge then 1.6 else 1)
		robot.ghost:PivotTo(CFrame.new(held) * CFrame.Angles(0, (now * 0.6) % (math.pi * 2), 0))
	end
	if robot.carryFn then
		robot.carryFn(robot)
	end
end

local function gearPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function makeChoreBox(): PVInstance
	local box: PVInstance
	local model = ModelLibrary.uploaded(chores.BoxModel) and ModelLibrary.get(chores.BoxModel)
	if model then
		box = model
	else
		local body = gearPart("Body", chores.BoxSize, chores.BoxColor, Enum.Material.Cardboard)
		local tape = gearPart(
			"Tape",
			Vector3.new(0.5, 0.05, chores.BoxSize.Z + 0.02),
			chores.TapeColor,
			Enum.Material.SmoothPlastic
		)
		tape.CFrame = CFrame.new(0, chores.BoxSize.Y / 2, 0)
		local stand = Instance.new("Model")
		body.Parent = stand
		tape.Parent = stand
		stand.PrimaryPart = body
		box = stand
	end
	box.Name = "ChoreBox"
	for _, part in partsOf(box) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		if part.Name ~= "Tape" then
			-- shows wherever the texture doesn't load, so it never reads as a black block
			part.Color = chores.BoxColor
		end
	end
	return box
end

-- A broom of plain blocks, its pivot at the grip with the handle running down -y.
local function makeBroom(): Model
	local broom = Instance.new("Model")
	broom.Name = "ChoreBroom"
	local handleLength = 3.4
	local handle =
		gearPart("Handle", Vector3.new(0.22, handleLength, 0.22), chores.BroomColor, Enum.Material.Wood)
	handle.CFrame = CFrame.new(0, -handleLength / 2, 0)
	local head = gearPart("Head", Vector3.new(2, 0.35, 0.45), chores.BroomColor, Enum.Material.Wood)
	head.CFrame = CFrame.new(0, -handleLength - 0.1, 0)
	local bristles =
		gearPart("Bristles", Vector3.new(1.9, 0.5, 0.4), chores.BristleColor, Enum.Material.Fabric)
	bristles.CFrame = CFrame.new(0, -handleLength - 0.5, 0)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Enabled = false
	dust.Color = ColorSequence.new(chores.DustColor)
	dust.Size = NumberSequence.new(0.3, 1.2)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(1.5, 3.5)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Acceleration = Vector3.new(0, -2, 0)
	dust.EmissionDirection = Enum.NormalId.Bottom
	dust.Parent = bristles
	handle.Parent = broom
	head.Parent = broom
	bristles.Parent = broom
	broom.PrimaryPart = handle
	broom.WorldPivot = CFrame.identity
	return broom
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

local function carryBroom(robot: Robot, carrying: boolean)
	if carrying and not robot.broom then
		local broom = makeBroom()
		robot.broom = broom
		holdBroom(robot, broom, os.clock())
		broom.Parent = folder
	elseif not carrying and robot.broom then
		robot.broom:Destroy()
		robot.broom = nil
	end
end

-- What a chore bot has in its hands for the pose it's in: a carrier's box until it's shelved, a
-- cleaner's broom on the way out and while sweeping.
local function choreGear(robot: Robot)
	local errand = robot.brain.errand
	if not errand then
		robot.boxPlaced = false
	end
	if robot.brain.companion then
		-- whatever a companion carries is real (a fort piece or junk for its player), never chore gear
		holdChoreBox(robot, false)
		carryBroom(robot, false)
		return
	end
	local pose = robot.pose
	local sweeping = errand ~= nil and errand.chore == "sweep" and robot.brain.state == "errand"
	holdChoreBox(robot, pose == "carry" or (pose == "shelve" and not robot.boxPlaced))
	carryBroom(robot, sweeping and (pose == "walk" or pose == "sweep"))
end

local function dress(robot: Robot)
	local model = robot.model
	local eyes = model:FindFirstChild(settings.EyePart, true)
	local befriended = robot.brain.companion
	local headPart = model:FindFirstChild("Head", true)
	robot.headPart = if headPart and headPart:IsA("BasePart") then headPart else nil
	if eyes and eyes:IsA("BasePart") then
		if befriended then
			eyes.Material = Enum.Material.Neon
			eyes.Color = Config.Companion.EyeColor
		elseif robot.night or robot.role == "prowler" then
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
	-- dress runs again when it's befriended or let go, so lights are found before they're made
	local head = robot.headPart
	local scanner = head and head:FindFirstChild("Scanner")
	if scanner and (befriended or not robot.night) then
		scanner:Destroy() -- no red scanner sweep on a friend
	elseif head and robot.night and not befriended and not scanner then
		local light = Instance.new("SpotLight")
		light.Name = "Scanner"
		light.Face = Enum.NormalId.Back -- the art's front is +z
		light.Color = settings.ScannerColor
		light.Range = settings.ScannerRange
		light.Angle = settings.ScannerAngle
		light.Brightness = settings.ScannerBrightness
		light.Shadows = false
		light.Parent = head
	end
	if robot.night and eyes and eyes:IsA("BasePart") then
		local found = eyes:FindFirstChild("EyeGlow")
		local glow = if found and found:IsA("PointLight") then found else Instance.new("PointLight")
		glow.Name = "EyeGlow"
		glow.Color = if befriended then Config.Companion.EyeColor else settings.NightEyeColor
		glow.Range = settings.EyeGlow.Range
		glow.Brightness = settings.EyeGlow.Brightness
		glow.Shadows = false
		glow.Parent = eyes
	end
	model:SetAttribute("RobotId", robot.id)
	model:SetAttribute("RobotType", robot.typeName)
	model:SetAttribute("Role", robot.role)
	model:SetAttribute("Night", robot.night)
	model:SetAttribute("Silent", robot.silent or nil)
	model:SetAttribute("State", robot.brain.state)
	model:SetAttribute("Pose", robot.pose)
	model:SetAttribute("Curious", befriended or nil)
	model:SetAttribute("Owner", if befriended then robot.ownerId else nil)
	model:SetAttribute("Wants", if befriended then robot.wants else nil)
	model:SetAttribute("Bonded", (befriended and robot.bonded) or nil)
end

local function modelName(typeName: string, night: boolean): string
	return if night then typeName .. settings.NightSuffix else typeName
end

local function spawnRobot(
	typeName: string,
	room: any?,
	position: Vector3,
	facing: Vector3,
	role: RobotBrain.Role?
): Robot?
	local info = settings.Types[typeName]
	local night = DayNight.isNight()
	local model, height = makeModel(modelName(typeName, night))
	if not info or not model then
		return nil
	end
	nextId += 1
	local now = os.clock()
	local robotRole: RobotBrain.Role = role or info.role
	local robot: Robot = {
		id = nextId,
		typeName = typeName,
		role = robotRole,
		room = room,
		home = if room then Warehouse.toWorld(room.cx, room.cz) else onFloor(position),
		model = model,
		brain = RobotBrain.new(robotRole, DayNight.phase(), now),
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
		straight = false,
		pathAt = -math.huge,
		pathBusy = false,
		studySpot = nil,
		studyFace = nil,
		studyUntil = 0,
		wander = nil,
		wanderAt = 0,
		carrying = nil,
		choreBox = nil,
		boxPlaced = false,
		broom = nil,
		sweepSide = 0,
		loose = nil,
		looseAt = 0,
		pry = nil,
		heardUpTo = now,
		ignore = {},
		lastPoses = {},
		dead = false,
		corner = false,
		watching = false,
		stareSince = nil,
		lookAt = nil,
		studyPose = "study",
		damage = 0,
		lastHitAt = -math.huge,
		staggerUntil = 0,
		knockedUntil = nil,
		shooter = nil,
		grudge = nil,
		grudgeUntil = 0,
		guard = nil,
		callAt = 0,
		shareAt = 0,
		lastTarget = nil,
		searchFrom = nil,
		lungeUntil = 0,
		lungeReadyAt = 0,
		burst = nil,
		staring = false,
		watch = RobotMotion.newWatch(),
		silent = false,
		perch = nil,
		publishedLook = nil,
		ownerId = nil,
		bonded = false,
		wants = nil,
		ghost = nil,
		badge = nil,
		lookFor = nil,
		blockedAt = -math.huge,
		carryFn = nil,
		headPart = nil,
		lure = nil,
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
	robot.publishedLook = nil
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

-- Fortified fort pieces hold against everything but a brute, which pries them out (prySpot).
local function isLoose(instance: PVInstance, position: Vector3, typeName: string): boolean
	if claimed[instance] or inAnyRoom(position) then
		return false
	end
	local _, size = boxOf(instance)
	if math.max(size.X, size.Y, size.Z) > settings.MaxHaulSize then
		return false
	end
	if instance:GetAttribute("CarriedBy") ~= nil then
		return false
	end
	return typeName == "brute" or not Grab.isFortified(instance)
end

-- A brute at a fortified piece: creaks loudly through Grab's pry noise until BrutePrySeconds of
-- prying are done. Returns true once it's loose. Walking off for a moment starts over.
local function pryLoose(robot: Robot, instance: PVInstance, now: number): boolean
	local pry = robot.pry
	if not pry or pry.instance ~= instance or now - pry.lastAt > 1 then
		pry = { instance = instance, since = now, lastAt = now, noiseAt = now, sound = 0 }
		robot.pry = pry
	end
	pry.lastAt = now
	if now >= pry.noiseAt then
		pry.noiseAt = now + Config.Grab.PryNoiseInterval
		pry.sound = Grab.pryNoise(instance, robot.model, pry.sound)
	end
	if now - pry.since < Config.Grab.BrutePrySeconds then
		return false
	end
	robot.pry = nil
	return true
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
			if d < bestDistance and isLoose(prop, position, robot.typeName) then
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
	robot.straight = true
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
	-- just hit a wall walking straight: get a real path round it instead of walking into it again
	local blockedLately = now - (robot.blockedAt or -math.huge) < 2
	if not blockedLately and (distance < 6 or (sameRoom and distance < settings.StraightLineRange)) then
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
			robot.straight = false
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

-- Robots are moved with PivotTo, so nothing physical stops them: walking straight (close goals, or
-- when no path exists because a fort is sealed) went right through placed pieces. A low ray ahead
-- stops them at any piece a player placed instead.
local fortParams = RaycastParams.new()
fortParams.FilterType = Enum.RaycastFilterType.Exclude
fortParams.RespectCanCollide = true

local function fortInTheWay(robot: Robot, direction: Vector3, step: number): boolean
	fortParams.FilterDescendantsInstances = { folder, stashFolder }
	local from = robot.position + Vector3.yAxis
	local hit = workspace:Raycast(from, direction * (settings.AgentRadius * 0.5 + step), fortParams)
	if not hit then
		return false
	end
	local prop = grabbableOf(hit.Instance :: BasePart)
	return prop ~= nil and prop:GetAttribute("PlacedBy") ~= nil and prop:GetAttribute("CarriedBy") == nil
end

-- A straight walk (no path, or a close goal) would carry a robot, and whatever it's hauling, through
-- walls. Two low rays ahead stop it at anything fixed and solid. Befriended robots check always.
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true
local WALL_HEIGHTS = { 1, 3.5 }
-- Rebuilt only when a character comes or goes (Start), not every frame per robot
local wallIgnoreDirty = true

local function refreshWallIgnore()
	local ignore: { Instance } = { folder, stashFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local sims = workspace:FindFirstChild(Config.SimPlayers.FolderName)
	if sims then
		table.insert(ignore, sims)
	end
	wallParams.FilterDescendantsInstances = ignore
	-- the sim players' folder may not exist yet: look again next time until it does
	wallIgnoreDirty = sims == nil
end

local function wallInTheWay(robot: Robot, direction: Vector3, step: number): boolean
	if wallIgnoreDirty then
		refreshWallIgnore()
	end
	for _, height in WALL_HEIGHTS do
		local from = robot.position + Vector3.yAxis * height
		local hit = workspace:Raycast(from, direction * (settings.AgentRadius * 0.5 + step), wallParams)
		local part = hit and hit.Instance
		if part and part:IsA("BasePart") and part.Transparency < 1 then
			local prop = grabbableOf(part)
			-- loose junk never stops a robot; placed pieces do (fortInTheWay)
			if not prop or prop:GetAttribute("PlacedBy") ~= nil then
				return true
			end
		end
	end
	return false
end

local function moveStep(robot: Robot, dt: number)
	if robot.knockedUntil or os.clock() < robot.staggerUntil then
		robot.moving = false
		return
	end
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
	-- a straight walk has no path round walls, and PivotTo moves through anything: stop at the wall
	-- and ask for a real path instead (this is how robots walked out of walls)
	if (robot.brain.companion or robot.straight) and wallInTheWay(robot, offset.Unit, step) then
		robot.moving = false
		robot.blockedAt = os.clock()
		robot.pathFor = nil -- the next goal update asks for a fresh path round it
		turnToward(robot, offset, dt)
		place(robot)
		return
	end
	if fortInTheWay(robot, offset.Unit, step) then
		robot.moving = false
		turnToward(robot, offset, dt)
		place(robot)
		return
	end
	robot.position = onGround(robot.position + offset.Unit * step, robot.position.Y)
	robot.stride += step * 0.9
	robot.moving = true
	turnToward(robot, offset, dt)
	place(robot)
end

local WORK_POSES = { sweep = true, restock = true, shelve = true }

local function animate(now: number)
	for _, robot in robots do
		local limbName, progress = robot.pose, nil
		if robot.pose == "shelve" then
			if robot.boxPlaced then
				limbName = "restock" -- the box is up: tidy the shelf
			else
				progress =
					RobotChores.shelve(workElapsed(robot, now) or 0, chores.ShelveLift, chores.ShelveSlide)
			end
		end
		if WORK_POSES[robot.pose] and not robot.moving then
			place(robot) -- the body sway and what's in its hands move every frame, not only on steps
		end
		local limbs = RobotPoses.limbs(limbName, robot.stride, now, robot.moving, progress)
		if robot.lookAt then
			limbs.Head = 0 -- clients turn it toward LookAt, smoothly, from straight ahead
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

-- From its eyes or its chest: a hanging set piece or a crate it's sitting by can block one but not
-- both, so a robot never stares straight through you.
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function lineOfSight(robot: Robot, target: Alive): boolean
	local params = sightParams
	params.FilterDescendantsInstances = { folder, stashFolder, target.character }
	local head = target.position + Vector3.yAxis * 1.5
	for _, height in { sense.EyeHeight, sense.ChestHeight } do
		local eye = robot.position + Vector3.yAxis * height
		if workspace:Raycast(eye, head - eye, params) == nil then
			return true
		end
	end
	return false
end

local function sameRoomAs(robot: Robot, position: Vector3): boolean
	return robot.room ~= nil and insideRoom(robot.room, position, 0)
end

local function calmGuard(robot: Robot): boolean
	local state = robot.brain.state
	return state == "study" or state == "suspicious"
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
	if robot.role == "prowler" and not night then
		sightRange *= prowl.SightFactor
	elseif night then
		sightRange *= threat.sight
	end
	-- the stash keeper hears anyone walking near it by day
	local guardEars = robot.guard ~= nil and not night and calmGuard(robot)
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
		-- root sits ~3 above the feet; a big height gap (on a hill, a catwalk) adds to the distance
		local rise = math.max(0, math.abs(target.position.Y - 3 - robot.position.Y) - 2)
		d = math.sqrt(d * d + rise * rise)
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
		elseif
			RobotSenses.hearsSteps(eye.x, eye.z, view, sense, roomOnly)
			or (
				guardEars
				and view.sameRoom
				and not view.hidden
				and view.stance ~= "Crouch"
				and d <= settings.Guard.HearRange
			)
		then
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
	for _, gunshot in gunshots do
		local inRange = flatDistance(gunshot.position, robot.position) <= gunRange
		if
			gunshot.time > robot.heardUpTo
			and inRange
			and (not roomOnly or sameRoomAs(robot, gunshot.position))
		then
			table.insert(heard, gunshot)
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
	if not target or player:GetAttribute("God") == true then
		return
	end
	local isPlayer = typeof(player) == "Instance" -- false for a simulated player's stand-in
	local caughtRemote = Net.event("RobotCaught")
	fxRemote:FireAllClients(robot.model, "catch", target.position)
	-- For the down screen (Combat): what got you
	local body = target.humanoid.Parent :: Instance
	body:SetAttribute("HurtBy", `Caught by a {robot.typeName} robot`)
	body:SetAttribute("HurtAt", workspace:GetServerTimeNow())
	if DayNight.isNight() then
		-- caught at night counts as going down: Combat drops their bag when the Humanoid dies
		if isPlayer then
			caughtRemote:FireClient(player, "night", nil, robot.position)
		end
		target.humanoid.Health = 0
		return
	end
	for key, untilTime in robot.ignore do
		if untilTime <= now then
			robot.ignore[key] = nil
		end
	end
	robot.ignore[player] = now + settings.CaughtGraceSeconds
	-- the client throws itself down (it owns its body); the server only takes the health
	local humanoid = target.humanoid
	humanoid.Health = math.max(0, humanoid.Health - catchFeel.DayDamage)
	-- going down drops the bag anyway (Combat), so only a survivor gets robbed
	local itemId = Inventory.bestItem(player)
	local takenName = nil
	if itemId and robot.room and humanoid.Health > 0 then
		local taken = Inventory.remove(player, itemId, Inventory.count(player, itemId))
		if taken > 0 then
			placeStash(robot.room.id, itemId, taken, shelfSpot(robot.room))
			takenName = itemName(itemId)
		end
	end
	if isPlayer then
		caughtRemote:FireClient(player, "day", takenName, robot.position)
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
		if
			farEnough
			and insideWarehouse(candidate, 4)
			and not inAnyRoom(candidate)
			and spotIsClear(candidate, Vector3.new(4, 6, 4))
		then
			break
		end
	end
	return candidate
end

local function studyTarget(robot: Robot, now: number): (Vector3?, boolean)
	local guard = robot.guard
	if guard then
		local glancing = guard.glance ~= nil
			and RobotRooms.keeperGlancing(now, guard.offset, settings.Guard.Work, settings.Guard.Glance)
		robot.studySpot = guard.spot
		robot.studyFace = if glancing then guard.glance else guard.face
		robot.studyPose = if glancing then "scan" else "study"
		robot.studyUntil = math.huge
		return guard.spot, flatDistance(guard.spot, robot.position) <= settings.ArriveRange
	end
	local room = robot.room
	if not room or #room.items == 0 then
		return nil, false
	end
	local spot = robot.studySpot
	local arrived = spot ~= nil and flatDistance(spot, robot.position) <= settings.ArriveRange
	if not spot or (arrived and now >= robot.studyUntil) then
		-- the next thing to look at, away from where its roommates are working
		local taken = {}
		for _, other in roomRobots[room.id] or {} do
			local at = if other ~= robot then other.studySpot or other.position else nil
			if at then
				table.insert(taken, { x = at.X, z = at.Z })
			end
		end
		local candidates = {}
		for _ = 1, 4 do
			local item = room.items[random:NextInteger(1, #room.items)]
			local at = Warehouse.toWorld(
				item.x + item.nx * settings.StudyReach,
				item.z + item.nz * settings.StudyReach
			)
			table.insert(candidates, { x = at.X, z = at.Z, item = item })
		end
		local pick = RobotRooms.spreadSpot(candidates, taken, settings.BotSpacing) :: any
		robot.studySpot = Warehouse.toWorld(
			pick.item.x + pick.item.nx * settings.StudyReach,
			pick.item.z + pick.item.nz * settings.StudyReach
		)
		robot.studyFace = Warehouse.toWorld(pick.item.x, pick.item.z)
		robot.studyUntil = math.huge
		robot.studyPose = settings.StudyPoses[random:NextInteger(1, #settings.StudyPoses)]
		return robot.studySpot, false
	end
	if arrived and robot.studyUntil == math.huge then
		robot.studyUntil = now + randomIn(settings.StudySeconds)
	end
	return spot, arrived
end

-- The next spot to check round where it lost its target. If they're tucked in a hiding spot close
-- by it sometimes heads straight for it, stopping in front so the reveal can reach.
local function searchSpot(robot: Robot, alive: { Alive }): Vector3?
	local from = robot.searchFrom
	if not from then
		return nil
	end
	local hiding = nil
	for _, target in alive do
		local spot = target.player == robot.lastTarget
			and Interact.isHidden(target.player)
			and Interact.hidingSpot(target.player)
		if spot then
			local at = spot:GetPivot().Position
			local toward = flat(from - at)
			local front = if toward.Magnitude > 0.01 then at + toward.Unit * 3.5 else at
			hiding = { x = front.X, z = front.Z }
		end
	end
	local around = { x = from.X, z = from.Z }
	for _ = 1, 4 do
		local point = RobotHunt.searchPoint(
			around,
			hiding,
			hunt,
			random:NextNumber(),
			random:NextNumber(0, math.pi * 2),
			random:NextNumber()
		)
		local spot = onFloor(Vector3.new(point.x, 0, point.z))
		if spotIsClear(spot, Vector3.new(3, 6, 3)) then
			return spot
		end
	end
	return nil
end

-- It has eyes on someone: tell the nearest awake robots where, and they run in from the sides. A
-- fresh sighting is loud (an alert and answers everyone hears); updates while chasing are silent.
local function callPack(caller: Robot, seen: RobotBrain.Seen, now: number, fresh: boolean)
	caller.shareAt = now + hunt.ShareEvery
	local loud = fresh and now >= caller.callAt
	if loud then
		caller.callAt = now + hunt.CallCooldown
		fxRemote:FireAllClients(caller.model, "alert", caller.position)
	end
	local night = DayNight.isNight()
	local candidates = {}
	for id, other in robots do
		local state = other.brain.state
		local awake = night or other.role == "prowler"
		if
			other ~= caller
			and awake
			and not other.knockedUntil
			and (state == "sweep" or state == "investigate")
		then
			table.insert(candidates, { id = id, x = other.position.X, z = other.position.Z })
		end
	end
	local target = { x = seen.x, z = seen.z }
	local from = { x = caller.position.X, z = caller.position.Z }
	local targetSpot = onFloor(Vector3.new(seen.x, 0, seen.z))
	local side = 1
	for _, id in RobotHunt.responders(target, candidates, hunt.CallRadius, hunt.MaxResponders) do
		local other = robots[id]
		local flank = RobotHunt.flankPoint(from, target, hunt.FlankOffset, side)
		side = -side
		local spot = onFloor(Vector3.new(flank.x, 0, flank.z))
		if not spotIsClear(spot, Vector3.new(3, 6, 3)) then
			spot = targetSpot
		end
		if RobotBrain.answerCall(other.brain, { x = spot.X, z = spot.Z }, hunt.Searches, now) then
			other.lastTarget = seen.id
			other.searchFrom = targetSpot
			if loud then
				fxRemote:FireAllClients(other.model, "answer", other.position)
			end
		end
	end
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
	local loose = robot.loose
	if intent.pickup and loose then
		local fortified = loose.kind == "prop" and Grab.isFortified(loose.instance)
		if not fortified or pryLoose(robot, loose.instance, now) then
			pickUp(robot, loose)
		end
	end
	if intent.catch then
		catch(robot, intent.catch, alive, now)
	end
	if intent.reveal then
		tryReveal(robot, alive)
	end
	if intent.search then
		local spot = searchSpot(robot, alive)
		if spot then
			brain.focus = { x = spot.X, z = spot.Z }
		end
	end

	robot.pose = intent.pose
	robot.face = if intent.face then onFloor(Vector3.new(intent.face.x, 0, intent.face.z)) else nil
	local hunterAtNight = DayNight.isNight() and robot.role ~= "chore"
	robot.speed = if intent.speed == "chase"
		then RobotNights.chaseSpeed(info, hunterAtNight, threat.speed)
		elseif intent.speed == "walk" then info.walkSpeed
		else 0
	if robot.grudge and now < robot.grudgeUntil then
		robot.speed *= shot.AngrySpeed
	end
	if brain.state == "chase" and now < robot.lungeUntil then
		robot.speed = math.max(robot.speed, hunt.Lunge.Speed)
	end

	local goal: Vector3? = nil
	if intent.goal == "home" then
		goal = robot.home
	elseif intent.goal == "focus" and brain.focus then
		goal = onFloor(Vector3.new(brain.focus.x, 0, brain.focus.z))
	elseif intent.goal == "errand" and brain.errand then
		goal = onFloor(Vector3.new(brain.errand.x, 0, brain.errand.z))
	elseif intent.goal == "loose" and robot.loose then
		goal = onFloor(robot.loose.position)
	elseif intent.goal == "order" and brain.order and brain.order.goal then
		goal = onFloor(Vector3.new(brain.order.goal.x, 0, brain.order.goal.z))
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
			robot.pose = robot.studyPose
			local box = robot.choreBox
			if box and not brain.errand then
				-- sets the hauled box down by the thing it's sorting and leaves it there a while
				robot.choreBox = nil
				setDown(box, robot.position + robot.facing * 2.5)
				Debris:AddItem(box, chores.BoxStays)
			end
		elseif robot.studyPose == "restock" and robot.typeName == "carrier" then
			robot.pose = "carry" -- a carrier hauls a box over to the thing it's about to sort
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
	-- after the goal is set, so standing still between bursts keeps the path
	local awake = DayNight.isNight() or robot.role == "prowler"
	if intent.speed == "walk" and awake and robot.role ~= "chore" then
		local factor
		robot.burst, factor = RobotMotion.burst(robot.burst, now, random:NextNumber(), motion.Burst)
		robot.speed *= factor
	end

	choreGear(robot)
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
		robot.model:SetAttribute("Watching", nil)
		return false
	end
	return true
end

-- Back up after being knocked down: it gets up and goes for whoever shot it.
local function reboot(robot: Robot, now: number)
	robot.knockedUntil = nil
	robot.damage = 0
	if not robot.brain.companion then
		robot.grudge = robot.shooter
		robot.grudgeUntil = now + shot.GrudgeSeconds
	end
	place(robot)
	fxRemote:FireAllClients(robot.model, "reboot", robot.position)
end

-- The shooter, as if seen, while the grudge lasts and they're in range and not hiding.
local function grudgeTarget(robot: Robot, alive: { Alive }, now: number): RobotBrain.Seen?
	if not robot.grudge or now >= robot.grudgeUntil then
		robot.grudge = nil
		return nil
	end
	for _, target in alive do
		if target.player == robot.grudge then
			local d = flatDistance(target.position, robot.position)
			local rise = math.max(0, math.abs(target.position.Y - 3 - robot.position.Y) - 2)
			d = math.sqrt(d * d + rise * rise)
			if d > shot.GrudgeRange or Interact.isHidden(target.player) then
				return nil
			end
			local range = settings.Types[robot.typeName].sightRange
			return {
				id = target.player,
				x = target.position.X,
				z = target.position.Z,
				distance = d,
				range = range,
			}
		end
	end
	return nil
end

-- Robots that end up standing in each other (two spawns, two study spots) step apart.
local function keepApart(robot: Robot)
	if robot.moving or robot.knockedUntil or robot.watching then
		return
	end
	local personal = settings.BotSpacing / 2
	for _, other in robots do
		local away = flat(robot.position - other.position)
		if other ~= robot and away.Magnitude < personal then
			local push = if away.Magnitude > 0.01
				then away.Unit
				else Vector3.new(random:NextNumber(-1, 1), 0, 1).Unit
			robot.position = onGround(robot.position + push * 0.6, robot.position.Y)
			place(robot)
			return
		end
	end
end

-- Where the head looks: clients turn it there smoothly. Only sent when it moves a stud or more.
local function publishLook(robot: Robot)
	local look, last = robot.lookAt, robot.publishedLook
	if look == last or (look and last and (look - last).Magnitude < 1) then
		return
	end
	robot.publishedLook = look
	robot.model:SetAttribute("LookAt", look)
end

local function nearestInView(robot: Robot, alive: { Alive }, range: number): Alive?
	local nearest, nearestDistance = nil, range
	for _, target in alive do
		local d = flatDistance(target.position, robot.position)
		if d <= nearestDistance and lineOfSight(robot, target) then
			nearest, nearestDistance = target, d
		end
	end
	return nearest
end

-- Someone looking straight at this robot from close by, with nothing in between.
local function watchedBy(robot: Robot, alive: { Alive }): Alive?
	local watched = motion.Watched
	local at = { x = robot.position.X, z = robot.position.Z }
	for _, target in alive do
		local look = target.root.CFrame.LookVector
		local from = { x = target.position.X, z = target.position.Z }
		if
			RobotMotion.looksAt(from, { x = look.X, z = look.Z }, at, watched.Range, watched.Angle)
			and lineOfSight(robot, target)
		then
			return target
		end
	end
	return nil
end

-- After the brain acted: who the head follows, and a studying robot stared at long enough stops work
-- and looks back until it's left alone.
local function lookAround(robot: Robot, alive: { Alive }, seen: RobotBrain.Seen?, dt: number)
	local brain = robot.brain
	local phase = DayNight.phase()
	local awake = phase == "Night" or robot.role == "prowler"
	robot.lookAt = nil
	if brain.companion then
		robot.lookAt = robot.lookFor
		return
	end
	if robot.role == "chore" and brain.state == "study" and phase ~= "Night" then
		local by = watchedBy(robot, alive)
		local wasFrozen = robot.watch.frozen
		RobotMotion.watchStep(robot.watch, by ~= nil, dt, motion.Watched)
		if robot.watch.frozen then
			robot.speed = 0
			robot.pose = "idle"
			robot.model:SetAttribute("Pose", "idle")
			robot.lookAt = if by then by.position else robot.publishedLook
		elseif wasFrozen then
			robot.lastPoses = {} -- back to work: the server poses every limb again
		end
		if robot.lookAt then
			return
		end
	elseif robot.watch.looked > 0 then
		robot.watch = RobotMotion.newWatch()
	end
	if robot.pose == "stare" and brain.focus then
		robot.lookAt = onFloor(Vector3.new(brain.focus.x, 0, brain.focus.z)) + Vector3.yAxis * 3
	elseif awake and seen and brain.state ~= "chase" then
		robot.lookAt = Vector3.new(seen.x, robot.position.Y + 3, seen.z)
	elseif robot.role == "hunter" and brain.state == "stalled" then
		local near = nearestInView(robot, alive, motion.StalledLookRange)
		robot.lookAt = near and near.position
	end
end

-- On top of a rack: hold still watching the nearest player, then drop into the aisle and land hard.
local function perchStep(robot: Robot, alive: { Alive }, now: number)
	local perch = robot.perch :: { dropAt: number, land: Vector3, dropping: boolean }
	local near = nearestInView(robot, alive, 60)
	robot.lookAt = near and near.position
	publishLook(robot)
	if perch.dropping or now < perch.dropAt then
		return
	end
	perch.dropping = true
	robot.model:SetAttribute("Perched", nil)
	task.spawn(function()
		local top = robot.position
		local started = os.clock()
		while not robot.dead do
			local t = math.min(1, (os.clock() - started) / racks.DropSeconds)
			-- across at an even pace, down like a falling weight
			local across = top:Lerp(perch.land, t)
			robot.position = Vector3.new(across.X, top.Y + (perch.land.Y - top.Y) * t * t, across.Z)
			place(robot)
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if robot.dead then
			return
		end
		robot.perch = nil
		robot.lastPoses = {}
		robot.staggerUntil = os.clock() + racks.LandStill
		fxRemote:FireAllClients(robot.model, "land", robot.position)
	end)
end

local function despawn(robot: Robot)
	dropCarried(robot, robot.position)
	holdChoreBox(robot, false)
	carryBroom(robot, false)
	if robot.ghost then
		robot.ghost:Destroy()
	end
	if robot.badge then
		robot.badge:Destroy()
	end
	robot.ghost, robot.badge, robot.carryFn = nil, nil, nil
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

-- The lure ---------------------------------------------------------------------------------------

local coverParams = RaycastParams.new()
coverParams.FilterType = Enum.RaycastFilterType.Exclude
coverParams.RespectCanCollide = true
local PROBE_DIRECTIONS = {}
for i = 0, 7 do
	local angle = i * math.pi / 4
	table.insert(PROBE_DIRECTIONS, Vector3.new(math.cos(angle), 0, math.sin(angle)))
end

-- The players its call is for: alive and within earshot of where it stands.
local function inEarshot(position: Vector3, alive: { Alive }): { Alive }
	local near = {}
	for _, target in alive do
		if flatDistance(target.position, position) <= Config.Callouts.HearRange then
			table.insert(near, target)
		end
	end
	return near
end

local function playCopy(robot: Robot, index: number)
	for _, target in inEarshot(robot.position, alivePlayers()) do
		mimicRemote:FireClient(target.player, robot.model, index)
	end
end

local function fortNear(position: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, stashFolder }
	for _, part in workspace:GetPartBoundsInRadius(onFloor(position), mimic.FortClearance, params) do
		local prop = grabbableOf(part)
		if prop and prop:GetAttribute("PlacedBy") ~= nil then
			return true
		end
	end
	return false
end

-- One place it could hide: open floor, out of every caller's sight, and how much is round it.
local function probeSpot(position: Vector3, callers: { Alive }): RobotMimic.Spot
	local spot = { x = position.X, z = position.Z, clear = false, hidden = false, cover = 0 }
	local floor = onFloor(position)
	spot.clear = math.abs(onGround(position, floorY).Y - floorY) < 1
		and spotIsClear(position, Vector3.new(3, 6, 3))
		and not fortNear(position)
	if not spot.clear then
		return spot
	end
	spot.hidden = true
	for _, caller in callers do
		local eye = caller.position + Vector3.yAxis * 1.5
		for _, height in { 2, 5 } do
			local at = floor + Vector3.yAxis * height
			if workspace:Raycast(eye, at - eye, coverParams) == nil then
				spot.hidden = false
				return spot
			end
		end
	end
	for _, direction in PROBE_DIRECTIONS do
		if workspace:Raycast(floor + Vector3.yAxis * 3, direction * mimic.CoverProbe, coverParams) then
			spot.cover += 1
		end
	end
	return spot
end

local function findCover(robot: Robot, callers: { Alive }, alive: { Alive }): Vector3?
	local ignore: { Instance } = { folder, stashFolder }
	for _, target in alive do
		table.insert(ignore, target.character)
	end
	coverParams.FilterDescendantsInstances = ignore
	local spots = {}
	for _, radius in mimic.CoverRings do
		for step = 1, mimic.CoverSteps do
			local angle = step / mimic.CoverSteps * math.pi * 2
			local position = robot.position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
			table.insert(spots, probeSpot(position, callers))
		end
	end
	local best = RobotMimic.coverSpot(spots, { x = robot.position.X, z = robot.position.Z }, mimic)
	return best and onFloor(Vector3.new(best.x, 0, best.z))
end

local function startLure(robot: Robot, call: RobotMimic.Call, now: number): boolean
	local alive = alivePlayers()
	local callers = inEarshot(robot.position, alive)
	if #callers == 0 then
		return false
	end
	local spot = findCover(robot, callers, alive)
	if not spot then
		return false
	end
	local middle = Vector3.zero
	for _, caller in callers do
		middle += caller.position
	end
	lurer = robot
	robot.lure = {
		spot = spot,
		face = onFloor(middle / #callers),
		index = call.index,
		waiting = false,
		untilAt = now + mimic.SneakSeconds,
		repeats = random:NextInteger(mimic.Repeats[1], mimic.Repeats[2]),
		nextCallAt = math.huge,
		lock = nil,
		distances = {},
		answered = {},
	}
	robot.model:SetAttribute("Silent", true)
	robot.model:SetAttribute("Lurking", true)
	return true
end

local function endLure(robot: Robot)
	robot.lure = nil
	if lurer == robot then
		lurer = nil
	end
	robot.lookAt = nil
	robot.model:SetAttribute("Lurking", nil)
	robot.model:SetAttribute("LockedOn", nil)
	robot.model:SetAttribute("Silent", robot.silent or nil)
end

-- Straight into the chase with a lunge, no stop and stare; the eyes snap bright as it goes.
local function pounceOn(robot: Robot, target: Alive, now: number)
	endLure(robot)
	robot.silent = false
	robot.model:SetAttribute("Silent", nil)
	RobotBrain.provoke(robot.brain, {
		id = target.player,
		x = target.position.X,
		z = target.position.Z,
		distance = flatDistance(target.position, robot.position),
		range = settings.Types[robot.typeName].sightRange,
	}, now)
	robot.lungeUntil = now + hunt.Lunge.Seconds
	robot.lungeReadyAt = robot.lungeUntil + hunt.Lunge.Cooldown
	fxRemote:FireAllClients(robot.model, "reveal", robot.position)
	fxRemote:FireAllClients(robot.model, "lunge", robot.position)
end

-- A different callout someone made near it lately, else the same one again.
local function nextCallIndex(robot: Robot, current: number): number
	for i = #calls, 1, -1 do
		local call = calls[i]
		local near = flatDistance(Vector3.new(call.x, 0, call.z), robot.position) <= Config.Callouts.HearRange
		if near and call.index ~= current then
			table.remove(calls, i)
			return call.index
		end
	end
	return current
end

-- Its head follows one player while it waits; that player's client feels singled out (LockedOn).
local function trackWatchers(robot: Robot, lure: Lure, alive: { Alive }, now: number)
	local watchers = {}
	local byPlayer: { [Player]: Alive } = {}
	for _, target in alive do
		local d = flatDistance(target.position, robot.position)
		local last = lure.distances[target.player]
		lure.distances[target.player] = d
		byPlayer[target.player] = target
		table.insert(watchers, {
			id = target.player,
			distance = d,
			approaching = last ~= nil and d < last - 0.05,
			answered = lure.answered[target.player] == true,
		})
	end
	lure.lock = RobotMimic.track(lure.lock, watchers, now, mimic)
	local locked = lure.lock and byPlayer[lure.lock.id]
	robot.lookAt = locked and locked.position
	local userId = locked and locked.player.UserId
	if robot.model:GetAttribute("LockedOn") ~= userId then
		robot.model:SetAttribute("LockedOn", userId)
	end
end

local function setPose(robot: Robot, pose: string)
	robot.pose = pose
	if robot.model:GetAttribute("Pose") ~= pose then
		robot.model:SetAttribute("Pose", pose)
	end
end

-- True while the lure has the robot this tick; false hands it back to its brain.
local function lureStep(robot: Robot, alive: { Alive }, now: number): boolean
	local lure = robot.lure :: Lure
	local state = robot.brain.state
	if
		not DayNight.isNight()
		or robot.knockedUntil
		or robot.brain.companion
		or (state ~= "sweep" and state ~= "investigate")
	then
		endLure(robot)
		return false
	end
	if not lure.waiting then
		if now >= lure.untilAt then
			endLure(robot)
			return false
		end
		if flatDistance(lure.spot, robot.position) > settings.ArriveRange then
			robot.speed = settings.Types[robot.typeName].walkSpeed
			robot.face = nil
			setPose(robot, "walk")
			setGoal(robot, lure.spot, now)
			robot.lookAt = nil
			publishLook(robot)
			return true
		end
		lure.waiting = true
		lure.untilAt = now + mimic.WaitSeconds
		lure.nextCallAt = now + randomIn(mimic.RepeatGap)
		robot.speed = 0
		robot.face = lure.face
		setGoal(robot, nil, now)
		setPose(robot, "idle")
		playCopy(robot, lure.index)
	end
	local near = {}
	for _, target in alive do
		if flatDistance(target.position, robot.position) <= mimic.ViewRange then
			table.insert(near, {
				id = target,
				x = target.position.X,
				z = target.position.Z,
				visible = lineOfSight(robot, target),
			})
		end
	end
	local eye = { x = robot.position.X, z = robot.position.Z, fx = robot.facing.X, fz = robot.facing.Z }
	local prey = RobotMimic.pounce(eye, near, mimic)
	if prey then
		pounceOn(robot, prey, now)
		return false
	end
	if now >= lure.untilAt then
		endLure(robot) -- nobody came: slips back to sweeping, still quiet
		return false
	end
	if lure.repeats > 0 and now >= lure.nextCallAt then
		lure.repeats -= 1
		lure.nextCallAt = now + randomIn(mimic.RepeatGap)
		lure.index = nextCallIndex(robot, lure.index)
		playCopy(robot, lure.index)
	end
	trackWatchers(robot, lure, alive, now)
	publishLook(robot)
	return true
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
		if robot.knockedUntil and now >= robot.knockedUntil then
			reboot(robot, now)
		end
		local seen, heard = nil, nil
		local befriended = robot.brain.companion
		-- stalled hunters sense nothing; befriended robots go by their orders
		if (robot.role ~= "hunter" or phase == "Night") and not befriended then
			seen, heard = senseRobot(robot, phase, alive, now)
		end
		local angryAt = if befriended then nil else grudgeTarget(robot, alive, now)
		if angryAt then
			seen = angryAt
			-- by day it gives up at the leash like any chase; no flapping back and forth at the edge
			local leashOk = phase == "Night"
				or robot.role == "prowler"
				or flatDistance(robot.home, robot.position) <= settings.DayLeash * 0.6
			if robot.brain.state ~= "chase" and leashOk then
				RobotBrain.provoke(robot.brain, angryAt, now)
			end
		end
		if robot.perch then
			perchStep(robot, alive, now)
			continue
		end
		keepApart(robot)
		if robot.lure and lureStep(robot, alive, now) then
			continue
		end
		if robot.watching and keepWatching(robot, alive, seen ~= nil or heard ~= nil, now) then
			publishLook(robot)
			continue
		end
		local state = robot.brain.state
		local awake = phase == "Night" or robot.role == "prowler"
		local hunting = awake and (state == "sweep" or state == "investigate")
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
			roll = random:NextNumber(),
		}
		local night = phase == "Night" and robot.role ~= "chore"
		if
			RobotHunt.shouldLunge(state, seen and seen.distance, night, now, robot.lungeReadyAt, hunt.Lunge)
			and now >= robot.brain.stareUntil
		then
			robot.lungeUntil = now + hunt.Lunge.Seconds
			robot.lungeReadyAt = robot.lungeUntil + hunt.Lunge.Cooldown
			if robot.silent then
				robot.silent = false
				robot.model:SetAttribute("Silent", nil)
			end
			fxRemote:FireAllClients(robot.model, "lunge", robot.position)
		end
		act(robot, RobotBrain.update(robot.brain, input, settings, now), alive, now, seen ~= nil)
		lookAround(robot, alive, seen, dt)
		publishLook(robot)

		local brain = robot.brain
		-- the pack hears nothing until the stare ends and it goes
		local stareEnded = robot.staring and robot.pose ~= "stare"
		robot.staring = robot.pose == "stare"
		if brain.targetId then
			robot.lastTarget = brain.targetId
		end
		if state == "chase" and brain.state == "investigate" and brain.focus then
			robot.searchFrom = onFloor(Vector3.new(brain.focus.x, 0, brain.focus.z))
		end
		local fresh = state ~= "chase" or stareEnded
		if
			awake
			and brain.state == "chase"
			and seen
			and not robot.staring
			and (fresh or now >= robot.shareAt)
		then
			callPack(robot, seen, now, fresh)
		end
	end
end

-- Waking and sleeping -----------------------------------------------------------------------------

-- A clear spot in the room, as far as it can get from the robots already living there.
local function roomSpawnSpot(room: any): Vector3
	local taken = {}
	for _, other in roomRobots[room.id] or {} do
		table.insert(taken, { x = other.position.X, z = other.position.Z })
	end
	local candidates = {}
	for _ = 1, 10 do
		local point = randomRoomPoint(room, 5)
		local here = point - origin
		if
			not RobotRooms.nearDoor(room, here.X, here.Z, settings.Guard.DoorClear)
			and spotIsClear(point, Vector3.new(4, 6, 4))
		then
			table.insert(candidates, { x = point.X, z = point.Z })
		end
	end
	local pick = RobotRooms.spreadSpot(candidates, taken, settings.BotSpacing)
	return if pick then onFloor(Vector3.new(pick.x, 0, pick.z)) else randomRoomPoint(room, 5)
end

local function spawnChoreBot(room: any, corner: boolean, guard: boolean)
	local typeName = RobotRooms.botFor(room.kind, settings.RoomBots, "cleaner")
	local position = roomSpawnSpot(room)
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
	local post = nil
	if guard then
		local at, face = RobotRooms.keeperPost(room, settings.Guard.Reach)
		local door = room.doors and room.doors[1]
		local doorAt = if door then RobotRooms.doorPost(room, door, 0) else nil
		position = Warehouse.toWorld(at.x, at.z)
		facing = Vector3.new(face.x, 0, face.z)
		post = {
			spot = onFloor(position),
			face = onFloor(position + facing * 10),
			glance = if doorAt then onFloor(Warehouse.toWorld(doorAt.x, doorAt.z)) else nil,
			offset = random:NextNumber(0, settings.Guard.Work),
		}
	end
	local robot = spawnRobot(typeName, room, position, facing)
	if robot then
		robot.corner, robot.watching = corner, corner
		robot.model:SetAttribute("Watching", corner or nil) -- clients crank its neck and let it breathe
		robot.guard = post
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
	local area = (room.x1 - room.x0) * (room.z1 - room.z0)
	return RobotRooms.botCount(area, range, settings.AreaPerBot, random:NextInteger(0, 1))
end

local nightStartedAt = 0
local dayStartedAt = 0

-- A night hunter perched on top of a rack bay near the player, behind them if it can, about to drop
-- into the aisle. Nil when no rack is in range or the landing isn't clear.
local function spawnOnRack(target: Alive, typeName: string): Robot?
	local look = target.root.CFrame.LookVector
	local here = target.position - origin
	local top, land = RobotRacks.dropSpot(
		Warehouse.layout().shelves,
		{ x = here.X, z = here.Z },
		{ x = look.X, z = look.Z },
		racks,
		random:NextNumber()
	)
	if not top or not land then
		return nil
	end
	local landing = onFloor(Warehouse.toWorld(land.x, land.z))
	local perch = onFloor(Warehouse.toWorld(top.x, top.z))
	if
		not insideWarehouse(landing, 4)
		or inAnyRoom(landing)
		or not spotIsClear(landing, Vector3.new(4, 7, 4))
	then
		return nil
	end
	local robot = spawnRobot(typeName, nearestRoom(landing), perch, landing - perch, "hunter")
	if robot then
		robot.position = perch + Vector3.yAxis * Config.Warehouse.RackHeight
		robot.pose = "stall"
		robot.perch = { dropAt = os.clock() + randomIn(racks.Perch), land = landing, dropping = false }
		robot.model:SetAttribute("Perched", true) -- clients tick on the rack top until it drops
		place(robot)
	end
	return robot
end

local function spawnHunter(target: Alive, role: RobotBrain.Role, types: { string }, distance: { number })
	local typeName = types[random:NextInteger(1, #types)]
	local robot: Robot? = nil
	if role == "hunter" and random:NextNumber() < racks.DropChance then
		robot = spawnOnRack(target, typeName)
	end
	for _ = 1, 8 do
		if robot then
			break
		end
		local angle = random:NextNumber(0, math.pi * 2)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = onFloor(target.position + direction * randomIn(distance))
		if insideWarehouse(spot, 4) and not inAnyRoom(spot) and spotIsClear(spot, Vector3.new(4, 7, 4)) then
			robot = spawnRobot(typeName, nearestRoom(spot), spot, -direction, role)
		end
	end
	if robot and role == "hunter" then
		huntersTonight += 1
		if huntersTonight == silentPick then
			robot.silent = true
			robot.model:SetAttribute("Silent", true)
		end
	end
end

local function spawnNear(
	need: { any },
	alive: { Alive },
	role: RobotBrain.Role,
	types: { string },
	distance: { number }
)
	for _, player in need do
		for _, target in alive do
			if target.player == player then
				spawnHunter(target, role, types, distance)
			end
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
			busy = busy or not (calmState(robot.brain.state) or far or robot.brain.companion)
		end
		if busy then
			wanted[id] = true -- one is out hunting near someone: keep the room until it calms down
		else
			local kept = 0
			for _, robot in table.clone(list) do
				if robot.brain.companion then
					kept += 1 -- still counts toward the room, but stays with its player
				else
					despawn(robot)
				end
			end
			if kept == 0 then
				roomRobots[id], roomWant[id] = nil, nil
			end
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
		local hasCorner, hasGuard = false, false
		for _, robot in list do
			hasCorner = hasCorner or robot.corner
			hasGuard = hasGuard or robot.guard ~= nil
		end
		for _ = #list + 1, roomWant[id] do
			if live >= settings.MaxLiveChoreBots then
				break
			end
			-- the first keeps the stash, the next watches from a corner, the rest wander and study
			local guard = not hasGuard
			local corner = hasGuard and not hasCorner
			spawnChoreBot(room, corner, guard)
			hasGuard = true
			hasCorner = hasCorner or corner
			live += 1
		end
	end
	activeRooms = wanted

	local hunters, prowlers = {}, {}
	for _, robot in robots do
		if robot.role ~= "chore" then
			local d = RobotRooms.distanceToNearest(robot.position.X, robot.position.Z, points)
			if d > settings.HunterDespawnRadius then
				despawn(robot)
			else
				local spot = { x = robot.position.X, z = robot.position.Z }
				table.insert(hunters, spot)
				if robot.role == "prowler" then
					table.insert(prowlers, spot)
				end
			end
		end
	end
	-- A quiet stretch after lights out, then hunters start far off and work their way in.
	-- By day a few prowlers turn up once the morning has settled.
	local now = os.clock()
	local phase = DayNight.phase()
	if phase == "Night" and now - nightStartedAt >= settings.HunterGrace then
		local need = RobotRooms.needHunters(
			points,
			hunters,
			settings.HunterNearRadius,
			settings.MaxHunters,
			threat.hunters
		)
		spawnNear(need, alive, "hunter", settings.HunterTypes, settings.HunterSpawnDistance)
	elseif phase == "Day" and now - dayStartedAt >= prowl.Grace then
		local need = RobotRooms.needHunters(points, prowlers, prowl.NearRadius, prowl.Max)
		spawnNear(need, alive, "prowler", prowl.Types, prowl.SpawnDistance)
	end
end

local function onPhaseChanged(phase: string)
	local now = os.clock()
	threat = RobotNights.threat(DayNight.day(), settings.Nights)
	if phase == "Night" then
		nightStartedAt = now
		huntersTonight = 0
		silentPick = random:NextInteger(1, settings.Silent.PickFrom)
	end
	if phase == "Day" then
		dayStartedAt = now
		table.clear(destroyedRooms)
		table.clear(roomWant) -- rooms you thinned out overnight fill back up
		for _, pickup in table.clone(stash[0] or {}) do
			removeStash(0, pickup) -- last night's wreck crates
		end
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

-- The mimic --------------------------------------------------------------------------------------

-- Remembers recent callouts (Callouts checks and plays them; this only listens).
local function heardCallout(player: Player, index: unknown)
	if not VoiceLines.validCallout(index, #Config.Callouts.Sounds) then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local lure = lurer and lurer.lure
	if
		lure
		and lure.waiting
		and (head.Position - (lurer :: Robot).position).Magnitude <= Config.Callouts.HearRange
	then
		lure.answered[player] = true -- someone calling back to it: its head turns their way
	end
	table.insert(calls, {
		speaker = player,
		index = index :: number,
		x = head.Position.X,
		z = head.Position.Z,
		time = os.clock(),
	})
	if #calls > 8 then
		table.remove(calls, 1)
	end
end

-- Now and then at night an awake robot somewhere else sneaks into cover and plays a recent callout
-- back, pitched wrong, to lure them in (lureStep). Companions never do.
local function tryMimic(now: number)
	if lurer and lurer.dead then
		lurer = nil
	end
	if
		lurer
		or not DayNight.isNight()
		or now < mimicReadyAt
		or #calls == 0
		or random:NextNumber() > mimic.Chance
	then
		return
	end
	local candidates = {}
	for id, robot in robots do
		local state = robot.brain.state
		if
			not robot.knockedUntil
			and not robot.perch
			and not robot.brain.companion
			and robot.role ~= "chore"
			and (state == "sweep" or state == "investigate")
		then
			table.insert(candidates, { id = id, x = robot.position.X, z = robot.position.Z })
		end
	end
	local call, id = RobotMimic.pick(calls, candidates, now, mimic)
	local robot = id and robots[id]
	if not call or not robot or not startLure(robot, call, now) then
		return
	end
	mimicReadyAt = now + randomIn(mimic.Cooldown)
	table.remove(calls, table.find(calls, call) :: number)
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
		if robot.role ~= "chore" or not robot.room or robot.watching or robot.guard then
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

-- A gun hit for damage from shooter (a Player or a simulated player's stand-in), fired from `from`.
-- The server's raycast already decided it landed. Sparks, a clank and a stagger every time; enough
-- damage inside Shot.HitMemory knocks it down. Hitting one that's already down only sparks.
local function pickWeighted(entries: { any }): any
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = random:NextNumber(0, total)
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

local function spillSalvage(robot: Robot)
	local today = DayNight.day()
	if robot.salvagedDay == today then
		return
	end
	robot.salvagedDay = today
	local salvage = shot.Salvage
	local contents = {}
	for _ = 1, random:NextInteger(salvage.Rolls[1], salvage.Rolls[2]) do
		local entry = pickWeighted(salvage.Common)
		table.insert(contents, { id = entry.id, count = entry.count })
	end
	if salvage.AlwaysRare[robot.typeName] or random:NextNumber() < salvage.RareChance then
		local entry = pickWeighted(salvage.Rare)
		table.insert(contents, { id = entry.id, count = entry.count })
	end
	Inventory.dropPile(robot.position + Vector3.new(0, 2, 0), contents)
end

function Robots.shot(robot: Robot, shooter: any, damage: number, from: Vector3, at: Vector3)
	if robot.dead then
		return
	end
	local now = os.clock()
	local down = robot.knockedUntil ~= nil
	if not down then
		if now - robot.lastHitAt > shot.HitMemory then
			robot.damage = 0
		end
		robot.lastHitAt = now
		robot.shooter = shooter
		if not robot.brain.companion then
			robot.grudge, robot.grudgeUntil = shooter, now + shot.GrudgeSeconds
		end
		robot.watching, robot.lookAt, robot.stareSince = false, nil, nil
		robot.model:SetAttribute("Watching", nil)
		robot.damage += damage
		down = robot.damage >= settings.Types[robot.typeName].armor
	end
	if down and not robot.knockedUntil then
		robot.knockedUntil = now + shot.DownSeconds
		Robots.disable(robot, shot.DownSeconds)
		dropCarried(robot, robot.position)
		spillSalvage(robot)
		robot.waypoints, robot.goal = {}, nil
		place(robot)
		fxRemote:FireAllClients(robot.model, "down", at)
		for _, listener in shotListeners do
			task.spawn(listener, robot, shooter, true)
		end
		return
	end
	if not down then
		robot.staggerUntil = now + shot.StaggerSeconds
		local back = flat(robot.position - from)
		if back.Magnitude > 0.01 then
			robot.position = onGround(robot.position + back.Unit * shot.Knockback, robot.position.Y)
			place(robot)
		end
	end
	fxRemote:FireAllClients(robot.model, "hit", at)
	for _, listener in shotListeners do
		task.spawn(listener, robot, shooter, false)
	end
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

-- The Sweep (PaEvents): for `seconds`, every awake hunter that isn't already chasing someone is
-- called to position, again every `every` seconds so ones that lose interest get pulled back in.
function Robots.converge(position: Vector3, seconds: number, every: number)
	local point = { x = position.X, z = position.Z }
	local endsAt = os.clock() + seconds
	task.spawn(function()
		while os.clock() < endsAt and DayNight.isNight() do
			local now = os.clock()
			for _, robot in robots do
				if robot.role == "hunter" and not robot.dead and not robot.knockedUntil then
					RobotBrain.answerCall(robot.brain, point, hunt.Searches, now)
				end
			end
			task.wait(every)
		end
	end)
end

-- A real gunshot at origin; only Combat (after its checks) and SimPlayers' bots call this.
function Robots.heardShot(position: Vector3)
	local now = os.clock()
	for i = #gunshots, 1, -1 do
		if now - gunshots[i].time > 3 then
			table.remove(gunshots, i)
		end
	end
	if #gunshots >= settings.MaxGunshots then
		table.remove(gunshots, 1)
	end
	table.insert(gunshots, { position = position, rank = LoudnessLogic.rank("loud"), time = now })
end

-- Companions (Systems/Companion) ---------------------------------------------------------------

-- Live chore bots that could turn curious: in a room, not the corner watcher or the doorway guard,
-- not down, not already befriended.
function Robots.choreBots(): { Robot }
	local list = {}
	for _, robot in robots do
		if
			robot.role == "chore"
			and robot.room
			and not robot.dead
			and not robot.watching
			and not robot.corner
			and not robot.guard
			and not robot.knockedUntil
			and not robot.brain.companion
		then
			table.insert(list, robot)
		end
	end
	return list
end

-- Befriended: its brain takes orders from now on, and its eyes turn blue-white.
function Robots.befriend(robot: Robot)
	if robot.dead or robot.brain.companion then
		return
	end
	RobotBrain.befriend(robot.brain, os.clock())
	robot.grudge, robot.shooter = nil, nil
	robot.watching, robot.stareSince = false, nil
	robot.model:SetAttribute("Watching", nil)
	robot.studySpot, robot.wander = nil, nil
	robot.brain.errand = nil
	dress(robot)
end

-- Let go: its own mind again (hunting, at night), red eyes, nothing on its head.
function Robots.release(robot: Robot)
	if robot.dead or not robot.brain.companion then
		return
	end
	RobotBrain.release(robot.brain, DayNight.phase(), os.clock())
	robot.lookFor, robot.carryFn = nil, nil
	robot.ownerId, robot.bonded, robot.wants = nil, false, nil
	Robots.attach(robot, "ghost", nil)
	Robots.attach(robot, "badge", nil)
	robot.waypoints, robot.goal, robot.pathFor = {}, nil, nil
	dress(robot)
end

-- Who it belongs to, whether it's bonded and what it asks for, shown on the model for clients.
function Robots.setCompanion(robot: Robot, ownerId: number?, bonded: boolean, wants: string?)
	if robot.ownerId == ownerId and robot.bonded == bonded and robot.wants == wants then
		return
	end
	robot.ownerId, robot.bonded, robot.wants = ownerId, bonded, wants
	local model = robot.model
	model:SetAttribute("Owner", ownerId)
	model:SetAttribute("Bonded", bonded or nil)
	model:SetAttribute("Wants", wants)
end

-- Something it holds up (the wanted item's ghost) or wears on its head (its owner's badge). It is
-- moved with the robot and destroyed with it. nil takes the current one off.
function Robots.attach(robot: Robot, slot: "ghost" | "badge", model: Model?)
	local current = if slot == "ghost" then robot.ghost else robot.badge
	if current == model then
		return
	end
	if current then
		current:Destroy()
	end
	if slot == "ghost" then
		robot.ghost = model
	else
		robot.badge = model
	end
	if model then
		model.Parent = folder
		place(robot)
	end
end

-- Where to go, how fast, in which pose, facing and looking where. Goal nil stands still.
export type Order = {
	goal: Vector3?,
	speed: ("walk" | "chase")?,
	pose: string,
	face: Vector3?,
	look: Vector3?,
}
function Robots.drive(robot: Robot, order: Order)
	RobotBrain.steer(robot.brain, {
		goal = if order.goal then { x = order.goal.X, z = order.goal.Z } else nil,
		speed = order.speed,
		pose = order.pose,
		face = if order.face then { x = order.face.X, z = order.face.Z } else nil,
	})
	robot.lookFor = order.look
end

-- Forget the current path so the next goal update plans a new one round whatever was in the way.
function Robots.repath(robot: Robot)
	robot.pathFor = nil
	robot.pathAt = -math.huge
	robot.waypoints = {}
end

-- A wall stopped it within the last `within` seconds.
function Robots.blocked(robot: Robot, within: number): boolean
	return os.clock() - robot.blockedAt <= within
end

-- Picks a loose prop up and holds it in front (no player can grab it out of its hands). False if
-- something else has it.
function Robots.hold(robot: Robot, prop: PVInstance): boolean
	if robot.carrying or claimed[prop] or not prop:IsDescendantOf(workspace) then
		return false
	end
	if prop:GetAttribute("CarriedBy") ~= nil or prop:GetAttribute("PlacedBy") ~= nil then
		return false
	end
	pickUp(robot, { instance = prop, kind = "prop", position = prop:GetPivot().Position })
	return robot.carrying ~= nil
end

function Robots.letGo(robot: Robot, position: Vector3)
	dropCarried(robot, position)
end

function Robots.carried(robot: Robot): PVInstance?
	return robot.carrying and robot.carrying.instance
end

-- Someone else (a robot or a player) has hold of it, or it's spoken for.
function Robots.isClaimed(prop: Instance): boolean
	return claimed[prop] ~= nil
end

-- Hauling a fort piece: fn holds it every time the robot is placed.
function Robots.carryWith(robot: Robot, fn: ((Robot) -> ())?)
	robot.carryFn = fn
end

function Robots.isDown(robot: Robot): boolean
	return robot.knockedUntil ~= nil
end

-- Keeps a knocked-down robot down for `seconds` from now.
function Robots.keepDown(robot: Robot, seconds: number)
	if not robot.knockedUntil then
		return
	end
	robot.knockedUntil = os.clock() + seconds
	RobotBrain.disable(robot.brain, robot.knockedUntil)
end

-- Repaired: up again right now, with no grudge.
function Robots.standUp(robot: Robot)
	if not robot.knockedUntil then
		return
	end
	robot.knockedUntil = nil
	robot.damage = 0
	robot.grudge, robot.shooter = nil, nil
	robot.brain.disabledUntil = -math.huge
	place(robot)
	fxRemote:FireAllClients(robot.model, "reboot", robot.position)
end

-- Called with (robot, shooter, knockedDown) after every gun hit.
function Robots.onShot(listener: (Robot, any, boolean) -> ())
	table.insert(shotListeners, listener)
end

-- Its room's doorway, just inside, and the way out. nil when its room has no door.
function Robots.doorway(robot: Robot, inset: number): (Vector3?, Vector3?)
	local room = robot.room
	local door = room and room.doors and room.doors[1]
	if not room or not door then
		return nil, nil
	end
	local at, out = RobotRooms.doorPost(room, door, inset)
	local spot = onFloor(Warehouse.toWorld(at.x, at.z))
	return spot, Vector3.new(out.x, 0, out.z)
end

-- An awake robot of the pack (not befriended, not down) within range has it in plain sight.
local scoutParams = RaycastParams.new()
scoutParams.FilterType = Enum.RaycastFilterType.Exclude

function Robots.scoutSees(robot: Robot, range: number): boolean
	local params = scoutParams
	params.FilterDescendantsInstances = { folder, stashFolder }
	local body = robot.position + Vector3.yAxis * sense.ChestHeight
	for _, other in robots do
		if
			other ~= robot
			and not other.dead
			and not other.knockedUntil
			and not other.brain.companion
			and other.brain.state ~= "stalled"
			and flatDistance(other.position, robot.position) <= range
		then
			local eye = other.position + Vector3.yAxis * sense.EyeHeight
			if workspace:Raycast(eye, body - eye, params) == nil then
				return true
			end
		end
	end
	return false
end

-- What Grab's placement check needs from a body, made up for a robot: a root at hip height whose
-- feet are on the floor, and eyes just in front of its face.
function Robots.body(robot: Robot): { root: any, humanoid: any, eye: Vector3 }
	local hip = robot.position + Vector3.yAxis * 3
	local root = {
		Position = hip,
		CFrame = CFrame.lookAt(hip, hip + robot.facing),
		Size = Vector3.new(2, 2, 1),
		Parent = robot.model,
	}
	return {
		root = root,
		humanoid = { HipHeight = 2 },
		eye = robot.position + Vector3.yAxis * sense.EyeHeight + robot.facing,
	}
end

function Robots.Init()
	folder = Instance.new("Folder")
	folder.Name = "Robots"
	folder.Parent = workspace
	stashFolder = Instance.new("Folder")
	stashFolder.Name = "RobotStash"
	stashFolder.Parent = workspace
	scoutParams.FilterDescendantsInstances = { folder, stashFolder }
	fxRemote = Net.event("RobotFx")
	mimicRemote = Net.event("RobotMimic")
	Net.event("Callout").OnServerEvent:Connect(heardCallout)
end

function Robots.Start()
	if not settings.Enabled then
		return
	end
	origin = Warehouse.toWorld(0, 0)
	floorY = origin.Y
	dayStartedAt = os.clock()
	threat = RobotNights.threat(DayNight.day(), settings.Nights)
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
	Players.PlayerRemoving:Connect(function(player)
		wallIgnoreDirty = true
		for _, robot in robots do
			robot.ignore[player] = nil
		end
	end)
	local function watchCharacters(player: Player)
		local function dirty()
			wallIgnoreDirty = true
		end
		player.CharacterAdded:Connect(dirty)
		player.CharacterRemoving:Connect(dirty)
		dirty()
	end
	Players.PlayerAdded:Connect(watchCharacters)
	for _, player in Players:GetPlayers() do
		watchCharacters(player)
	end

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
	task.spawn(function()
		while true do
			task.wait(mimic.CheckEvery)
			tryMimic(os.clock())
		end
	end)
end

return Robots
