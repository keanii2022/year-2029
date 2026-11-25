-- The Sorter: Haunts places store displays of mannequins (Config.Haunts.StorySpots.display), and one
-- in each is a real robot. This shuffles which spot it stands in, swaps everyone's poses while
-- nobody looks, and at night moves the real one toward players only while nobody sees it.
-- Shooting it knocks it flat. SorterBrain decides; this moves models and hurts players.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HauntLife = require(ReplicatedStorage.Shared.Logic.HauntLife)
local HauntSight = require(ReplicatedStorage.Shared.Logic.HauntSight)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local SorterBrain = require(ReplicatedStorage.Shared.Logic.SorterBrain)
local DayNight = require(script.Parent.DayNight)
local Interact = require(script.Parent.Interact)
local Loudness = require(script.Parent.Loudness)
local Tokens = require(script.Parent.Tokens)

local Settings = Config.Sorters

type Sorter = {
	model: Model,
	home: CFrame,
	feet: number, -- pivot height above the floor
	state: SorterBrain.State,
	rewardedDay: number?,
}
type Member = { model: Model, pose: string? }
type Viewer = {
	player: Player,
	character: Model,
	eye: Vector3,
	look: Vector3,
	position: Vector3,
	hunted: boolean,
}

local Sorters = {}

local sorters: { [Model]: Sorter } = {}
local members: { Member } = {}
local isMember: { [Model]: boolean } = {}
local caughtRemote: RemoteEvent
local random = Random.new()

local function playSound(model: Model, name: string)
	local id = ModelLibrary.soundId(name)
	local part = model.PrimaryPart
	if not id or not part then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Settings.Volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff("quiet")
	sound.Parent = part
	Mix.route(sound, "SFX")
	Debris:AddItem(sound, 10)
	sound:Play()
end

local function setPose(model: Model, poseName: string)
	local pose = Settings.Poses[poseName] or {}
	for _, part in ModelRig.movingParts(model) do
		ModelRig.setPose(model, part, pose[part] or 0)
	end
end

local function setLens(model: Model, on: boolean)
	local lens = model:FindFirstChild("Extra", true)
	if not (lens and lens:IsA("BasePart")) then
		return
	end
	lens.Transparency = if on then 0 else 1
	local light = lens:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Range = Settings.Lens.Range
		light.Brightness = Settings.Lens.Brightness
		light.Color = Settings.Lens.Color
		light.Parent = lens
	end
	light.Enabled = on
end

local function viewersNow(): { Viewer }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
			continue
		end
		local head = character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart")
			then head.Position
			else root.Position + Vector3.new(0, 1.5, 0)
		table.insert(list, {
			player = player,
			character = character,
			eye = eye,
			look = root.CFrame.LookVector,
			position = root.Position,
			hunted = not Interact.isHidden(player)
				and player:GetAttribute("God") ~= true
				and player:GetAttribute("SpawnGrace") ~= true,
		})
	end
	return list
end

-- Seen: inside someone's view cone with nothing solid between their eyes and its chest
local function seenBy(model: Model, viewers: { Viewer }): boolean
	local chest = model:GetPivot().Position + Vector3.new(0, 1, 0)
	for _, viewer in viewers do
		if
			not HauntSight.inView(viewer.eye, viewer.look, chest, Settings.ViewHalfAngle, Settings.ViewRange)
		then
			continue
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { viewer.character, model }
		local hit = workspace:Raycast(viewer.eye, chest - viewer.eye, params)
		if not hit or (hit.Instance.Transparency >= 0.9 and not hit.Instance.CanCollide) then
			return true
		end
	end
	return false
end

local function nearestHunted(position: Vector3, viewers: { Viewer }): Viewer?
	local best, bestDistance = nil, math.huge
	for _, viewer in viewers do
		local distance = SorterBrain.flatDistance(position, viewer.position)
		if viewer.hunted and distance < bestDistance then
			best, bestDistance = viewer, distance
		end
	end
	return best
end

