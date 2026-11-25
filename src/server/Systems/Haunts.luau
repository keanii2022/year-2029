-- Haunts and life. Places survivor story spots, critter groups, moths, the greeter and security cams
-- around the built warehouse, and brings the warehouse's own mannequins, shirt folders and robot
-- piles to life. A low-rate director picks private scares for players alone and tells only that
-- client (Net "HauntScare"); the client draws them. Continuous loops (waving, folding, moths,
-- cams turning) run on clients from the "HauntLoop" tag so the server only sends state changes.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HauntDirector = require(ReplicatedStorage.Shared.Logic.HauntDirector)
local HauntLife = require(ReplicatedStorage.Shared.Logic.HauntLife)
local HauntPlacement = require(ReplicatedStorage.Shared.Logic.HauntPlacement)
local HauntSight = require(ReplicatedStorage.Shared.Logic.HauntSight)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Interact = require(script.Parent.Interact)
local Loudness = require(script.Parent.Loudness)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Haunts

-- Models the client clones for private scares. Kept here so they are the uploaded meshes, not the
-- grey stand-ins ModelLibrary builds on clients.
local CLIENT_TEMPLATES = { "lost_kid", "stuffed_robot", "mannequin", "kid_ball", "pigeon" }
local GRID = 50 -- studs per cell when checking spots against junk and loose furniture
local YIELD_EVERY = 100

type Watcher = HauntLife.Watcher & { player: Player, eye: Vector3 }
type Group = {
	kind: "pigeons" | "rats",
	center: Vector3,
	members: { Model },
	homes: { CFrame },
	awayUntil: number?,
}
type Cam = { model: Model, yaw: number }
type Mannequin = { model: Model, pose: string? }

local Haunts = {}

local scareRemote: RemoteEvent
local folder: Folder
local random = Random.new()
local director = HauntDirector.newServer()
local playerStates: { [Player]: HauntDirector.PlayerState } = {}
local groups: { Group } = {}
local cams: { Cam } = {}
local mannequins: { Mannequin } = {}
local moonlights: { SpotLight } = {}
local greeter: Model?
local placed = 0

local function roll(): number
	return random:NextNumber()
end

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function noteBuilt()
	placed += 1
	if placed % YIELD_EVERY == 0 then
		task.wait()
	end
end

local function positionsOf(watchers: { Watcher }): { Vector3 }
	local positions = {}
	for index, watcher in watchers do
		positions[index] = watcher.position :: any
	end
	return positions
end

local function loop(model: Model, kind: string)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- clients need every motor at once
	model:SetAttribute("Loop", kind)
	CollectionService:AddTag(model, "HauntLoop")
end

