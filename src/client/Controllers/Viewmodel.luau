-- The blaster in your hands: a client-only model on the camera that bobs with your steps, kicks
-- back on each shot, and drops out of view while carrying a prop or holding no blaster.
-- Uses the uploaded viewmodel_blaster once the server copies it into ReplicatedStorage.Viewmodels,
-- otherwise a stand-in built from plain parts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local Config = require(ReplicatedStorage.Shared.Config)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)

local settings = Config.Guns
local movementSettings = Config.Movement
local player = Players.LocalPlayer

local Viewmodel = {}

local model: Model? = nil
local muzzle: BasePart? = nil
-- Turns the model's own pivot into "barrel along -Z, centred on the body".
local alignment = CFrame.identity
local armed = false
local aimBlend = 0
local lowerBlend = 1
local bobAmount = 0
local phase = 0
local lastKickAt = -math.huge

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

local function use(newModel: Model, newAlignment: CFrame)
	if model then
		model:Destroy()
	end
	model = newModel
	alignment = newAlignment
	local found = newModel:FindFirstChild("Muzzle", true)
	muzzle = if found and found:IsA("BasePart") then found else nil -- The kit's marker cubes (bright magenta) only say where things attach
	for _, markerName in { "Muzzle", "Grip" } do
		local marker = newModel:FindFirstChild(markerName, true)
		if marker and marker:IsA("BasePart") then
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
-- centre toward the muzzle instead of trusting its pivot.
local function useUploaded(template: Instance)
	if not template:IsA("Model") then
		return
	end
	local copy = template:Clone()
	local pivot = copy:GetPivot()
	local body = copy:FindFirstChild("Body", true)
	local tip = copy:FindFirstChild("Muzzle", true)
	local newAlignment = CFrame.identity
	if body and body:IsA("BasePart") and tip and tip:IsA("BasePart") then
		local centre = pivot:PointToObjectSpace(body.Position)
		local forward = pivot:PointToObjectSpace(tip.Position) - centre
		if forward.Magnitude > 0.01 then
			newAlignment = CFrame.lookAt(centre, centre + forward):Inverse()
		end
	end
	use(copy, newAlignment)
end

local function watchForUploaded()
	local folder = ReplicatedStorage:WaitForChild("Viewmodels")
	local existing = folder:FindFirstChild("viewmodel_blaster")
	if existing then
		useUploaded(existing)
		return
	end
	local connection
	connection = folder.ChildAdded:Connect(function(child)
		if child.Name == "viewmodel_blaster" then
			connection:Disconnect()
			useUploaded(child)
		end
	end)
end

-- Gun calls this whenever what you carry changes.
function Viewmodel.setArmed(hasBlaster: boolean)
	armed = hasBlaster
end

-- 0 at the hip, 1 fully aimed.
function Viewmodel.setAim(blend: number)
	aimBlend = blend
end

function Viewmodel.kick()
	lastKickAt = os.clock()
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
	local lowered = not alive or not armed or player:GetAttribute("CarrySpeedMultiplier") ~= nil
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

	local kick = Viewmodel.recoil()
	local offset = settings.ViewmodelOffset:Lerp(settings.ViewmodelAimOffset, aimBlend)
	local hold = camera.CFrame
		* CFrame.new(offset + Vector3.new(side, up - settings.ViewmodelLoweredDrop * lowerBlend, 0))
		* CFrame.Angles(math.rad(-settings.ViewmodelLoweredPitch * lowerBlend), 0, math.rad(roll))
		* CFrame.new(0, 0, settings.RecoilKickBack * kick)
		* CFrame.Angles(math.rad(settings.RecoilKickPitch * kick), 0, 0)
	model:PivotTo(hold * alignment)
	model.Parent = camera
end

function Viewmodel.Init()
	use(buildStandIn(), CFrame.identity)
end

function Viewmodel.Start()
	task.spawn(watchForUploaded)
	-- After Gun's aim step (Camera + 2) so the blaster follows the final camera for the frame.
	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 3, update)
end

return Viewmodel
