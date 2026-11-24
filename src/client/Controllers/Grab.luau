-- Grab and build controls. Reads keyboard, mouse and gamepad directly, asks the server to
-- grab or drop, streams aim and rotation while carrying, and draws the ghost and axis arrow.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.Grab
local player = Players.LocalPlayer

local GHOST_OK = Color3.fromRGB(120, 220, 140)
local GHOST_BAD = Color3.fromRGB(230, 80, 70)
local AXIS_COLORS = {
	Turn = Color3.fromRGB(255, 210, 80),
	Tip = Color3.fromRGB(90, 200, 255),
	Roll = Color3.fromRGB(200, 120, 255),
}
local DPAD_AXES = {
	[Enum.KeyCode.DPadLeft] = "Turn",
	[Enum.KeyCode.DPadUp] = "Tip",
	[Enum.KeyCode.DPadRight] = "Roll",
}

local Grab = {}

local requestRemote: RemoteEvent
local dropRemote: RemoteEvent
local stateRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent
local ghostRemote: UnreliableRemoteEvent

local holding: PVInstance? = nil
local angles = { Tip = 0, Turn = 0, Roll = 0 }
local axis: GrabMath.Axis = "Turn"
local holdDistance = Settings.DefaultHoldDistance
local freeRotate = false
local rotateHeld: { [Enum.KeyCode]: number } = {}
local lastAim = 0

local ghost: BoxHandleAdornment
local arrow: ConeHandleAdornment

local function boxOf(prop: PVInstance): (CFrame, Vector3)
	if prop:IsA("BasePart") then
		return prop.CFrame, prop.Size
	end
	return (prop :: Model):GetBoundingBox()
end

local function grabbableFrom(instance: Instance?): PVInstance?
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, Settings.Tag) and instance:IsA("PVInstance") then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

local function tryGrab(input: InputObject)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return
	end

	local usesMouse = input.UserInputType == Enum.UserInputType.Keyboard
		and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
	local screenPoint = if usesMouse then UserInputService:GetMouseLocation() else camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local range = Settings.GrabReach + (camera.CFrame.Position - root.Position).Magnitude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * range, params)
	local prop = grabbableFrom(hit and hit.Instance)
	if prop then
		requestRemote:FireServer(prop)
	end
end