-- Same as the warehouse build: front (+z) faces turn degrees, bottom sits at height y above the floor.
local function place(name: string, x: number, z: number, turn: number, y: number?): Model?
	local model = ModelLibrary.get(name)
	if not model then
		return nil
	end
	local radians = math.rad(turn)
	local rotation = CFrame.lookAt(Vector3.zero, -Vector3.new(math.sin(radians), 0, math.cos(radians)))
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local target = Warehouse.toWorld(x, z) + Vector3.new(0, y or 0, 0)
	model:PivotTo(rotation + (target - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	model.Parent = folder
	noteBuilt()
	return model
end

local function playSound(model: Model, name: string, level: string, speed: number?, distortion: number?)
	local id = ModelLibrary.soundId(name)
	local part = model.PrimaryPart
	if not id or not part then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Settings.Volume
	sound.PlaybackSpeed = speed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	if distortion and distortion > 0 then
		local effect = Instance.new("DistortionSoundEffect")
		effect.Level = distortion
		effect.Parent = sound
	end
	sound.Parent = part
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 30) -- in case it never loads and so never ends
	sound:Play()
end

-- Spot checks ------------------------------------------------------------------------------------

local function cellKey(x: number, z: number): string
	return `{math.floor(x / GRID)},{math.floor(z / GRID)}`
end

local function makeClearCheck(layout: WarehouseGen.Layout): (number, number) -> boolean
	local cells: { [string]: { { x: number, z: number } } } = {}
	local function add(x: number, z: number)
		local key = cellKey(x, z)
		cells[key] = cells[key] or {}
		table.insert(cells[key], { x = x, z = z })
	end
	for _, junk in layout.junk do
		add(junk.x, junk.z)
	end
	for _, item in layout.loose do
		add(item.x, item.z)
	end
	local pad = Settings.SpotPad
	return function(x: number, z: number): boolean
		if not WarehouseGen.isClear(layout, Config.Warehouse, x, z, pad) then
			return false
		end
		local ci, cj = math.floor(x / GRID), math.floor(z / GRID)
		for i = ci - 1, ci + 1 do
			for j = cj - 1, cj + 1 do
				for _, other in cells[`{i},{j}`] or {} do
					if (other.x - x) ^ 2 + (other.z - z) ^ 2 < pad * pad then
						return false
					end
				end
			end
		end
		return true
	end
end

-- Story spots ------------------------------------------------------------------------------------

local function dress(model: Model, name: string)
	if name == "candles" then
		ModelRig.rig(model)
		local glow = model:FindFirstChild("Glow", true)
		if glow and glow:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Range = Settings.CandleLight.Range
			light.Brightness = Settings.CandleLight.Brightness
			light.Color = Settings.CandleLight.Color
			light.Parent = glow
		end
		loop(model, "flicker")
	elseif name == "notes_wall" or name == "drawing_wall" then
		ModelRig.rig(model) -- puts the survivor notes / kids' drawings on the Screen
	elseif name == "puddle" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0.35
				part.Reflectance = 0.25
				part.CanCollide = false
			end
		end
	end
end

-- The skylight is up in the roof haze; the moonlight is a lamp just under it so it reaches the floor.
local function addSkylight(spot: HauntPlacement.Spot)
	local skylight = place("broken_skylight", spot.x, spot.z, spot.turn, Config.Warehouse.CeilingHeight - 3)
	if skylight then
		local glass = skylight:FindFirstChild("Glass", true)
		if glass and glass:IsA("BasePart") then
			glass.Transparency = 0.7
		end
	end
	local holder = Instance.new("Part")
	holder.Name = "Moonlight"
	holder.Size = Vector3.one
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Position = Warehouse.toWorld(spot.x, spot.z) + Vector3.new(0, Settings.Moonlight.Height, 0)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = Settings.Moonlight.Range
	light.Angle = Settings.Moonlight.Angle
	light.Brightness = Settings.Moonlight.Brightness
	light.Color = Settings.Moonlight.Color
	light.Enabled = DayNight.isNight()
	light.Parent = holder
	holder.Parent = folder
	table.insert(moonlights, light)
end

local function placeStorySpots(
	clear: (number, number) -> boolean,
	taken: { HauntPlacement.Spot },
	half: number
)
	local kinds = {}
	for kind in Settings.StorySpots do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	for _, kind in kinds do
		local group = Settings.StorySpots[kind]
		local spots = HauntPlacement.spots(
			Warehouse.scaled(group.count),
			half,
			Settings.SpotGap,
			Settings.SpotTries,
			clear,
			taken,
			roll
		)
		for _, spot in spots do
			for _, item in HauntPlacement.arrange(group.items, spot) do
				local model = place(item.name, item.x, item.z, item.turn)
				if model then
					dress(model, item.name)
				end
			end
			if kind == "skylight" then
				addSkylight(spot)
			end
		end
	end
end

-- Critters ---------------------------------------------------------------------------------------

local function placeGroups(
	kind: "pigeons" | "rats",
	clear: (number, number) -> boolean,
	taken: { HauntPlacement.Spot },
	half: number
)
	local rules = Settings[if kind == "pigeons" then "Pigeons" else "Rats"]
	local count = Warehouse.scaled(if kind == "pigeons" then rules.Flocks else rules.Nests)
	local size = if kind == "pigeons" then rules.PerFlock else rules.PerNest
	local model = if kind == "pigeons" then "pigeon" else "rat"
	for _, spot in HauntPlacement.spots(count, half, Settings.SpotGap, Settings.SpotTries, clear, taken, roll) do
		local group: Group =
			{ kind = kind, center = Warehouse.toWorld(spot.x, spot.z), members = {}, homes = {} }
		for _, offset in HauntLife.scatter(random:NextInteger(size[1], size[2]), rules.Spread, roll) do
			local critter = place(model, spot.x + offset.x, spot.z + offset.z, random:NextNumber(0, 360))
			if critter then
				ModelRig.rig(critter)
				loop(critter, "peck")
				table.insert(group.members, critter)
				table.insert(group.homes, critter:GetPivot())
			end
		end
		table.insert(groups, group)
	end
end

local function spookRules(kind: string): HauntLife.Spook
	if kind == "pigeons" then
		local p = Settings.Pigeons
		return { near = p.WalkNear, sprintNear = p.SprintNear, sprintSpeed = p.SprintSpeed }
	end
	local r = Settings.Rats
	return { near = r.Near, beamRange = r.BeamRange, beamHalfAngle = r.BeamHalfAngle }
end

local SPOOK = { pigeons = spookRules("pigeons"), rats = spookRules("rats") }

local function scatterGroup(group: Group, threat: Vector3)
	local now = os.clock()
	local pigeons = group.kind == "pigeons"
	local time = if pigeons then Settings.Pigeons.FlyTime else Settings.Rats.FleeTime
	group.awayUntil = now + (if pigeons then Settings.Pigeons.ReturnAfter else Settings.Rats.ReturnAfter)
	for _, member in group.members do
		local root = member.PrimaryPart
		if not root then
			continue
		end
		local from = root.Position
		local target: Vector3
		if pigeons then
			local away = Vector3.new(from.X - threat.X, 0, from.Z - threat.Z)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			target = from + away * Settings.Pigeons.FlyAway + Vector3.new(0, Settings.Pigeons.FlyHeight, 0)
		else
			-- Along the aisle, so they don't run through the shelving
			target = from
				+ Vector3.xAxis
					* HauntSight.fleeSign(from.X, threat.X)
					* between(Settings.Rats.FleeDistance)
		end
		member:SetAttribute("Flying", true)
		local facing = CFrame.lookAt(from, from - (target - from) * Vector3.new(1, 0, 1)).Rotation
		root.CFrame = facing + from
		TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = facing + target,
		}):Play()
	end
	local first = group.members[1]
	if first then
		if pigeons then
			Loudness.emit(group.center, "loud", first)
			playSound(first, Settings.Sounds.PigeonBurst, "loud")
		else
			playSound(first, Settings.Sounds.RatScatter, "quiet")
		end
	end
	task.delay(time, function()
		for _, member in group.members do
			member.Parent = nil
		end
	end)
