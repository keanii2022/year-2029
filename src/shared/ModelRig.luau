-- Brings a ModelLibrary model to life: moving parts get a Motor6D on their hinge, still parts are welded
-- to the root, Glow parts turn Neon and Screen parts get a swappable image.
-- The root stays anchored and moving parts drive through Motor6D.C0, so server-set poses replicate.
local Config = require(script.Parent.Config)
local Manifest = require(script.Parent.Logic.Manifest)
local ModelLibrary = require(script.Parent.ModelLibrary)

export type Joint = { motor: Motor6D, base: CFrame, motion: Manifest.Motion, info: Manifest.PartInfo }

local ModelRig = {}

local rigs: { [Model]: { [string]: Joint } } = setmetatable({}, { __mode = "k" }) :: any

local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

local function vector(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function addScreen(part: BasePart, imageId: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Back -- screens face the model's front, which is +z
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(800, 600)
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Stretch
	image.Image = imageId or ""
	image.Parent = gui
	gui.Parent = part
end

function ModelRig.rig(model: Model): { [string]: Joint }
	local existing = rigs[model]
	if existing then
		return existing
	end
	local joints: { [string]: Joint } = {}
	rigs[model] = joints

	local entry = ModelLibrary.entry(model:GetAttribute("ModelName") or model.Name)
	if not entry then
		warn(`[ModelRig] {model.Name} is not in the manifest`)
		return joints
	end

	local parts: { [string]: BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts[descendant.Name] = descendant
		end
	end
	local names = Manifest.partNames(entry)
	local rootName = Manifest.rootPart(names)
	local root = rootName and parts[rootName]
	if not root then
		warn(`[ModelRig] {entry.name} has no root part`)
		return joints
	end
	root.Anchored = true
	model.PrimaryPart = root

	for _, info in entry.parts do
		local part = parts[info.name]
		if not part then
			continue
		end
		if Manifest.isGlow(info.name) then
			part.Material = Enum.Material.Neon
		elseif Manifest.isScreen(info.name) then
			addScreen(part, Manifest.contentId(entry.screenId))
		end
		if part == root then
			continue
		end

		local parent = parts[Manifest.parentPart(info.name, names, root.Name)] or root
		local motion = Manifest.motion(entry.name, info.name, Config.Models.AxisOverrides)
		if motion then
			-- MeshParts and greybox parts both sit at their bounds center, so the hinge is the manifest offset from there
			local hinge = part.CFrame * CFrame.new(vector(info.pivot) - vector(info.center))
			local motor = Instance.new("Motor6D")
			motor.Name = info.name
			motor.Part0 = parent
			motor.Part1 = part
			motor.C0 = parent.CFrame:ToObjectSpace(hinge)
			motor.C1 = part.CFrame:ToObjectSpace(hinge)
			motor.Parent = parent
			joints[info.name] = { motor = motor, base = motor.C0, motion = motion, info = info }
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
		part.Anchored = false
	end

	model:SetAttribute("Rigged", true)
	return joints
end

-- t: 0 closed or resting, 1 fully open (hinges, slides), one full turn (spins), full swing (movers, joints).
function ModelRig.setPose(model: Model, partName: string, t: number)
	local joint = ModelRig.rig(model)[partName]
	if not joint then
		return
	end
	local degrees, studs = Manifest.pose(joint.motion, t, joint.info, Config.Models)
	local axis = AXES[joint.motion.axis]
	joint.motor.C0 = joint.base * CFrame.new(axis * studs) * CFrame.fromAxisAngle(axis, math.rad(degrees))
end

function ModelRig.movingParts(model: Model): { string }
	local names = {}
	for name in ModelRig.rig(model) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ModelRig.setGlow(model: Model, on: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and Manifest.isGlow(part.Name) then
			part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

-- imageId: an asset id number or a content string. screenName picks one screen (Screen2), default all of them.
function ModelRig.setScreen(model: Model, imageId: number | string, screenName: string?)
	local content = if type(imageId) == "number" then Manifest.contentId(imageId) else imageId
	for _, part in model:GetDescendants() do
		if
			part:IsA("BasePart")
			and Manifest.isScreen(part.Name)
			and (not screenName or part.Name == screenName)
		then
			local gui = part:FindFirstChild("Screen")
			local image = gui and gui:FindFirstChild("Image")
			if image and image:IsA("ImageLabel") then
				image.Image = content or ""
			end
		end
	end
end

return ModelRig
