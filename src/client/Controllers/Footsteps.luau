-- Footsteps for every body nearby: yours land on the head bob's dips, other players' and sim bots'
-- every half bob stride they walk. The sound is picked by the floor under the foot and the stance
-- (crouch nearly silent, sprint heavy), plays as a 3D sound on the body, and a thud plays on landing.
-- Roblox's own running and landing sounds are muted so these are the only steps you hear.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local FootstepsLogic = require(ReplicatedStorage.Shared.Logic.Footsteps)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Camera = require(script.Parent.Camera)
local Movement = require(script.Parent.Movement)

local settings = Config.Footsteps
local player = Players.LocalPlayer
local STRIDE = Config.Movement.BobStride / 2
local TELEPORT = 10 -- studs moved in one frame that count as a teleport, not walking

type Body = { root: BasePart, humanoid: Humanoid, lastPosition: Vector3, walked: number }

local Footsteps = {}

local random = Random.new()
local bodies: { [Model]: Body } = {}
local lastPhase = 0
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude

local function play(root: BasePart, name: string, volume: number, rollOff: { number }, group: Mix.Group)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = 1 + random:NextNumber(-settings.PitchJitter, settings.PitchJitter)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = rollOff[1]
	sound.RollOffMaxDistance = rollOff[2]
	sound.Parent = root
	Mix.route(sound, group)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function stanceOf(model: Model): string
	if model == player.Character then
		return Movement.getStance()
	end
	local stance = model:GetAttribute("Stance")
	return if type(stance) == "string" then stance else "Walk"
end

local function stepOn(model: Model, body: Body)
	floorParams.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(body.root.Position, Vector3.new(0, -settings.FloorProbe, 0), floorParams)
	if not hit then
		return
	end
	local floor = FootstepsLogic.floor(hit.Material.Name, settings.Floors)
	local step = FootstepsLogic.step(stanceOf(model), floor, settings)
	play(body.root, step.sound, step.volume, step.rollOff, "SFX")
end

local function muteDefault(child: Instance)
	if child:IsA("Sound") and table.find(settings.MutedDefaults, child.Name) then
		child.Volume = 0
	end
end

local function track(model: Model)
	if bodies[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	local body: Body = { root = root, humanoid = humanoid, lastPosition = root.Position, walked = 0 }
	bodies[model] = body
	for _, child in root:GetChildren() do
		muteDefault(child)
	end
	root.ChildAdded:Connect(muteDefault)
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			play(root, settings.Land.Sound, settings.Land.Volume, settings.Land.RollOff, "SFX")
		end
	end)
end

local function nearbyBodies(): { Model }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, bot in CollectionService:GetTagged(Config.SimPlayers.Tag) do
		if bot:IsA("Model") then
			table.insert(list, bot)
		end
	end
	return list
end

local function walkedOn(body: Body): boolean
	local state = body.humanoid:GetState()
	return body.humanoid.Health > 0
		and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Seated
		and not body.humanoid.PlatformStand
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local seen = {}
	for _, model in nearbyBodies() do
		seen[model] = true
		track(model)
	end
	for model, body in bodies do
		if not seen[model] or not body.root.Parent then
			bodies[model] = nil
			continue
		end
		if model == player.Character then
			local phase = Camera.bobPhase()
			if FootstepsLogic.footDown(lastPhase, phase) and walkedOn(body) then
				stepOn(model, body)
			end
			lastPhase = phase
			continue
		end
		local position = body.root.Position
		local offset = position - body.lastPosition
		body.lastPosition = position
		local moved = Vector2.new(offset.X, offset.Z).Magnitude
		local near = (position - camera.CFrame.Position).Magnitude <= settings.Range
		if moved > TELEPORT or not near or not walkedOn(body) then
			body.walked = 0
			continue
		end
		local down, walked = FootstepsLogic.advance(body.walked, moved, STRIDE)
		body.walked = walked
		if down then
			stepOn(model, body)
		end
	end
end

function Footsteps.Start()
	RunService.Heartbeat:Connect(update)
end

return Footsteps
