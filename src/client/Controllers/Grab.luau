-- Grab and build controls. Grabbing works like shooting: with empty hands (the HANDS hotbar slot)
-- Fire grabs and, while carrying, places; F on the keyboard empties your hands and grabs, and
-- while carrying drops the prop where it's held.
-- While carrying, your own screen hides the real prop and shows a see-through copy of it (the
-- ghost) where it will go: sitting on the floor or top under the crosshair, backed flush against a
-- wall, or at the held distance when the crosshair is on nothing. It snaps flush to placed pieces
-- close by, then to the grid, and a blocked spot is nudged out along the blocking face. All of it
-- runs here every frame with Shared/GrabFit, the same check the server runs on place, so a green
-- ghost always places. The server moves the real prop for everyone else from our hold reports.
-- Spin and tip are 90 degree taps (R / T, D-pad, SPIN / TIP); holding the fine modifier (Shift,
-- L2) makes them 15 and turns snapping off. A held SPIN on a phone steps 15 at a time.
-- L1 / R1, the wheel, and NEAR / FAR set the held distance.
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
local GrabFit = require(ReplicatedStorage.Shared.GrabFit)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local GrabPlace = require(ReplicatedStorage.Shared.Logic.GrabPlace)
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
-- Landing casts use a slightly smaller box so props slide down flush against walls and each other.
local CAST_SHRINK = 0.98
-- Rotate keys: which axis and which way (1 = front right, top away)
type RotateKey = { axis: GrabMath.Axis, direction: number }
local ROTATE_KEYS: { [Enum.KeyCode]: RotateKey } = {
	[Enum.KeyCode.DPadLeft] = { axis = "Turn", direction = -1 },
	[Enum.KeyCode.DPadRight] = { axis = "Turn", direction = 1 },
	[Enum.KeyCode.DPadUp] = { axis = "Tip", direction = 1 },
	[Enum.KeyCode.DPadDown] = { axis = "Tip", direction = -1 },
	[Enum.KeyCode.R] = { axis = "Turn", direction = 1 },
	[Enum.KeyCode.T] = { axis = "Tip", direction = 1 },
}
-- Casts that hit something see-through or non-solid and untagged try again past it, this many times
local LOOK_THROUGH = 3
local DISTANCE_KEYS = {
	[Enum.KeyCode.ButtonR1] = 1,
	[Enum.KeyCode.ButtonL1] = -1,
}
-- Ghost copies keep only their looks
local GHOST_STRIP = {
	"LuaSourceContainer",
	"Sound",
	"ParticleEmitter",
	"Light",
	"ProximityPrompt",
	"ClickDetector",
	"BillboardGui",
	"Beam",
	"Trail",
	"Fire",
	"Smoke",
	"Sparkles",
	"Constraint",
	"JointInstance",
}

type Spot = { box: CFrame, ok: boolean, reason: string? }
type Edge = { from: Vector3, to: Vector3 }

local Grab = {}

local requestRemote: RemoteEvent
local dropRemote: RemoteEvent
local stateRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent
local pryRemote: RemoteEvent

local holding: PVInstance? = nil
local holdSize = Vector3.one
-- The prop's pivot relative to its bounding box, to turn a ghost box back into a pivot
local pivotOffset = CFrame.identity
-- The carried prop's rotation, turned about world axes so every axis keeps working whatever the
-- prop's already been turned to (separate tip / turn angles lock up once tipped 90 degrees).
local rotation = CFrame.identity
local holdDistance = Settings.DefaultHoldDistance
local fineHeld = false
-- Closer / farther keys held right now, by key name
local held: { [string]: { direction: number, since: number } } = {}
-- The phone's SPIN while held: since when and how many fine steps it has turned
local spinHold: { since: number, steps: number }? = nil
local spot: Spot? = nil
local lastAim = 0
local prying: { prop: PVInstance, startedAt: number, duration: number }? = nil
-- When the grab button went down while carrying, until it's let up or the hold lets go
local dropPressedAt: number? = nil
local lastTarget: "grab" | "pry" | nil = nil

local ghost: PVInstance? = nil
local ghostHighlight: Highlight? = nil
local edgeLine: BoxHandleAdornment
local pryBar: Frame
local pryFill: Frame

