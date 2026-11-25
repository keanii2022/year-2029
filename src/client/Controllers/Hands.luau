-- First-person arms on the camera: food comes up and gets bitten, drinks tip back, bandages get
-- wrapped, boxes get pulled open, and pressing use reaches out with the left hand. Driven by the
-- server's "UsingSupply" attribute (the item id being used), with a progress ring round the
-- crosshair. Sets the local "HandsBusy" attribute while the hands are up.
-- Between uses they hold whatever is selected on the hotbar: the gloves on a gun's Grip and
-- Foregrip, or the item in the right hand.
-- Uses the uploaded arm and item models once the server copies them into
-- ReplicatedStorage.Viewmodels, otherwise stand-ins built from plain parts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HandsLogic = require(ReplicatedStorage.Shared.Logic.Hands)
local Hotbar = require(script.Parent.Hotbar)
local Viewmodel = require(script.Parent.Viewmodel)

local settings = Config.Hands
local hotbarSettings = Config.Hotbar
local uses = Config.Supplies.Uses
local player = Players.LocalPlayer

local TEXT = Color3.fromRGB(225, 222, 215)
local LEFT_KINDS = { Heal = "LeftOpen", Open = "Left", Medkit = "LeftOpen" }
local MARKERS = { "Lens", "Grip", "Muzzle", "Foregrip", "Rear", "Eject" }

type Arm = { model: Model, offset: CFrame, length: number, uploaded: boolean }
-- tip: the item's Lens marker, which also points it forward
type Item =
	{ model: Model, centre: CFrame, baseScale: number, crumbs: Color3?, offset: CFrame, tip: BasePart? }
type Holding = { itemId: string, item: Item, since: number, shown: boolean }
type Action = {
	kind: string,
	started: number,
	duration: number,
	item: Item,
	lastT: number,
}

local Hands = {}

local arms: { [string]: Arm } = {}
local action: Action? = nil
local holding: Holding? = nil
local reachStarted = -math.huge
local reachDirection = Vector3.new(0, 0, -1)
local crumbPart: Part
local crumbs: ParticleEmitter
local ringGui: ScreenGui
local ringDots: { Frame } = {}
local busy = false

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

