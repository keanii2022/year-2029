-- Models by name. get() returns a fresh clone: the uploaded model when the manifest has its id,
-- else a greybox stand-in built from the manifest (one block per part, same names, sizes and hinges).
-- Uploaded models only load on the server (InsertService); clients always get the greybox.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Manifest = require(script.Parent.Logic.Manifest)
local ManifestData = require(script.Parent.Logic.ManifestData)

local ModelLibrary = {}

local index = Manifest.index(ManifestData :: Manifest.Data)
local templates: { [string]: Model } = {}

local function vector(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function buildGreybox(entry: Manifest.ModelEntry): Model
	local settings = Config.Models
	local model = Instance.new("Model")
	model.Name = entry.name
	for _, info in entry.parts do
		local part = Instance.new("Part")
		part.Name = info.name
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = vector(info.size):Max(Vector3.one * 0.05)
		part.CFrame = CFrame.new(vector(info.center))
		part.PivotOffset = CFrame.new(vector(info.pivot) - vector(info.center))
		part.Color = if Manifest.isGlow(info.name)
			then settings.GreyboxGlowColor
			elseif Manifest.isScreen(info.name) then settings.GreyboxScreenColor
			else settings.GreyboxColor
		part.Parent = model
	end
	local root = Manifest.rootPart(Manifest.partNames(entry))
	model.PrimaryPart = root and model:FindFirstChild(root) :: BasePart?
	model:SetAttribute("Greybox", true)
	return model
end

-- Box round every part, in world axes
local function worldExtents(model: Model): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in
				{
					Vector3.new(1, 1, 1),
					Vector3.new(1, 1, -1),
					Vector3.new(1, -1, 1),
					Vector3.new(1, -1, -1),
					Vector3.new(-1, 1, 1),
					Vector3.new(-1, 1, -1),
					Vector3.new(-1, -1, 1),
					Vector3.new(-1, -1, -1),
				}
			do
				local point = part.CFrame:PointToWorldSpace(half * corner)
				low, high = low:Min(point), high:Max(point)
			end
		end
	end
	return low, high
end

-- The pivot keeps its position but loses any tilt, so placing code can turn the model freely
local function levelPivot(model: Model)
	local root = model.PrimaryPart
	if root then
		root.PivotOffset = root.CFrame:ToObjectSpace(CFrame.new(root:GetPivot().Position))
	else
		model.WorldPivot = CFrame.new(model:GetPivot().Position)
	end
end

-- An imported model can come in tipped over (the art is built z-up). Stand it upright by checking
-- which way its height (from the manifest) is pointing, and level its pivot either way.
local function standUpright(model: Model, entry: Manifest.ModelEntry)
	levelPivot(model)
	local want = entry.size[2]
	local low, high = worldExtents(model)
	local extents = high - low
	local function near(a: number): boolean
		return math.abs(a - want) <= math.max(0.15 * want, 0.1)
	end
	if near(extents.Y) or not (near(extents.Z) or near(extents.X)) then
		return
	end
	local axis = if near(extents.Z) then Vector3.xAxis else Vector3.zAxis -- Of the two quarter turns, keep the one that leaves most of the model's weight low, the way
	-- furniture and racks sit; hanging things (signs, lights) hang from their top, so the reverse
	local hangs = Config.Models.HangingModels[entry.name] == true
	local best, bestScore = nil, math.huge
	for _, sign in { 1, -1 } do
		local turn = CFrame.fromAxisAngle(axis, sign * math.pi / 2)
		local trial = model:Clone()
		trial:PivotTo(trial:GetPivot() * turn)
		local tLow, tHigh = worldExtents(trial)
		local root = trial.PrimaryPart
		local score = if root then (root.Position.Y - tLow.Y) / math.max(tHigh.Y - tLow.Y, 0.01) else 0
		if hangs then
			score = -score
		end
		trial:Destroy()
		if score < bestScore then
			best, bestScore = turn, score
		end
	end
	model:PivotTo(model:GetPivot() * best)
	levelPivot(model)
end

local function loadUploaded(entry: Manifest.ModelEntry): Model?
	local ok, result = pcall(InsertService.LoadAsset, InsertService, entry.assetId :: number)
	if not ok then
		warn(`[ModelLibrary] {entry.name} ({entry.assetId}) failed to load, using greybox: {result}`)
		return nil
	end
	local model = result:FindFirstChildWhichIsA("Model") or result
	model.Name = entry.name
	local texture = Manifest.contentId(entry.textureId)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			part.Anchored = true
			if texture and part.TextureID == "" then
				part.TextureID = texture
			end
		end
	end
	local root = Manifest.rootPart(Manifest.partNames(entry))
	model.PrimaryPart = root and model:FindFirstChild(root, true) :: BasePart?
	standUpright(model, entry)
	return model
end

local function template(entry: Manifest.ModelEntry): Model
	local cached = templates[entry.name]
	if cached then
		return cached
	end
	local model = if entry.assetId and RunService:IsServer() then loadUploaded(entry) else nil
	if model then
		model:SetAttribute("Uploaded", true)
	end
	model = model or buildGreybox(entry)
	model:SetAttribute("ModelName", entry.name)
	templates[entry.name] = model
	return model
end

function ModelLibrary.get(name: string): Model?
	local entry = index.models[name]
	if not entry then
		warn(`[ModelLibrary] no model named {name}`)
		return nil
	end
	return template(entry):Clone()
end

-- True once the real model has been uploaded and actually loads here, so callers can swap their own
-- stand-in geometry for it. A failed load (no permission, still in review) counts as not uploaded.
function ModelLibrary.uploaded(name: string): boolean
	local entry = index.models[name]
	if not entry or not entry.assetId then
		return false
	end
	return template(entry):GetAttribute("Uploaded") == true
end

function ModelLibrary.entry(name: string): Manifest.ModelEntry?
	return index.models[name]
end

function ModelLibrary.groups(): { { name: string, models: { Manifest.ModelEntry } } }
	return index.groups
end

function ModelLibrary.soundId(name: string): string?
	return Manifest.soundId(index, name)
end

-- Pictures were uploaded as Decals, and an ImageLabel or Decal can't show a decal's own id: it
-- needs the image inside it. The server loads each decal once (InsertService), reads the image
-- from its Texture, and shares it with clients as an attribute on ReplicatedStorage.ImageIds.
local function imageStore(): Instance?
	local store = ReplicatedStorage:FindFirstChild("ImageIds")
	if not store and RunService:IsServer() then
		store = Instance.new("Folder")
		store.Name = "ImageIds"
		store.Parent = ReplicatedStorage
	end
	return store
end

function ModelLibrary.imageId(name: string): string?
	local fallback = Manifest.imageId(index, name)
	if not fallback then
		return nil
	end
	local store = imageStore()
	local known = store and store:GetAttribute(name)
	if type(known) == "string" then
		return known
	end
	if not RunService:IsServer() or not store then
		return fallback
	end
	local resolved = fallback
	local entry = index.images[name]
	local ok, model = pcall(InsertService.LoadAsset, InsertService, entry.assetId :: number)
	if ok and model then
		local decal = model:FindFirstChildWhichIsA("Decal", true)
		if decal and decal.Texture ~= "" then
			resolved = decal.Texture
		end
		model:Destroy()
	end
	store:SetAttribute(name, resolved)
	return resolved
end

-- Server start: resolve every picture up front so screens, decals and clients have them ready
function ModelLibrary.preloadImages()
	for name in index.images do
		task.spawn(ModelLibrary.imageId, name)
	end
end

return ModelLibrary