end

local function returnGroup(group: Group)
	group.awayUntil = nil
	for index, member in group.members do
		member:SetAttribute("Flying", nil)
		member:PivotTo(group.homes[index])
		member.Parent = folder
	end
end

local function stepGroups(watchers: { Watcher })
	local now = os.clock()
	for _, group in groups do
		if group.awayUntil then
			if now >= group.awayUntil then
				local _, distance =
					HauntSight.nearest(group.center, positionsOf(watchers), Settings.Pigeons.SprintNear * 2)
				if distance >= Settings.Pigeons.SprintNear * 2 then
					returnGroup(group)
				end
			end
		else
			local index = HauntLife.spookedBy(group.center, watchers, SPOOK[group.kind])
			if index then
				scatterGroup(group, watchers[index].position :: any)
			end
		end
	end
end

-- Moths circle a spread of the room lamps; clients fly them.
local function placeMoths(lamps: { Model })
	for _, lamp in HauntPlacement.everyNth(lamps, Settings.Moths.Lamps) do
		local box, size = lamp:GetBoundingBox()
		local center =
			Vector3.new(box.Position.X, box.Position.Y - size.Y / 2 + Settings.Moths.Height, box.Position.Z)
		for index = 1, Settings.Moths.PerLamp do
			local moth = ModelLibrary.get("moth")
			if not moth then
				return
			end
			moth:PivotTo(CFrame.new(center))
			ModelRig.rig(moth)
			moth:SetAttribute("Center", center)
			moth:SetAttribute("Radius", between(Settings.Moths.Radius))
			moth:SetAttribute("Speed", between(Settings.Moths.Speed) * (if index % 2 == 0 then -1 else 1))
			moth:SetAttribute("Phase", random:NextNumber(0, math.pi * 2))
			loop(moth, "circle")
			moth.Parent = folder
			noteBuilt()
		end
	end
end

-- Greeter and cams -------------------------------------------------------------------------------