local function floorAt(x: number, z: number, aroundY: number, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(
		Vector3.new(x, aroundY + Settings.StepHeight, z),
		Vector3.new(0, -Settings.StepHeight * 2, 0),
		params
	)
	return hit and hit.Position.Y
end

-- Steps toward (x, z) if the way is clear, else slides along one axis, else stays put
local function moveTo(sorter: Sorter, x: number, z: number, face: Vector3, ignore: { Instance })
	local pivot = sorter.model:GetPivot()
	local from = pivot.Position
	local floorY = from.Y - sorter.feet
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, goal in { Vector2.new(x, z), Vector2.new(x, from.Z), Vector2.new(from.X, z) } do
		local chest = Vector3.new(from.X, floorY + 3, from.Z)
		local ahead = Vector3.new(goal.X, floorY + 3, goal.Y) - chest
		if ahead.Magnitude < 0.05 or workspace:Raycast(chest, ahead + ahead.Unit * 0.8, params) then
			continue
		end
		local groundY = floorAt(goal.X, goal.Y, floorY, ignore)
		if not groundY then
			continue
		end
		local position = Vector3.new(goal.X, groundY + sorter.feet, goal.Y)
		local toward = Vector3.new(face.X - position.X, 0, face.Z - position.Z)
		local look = if toward.Magnitude > 0.1 then -toward.Unit else pivot.LookVector
		sorter.model:PivotTo(CFrame.lookAt(position, position + look))
		return
	end
end

local function catch(sorter: Sorter, viewer: Viewer)
	local humanoid = viewer.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	setPose(sorter.model, "reach")
	playSound(sorter.model, Settings.Sounds.Catch)
	viewer.character:SetAttribute("HurtBy", Settings.HurtBy)
	viewer.character:SetAttribute("HurtAt", workspace:GetServerTimeNow())
	humanoid.Health = math.max(0, humanoid.Health - Settings.CatchDamage)
	caughtRemote:FireClient(viewer.player, "day", nil, sorter.model:GetPivot().Position)
end

local function stepSorters(dt: number)
	local viewers = viewersNow()
	local ignore: { Instance } = {}
	for _, viewer in viewers do
		table.insert(ignore, viewer.character)
	end
	local now = os.clock()
	local night = DayNight.isNight()
	for model, sorter in sorters do
		if not model:IsDescendantOf(workspace) then
			sorters[model] = nil
			continue
		end
		local position = model:GetPivot().Position
		local target = nearestHunted(position, viewers)
		local wasMode = sorter.state.mode
		local action = SorterBrain.decide(Settings, sorter.state, {
			now = now,
			dt = dt,
			night = night,
			seen = seenBy(model, viewers),
			position = position,
			home = sorter.home.Position,
			target = target and target.position,
		}) :: any
		local own = table.clone(ignore)
		table.insert(own, model)
		if action.kind == "move" and target then
			if wasMode ~= "creep" then
				setPose(model, Settings.CreepPose)
			end
			moveTo(sorter, action.x, action.z, target.position, own)
		elseif action.kind == "catch" and target then
			catch(sorter, target)
		elseif action.kind == "home" then
			model:PivotTo(sorter.home)
			setPose(model, "stand")
		elseif action.kind == "stand" then
			local pivot = model:GetPivot()
			local floorY = floorAt(pivot.X, pivot.Z, pivot.Y, own) or pivot.Y
			model:PivotTo(CFrame.new(pivot.X, floorY + sorter.feet, pivot.Z) * sorter.home.Rotation)
			setLens(model, night)
			setPose(model, "stand")
		end
	end
end

-- Everyone in a display swaps pose now and then, real or not, but only while nobody is looking
local function stepPoses()
	local viewers = viewersNow()
	local chance = Settings.PoseChance[DayNight.phase()] or 0
	local positions = {}
	for _, viewer in viewers do
		table.insert(positions, viewer.position)
	end
	for _, member in members do
		local model = member.model
		local sorter = sorters[model]
		if sorter and sorter.state.mode ~= "still" then
			continue
		end
		if not model:IsDescendantOf(workspace) or random:NextNumber() >= chance then
			continue
		end
		local position = model:GetPivot().Position
		if
			not HauntLife.mannequinMayMove(
				position,
				viewers :: any,
				Settings.ViewHalfAngle,
				Settings.ViewRange,
				Settings.NearPlayer
			)
		then
			continue
		end
		local pose = HauntLife.nextPose(Settings.Poses, member.pose, random:NextNumber())
		if pose then
			member.pose = pose
			setPose(model, pose)
			playSound(model, Settings.Sounds.Snap)
		end
		local index = HauntSight.nearest(position, positions, Settings.NearPlayer)
		if index and random:NextNumber() < Settings.FaceTurn then
			local pivot = model:GetPivot()
			local offset = pivot:PointToObjectSpace(positions[index])
			model:PivotTo(pivot * CFrame.Angles(0, math.rad(HauntSight.yawTo(offset.X, offset.Z)), 0))
		end
	end
end

local function feetOf(model: Model): number
	local box, size = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
end

-- Each display gets its real one swapped into a random spot, so the layout never gives it away
local function adopt(folder: Instance)
	local models: { Model } = {}
	for _, child in folder:GetChildren() do
		local name = child:GetAttribute("ModelName")
		if child:IsA("Model") and (name == "sorter" or name == "sorter_decoy") then
			ModelRig.rig(child)
			table.insert(models, child)
		end
	end
	local points = {}
	for _, model in models do
		table.insert(points, model:GetPivot().Position)
	end
	for _, group in SorterBrain.groupNear(points, Settings.GroupRadius) do
		local real, decoys = nil, {}
		for _, index in group do
			local model = models[index]
			if model:GetAttribute("ModelName") == "sorter" then
				real = model
			else
				table.insert(decoys, model)
			end
		end
		if real and #decoys > 0 then
			local swap = decoys[random:NextInteger(1, #decoys)]
			local realAt, swapAt = real:GetPivot(), swap:GetPivot()
			real:PivotTo(swapAt)
			swap:PivotTo(realAt)
		end
	end
	for _, model in models do
		table.insert(members, { model = model })
		isMember[model] = true
		CollectionService:AddTag(model, "Sorter")
		if model:GetAttribute("ModelName") == "sorter" then
			sorters[model] = {
				model = model,
				home = model:GetPivot(),
				feet = feetOf(model),
				state = SorterBrain.new(),
			}
			setLens(model, DayNight.isNight())
		end
	end
end

-- The display model a part belongs to, real or decoy
function Sorters.fromPart(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not isMember[model] do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

-- A decoy just takes the bullet. The real one goes flat, says so, and pays out once a day.
function Sorters.shot(model: Model, shooter: Player?)
	local sorter = sorters[model]
	if not sorter or sorter.state.mode == "down" then
		return
	end
	SorterBrain.knockDown(sorter.state, os.clock(), Settings.DownSeconds)
	local pivot = model:GetPivot()
	model:PivotTo(pivot * CFrame.new(0, -sorter.feet + 0.5, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	setLens(model, false)
	playSound(model, Settings.Sounds.Down)
	local day = DayNight.day()
	if shooter and typeof(shooter) == "Instance" and sorter.rewardedDay ~= day then
		sorter.rewardedDay = day
		Tokens.add(shooter, Settings.KnockdownTokens)
	end
end

function Sorters.Init()
	caughtRemote = Net.event("RobotCaught")
	DayNight.onPhaseChanged(function(phase)
		for model, sorter in sorters do
			if sorter.state.mode ~= "down" then
				setLens(model, phase == "Night")
			end
		end
	end)
end

function Sorters.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Haunts")
		while not folder:GetAttribute("Built") do
			task.wait(1)
		end
		adopt(folder)
		local sinceTick, sincePose = 0, 0
		RunService.Heartbeat:Connect(function(dt)
			sinceTick += dt
			sincePose += dt
			if sinceTick >= Settings.Every then
				local step = sinceTick
				sinceTick = 0
				stepSorters(step)
			end
			if sincePose >= Settings.PoseEvery then
				sincePose = 0
				stepPoses()
			end
		end)
	end)
end

return Sorters
