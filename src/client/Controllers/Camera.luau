-- Forced first person with head bob, sway into turns, crouch drop and sprint FOV.
-- Runs right after Roblox's camera each frame and offsets the CFrame it produced;
-- the default camera rebuilds its CFrame from scratch every frame, so offsets never pile up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Movement = require(script.Parent.Movement)

local settings = Config.Movement
local player = Players.LocalPlayer

local Camera = {}

local phase = 0
local bobAmount = 0
local sway = 0
local crouchBlend = 0
local lastYaw: number? = nil

local function yawOf(cframe: CFrame): number
	local look = cframe.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not humanoid or not root or dt <= 0 then
		return
	end

	local stance = Movement.getStance()
	local velocity = root.AssemblyLinearVelocity
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local groundSpeed = if onGround then Vector2.new(velocity.X, velocity.Z).Magnitude else 0

	bobAmount =
		MovementLogic.smooth(bobAmount, MovementLogic.bobAmount(settings, groundSpeed), settings.BobEase, dt)
	phase = MovementLogic.advancePhase(settings, phase, groundSpeed, dt)
	local side, up, roll = MovementLogic.bobOffset(settings, phase, bobAmount)

	local yaw = yawOf(camera.CFrame)
	local turnRate = if lastYaw then wrapAngle(yaw - lastYaw) / dt else 0
	lastYaw = yaw
	sway = MovementLogic.smooth(sway, MovementLogic.swayTarget(settings, turnRate), settings.SwayEase, dt)

	local crouchTarget = if stance == "Crouch" then 1 else 0
	crouchBlend = MovementLogic.smooth(crouchBlend, crouchTarget, settings.CrouchCameraEase, dt)
	humanoid.CameraOffset = Vector3.new(0, -settings.CrouchCameraDrop * crouchBlend, 0)

	local fovTarget = if stance == "Sprint" and groundSpeed > settings.WalkSpeed
		then settings.SprintFieldOfView
		else settings.FieldOfView
	camera.FieldOfView = MovementLogic.smooth(camera.FieldOfView, fovTarget, settings.FieldOfViewEase, dt)

	camera.CFrame *= CFrame.new(side, up, 0) * CFrame.Angles(0, 0, math.rad(roll + sway))
end

function Camera.Init()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	if Config.Game.HidePlayerList then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end
end

function Camera.Start()
	RunService:BindToRenderStep("FirstPersonFeel", Enum.RenderPriority.Camera.Value + 1, update)
end

return Camera