local function placeGreeter(layout: WarehouseGen.Layout)
	local model = place("greeter", layout.entrance.x + 14, layout.entrance.z - 16, 180)
	if model then
		ModelRig.rig(model)
		loop(model, "wave")
		greeter = model
	end
end

local function sayWelcome(watchers: { Watcher })
	local model = greeter
	if not model then
		return
	end
	local _, distance =
		HauntSight.nearest(model:GetPivot().Position, positionsOf(watchers), Settings.Greeter.Hear)
	if distance >= Settings.Greeter.Hear then
		return
	end
	local speed, distortion = HauntLife.greeterVoice(Settings.Greeter, DayNight.day())
	playSound(model, Settings.Sounds.Greeter, "normal", speed, distortion)
end

local function placeCams(layout: WarehouseGen.Layout)
	local out = Config.Warehouse.PillarSize / 2 + 0.3
	for _, pillar in HauntPlacement.everyNth(layout.pillars, Warehouse.scaled(Settings.Cams.Count)) do
		local turn = random:NextInteger(0, 3) * 90
		local radians = math.rad(turn)
		local x, z = pillar.x + math.sin(radians) * out, pillar.z + math.cos(radians) * out
		local model = place("security_cam", x, z, turn, Settings.Cams.Height)
		if model then
			ModelRig.rig(model)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Name == "Glow" then
					part.Color = Settings.Cams.Color
				end
			end
			ModelRig.setGlow(model, true)
			model:SetAttribute("Yaw", 0)
			loop(model, "cam")
			table.insert(cams, { model = model, yaw = 0 })
		end
	end
end

local function stepCams(watchers: { Watcher })
	local maxStep = Settings.Cams.TurnSpeed * Settings.CamEvery
	for _, cam in cams do
		local pivot = cam.model:GetPivot()
		local index = HauntSight.nearest(pivot.Position, positionsOf(watchers), Settings.Cams.Range)
		if index then
			local offset = pivot:PointToObjectSpace(watchers[index].position :: any)
			local yaw = HauntSight.turnToward(cam.yaw, HauntSight.yawTo(offset.X, offset.Z), maxStep)
			if math.abs(yaw - cam.yaw) > 0.5 then
				cam.yaw = yaw
				cam.model:SetAttribute("Yaw", yaw)
			end
		end
	end
end

-- Warehouse's own haunted furniture --------------------------------------------------------------

local function adoptWarehouseModels(root: Instance): { Model }
	local lamps = {}
	for index, descendant in root:GetDescendants() do
		if index % 2000 == 0 then
			task.wait()
		end
		if not descendant:IsA("Model") then
			continue
		end
		local name = descendant:GetAttribute("ModelName")
		if name == "mannequin" then
			ModelRig.rig(descendant)
			table.insert(mannequins, { model = descendant })
		elseif name == "shirt_folder" then
			ModelRig.rig(descendant)
			loop(descendant, "fold")
		elseif name == "robot_pile" then
			ModelRig.rig(descendant)
			loop(descendant, "twitch")
		elseif name == "floor_lamp" then
			table.insert(lamps, descendant)
		end
	end
	return lamps
end

local function setPose(model: Model, poseName: string)
	local pose = Settings.Mannequins.Poses[poseName] or {}
	for _, part in ModelRig.movingParts(model) do
		ModelRig.setPose(model, part, pose[part] or 0)
	end
end

local function stepMannequins(watchers: { Watcher })
	local chance = Settings.Mannequins.Chance[DayNight.phase()] or 0
	for _, entry in mannequins do
		local model = entry.model
		local root = model.PrimaryPart
		if not root or not model:IsDescendantOf(workspace) or roll() >= chance then
			continue
		end
		local position = root.Position
		if
			not HauntLife.mannequinMayMove(
				position,
				watchers :: any,
				Settings.ViewHalfAngle,
				Settings.ViewRange,
				Settings.Mannequins.NearPlayer
			)
		then
			continue
		end
		local pose = HauntLife.nextPose(Settings.Mannequins.Poses, entry.pose, roll())
		if pose then
			entry.pose = pose
			setPose(model, pose)
		end
		-- A held mannequin is unanchored; never spin one out of someone's hands
		local index = HauntSight.nearest(position, positionsOf(watchers), Settings.Mannequins.NearPlayer)
		if index and root.Anchored and roll() < Settings.Mannequins.FaceTurn then
			local pivot = model:GetPivot()
			local offset = pivot:PointToObjectSpace(watchers[index].position :: any)
			model:PivotTo(pivot * CFrame.Angles(0, math.rad(HauntSight.yawTo(offset.X, offset.Z)), 0))
		end
	end