local function onToggle(_, inputState: Enum.UserInputState, input: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if holding then
		dropRemote:FireServer()
	else
		tryGrab(input)
	end
	return Enum.ContextActionResult.Sink
end

local function onRotate(_, inputState: Enum.UserInputState, input: InputObject)
	local direction = if input.KeyCode == Enum.KeyCode.ButtonL2 then -1 else 1
	if inputState == Enum.UserInputState.Begin then
		rotateHeld[input.KeyCode] = direction
		if not freeRotate then
			angles[axis] = GrabMath.stepAngle(angles[axis], direction, Settings.RotateStep)
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		rotateHeld[input.KeyCode] = nil
	end
	return Enum.ContextActionResult.Sink
end

local function onAxis(_, inputState: Enum.UserInputState, input: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.T then
		axis = GrabMath.nextAxis(axis)
	elseif input.KeyCode == Enum.KeyCode.DPadDown then
		angles.Tip, angles.Turn, angles.Roll = 0, 0, 0
	else
		axis = DPAD_AXES[input.KeyCode] or axis
	end
	return Enum.ContextActionResult.Sink
end

local function onFree(_, inputState: Enum.UserInputState)
	freeRotate = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

local function onDistance(_, inputState: Enum.UserInputState, input: InputObject)
	if inputState == Enum.UserInputState.Change then
		holdDistance = GrabMath.clampHoldDistance(
			holdDistance + math.sign(input.Position.Z) * Settings.WheelStep,
			Settings.MinHoldDistance,
			Settings.MaxHoldDistance
		)
	end
	return Enum.ContextActionResult.Sink
end

local function axisDirection(): Vector3
	local turn, tip = math.rad(angles.Turn), math.rad(angles.Tip)
	if axis == "Tip" then
		return CFrame.fromEulerAnglesYXZ(0, turn, 0).RightVector
	elseif axis == "Roll" then
		return CFrame.fromEulerAnglesYXZ(tip, turn, 0).LookVector
	end
	return Vector3.yAxis
end

local function bindCarryControls()
	ContextActionService:BindAction(
		"GrabRotate",
		onRotate,
		false,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:BindAction(
		"GrabAxis",
		onAxis,
		false,
		Enum.KeyCode.T,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.DPadDown
	)
	ContextActionService:BindAction("GrabFree", onFree, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.LeftAlt)
	ContextActionService:BindAction("GrabDistance", onDistance, false, Enum.UserInputType.MouseWheel)
end

local function unbindCarryControls()
	for _, name in { "GrabRotate", "GrabAxis", "GrabFree", "GrabDistance" } do
		ContextActionService:UnbindAction(name)
	end
	rotateHeld = {}
	freeRotate = false
end

local function onState(prop: PVInstance?)
	holding = prop
	if prop then
		local boxCFrame = boxOf(prop)
		local tip, turn, roll = boxCFrame:ToEulerAnglesYXZ()
		angles.Tip = GrabMath.wrapAngle(math.deg(tip))
		angles.Turn = GrabMath.wrapAngle(math.deg(turn))
		angles.Roll = GrabMath.wrapAngle(math.deg(roll))
		axis = "Turn"
		holdDistance = Settings.DefaultHoldDistance
		bindCarryControls()
		arrow.Visible = true
	else
		unbindCarryControls()
		ghost.Visible = false
		arrow.Visible = false
	end
end

local function onGhost(landed: CFrame?, size: Vector3, ok: boolean)
	if not holding or not landed then
		ghost.Visible = false
		return
	end
	ghost.CFrame = landed
	ghost.Size = size
	ghost.Color3 = if ok then GHOST_OK else GHOST_BAD
	ghost.Visible = true
end

local function onRender(dt: number)
	local prop = holding
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not prop or not camera or not head then
		return
	end

	if freeRotate then
		for _, direction in rotateHeld do
			angles[axis] = GrabMath.wrapAngle(angles[axis] + direction * Settings.FreeRotateSpeed * dt)
		end
	end

	local now = os.clock()
	if now - lastAim >= 1 / Settings.AimRate then
		lastAim = now
		local aim = head.Position + camera.CFrame.LookVector * holdDistance
		aimRemote:FireServer(aim, angles.Tip, angles.Turn, angles.Roll)
	end

	local boxCFrame, size = boxOf(prop)
	local direction = axisDirection()
	local base = boxCFrame.Position + direction * (size.Magnitude / 2 + 0.5)
	arrow.CFrame = CFrame.lookAt(base, base + direction)
	arrow.Color3 = AXIS_COLORS[axis]
end

local function makeAdornments()
	local gui = player:WaitForChild("PlayerGui")

	-- Adorned to Terrain so CFrame is plain world space.
	ghost = Instance.new("BoxHandleAdornment")
	ghost.Name = "GrabGhost"
	ghost.Adornee = workspace.Terrain
	ghost.Transparency = 0.6
	ghost.AlwaysOnTop = false
	ghost.Visible = false
	ghost.Parent = gui

	arrow = Instance.new("ConeHandleAdornment")
	arrow.Name = "GrabAxisArrow"
	arrow.Adornee = workspace.Terrain
	arrow.Radius = 0.5
	arrow.Height = 1.5
	arrow.AlwaysOnTop = true
	arrow.ZIndex = 1
	arrow.Visible = false
	arrow.Parent = gui
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Grab:Start()
	requestRemote = Net.event("GrabRequest")
	dropRemote = Net.event("GrabDrop")
	stateRemote = Net.event("GrabState")
	aimRemote = Net.unreliable("GrabAim")
	ghostRemote = Net.unreliable("GrabGhost")
	makeAdornments()

	stateRemote.OnClientEvent:Connect(onState)
	ghostRemote.OnClientEvent:Connect(onGhost)
	RunService.RenderStepped:Connect(onRender)
	ContextActionService:BindAction("GrabToggle", onToggle, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
end

return Grab
