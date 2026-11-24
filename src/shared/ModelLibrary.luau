-- Models by name. get() returns a fresh clone: the uploaded model when the manifest has its id,
-- else a greybox stand-in built from the manifest (one block per part, same names, sizes and hinges).
-- Uploaded models only load on the server (InsertService); clients always get the greybox.
local InsertService = game:GetService("InsertService")
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
	return model
end

local function template(entry: Manifest.ModelEntry): Model
	local cached = templates[entry.name]
	if cached then
		return cached
	end
	local model = if entry.assetId and RunService:IsServer() then loadUploaded(entry) else nil
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

function ModelLibrary.entry(name: string): Manifest.ModelEntry?
	return index.models[name]
end

function ModelLibrary.groups(): { { name: string, models: { Manifest.ModelEntry } } }
	return index.groups
end

function ModelLibrary.soundId(name: string): string?
	return Manifest.soundId(index, name)
end

function ModelLibrary.imageId(name: string): string?
	return Manifest.imageId(index, name)
end

return ModelLibrary
