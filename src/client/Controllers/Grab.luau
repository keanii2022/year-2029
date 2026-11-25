-- Grab and build controls. Grabbing works like shooting: with empty hands (the HANDS hotbar slot)
-- Fire grabs and, while carrying, drops; F on the keyboard empties your hands and does the same.
-- While carrying, Grab takes over the keys that move the prop: D-pad / arrows left and right spin it
-- flat, up and down tip it forward and back, and L2 or right mouse + left / right (or Z / X) roll
-- it sideways; R and T spin and tip one way. L1 / R1 / the wheel bring it closer or push it away.
-- Phone players get SPIN, TIP, ROLL, NEAR and FAR buttons. A tap steps; holding keeps turning,
-- faster the longer it's held, and snaps to the step when let go.
-- Asks the server to grab or drop, streams aim and rotation, and draws the placement ghost.
-- Someone else's placed piece needs the button held while a pry bar fills; the server times it too.
-- While carrying, a tap places the prop at the ghost; holding the button lets go right there with
-- physics, so nothing can leave you stuck holding it. The same bar fills for that hold.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local GrabPry = require(ReplicatedStorage.Shared.Logic.GrabPry)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.Grab
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local player = Players.LocalPlayer

local GHOST_OK = Color3.fromRGB(120, 220, 140)
local GHOST_BAD = Color3.fromRGB(230, 80, 70)
local HANDS_SLOT = "Hands"
-- Rotate keys: which axis and which way (1 = front right, top away, top right). Left / right
-- roll instead while L2 or the right mouse button is held.
type RotateKey = { axis: GrabMath.Axis, direction: number, rolls: boolean? }
local ROTATE_KEYS: { [Enum.KeyCode]: RotateKey } = {
	[Enum.KeyCode.DPadLeft] = { axis = "Turn", direction = -1, rolls = true },
	[Enum.KeyCode.DPadRight] = { axis = "Turn", direction = 1, rolls = true },
	[Enum.KeyCode.DPadUp] = { axis = "Tip", direction = 1 },
	[Enum.KeyCode.DPadDown] = { axis = "Tip", direction = -1 },
	[Enum.KeyCode.Left] = { axis = "Turn", direction = -1, rolls = true },
	[Enum.KeyCode.Right] = { axis = "Turn", direction = 1, rolls = true },
	[Enum.KeyCode.Up] = { axis = "Tip", direction = 1 },
	[Enum.KeyCode.Down] = { axis = "Tip", direction = -1 },
	[Enum.KeyCode.Z] = { axis = "Roll", direction = -1 },
	[Enum.KeyCode.X] = { axis = "Roll", direction = 1 },
	[Enum.KeyCode.R] = { axis = "Turn", direction = 1 },
	[Enum.KeyCode.T] = { axis = "Tip", direction = 1 },
}
-- Phone rotate buttons, by Input action
local TOUCH_ROTATE: { [string]: RotateKey } = {
	CarrySpinLeft = { axis = "Turn", direction = -1 },
	CarrySpinRight = { axis = "Turn", direction = 1 },
	CarryTipForward = { axis = "Tip", direction = 1 },
	CarryTipBack = { axis = "Tip", direction = -1 },
	CarryRollLeft = { axis = "Roll", direction = -1 },
	CarryRollRight = { axis = "Roll", direction = 1 },
}
-- Casts that hit something see-through or non-solid and untagged try again past it, this many times
local LOOK_THROUGH = 3
local DISTANCE_KEYS = {
	[Enum.KeyCode.ButtonR1] = 1,
	[Enum.KeyCode.ButtonL1] = -1,
}

local Grab = {}

local requestRemote: RemoteEvent
local dropRemote: RemoteEvent
local stateRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent
local ghostRemote: UnreliableRemoteEvent
local pryRemote: RemoteEvent

