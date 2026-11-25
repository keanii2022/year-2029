-- The gun in your hands: a client-only model on the camera that bobs with your steps, kicks back
-- on each shot, and drops out of view while carrying a prop or when no gun is selected.
-- Uses the gun's uploaded viewmodel once the server copies it into ReplicatedStorage.Viewmodels,
-- otherwise a stand-in built from plain parts. Hands puts the gloves on its Grip and Foregrip.
-- On reload it dips and its Mag part (a small block on the stand-in) drops out and fades.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatReload = require(ReplicatedStorage.Shared.Logic.CombatReload)
local Config = require(ReplicatedStorage.Shared.Config)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)

local settings = Config.Guns
local movementSettings = Config.Movement
local player = Players.LocalPlayer

local Viewmodel = {}

local MARKERS = { "Muzzle", "Grip", "Foregrip", "Lens", "Rear" }

local model: Model? = nil
local modelName: string? = nil -- uploaded template in use, nil for the stand-in
local wantedName: string? = nil
local muzzle: BasePart? = nil
local gripMarker: BasePart? = nil
local foregripMarker: BasePart? = nil
local magPart: BasePart? = nil
-- Turns the model's own pivot into "barrel along -Z, centred on the body".
local alignment = CFrame.identity
local armed = false
local aimBlend = 0
local lowerBlend = 1
local bobAmount = 0
local phase = 0
local lastKickAt = -math.huge
local kickWeight = 1
local reloadStartedAt = -math.huge
local reloadDuration = 0

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

local function block(
	parent: Model,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	prepare(part)
	part.Parent = parent
	return part
end

-- Chunky stand-in blaster, barrel along -Z: white shell, grey shroud, dark grip, orange stripe,
-- glowing cell on the side.
local function buildStandIn(): Model
	local blaster = Instance.new("Model")
	blaster.Name = "ViewmodelBlaster"
	local shell = Color3.fromRGB(232, 234, 237)
	local grey = Color3.fromRGB(120, 126, 134)
	local dark = Color3.fromRGB(38, 40, 44)
	local orange = Color3.fromRGB(255, 128, 40)
	local body = block(blaster, "Body", Vector3.new(0.3, 0.34, 1.05), Vector3.zero, shell)
	block(blaster, "Shroud", Vector3.new(0.24, 0.24, 0.42), Vector3.new(0, 0.02, -0.72), grey)
	block(blaster, "Tip", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0, 0.02, -0.96), dark)
	block(blaster, "Stripe", Vector3.new(0.32, 0.06, 0.7), Vector3.new(0, 0.12, -0.05), orange)
	block(blaster, "Sight", Vector3.new(0.1, 0.1, 0.24), Vector3.new(0, 0.22, 0.2), dark)
	local grip = block(blaster, "Grip", Vector3.new(0.2, 0.46, 0.24), Vector3.zero, dark)
	grip.CFrame = CFrame.new(0, -0.34, 0.28) * CFrame.Angles(math.rad(-14), 0, 0)
	block(
		blaster,
		"Cell",
		Vector3.new(0.08, 0.14, 0.36),
		Vector3.new(0.17, -0.02, 0.12),
		Color3.fromRGB(90, 230, 255),
		Enum.Material.Neon
	)
	local tip = block(blaster, "Muzzle", Vector3.one * 0.05, Vector3.new(0, 0.02, -1.03), dark)
	tip.Transparency = 1
	blaster.PrimaryPart = body
	return blaster
end

local function findPart(parent: Instance, name: string): BasePart?
	local found = parent:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function use(newModel: Model, newAlignment: CFrame, name: string?)
	if model then
		model:Destroy()
	end
	model = newModel
	modelName = name
	alignment = newAlignment
	muzzle = findPart(newModel, "Muzzle")
	gripMarker = findPart(newModel, "Grip")
	foregripMarker = findPart(newModel, "Foregrip")
	magPart = findPart(newModel, "Mag")
	-- The kit's marker cubes (bright magenta) only say where things attach. The stand-in's grip is
	-- a real part, so only uploaded models hide theirs.
	for _, markerName in MARKERS do
		local marker = findPart(newModel, markerName)
		if marker and (name or markerName ~= "Grip") then
			marker.Transparency = 1
			marker.CanCollide = false
			marker.CanQuery = false
		end
	end
	for _, part in newModel:GetDescendants() do
		if part:IsA("BasePart") then
			prepare(part)
		end
	end