local function block(parent: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	prepare(part)
	part.Parent = parent
	return part
end

local function template(name: string?): Model?
	local folder = ReplicatedStorage:FindFirstChild("Viewmodels")
	local found = name and folder and folder:FindFirstChild(name)
	return if found and found:IsA("Model") then found:Clone() else nil
end

-- The elbow is the end of Body facing away from Grip. Works whatever way the model was exported.
local function armFrom(model: Model, uploaded: boolean): Arm?
	local body = model:FindFirstChild("Body", true)
	local grip = model:FindFirstChild("Grip", true)
	if not (body and body:IsA("BasePart") and grip and grip:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			prepare(part)
		end
	end
	grip.Transparency = 1
	local toGrip = grip.Position - body.Position
	if toGrip.Magnitude < 0.01 then
		model:Destroy()
		return nil
	end
	local direction = toGrip.Unit
	local inBody = body.CFrame:VectorToObjectSpace(direction)
	local extent = math.abs(inBody.X * body.Size.X)
		+ math.abs(inBody.Y * body.Size.Y)
		+ math.abs(inBody.Z * body.Size.Z)
	local elbow = body.Position - direction * (extent / 2)
	local frame = CFrame.lookAt(elbow, grip.Position)
	return {
		model = model,
		offset = frame:ToObjectSpace(model:GetPivot()),
		length = (grip.Position - elbow).Magnitude,
		uploaded = uploaded,
	}
end

-- Sleeve from the elbow along -Z, glove at the end: a fist, or a flat palm for the open hand.
local function buildStandInArm(open: boolean): Arm
	local model = Instance.new("Model")
	model.Name = "ViewmodelArm"
	local length = settings.StandInLength
	local sleeve = length - 0.28
	block(model, "Body", Vector3.new(0.36, 0.36, sleeve), CFrame.new(0, 0, -sleeve / 2), settings.SleeveColor)
	block(model, "Cuff", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0, -sleeve - 0.04), settings.GloveColor)
	local gloveSize = if open then Vector3.new(0.34, 0.09, 0.34) else Vector3.new(0.3, 0.28, 0.28)
	block(model, "Glove", gloveSize, CFrame.new(0, 0, -length + gloveSize.Z / 2), settings.GloveColor)
	block(
		model,
		"Grip",
		Vector3.one * 0.05,
		CFrame.new(0, if open then 0.06 else 0, -length + 0.14),
		settings.GloveColor
	)
	return armFrom(model, false) :: Arm
end

-- Swaps a stand-in for the uploaded arm as soon as it shows up.
local function arm(slot: string): Arm
	local existing = arms[slot]
	if existing and existing.uploaded then
		return existing
	end
	local uploaded = template(settings.Arms[slot])
	local built = uploaded and armFrom(uploaded, true)
	if built then
		if existing then
			existing.model:Destroy()
		end
		arms[slot] = built
		return built
	end
	if not existing then
		existing = buildStandInArm(slot == "LeftOpen")
		arms[slot] = existing
	end
	return existing :: Arm
end

local function buildStandInItem(look: { [string]: any }): Model
	local model = Instance.new("Model")
	model.Name = "HeldItem"
	local size: Vector3 = look.size
	local part: BasePart
	if look.shape == "Wedge" then
		part = Instance.new("WedgePart")
		part.Size = size
		part.CFrame = CFrame.identity
	else
		part = Instance.new("Part")
		if look.shape == "Can" then
			-- Cylinders run along X, so stand it up
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(size.Y, size.X, size.Z)
			part.CFrame = CFrame.Angles(0, 0, math.pi / 2)
		elseif look.shape == "Roll" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(size.X * 0.8, size.Y, size.Z)
			part.CFrame = CFrame.identity
		elseif look.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
			part.Size = size
			part.CFrame = CFrame.identity
		else
			part.Size = size
			part.CFrame = CFrame.identity
		end
	end
	part.Name = "Body"
	part.Color = look.color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	prepare(part)
	part.Parent = model
	model.WorldPivot = CFrame.identity
	return model
end

local function heldItem(itemId: string, kind: string): Item
	local look = settings.Items[itemId]
		or hotbarSettings.Held[itemId]
		or settings.Fallback[kind]
		or settings.Fallback.Eat
	local model = template(look.model)
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				prepare(part)
			end
		end
		local _, size = model:GetBoundingBox()
		local longest = math.max(size.X, size.Y, size.Z)
		local want = math.max(look.size.X, look.size.Y, look.size.Z)
		if longest > 0.001 then
			model:ScaleTo(model:GetScale() * want / longest)
		end
	else
		model = buildStandInItem(look)
	end
	local held = model :: Model
	local box = held:GetBoundingBox()
	local centre = box:ToObjectSpace(held:GetPivot())
	for _, name in MARKERS do
		local marker = held:FindFirstChild(name, true)
		if marker and marker:IsA("BasePart") then
			marker.Transparency = 1
		end
	end
	local lens = held:FindFirstChild("Lens", true)
	local tip = if lens and lens:IsA("BasePart") then lens else nil
	if tip then
		local forward = box:VectorToObjectSpace(tip.Position - box.Position)
		if forward.Magnitude > 0.01 then
			centre = CFrame.lookAt(Vector3.zero, forward):Inverse() * centre
		end
	end
	return {
		model = held,
		centre = centre,
		baseScale = held:GetScale(),
		crumbs = look.crumbs,
		offset = look.offset or settings.ItemOffset,
		tip = tip,
	}
end

local function poseFrame(camera: Camera, pose: HandsLogic.Pose): CFrame
	return camera.CFrame
		* CFrame.new(pose.x, pose.y, pose.z)
		* CFrame.Angles(math.rad(pose.pitch), math.rad(pose.yaw), math.rad(pose.roll))
end

local function placeArmAt(camera: Camera, slot: string, side: string, hand: CFrame)
	local chosen = arm(slot)
	local tilt = settings.ArmTilt[side]
	local forearm = hand * CFrame.Angles(math.rad(tilt.pitch), math.rad(tilt.yaw), 0)
	chosen.model:PivotTo(forearm * CFrame.new(0, 0, chosen.length) * chosen.offset)
	chosen.model.Parent = camera
end

local function placeArm(camera: Camera, slot: string, side: string, pose: HandsLogic.Pose): CFrame
	local hand = poseFrame(camera, pose)
	placeArmAt(camera, slot, side, hand)
	return hand
end

-- A glove on a gun marker, facing the way the camera looks
local function onMarker(camera: Camera, marker: CFrame): CFrame
	return CFrame.new(marker.Position) * camera.CFrame.Rotation
end

local function hideArms(except: { [string]: boolean })
	for slot, built in arms do
		if not except[slot] then
			built.model.Parent = nil
		end
	end
end

-- Takes a bite out of the held food: shrinks it round its pivot and throws crumbs.
local function bite(item: Item, count: number, bitesSoFar: number)
	local scale = math.max(1 - settings.BiteShrink * bitesSoFar, settings.MinFoodScale)
	item.model:ScaleTo(item.baseScale * scale)
	if item.crumbs then
		crumbs.Color = ColorSequence.new(item.crumbs)
		crumbs:Emit(settings.CrumbsPerBite * count)
	end
end

local function itemScale(item: Item): number
	return item.model:GetScale() / item.baseScale
end

local function heldFor(itemId: string): Holding
	local current = holding
	if current and current.itemId == itemId then
		return current
	end
	if current then
		current.item.model:Destroy()
	end
	local use = uses[itemId]
	local fresh = {
		itemId = itemId,
		item = heldItem(itemId, if use then use.kind else "Eat"),
		since = 0,
		shown = false,
	}
	holding = fresh
	return fresh
end

local function hideHeld()
	if holding then
		holding.item.model.Parent = nil
		holding.shown = false
	end
end

local function endAction()
	if action then
		action.item.model:Destroy()
		action = nil
	end
end

local function onUsingSupply()
	local itemId = player:GetAttribute("UsingSupply")
	local now = os.clock()
	if type(itemId) == "string" then
		local use = uses[itemId]
		if not use then
			return
		end
		endAction()
		local kind = if use.opens then "Open" else use.kind
		action = {
			kind = kind,
			started = now,
			duration = use.time,
			item = heldItem(itemId, kind),
			lastT = 0,
		}
	elseif action then
		-- Cut short (died, cuffed): drop the hands from where they are now
		action.duration = math.min(action.duration, now - action.started)
	end
end

local function setBusy(value: boolean)
	if value ~= busy then
		busy = value
		player:SetAttribute("HandsBusy", value or nil)
	end
end

local function updateRing()
	local current = action
	local using = current ~= nil and player:GetAttribute("UsingSupply") ~= nil
	ringGui.Enabled = using
	if not current or not using then
		return
	end
	local progress = math.clamp((os.clock() - current.started) / current.duration, 0, 1)
	local lit = math.floor(progress * #ringDots + 0.5)
	for index, dot in ringDots do
		dot.BackgroundTransparency = if index <= lit then 0.05 else 0.75
	end
end

local function update()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not humanoid or humanoid.Health <= 0 then
		endAction()
		hideArms({})
		hideHeld()
		ringGui.Enabled = false
		setBusy(false)
		return
	end

	local now = os.clock()
	local shown: { [string]: boolean } = {}
	local current = action
	if current then
		local t = now - current.started
		if HandsLogic.finished(t, current.duration, settings.LowerTime) then
			endAction()
			current = nil
		else
			local right, left = HandsLogic.pose(current.kind, t, current.duration, settings)
			local hand = placeArm(camera, "Right", "Right", right)
			shown.Right = true
			local leftSlot = LEFT_KINDS[current.kind]
			if leftSlot then
				placeArm(camera, leftSlot, "Left", left)
				shown[leftSlot] = true
			end

			local item = current.item
			if current.kind == "Eat" and t < current.duration then
				local start = settings.RaiseTime + settings.BiteLength / 2
				local count =
					HandsLogic.bitesBetween(current.lastT, t, start, settings.BiteInterval, current.duration)
				if count > 0 then
					local bitesSoFar =
						HandsLogic.bitesBetween(-1, t, start, settings.BiteInterval, current.duration)
					bite(item, count, bitesSoFar)
				end
			end
			current.lastT = t
			local scale = itemScale(item)
			local centre = CFrame.new(item.centre.Position * scale) * item.centre.Rotation
			local itemFrame = hand * item.offset
			item.model:PivotTo(itemFrame * centre)
			item.model.Parent = camera
			crumbPart.CFrame = itemFrame
			crumbPart.Parent = camera
		end
	end

	local slot = Hotbar.selected()
	local handsFree = not current
		and player:GetAttribute("CarrySpeedMultiplier") == nil
		and player:GetAttribute("Cuffed") ~= true
	local foregrip: CFrame? = nil
	local held: Holding? = nil
	if handsFree and slot and slot.use == "Fire" then
		local grip
		grip, foregrip = Viewmodel.grips()
		if grip then
			placeArmAt(camera, "Right", "Right", onMarker(camera, grip))
			shown.Right = true
		end
	elseif handsFree and slot and slot.item then
		held = heldFor(slot.item)
	end
	if held then
		if not held.shown then
			held.since = now
			held.shown = true
		end
		local raise = HandsLogic.smooth(math.clamp((now - held.since) / hotbarSettings.SwapTime, 0, 1))
		local hand =
			placeArm(camera, "Right", "Right", HandsLogic.lerp(settings.Rest, hotbarSettings.HoldPose, raise))
		shown.Right = true
		held.item.model:PivotTo(hand * held.item.offset * held.item.centre)
		held.item.model.Parent = camera
	else
		hideHeld()
	end

	local sinceReach = now - reachStarted
	local leftFree = not (current and LEFT_KINDS[current.kind])
	local reaching = leftFree and sinceReach < settings.ReachTime
	if reaching then
		local start = settings.ReachStart
		local target = HandsLogic.reachTarget(
			start,
			reachDirection.X,
			reachDirection.Y,
			reachDirection.Z,
			settings.ReachDistance
		)
		local pose = HandsLogic.lerp(
			settings.Rest,
			HandsLogic.lerp(start, target, HandsLogic.reach(sinceReach, settings.ReachTime)),
			HandsLogic.smooth(
				math.min(sinceReach, settings.ReachTime - sinceReach) / (settings.ReachTime * 0.25)
			)
		)
		placeArm(camera, "LeftOpen", "Left", pose)
		shown.LeftOpen = true
	elseif foregrip then
		placeArmAt(camera, "Left", "Left", onMarker(camera, foregrip))
		shown.Left = true
	end

	hideArms(shown)
	updateRing()
	setBusy(current ~= nil or reaching)
end

-- Where a flashlight beam leaves the held item, facing where you look; nil when nothing held has
-- a Lens marker.
function Hands.lensFrame(): CFrame?
	local camera = workspace.CurrentCamera
	local item = holding and holding.shown and holding.item
	if not camera or not item or not item.tip then
		return nil
	end
	return CFrame.lookAt(item.tip.Position, item.tip.Position + camera.CFrame.LookVector)
end

-- Interact calls this on a use press: a quick left-hand reach toward what's being used.
function Hands.reach(worldPosition: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	reachDirection = camera.CFrame:VectorToObjectSpace(worldPosition - camera.CFrame.Position)
	reachStarted = os.clock()
end

local function buildCrumbs()
	crumbPart = Instance.new("Part")
	crumbPart.Name = "Crumbs"
	crumbPart.Size = Vector3.one * 0.05
	crumbPart.Transparency = 1
	prepare(crumbPart)
	crumbs = Instance.new("ParticleEmitter")
	crumbs.Enabled = false
	crumbs.Rate = 0
	crumbs.Size = NumberSequence.new(0.035)
	crumbs.Lifetime = NumberRange.new(0.4, 0.7)
	crumbs.Speed = NumberRange.new(1.2, 2.6)
	crumbs.SpreadAngle = Vector2.new(70, 70)
	crumbs.EmissionDirection = Enum.NormalId.Top
	crumbs.Acceleration = Vector3.new(0, -22, 0)
	crumbs.RotSpeed = NumberRange.new(-180, 180)
	crumbs.LightInfluence = 1
	crumbs.Parent = crumbPart
end

local function buildRing()
	ringGui = Instance.new("ScreenGui")
	ringGui.Name = "HandsRing"
	ringGui.ResetOnSpawn = false
	ringGui.IgnoreGuiInset = true
	ringGui.Enabled = false
	for index = 1, settings.RingDots do
		-- Clockwise from the top
		local angle = (index - 1) / settings.RingDots * 2 * math.pi
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position =
			UDim2.new(0.5, math.sin(angle) * settings.RingRadius, 0.5, -math.cos(angle) * settings.RingRadius)
		dot.Size = UDim2.fromOffset(settings.RingDotSize, settings.RingDotSize)
		dot.BackgroundColor3 = TEXT
		dot.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		dot.Parent = ringGui
		ringDots[index] = dot
	end
end

function Hands.Init()
	buildCrumbs()
	buildRing()
end

function Hands.Start()
	ringGui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("UsingSupply"):Connect(onUsingSupply)
	onUsingSupply()
	-- After Viewmodel (Camera + 3) so the arms follow the final camera for the frame.
	RunService:BindToRenderStep("Hands", Enum.RenderPriority.Camera.Value + 4, update)
end

return Hands