local holding: PVInstance? = nil
-- The carried prop's rotation, turned about world axes so every axis keeps working whatever the
-- prop's already been turned to (separate tip / turn / roll angles lock up once tipped 90 degrees).
local rotation = CFrame.identity
local holdDistance = Settings.DefaultHoldDistance
local rollModifier = false
-- Rotate / distance keys held right now, by key name: what they move, since when, and how many
-- degrees this hold has turned (for the snap on release)
type Held = { axis: GrabMath.Axis?, direction: number, since: number, turned: number }
local held: { [string]: Held } = {}
local lastAim = 0
local prying: { prop: PVInstance, startedAt: number }? = nil
-- When the grab button went down while carrying, until it's let up or the hold lets go
local dropPressedAt: number? = nil
local lastTarget: "grab" | "pry" | nil = nil

local ghost: BoxHandleAdornment
local pryBar: Frame
local pryFill: Frame

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

local function solid(part: BasePart): boolean
	return part.CanCollide and part.Transparency < 0.9
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Same reach the server checks: gap from the root to the prop's edge, free straight up a bit.
local function inReach(root: BasePart, prop: PVInstance): boolean
	local boxCFrame, size = boxOf(prop)
	local offset = boxCFrame.Position - root.Position
	local gap = GrabMath.reachGap(offset.X, offset.Y, offset.Z, Settings.GrabReachUp)
	return gap - size.Magnitude / 2 <= Settings.GrabReach
end

-- The grabbable the ray hits first, looking through see-through and non-solid parts.
local function grabbableHit(
	origin: Vector3,
	direction: Vector3,
	range: number,
	ignore: { Instance }
): PVInstance?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = table.clone(ignore)
	for _ = 1, LOOK_THROUGH do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, direction * range, params)
		if not hit then
			return nil
		end
		local prop = grabbableFrom(hit.Instance)
		if prop then
			return prop
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or solid(part) then
			return nil
		end
		table.insert(skip, part)
	end
	return nil
end

-- Nothing hit dead on: the grabbable nearest the ray inside the aim cone. Rack bays and other big
-- meshes have collision hulls that wrap the stock sitting on them, so the straight ray stops on
-- the rack; a prop still counts as seen when whatever's in front of it is right up against it.
local function grabbableNear(
	origin: Vector3,
	direction: Vector3,
	range: number,
	ignore: { Instance }
): PVInstance?
	local width = (Settings.AimConeRadius + 2) * 2
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.MaxParts = 200
	local along = CFrame.lookAt(origin + direction * range / 2, origin + direction * range)
	local best, bestScore = nil, math.huge
	local seen = {}
	for _, part in workspace:GetPartBoundsInBox(along, Vector3.new(width, width, range), params) do
		local prop = grabbableFrom(part)
		if not prop or seen[prop] then
			continue
		end
		seen[prop] = true
		local boxCFrame, size = boxOf(prop)
		local toCenter = boxCFrame.Position - origin
		local ahead = toCenter:Dot(direction)
		if ahead <= 0 then
			continue
		end
		local score = (toCenter - direction * ahead).Magnitude - math.min(size.X, size.Y, size.Z) / 2
		if score > Settings.AimConeRadius or score >= bestScore then
			continue
		end
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { prop, table.unpack(ignore) }
		local blocker = workspace:Raycast(origin, toCenter, rayParams)
		local slack = size.Magnitude / 2 + 1.5
		if blocker and blocker.Distance < toCenter.Magnitude - slack then
			continue
		end
		best, bestScore = prop, score
	end
	return best
end

-- The grabbable under the crosshair and in reach. Range counts from the camera, so it adds the
-- camera's distance to the root on top of the server's reach (measured from the root).
local function grabbableAlong(origin: Vector3, direction: Vector3): PVInstance?
	local camera = workspace.CurrentCamera
	local root = rootPart()
	if not camera or not root then
		return nil
	end
	local ignore: { Instance } = { player.Character :: Instance, camera }
	local range = Settings.GrabReach + Settings.GrabReachUp + (origin - root.Position).Magnitude
	local unit = direction.Unit
	local prop = grabbableHit(origin, unit, range, ignore)
	if prop and inReach(root, prop) then
		return prop
	end
	prop = grabbableNear(origin, unit, range, ignore)
	return if prop and inReach(root, prop) then prop else nil
