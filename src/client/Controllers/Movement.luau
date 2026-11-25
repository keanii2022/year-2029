-- Sprint, crouch and eased walk speed for the local character.
-- Speed is applied locally for feel; the stance is mirrored to the server so later systems
-- (robot hearing, noise) read the server's copy, not the client's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clamp = require(ReplicatedStorage.Shared.Logic.Clamp)
local Config = require(ReplicatedStorage.Shared.Config)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Input)

local settings = Config.Movement
local player = Players.LocalPlayer

local Movement = {}

local crouched = false
local sprintHeld = false -- keyboard: hold Shift
local sprintToggled = false -- gamepad: click L3, turns off when you stop
local stance: MovementLogic.Stance = "Walk"
local sentStance: MovementLogic.Stance = "Walk"
local lastSentAt = 0
local currentSpeed = settings.WalkSpeed

function Movement.getStance(): MovementLogic.Stance
	return stance
end

local function onSprint(began: boolean, device: Input.Device)
	if device == "Gamepad" then
		if began then
			sprintToggled = not sprintToggled
		end
	else
		sprintHeld = began
	end
	if began then
		crouched = false
	end
end

local function onCrouch(began: boolean)
	if began then
		crouched = not crouched
		if crouched then
			sprintToggled = false
		end
	end
end

local function onJump(began: boolean)
	if began then
		crouched = false
	end
end

local function resetForNewCharacter()
	crouched = false
	sprintToggled = false
	stance = "Walk"
	currentSpeed = settings.WalkSpeed
end

function Movement.Init()
	Input.bind("Sprint", onSprint)
	Input.bind("Crouch", onCrouch)
	Input.bind("Jump", onJump)
	player.CharacterAdded:Connect(resetForNewCharacter)
end

function Movement.Start()
	local stanceRemote = Net.event("MovementStance")

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local moveAmount = humanoid.MoveDirection.Magnitude
		if sprintToggled and moveAmount < settings.SprintStopMove then
			sprintToggled = false
		end

		local canSprint = player:GetAttribute("Exhausted") ~= true
		stance = MovementLogic.stance((sprintHeld or sprintToggled) and canSprint, crouched, moveAmount)
		local target = MovementLogic.targetSpeed(settings, stance)
		currentSpeed = Clamp.approach(currentSpeed, target, settings.SpeedEase * dt)
		local carryMultiplier = player:GetAttribute("CarrySpeedMultiplier")
		humanoid.WalkSpeed = currentSpeed
			* (if type(carryMultiplier) == "number" then carryMultiplier else 1)
			* (tonumber(player:GetAttribute("AdminSpeed")) or 1)

		local now = os.clock()
		if stance ~= sentStance and now - lastSentAt >= settings.StanceMinInterval then
			sentStance = stance
			lastSentAt = now
			stanceRemote:FireServer(stance)
		end
	end)
end

return Movement