local boxOf = GrabFit.boxOf

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
		-- PrySeconds until the server says this piece is fortified and takes longer
		prying = { prop = prop, startedAt = os.clock(), duration = Settings.PrySeconds }
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

-- Where the placer looks from: the camera, or the head when the camera is pulled far back. The
-- server uses the same rule.
local function eyeOf(camera: Camera, head: BasePart): Vector3
	local eye = camera.CFrame.Position
	return if (eye - head.Position).Magnitude <= Settings.CameraSlack then eye else head.Position
end

local function place()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if spot and camera and head then
		dropRemote:FireServer(false, spot.box, eyeOf(camera, head))
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
			place()
		end
	elseif not began then
		stopPry(true)
	else
		tryGrab(device)
	end
end

-- The F shortcut empties your hands first, so the rule stays "only empty hands carry". While
-- carrying it drops the prop right where it's held.
local function onGrabKey(began: boolean, device: Input.Device)
	if holding then
		if began then
			stopDropHold()
			dropRemote:FireServer(true)
		end
		return
	end
	if began then
		Hotbar.select(HANDS_SLOT)
	end
	onToggle(began, device)
end

-- Shift on the keyboard or L2 on a pad: 15 degree steps and no snapping
local function fine(): boolean
	return fineHeld
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- The world axis each rotate input turns about. Tip follows the camera, squared to the nearest
-- wall, so "forward" is always away from you.
local function axisVector(turnAxis: GrabMath.Axis): Vector3
	if turnAxis == "Turn" then
		return -Vector3.yAxis
	end
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else -Vector3.zAxis
	local facing = CFrame.fromEulerAnglesYXZ(0, math.rad(GrabMath.quarterYaw(look.X, look.Z)), 0)
	return -facing.RightVector
end

local function turnBy(turnAxis: GrabMath.Axis, degrees: number)
	rotation = (CFrame.fromAxisAngle(axisVector(turnAxis), math.rad(degrees)) * rotation):Orthonormalize()
end

local function nudgeDistance(direction: number)
	holdDistance = GrabMath.clampHoldDistance(
		holdDistance + direction * Settings.WheelStep,
		Settings.MinHoldDistance,
		Settings.MaxHoldDistance
	)
end

local function onRotate(_, inputState: Enum.UserInputState, input: InputObject)
	local key = ROTATE_KEYS[input.KeyCode]
	if inputState == Enum.UserInputState.Begin and key then
		turnBy(key.axis, key.direction * (if fine() then Settings.FineRotateStep else Settings.RotateStep))
	end
	return Enum.ContextActionResult.Sink
end