end

local function needsPry(prop: PVInstance): boolean
	local placedBy = prop:GetAttribute("PlacedBy")
	return GrabPry.needsPry(if type(placedBy) == "number" then placedBy else nil, player.UserId)
end

local function handsEmpty(): boolean
	local slot = Hotbar.selected()
	return slot ~= nil and slot.id == HANDS_SLOT
end

local function stopPry(tellServer: boolean)
	if not prying then
		return
	end
	prying = nil
	pryBar.Visible = false
	if tellServer then
		pryRemote:FireServer(nil)
	end
end

local function tryGrab(device: Input.Device)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local usesMouse = device == "Keyboard" and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
	local screenPoint = if usesMouse then UserInputService:GetMouseLocation() else camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local prop = grabbableAlong(ray.Origin, ray.Direction)
	if not prop then
		return
	end
	if needsPry(prop) then
		prying = { prop = prop, startedAt = os.clock() }
		pryFill.Size = UDim2.fromScale(0, 1)
		pryBar.Visible = true
		pryRemote:FireServer(prop)
	else
		requestRemote:FireServer(prop)
	end
end

local function stopDropHold()
	dropPressedAt = nil
	if not prying then
		pryBar.Visible = false
	end
end

-- Fire with empty hands: grab, hold to pry; while carrying, tap to place or hold to let go
local function onToggle(began: boolean, device: Input.Device)
	if holding then
		if began then
			dropPressedAt = os.clock()
			pryFill.Size = UDim2.fromScale(0, 1)
		elseif dropPressedAt then
			stopDropHold()
			dropRemote:FireServer(false)
		end
	elseif not began then
		stopPry(true)
	else
		tryGrab(device)
	end
end

-- The F shortcut empties your hands first, so the rule stays "only empty hands carry"
local function onGrabKey(began: boolean, device: Input.Device)
	if began and not holding then
		Hotbar.select(HANDS_SLOT)
	end
	onToggle(began, device)
end

-- The world axis each rotate input turns about. Tip and roll follow the camera, squared to the
-- nearest wall, so "forward" is always away from you.
local function axisVector(turnAxis: GrabMath.Axis): Vector3
	if turnAxis == "Turn" then
		return -Vector3.yAxis
	end
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else -Vector3.zAxis
	local facing = CFrame.fromEulerAnglesYXZ(0, math.rad(GrabMath.quarterYaw(look.X, look.Z)), 0)
	return if turnAxis == "Tip" then -facing.RightVector else facing.LookVector
end

local function turnBy(turnAxis: GrabMath.Axis, degrees: number)
	rotation = (CFrame.fromAxisAngle(axisVector(turnAxis), math.rad(degrees)) * rotation):Orthonormalize()
end

local function startHold(key: string, turnAxis: GrabMath.Axis?, direction: number)
	local step = if turnAxis then direction * Settings.RotateStep else 0
	held[key] = { axis = turnAxis, direction = direction, since = os.clock(), turned = step }
	if turnAxis then
		turnBy(turnAxis, step)
	else
		holdDistance = GrabMath.clampHoldDistance(
			holdDistance + direction * Settings.WheelStep,
			Settings.MinHoldDistance,
			Settings.MaxHoldDistance
		)
	end
end

local function endHold(key: string)
	local hold = held[key]
	held[key] = nil
	if hold and hold.axis then
		turnBy(hold.axis, GrabMath.snapTurn(hold.turned, Settings.RotateStep))
	end
end

local function onRotate(_, inputState: Enum.UserInputState, input: InputObject)
	local key = ROTATE_KEYS[input.KeyCode]
	if inputState == Enum.UserInputState.Begin and key then
		startHold(input.KeyCode.Name, if key.rolls and rollModifier then "Roll" else key.axis, key.direction)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		endHold(input.KeyCode.Name)
	end
	return Enum.ContextActionResult.Sink
end