end

-- Players and the director -----------------------------------------------------------------------

local function watchersNow(includeHidden: boolean): { Watcher }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
			continue
		end
		if not includeHidden and Interact.isHidden(player) then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		table.insert(list, {
			player = player,
			position = root.Position,
			eye = root.Position + Vector3.new(0, 1.5, 0),
			look = root.CFrame.LookVector,
			speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude,
			flashlight = player:GetAttribute("FlashlightOn") == true,
		})
	end
	return list
end

local function runDirector()
	local everyone = watchersNow(true)
	local positions = positionsOf(everyone)
	local now = os.clock()
	local phase = DayNight.phase()
	for index, watcher in everyone do
		local others = table.clone(positions)
		table.remove(others, index)
		local state = playerStates[watcher.player]
		if not state then
			state = HauntDirector.newPlayer()
			playerStates[watcher.player] = state
		end
		local scare = HauntDirector.decide(Settings, {
			now = now,
			dt = Settings.DirectorEvery,
			phase = phase,
			alone = HauntDirector.isAlone(watcher.position :: any, others :: any, Settings.AloneRadius),
			hidden = Interact.isHidden(watcher.player),
			roll = roll(),
			pick = roll(),
		}, state, director)
		if scare then
			HauntDirector.record(state, director, scare, now)
			scareRemote:FireClient(watcher.player, scare)
		end
	end
end

local function onPhaseChanged(phase: string)
	if phase == "Night" then
		HauntDirector.newNight(director)
	end
	for _, light in moonlights do
		light.Enabled = phase == "Night"
	end
end

local function makeClientTemplates()
	local templates = Instance.new("Folder")
	templates.Name = "HauntTemplates"
	for _, name in CLIENT_TEMPLATES do
		local model = ModelLibrary.get(name)
		if model then
			model.Name = name
			ModelRig.rig(model)
			model.Parent = templates
		end
	end
	templates.Parent = ReplicatedStorage
end

local function waitForWarehouse(): Instance
	local root = workspace:FindFirstChild("Warehouse")
	while not (root and root:GetAttribute("Built")) do
		task.wait(1)
		root = workspace:FindFirstChild("Warehouse")
	end
	return root :: Instance
end

function Haunts.Init()
	scareRemote = Net.event("HauntScare")
	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)
	DayNight.onPhaseChanged(onPhaseChanged)
end

function Haunts.Start()
	makeClientTemplates()
	local root = waitForWarehouse()
	folder = Instance.new("Folder")
	folder.Name = "Haunts"
	folder.Parent = workspace

	local layout = Warehouse.layout()
	local clear = makeClearCheck(layout)
	local half = layout.half - Config.Warehouse.WallThickness - Settings.SpotPad
	local taken: { HauntPlacement.Spot } = {}
	placeGreeter(layout)
	placeCams(layout)
	placeStorySpots(clear, taken, half)
	placeGroups("pigeons", clear, taken, half)
	placeGroups("rats", clear, taken, half)
	placeMoths(adoptWarehouseModels(root))

	local sinceDirector, sinceLife, sinceCams, sinceMannequins, sinceGreeter = 0, 0, 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		sinceDirector += dt
		sinceLife += dt
		sinceCams += dt
		sinceMannequins += dt
		sinceGreeter += dt
		if sinceDirector >= Settings.DirectorEvery then
			sinceDirector = 0
			runDirector()
		end
		if sinceLife >= Settings.LifeEvery then
			sinceLife = 0
			stepGroups(watchersNow(false))
		end
		if sinceCams >= Settings.CamEvery then
			sinceCams = 0
			stepCams(watchersNow(false))
		end
		if sinceMannequins >= Settings.Mannequins.CheckEvery then
			sinceMannequins = 0
			stepMannequins(watchersNow(true))
		end
		if sinceGreeter >= Settings.Greeter.Every then
			sinceGreeter = 0
			sayWelcome(watchersNow(true))
		end
	end)
end

return Haunts