local function onDistance(_, inputState: Enum.UserInputState, input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if inputState == Enum.UserInputState.Change then
			nudgeDistance(math.sign(input.Position.Z))
		end
	elseif inputState == Enum.UserInputState.Begin then
		local direction = DISTANCE_KEYS[input.KeyCode] or 0
		nudgeDistance(direction)
		held[input.KeyCode.Name] = { direction = direction, since = os.clock() }
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		held[input.KeyCode.Name] = nil
	end
	return Enum.ContextActionResult.Sink
end

local function onFine(_, inputState: Enum.UserInputState)
	fineHeld = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	return Enum.ContextActionResult.Sink
end

-- Phone SPIN: a tap turns RotateStep when let go; held, it steps FineRotateStep instead
local function onTouchSpin(began: boolean)
	if not holding then
		return
	end
	if began then
		spinHold = { since = os.clock(), steps = 0 }
	elseif spinHold then
		if spinHold.steps == 0 then
			turnBy("Turn", Settings.RotateStep)
		end
		spinHold = nil
	end
end

local function onTouchTip(began: boolean)
	if holding and began then
		turnBy("Tip", Settings.RotateStep)
	end
end

local function touchDistance(key: string, direction: number)
	return function(began: boolean)
		if not holding then
			return
		end
		if began then
			nudgeDistance(direction)
			held[key] = { direction = direction, since = os.clock() }
		else
			held[key] = nil
		end
	end
end

-- High priority so the D-pad and shoulders move the prop instead of their usual jobs. The phone's
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
	ContextActionService:BindActionAtPriority("GrabFine", onFine, false, high, Enum.KeyCode.ButtonL2)
end

local function unbindCarryControls()
	for _, name in { "GrabRotate", "GrabDistance", "GrabFine" } do
		ContextActionService:UnbindAction(name)
	end
	held = {}
	fineHeld = false
	spinHold = nil
end

-- Your own screen only: the carried prop disappears and the ghost stands in for it.
local function hideProp(prop: PVInstance, hidden: boolean)
	local value = if hidden then 1 else 0
	if prop:IsA("BasePart") then
		prop.LocalTransparencyModifier = value
	end
	for _, descendant in prop:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

local function stripped(instance: Instance): boolean
	for _, className in GHOST_STRIP do
		if instance:IsA(className) then
			return true
		end
	end
	return instance.Name == "FortBlocker"
end

-- A see-through copy of the real model, tinted green or red by a Highlight. Untagged and without
-- attributes so nothing on this client mistakes it for the prop. A plain box when it won't copy.
local function makeGhost(prop: PVInstance, camera: Camera): PVInstance
	local archivable = prop.Archivable
	prop.Archivable = true
	local copy: PVInstance? = prop:Clone()
	prop.Archivable = archivable
	if not copy then
		local box = Instance.new("Part")
		box.Size = holdSize
		copy = box
	end
	local model = copy :: PVInstance
	local all = model:GetDescendants()
	table.insert(all, model)
	for _, instance in all do
		for _, tag in CollectionService:GetTags(instance) do
			CollectionService:RemoveTag(instance, tag)
		end
		for name in instance:GetAttributes() do
			instance:SetAttribute(name, nil)
		end
		if instance ~= model and stripped(instance) then
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanQuery = false
			instance.CanTouch = false
			instance.CastShadow = false
			instance.LocalTransparencyModifier = 0
			if instance.Transparency < 1 then
				instance.Transparency = math.max(instance.Transparency, Settings.GhostTransparency)
			end
		elseif instance:IsA("Decal") then
			instance.LocalTransparencyModifier = 0
			instance.Transparency = math.max(instance.Transparency, Settings.GhostTransparency)
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.4
	highlight.Adornee = model
	highlight.Parent = model
	ghostHighlight = highlight
	model.Parent = camera
	return model
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostHighlight, spot = nil, nil, nil
	edgeLine.Visible = false
end

-- The first solid thing under the crosshair, looking through see-through and non-solid parts.
local function aimHit(origin: Vector3, direction: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = table.clone(ignore)
	for _ = 1, LOOK_THROUGH do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, direction.Unit * Settings.PlaceReach, params)
		if not hit or not hit.Instance:IsA("BasePart") or solid(hit.Instance :: BasePart) then
			return hit
		end
		table.insert(skip, hit.Instance)
	end
	return nil
end

-- Drops a box onto whatever is under it. A box partly inside the floor (aimed low at a wall)
-- can't see that floor from inside, so it's tried again from a box-height above.
local function land(box: CFrame, ignore: { Instance }): CFrame?
	local halfHeight = GrabFit.reach(box.Rotation, holdSize, Vector3.yAxis)
	for _, lift in { 0, 2 * halfHeight + 0.5 } do
		local start = box + Vector3.new(0, lift, 0)
		local hit = GrabFit.castDown(start, holdSize * CAST_SHRINK, ignore)
		if hit then
			local y = GrabMath.landingY(start.Y, hit.Distance, halfHeight, CAST_SHRINK)
			return CFrame.new(box.X, y, box.Z) * box.Rotation
		end
	end
	return nil
end

-- A frame on the neighbour's centre with its X and Z along the neighbour's flat sides.
local function flatFrame(box: CFrame): CFrame
	local side = box.RightVector
	if math.abs(side.Y) > 0.7 then
		side = box.LookVector
	end
	local flat = Vector3.new(side.X, 0, side.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(box.Position)
	end
	return CFrame.fromMatrix(box.Position, flat.Unit, Vector3.yAxis)
end

-- Flush against the closest placed piece beside the box that faces the same way, with the shared
-- edge for the white line. Returns the box unchanged and no edge when nothing's close enough.
local function snapToNeighbours(box: CFrame, ignore: { Instance }): (CFrame, Edge?)
	local rotationOnly = box.Rotation
	local halfHeight = GrabFit.reach(rotationOnly, holdSize, Vector3.yAxis)
	local around = Vector3.new(
		GrabFit.reach(rotationOnly, holdSize, Vector3.xAxis),
		halfHeight,
		GrabFit.reach(rotationOnly, holdSize, Vector3.zAxis)
	) * 2 + Vector3.one * 2 * Settings.SnapReach
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local axes = { box.RightVector, box.UpVector, box.LookVector }
	local best: GrabPlace.Snap? = nil
	local bestFrame, bestAt, bestHalves = CFrame.identity, Vector3.zero, Vector3.zero
	local seen = {}
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(box.Position), around, params) do
		local other = grabbableFrom(part)
		if not other or seen[other] or other == holding then
			continue
		end
		seen[other] = true
		if other:GetAttribute("PlacedBy") == nil or other:GetAttribute("CarriedBy") ~= nil then
			continue
		end
		local otherBox, otherSize = boxOf(other)
		local otherAxes = { otherBox.RightVector, otherBox.UpVector, otherBox.LookVector }
		if not GrabPlace.squareTo(axes, otherAxes, Settings.SnapAngle) then
			continue
		end
		local otherHalfHeight = GrabFit.reach(otherBox.Rotation, otherSize, Vector3.yAxis)
		-- only pieces beside it: one it sits on or under is for the grid
		if math.abs(box.Y - otherBox.Y) >= halfHeight + otherHalfHeight then
			continue
		end
		local frame = flatFrame(otherBox)
		local at = frame:PointToObjectSpace(box.Position)
		local halves = Vector3.new(
			GrabFit.reach(otherBox.Rotation, otherSize, frame.XVector),
			otherHalfHeight,
			GrabFit.reach(otherBox.Rotation, otherSize, frame.ZVector)
		)
		local snap = GrabPlace.snapFlush(
			at.X,
			at.Z,
			GrabFit.reach(rotationOnly, holdSize, frame.XVector),
			GrabFit.reach(rotationOnly, holdSize, frame.ZVector),
			halves.X,
			halves.Z,
			Settings.SnapRange
		)
		if snap and (not best or snap.gap < best.gap) then
			best, bestFrame, bestAt, bestHalves = snap, frame, at, halves
		end
	end
	if not best then
		return box, nil
	end
	local position = bestFrame:PointToWorldSpace(Vector3.new(best.x, bestAt.Y, best.z))
	-- along the shared face, level with the lower of the two tops
	local top = math.min(bestAt.Y + halfHeight, bestHalves.Y)
	local from, to
	if best.axis == "x" then
		local face = best.side * bestHalves.X
		from, to = Vector3.new(face, top, best.from), Vector3.new(face, top, best.to)
	else
		local face = best.side * bestHalves.Z
		from, to = Vector3.new(best.from, top, face), Vector3.new(best.to, top, face)
	end
	local edge = { from = bestFrame:PointToWorldSpace(from), to = bestFrame:PointToWorldSpace(to) }
	return CFrame.new(position) * rotationOnly, edge
end

-- Grid snap on x and z, except across the face of a wall it's backed against
local function toGrid(box: CFrame, wallNormal: Vector3?): CFrame
	local x, z = box.X, box.Z
	if not (wallNormal and math.abs(wallNormal.X) > 0.7) then
		x = GrabMath.snapToGrid(x, Settings.GridSize)
	end
	if not (wallNormal and math.abs(wallNormal.Z) > 0.7) then
		z = GrabMath.snapToGrid(z, Settings.GridSize)
	end
	return CFrame.new(x, box.Y, z) * box.Rotation
end

-- Out of the blocking part's nearest face, in world space
local function pushDirection(box: CFrame, blocker: BasePart): Vector3
	local at = blocker.CFrame:PointToObjectSpace(box.Position)
	local half = blocker.Size / 2
	local x, y, z = GrabPlace.faceNormal(at.X, at.Y, at.Z, half.X, half.Y, half.Z)
	return blocker.CFrame:VectorToWorldSpace(Vector3.new(x, y, z))
end

-- Where the carried prop goes right now, whether it may, and the snapped edge if any
local function solve(camera: Camera, head: BasePart, root: BasePart, humanoid: Humanoid): (Spot, Edge?)
	local prop = holding :: PVInstance
	local ignore: { Instance } = GrabFit.characters()
	table.insert(ignore, prop)
	table.insert(ignore, camera)
	local screen = camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local hit = aimHit(ray.Origin, ray.Direction, ignore)
	-- aimed past arm's reach: hold it out in front instead of showing a red ghost far away
	if hit and (hit.Position - root.Position).Magnitude > Settings.PlaceReach - 1 then
		hit = nil
	end
	local kind = if hit then GrabPlace.faceKind(hit.Normal.Y) else nil
	local box
	local wallNormal: Vector3? = nil
	if hit and kind ~= "under" then
		local x, y, z =
			GrabPlace.onFace(hit.Position, hit.Normal, GrabFit.reach(rotation, holdSize, hit.Normal))
		box = CFrame.new(x, y, z) * rotation
		wallNormal = if kind == "wall" then hit.Normal else nil
	else
		box = CFrame.new(head.Position + camera.CFrame.LookVector * holdDistance) * rotation
	end
	local sitting = kind == "top"
	local function settle(at: CFrame): CFrame?
		return if sitting then at else land(at, ignore)
	end

	local landed = settle(box)
	if not landed then
		return { box = box, ok = false, reason = "no ground" }, nil
	end
	box = landed
	local edge: Edge? = nil
	if not fine() then
		local snapped
		snapped, edge = snapToNeighbours(box, ignore)
		if not edge then
			snapped = toGrid(box, wallNormal)
		end
		-- always land again: a grid step off the edge of a top would otherwise leave it floating
		box = land(snapped, ignore) or box
	end

	local eye = eyeOf(camera, head)
	local function check(at: CFrame, carrierBlocks: boolean): (boolean, string?, BasePart?)
		return GrabFit.check({
			prop = prop,
			size = holdSize,
			box = at,
			carrier = player,
			root = root,
			humanoid = humanoid,
			eye = eye,
			tolerance = Settings.PlaceTolerance,
			carrierBlocks = carrierBlocks,
			groundFound = true,
		})
	end
	local ok, reason, blocker = check(box, true)
	if ok then
		return { box = box, ok = true }, edge
	end
	if blocker then
		local out = pushDirection(box, blocker)
		for _, distance in GrabPlace.pushSteps(Settings.PushMax, Settings.PushStep) do
			local moved = box + out * distance
			if check(moved, true) then
				return { box = moved, ok = true }, nil
			end
		end
	end
	-- Still blocked: the nearest free spot a little back toward you or to the side, landed again
	local toward = Vector3.new(root.Position.X - box.X, 0, root.Position.Z - box.Z)
	if toward.Magnitude > 0.1 then
		toward = toward.Unit
		local side = Vector3.new(-toward.Z, 0, toward.X)
		for _, offset in
			GrabPlace.searchOffsets(Settings.SearchBack, Settings.SearchSide, Settings.SearchStep)
		do
			local moved = land(box + toward * offset[1] + side * offset[2], ignore)
			if moved and check(moved, true) then
				return { box = moved, ok = true }, nil
			end
		end
	end
	-- nothing clear of the carrier: clipping your own body is fine, the prop shoves you aside
	ok, reason = check(box, false)
	return { box = box, ok = ok, reason = reason }, if ok then edge else nil
end

local function showEdge(edge: Edge?)
	if not edge then
		edgeLine.Visible = false
		return
	end
	local length = (edge.to - edge.from).Magnitude
	if length < 0.05 then
		edgeLine.Visible = false
		return
	end
	edgeLine.Size = Vector3.new(0.06, 0.06, length)
	edgeLine.CFrame = CFrame.lookAt((edge.from + edge.to) / 2, edge.to)
	edgeLine.Visible = true
end

local function onState(prop: PVInstance?)
	if holding and holding ~= prop then
		hideProp(holding, false)
	end
	clearGhost()
	holding = prop
	stopPry(false)
	stopDropHold()
	local camera = workspace.CurrentCamera
	if prop and camera then
		local box, size = boxOf(prop)
		holdSize = size
		pivotOffset = box:ToObjectSpace(prop:GetPivot())
		-- stood upright and squared to the nearest quarter turn
		local look = if math.abs(box.LookVector.Y) > 0.7 then box.UpVector else box.LookVector
		rotation = CFrame.fromEulerAnglesYXZ(0, math.rad(GrabMath.quarterYaw(look.X, look.Z)), 0)
		holdDistance = Settings.DefaultHoldDistance
		hideProp(prop, true)
		ghost = makeGhost(prop, camera)
		bindCarryControls()
		Hints.set("grabTarget", nil)
		Hints.set("carry", Config.Hints.CarryHint, 2)
	else
		unbindCarryControls()
		Hints.set("carry", nil)
		Hints.set("placeRefused", nil)
	end
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
	local progress = GrabPry.progress(os.clock() - pry.startedAt, pry.duration)
	pryFill.Size = UDim2.fromScale(progress, 1)
	if progress >= 1 then
		stopPry(false)
		requestRemote:FireServer(pry.prop)
	end
end

local function stepHolds(now: number, dt: number)
	for _, hold in held do
		if now - hold.since >= Settings.RepeatDelay then
			holdDistance = GrabMath.clampHoldDistance(
				holdDistance + hold.direction * Settings.HoldDistanceSpeed * dt,
				Settings.MinHoldDistance,
				Settings.MaxHoldDistance
			)
		end
	end
	local spin = spinHold
	if spin then
		local due = math.floor((now - spin.since) / Settings.TouchSpinRepeat)
		while spin.steps < due do
			spin.steps += 1
			turnBy("Turn", Settings.FineRotateStep)
		end
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
	local root = rootPart()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not head or not root or not humanoid then
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
	stepHolds(now, dt)

	local found, edge = solve(camera, head, root, humanoid)
	spot = found
	if ghost then
		ghost:PivotTo(found.box * pivotOffset)
	end
	if ghostHighlight then
		local color = if found.ok then GHOST_OK else GHOST_BAD
		ghostHighlight.FillColor = color
		ghostHighlight.OutlineColor = color
	end
	showEdge(edge)
	local text = if found.ok then nil else found.reason and Settings.Refused[found.reason]
	Hints.set("placeRefused", if text then `{text}   Hold \{Fire\} Let go` else nil, 2, "warn")

	if now - lastAim >= 1 / Settings.AimRate then
		lastAim = now
		aimRemote:FireServer(CFrame.new(head.Position + camera.CFrame.LookVector * holdDistance) * rotation)
	end
end

local function makeAdornments()
	local gui = player:WaitForChild("PlayerGui")

	-- The shared edge when a piece snaps flush. Adorned to Terrain so CFrame is plain world space.
	edgeLine = Instance.new("BoxHandleAdornment")
	edgeLine.Name = "GrabSnapEdge"
	edgeLine.Adornee = workspace.Terrain
	edgeLine.Color3 = Color3.new(1, 1, 1)
	edgeLine.Transparency = 0.1
	edgeLine.AlwaysOnTop = false
	edgeLine.Visible = false
	edgeLine.Parent = gui

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
	pryRemote = Net.event("GrabPry")
	makeAdornments()

	stateRemote.OnClientEvent:Connect(onState)
	-- A number is how long this pry takes; nil means it was called off
	pryRemote.OnClientEvent:Connect(function(duration: number?)
		if type(duration) == "number" then
			if prying then
				prying.duration = duration
			end
		else
			stopPry(false)
		end
	end)
	RunService.RenderStepped:Connect(onRender)
	Input.bind("Grab", onGrabKey)
	Hotbar.onUse("Grab", onToggle)
	Input.bind("CarrySpin", onTouchSpin)
	Input.bind("CarryTip", onTouchTip)
	Input.bind("CarryCloser", touchDistance("CarryCloser", -1))
	Input.bind("CarryFarther", touchDistance("CarryFarther", 1))
end

return Grab
