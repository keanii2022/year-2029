-- Test area far from the origin: every model in labelled rows by group, rigged, its moving parts swinging.
-- Off with Config.Models.ShowroomEnabled.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ManifestLayout = require(ReplicatedStorage.Shared.Logic.ManifestLayout)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)

local Showroom = {}

local MARGIN = 10
local DEMO_PERIOD = 4 -- seconds per open-close swing

local function label(parent: Instance, text: string, position: Vector3, size: number, maxDistance: number)
	local anchor = Instance.new("Part")
	anchor.Name = text
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 12, size * 2)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Parent = gui
	gui.Parent = anchor
	anchor.Parent = parent
end

-- Sits the model's bounding box bottom-center on the spot, whatever origin the import gave it.
local function place(model: Model, spot: Vector3)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (spot - bottom))
end

function Showroom:Start()
	local settings = Config.Models
	if not settings.ShowroomEnabled then
		return
	end

	local plan = ManifestLayout.plan(ModelLibrary.groups(), {
		spacing = settings.ShowroomSpacing,
		rowGap = settings.ShowroomRowGap,
		maxRowWidth = settings.ShowroomMaxRowWidth,
	})
	local origin: Vector3 = settings.ShowroomOrigin

	local folder = Instance.new("Folder")
	folder.Name = "Showroom"

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(70, 72, 76)
	floor.Size = Vector3.new(plan.width + MARGIN * 2, 1, plan.depth + MARGIN * 2)
	floor.Position = origin + Vector3.new(plan.width / 2, -0.5, plan.depth / 2)
	floor.Parent = folder

	local spawnPoint = origin + Vector3.new(plan.width / 2, 3, -MARGIN / 2)

	for _, row in plan.labels do
		label(folder, string.upper(row.group), origin + Vector3.new(row.x, 10, row.z - 3), 4, 400)
	end

	local rigged = {}
	for _, spot in plan.spots do
		local model = ModelLibrary.get(spot.name)
		if model then
			local position = origin + Vector3.new(spot.x, 0, spot.z)
			place(model, position)
			model.Parent = folder
			ModelRig.rig(model)
			local _, size = model:GetBoundingBox()
			label(folder, spot.name, position + Vector3.new(0, size.Y + 1.5, 0), 1, 60)
			table.insert(rigged, { model = model, parts = ModelRig.movingParts(model) })
		end
	end
	folder.Parent = workspace

	if settings.ShowroomSpawnPlayers then
		local function moveCharacter(character: Model)
			task.defer(function()
				character:PivotTo(CFrame.new(spawnPoint))
			end)
		end
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(moveCharacter)
		end)
		for _, player in Players:GetPlayers() do
			if player.Character then
				moveCharacter(player.Character)
			end
			player.CharacterAdded:Connect(moveCharacter)
		end
	end

	if settings.ShowroomDemoMotion then
		while true do
			local t = (1 - math.cos(os.clock() / DEMO_PERIOD * math.pi * 2)) / 2
			for _, item in rigged do
				for _, partName in item.parts do
					ModelRig.setPose(item.model, partName, t)
				end
			end
			task.wait(0.1)
		end
	end
end

return Showroom