local function onDistance(_, inputState: Enum.UserInputState, input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if inputState == Enum.UserInputState.Change then
			startHold("Wheel", nil, math.sign(input.Position.Z))
			held.Wheel = nil
		end
	elseif inputState == Enum.UserInputState.Begin then
		startHold(input.KeyCode.Name, nil, DISTANCE_KEYS[input.KeyCode] or 0)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		held[input.KeyCode.Name] = nil
	end
	return Enum.ContextActionResult.Sink
end

local function onRollModifier(_, inputState: Enum.UserInputState)
	rollModifier = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	return Enum.ContextActionResult.Sink
end

-- Phone carry buttons come in through Input actions
local function touchHold(key: string, turnAxis: GrabMath.Axis?, direction: number)
	return function(began: boolean)
		if not holding then
			return
		end
		if began then
			startHold(key, turnAxis, direction)
		else
			endHold(key)
		end
	end
end

-- High priority so the arrow keys move the prop instead of the character and camera. The phone's
-- carry buttons are TouchButtons, not CAS's grey defaults.
local function bindCarryControls()
	local high = Enum.ContextActionPriority.High.Value
	local rotateKeys = {}
	for key in ROTATE_KEYS do
		table.insert(rotateKeys, key)
	end
	ContextActionService:BindActionAtPriority("GrabRotate", onRotate, false, high, table.unpack(rotateKeys))
	ContextActionService:BindActionAtPriority(
		"GrabDistance",
		onDistance,
		false,
		high,
		Enum.UserInputType.MouseWheel,
		Enum.KeyCode.ButtonR1,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindActionAtPriority(
		"GrabRoll",
		onRollModifier,
		false,
		high,
		Enum.KeyCode.ButtonL2,
		Enum.UserInputType.MouseButton2
	)
end

local function unbindCarryControls()
	for _, name in { "GrabRotate", "GrabDistance", "GrabRoll" } do
		ContextActionService:UnbindAction(name)
	end
	held = {}
	rollModifier = false
end

local function onState(prop: PVInstance?)
	holding = prop
	stopPry(false)
	stopDropHold()
	if prop then
		rotation = boxOf(prop).Rotation
		holdDistance = Settings.DefaultHoldDistance
		bindCarryControls()
		Hints.set("grabTarget", nil)
		Hints.set("carry", Config.Hints.CarryHint, 2)
	else
		unbindCarryControls()
		ghost.Visible = false
		Hints.set("carry", nil)
		Hints.set("placeRefused", nil)
	end
end

-- reason: short words for why it can't go down here, only sent with a red ghost
local function onGhost(landed: CFrame?, size: Vector3, ok: boolean, reason: string?)
	local refused = if holding and not ok and reason then `{reason}   Hold \{Fire\} Let go` else nil
	Hints.set("placeRefused", refused, 2, "warn")
	if not holding or not landed then
		ghost.Visible = false
		return
	end
	ghost.CFrame = landed
	ghost.Size = size
	ghost.Color3 = if ok then GHOST_OK else GHOST_BAD
	ghost.Visible = true
end

-- "Grab" under the crosshair when something grabbable is in reach, checked a few times a second.
-- With something else in hand it says how to empty them instead.
local lastLook = 0
local function lookForGrabbable(camera: Camera?, head: BasePart?)
	local now = os.clock()
	if now - lastLook < 0.2 then
		return
	end
	lastLook = now
	if not camera or not head then
		lastTarget = nil
		Hints.set("grabTarget", nil)
		return
	end
	local target = grabbableAlong(camera.CFrame.Position, camera.CFrame.LookVector)
	local pry = target ~= nil and needsPry(target)
	lastTarget = if not target then nil elseif pry then "pry" else "grab"
	local hints = Config.Hints
	local empty = handsEmpty()
	local text = if not target
		then nil
		elseif pry then (if empty then hints.PryHint else hints.PryNeedsHands)
		elseif empty then hints.GrabTargetHint
		else hints.GrabNeedsHands
	if text and Hints.nudge("grab", hints.GrabNudge) then
		text = nil
	end
	Hints.set("grabTarget", text, 3)
end

-- What's in reach for the phone's big button: "grab", "pry" or nil
function Grab.target(): "grab" | "pry" | nil
	return lastTarget
end

function Grab.carrying(): boolean
	return holding ~= nil
end

local function stepPry()
	local pry = prying
	if not pry then
		return
	end
	local progress = GrabPry.progress(os.clock() - pry.startedAt, Settings.PrySeconds)
	pryFill.Size = UDim2.fromScale(progress, 1)
	if progress >= 1 then
		stopPry(false)
		requestRemote:FireServer(pry.prop)
	end
end

local function onRender(dt: number)
	local prop = holding
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not prop then
		lookForGrabbable(camera, head)
		stepPry()
		return
	end
	if not camera or not head then
		return
	end

	local now = os.clock()
	if dropPressedAt then
		local progress = math.clamp((now - dropPressedAt) / Settings.HoldToLetGo, 0, 1)
		pryFill.Size = UDim2.fromScale(progress, 1)
		pryBar.Visible = progress > 0.15
		if progress >= 1 then
			stopDropHold()
			dropRemote:FireServer(true)
		end
	end
	for _, hold in held do
		local heldFor = now - hold.since
		if heldFor < Settings.RepeatDelay then
			continue
		end
		if hold.axis then
			local speed = GrabMath.rotateSpeed(
				heldFor,
				Settings.RepeatDelay,
				Settings.RotateStartSpeed,
				Settings.RotateMaxSpeed,
				Settings.RotateRampSeconds
			)
			local degrees = hold.direction * speed * dt
			turnBy(hold.axis, degrees)
			hold.turned += degrees
		else
			holdDistance = GrabMath.clampHoldDistance(
				holdDistance + hold.direction * Settings.HoldDistanceSpeed * dt,
				Settings.MinHoldDistance,
				Settings.MaxHoldDistance
			)
		end
	end

	if now - lastAim >= 1 / Settings.AimRate then
		lastAim = now
		local aim = head.Position + camera.CFrame.LookVector * holdDistance
		local tip, turn, roll = rotation:ToEulerAnglesYXZ()
		aimRemote:FireServer(aim, math.deg(tip), math.deg(turn), math.deg(roll))
	end
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

	local screen = Instance.new("ScreenGui")
	screen.Name = "GrabPry"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.Parent = gui

	-- Sits just under the crosshair, above the hint lines.
	pryBar = Instance.new("Frame")
	pryBar.AnchorPoint = Vector2.new(0.5, 0.5)
	pryBar.Position = UDim2.new(0.5, 0, 0.5, 26)
	pryBar.Size = UDim2.fromOffset(120, 6)
	pryBar.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	pryBar.BackgroundTransparency = 0.3
	pryBar.BorderSizePixel = 0
	pryBar.Visible = false
	pryBar.Parent = screen

	pryFill = Instance.new("Frame")
	pryFill.Size = UDim2.fromScale(0, 1)
	pryFill.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	pryFill.BorderSizePixel = 0
	pryFill.Parent = pryBar
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Grab:Start()
	requestRemote = Net.event("GrabRequest")
	dropRemote = Net.event("GrabDrop")
	stateRemote = Net.event("GrabState")
	aimRemote = Net.unreliable("GrabAim")
	ghostRemote = Net.unreliable("GrabGhost")
	pryRemote = Net.event("GrabPry")
	makeAdornments()

	stateRemote.OnClientEvent:Connect(onState)
	ghostRemote.OnClientEvent:Connect(onGhost)
	pryRemote.OnClientEvent:Connect(function()
		stopPry(false)
	end)
	RunService.RenderStepped:Connect(onRender)
	Input.bind("Grab", onGrabKey)
	Hotbar.onUse("Grab", onToggle)
	for action, rotate in TOUCH_ROTATE do
		Input.bind(action, touchHold(action, rotate.axis, rotate.direction))
	end
	Input.bind("CarryCloser", touchHold("CarryCloser", nil, -1))
	Input.bind("CarryFarther", touchHold("CarryFarther", nil, 1))
end

return Grab