end

-- The uploaded model's facing depends on how it was exported, so point it from the body's
-- centre (or the model's middle without a Body part) toward the muzzle instead of trusting its pivot.
local function useUploaded(template: Instance)
	if not template:IsA("Model") then
		return
	end
	local copy = template:Clone()
	local pivot = copy:GetPivot()
	local body = findPart(copy, "Body")
	local tip = findPart(copy, "Muzzle")
	local newAlignment = CFrame.identity -- The barrel line runs Rear -> Muzzle; the body's centre sits low in the grip and tips the nose down
	local rear = findPart(copy, "Rear")
	if tip then
		local middle = if rear
			then rear.Position
			elseif body then body.Position
			else (copy:GetBoundingBox()).Position
		local centre = pivot:PointToObjectSpace(middle)
		local forward = pivot:PointToObjectSpace(tip.Position) - centre
		if forward.Magnitude > 0.01 then
			newAlignment = CFrame.lookAt(centre, centre + forward):Inverse()
		end
	end
	use(copy, newAlignment, template.Name)
end

-- Swaps to the wanted gun's uploaded model, or the stand-in until it has been published.
local function refreshModel()
	local name = wantedName
	if not name or name == modelName then
		return
	end
	local templates = ReplicatedStorage:FindFirstChild("Viewmodels")
	local template = templates and templates:FindFirstChild(name)
	if template then
		useUploaded(template)
	elseif modelName ~= nil then
		use(buildStandIn(), CFrame.identity, nil)
	end
end

-- Gun calls this whenever the gun in hand changes: its viewmodel template name, or nil for none.
function Viewmodel.setArmed(name: string?)
	armed = name ~= nil
	if name then
		wantedName = name
		refreshModel()
	end
end

-- Where the gloves go on the gun right now: the Grip and, on two-handed guns, the Foregrip.
-- Both nil while the gun is out of view.
function Viewmodel.grips(): (CFrame?, CFrame?)
	if not model or model.Parent == nil then
		return nil, nil
	end
	return gripMarker and gripMarker.CFrame, foregripMarker and foregripMarker.CFrame
end

-- 0 at the hip, 1 fully aimed.
function Viewmodel.setAim(blend: number)
	aimBlend = blend
end

-- weight scales how hard this shot throws the gun back (1 for the starter blaster).
function Viewmodel.kick(weight: number)
	lastKickAt = os.clock()
	kickWeight = weight
end

local function dropMag(camera: Camera)
	local character = player.Character
	if not model or model.Parent == nil or not character then
		return
	end
	local piece: BasePart
	if magPart then
		piece = magPart:Clone()
		for _, child in piece:GetDescendants() do
			if child:IsA("JointInstance") or child:IsA("Constraint") then
				child:Destroy()
			end
		end
		piece.CFrame = magPart.CFrame
	else
		local body = model.PrimaryPart or findPart(model, "Body")
		local part = Instance.new("Part")
		part.Size = settings.MagStandInSize
		part.Color = settings.MagStandInColor
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = if body
			then body.CFrame * CFrame.new(0, -0.2, 0.1)
			else camera.CFrame * CFrame.new(0.6, -0.9, -1.2)
		piece = part
	end
	piece.Name = "DroppedMag"
	piece.Anchored = false
	piece.CanCollide = true
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = false
	piece.Transparency = 0
	piece.LocalTransparencyModifier = 0
	-- It starts inside your own body; without these it would shove you around.
	for _, bodyPart in character:GetDescendants() do
		if bodyPart:IsA("BasePart") then
			local ignore = Instance.new("NoCollisionConstraint")
			ignore.Part0 = piece
			ignore.Part1 = bodyPart
			ignore.Parent = piece
		end
	end
	piece.Parent = workspace
	piece.AssemblyLinearVelocity = camera.CFrame.RightVector * 1.5 + Vector3.new(0, -3, 0)
	task.delay(settings.MagFallTime, function()
		if piece.Parent then
			local fade = TweenService:Create(piece, TweenInfo.new(settings.MagFadeTime), { Transparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			piece:Destroy()
		end
	end)
end

-- Gun calls this when a reload starts: dip the blaster for duration seconds and drop the old mag.
function Viewmodel.reload(duration: number)
	reloadStartedAt = os.clock()
	reloadDuration = duration
	local camera = workspace.CurrentCamera
	if camera then
		dropMag(camera)
	end
end

-- Current kick strength 0..1, so the camera can tip with the blaster.
function Viewmodel.recoil(): number
	return CombatFeel.recoil(os.clock() - lastKickAt, settings.RecoilRise, settings.RecoilSettle)
end

-- Where the barrel tip is right now, or nil when the blaster is out of view.
function Viewmodel.muzzlePosition(): Vector3?
	if not muzzle or not model or model.Parent == nil then
		return nil
	end
	return muzzle.Position
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not camera or dt <= 0 then
		return
	end
	local alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0
	local lowered = not alive
		or not armed
		or player:GetAttribute("CarrySpeedMultiplier") ~= nil
		or player:GetAttribute("HandsBusy") == true
	lowerBlend = MovementLogic.smooth(lowerBlend, if lowered then 1 else 0, settings.ViewmodelLowerEase, dt)
	if lowered and lowerBlend > 0.98 then
		model.Parent = nil
		return
	end

	local groundSpeed = 0
	if humanoid and root and humanoid.FloorMaterial ~= Enum.Material.Air then
		local velocity = root.AssemblyLinearVelocity
		groundSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	end
	bobAmount = MovementLogic.smooth(
		bobAmount,
		MovementLogic.bobAmount(movementSettings, groundSpeed),
		movementSettings.BobEase,
		dt
	)
	phase = MovementLogic.advancePhase(movementSettings, phase, groundSpeed, dt)
	local side, up, roll = MovementLogic.bobOffset(
		movementSettings,
		phase,
		bobAmount * settings.ViewmodelBobScale * (1 - aimBlend)
	)

	local kick = Viewmodel.recoil() * kickWeight
	local reloadT = os.clock() - reloadStartedAt
	local dip =
		CombatReload.motion(reloadT, reloadDuration, settings.ReloadDipShare, settings.ReloadRiseShare)
	-- The gun's own mag is gone from the drop until the fresh one comes up with the rise.
	if magPart then
		local swapping = reloadT >= 0 and reloadT < reloadDuration * (1 - settings.ReloadRiseShare)
		magPart.LocalTransparencyModifier = if swapping then 1 else 0
	end
	local offset = settings.ViewmodelOffset:Lerp(settings.ViewmodelAimOffset, aimBlend)
	local hold = camera.CFrame
		* CFrame.new(offset + Vector3.new(side, up - settings.ViewmodelLoweredDrop * lowerBlend, 0))
		* CFrame.Angles(math.rad(-settings.ViewmodelLoweredPitch * lowerBlend), 0, math.rad(roll))
		* CFrame.new(0, 0, settings.RecoilKickBack * kick)
		* CFrame.Angles(math.rad(settings.RecoilKickPitch * kick), 0, 0)
		* CFrame.new(0, -settings.ReloadDropSink * dip, 0)
		* CFrame.Angles(math.rad(-settings.ReloadDropPitch * dip), 0, math.rad(settings.ReloadDropRoll * dip))
	model:PivotTo(hold * alignment)
	model.Parent = camera
end

function Viewmodel.Init()
	use(buildStandIn(), CFrame.identity, nil)
end

function Viewmodel.Start()
	task.spawn(function()
		ReplicatedStorage:WaitForChild("Viewmodels").ChildAdded:Connect(refreshModel)
		refreshModel()
	end)
	-- After Gun's aim step (Camera + 2) so the blaster follows the final camera for the frame.
	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 3, update)
end

return Viewmodel
