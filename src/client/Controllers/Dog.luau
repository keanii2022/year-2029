-- The dog, client side: trust hearts over its head that only you see (from your "DogTrust" attribute),
-- and the right prompt for you: strangers get Feed, its owner gets the follow / guard / stay command.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogTrust = require(ReplicatedStorage.Shared.Logic.DogTrust)

local settings = Config.Dog
local player = Players.LocalPlayer

local HEART_FULL = "♥"
local HEART_EMPTY = "♡"

local Dog = {}

local hearts: { [Model]: TextLabel } = {}

local function heartText(): (string, boolean)
	local trust = player:GetAttribute("DogTrust")
	if type(trust) ~= "number" or trust <= 0 then
		return "", false
	end
	local filled = DogTrust.hearts(trust, settings.Trust, settings.Hearts.Count)
	return string.rep(HEART_FULL, filled) .. string.rep(HEART_EMPTY, settings.Hearts.Count - filled), true
end

local function refreshHearts()
	local text, visible = heartText()
	for _, label in hearts do
		label.Text = text
		local gui = label.Parent
		if gui and gui:IsA("BillboardGui") then
			gui.Enabled = visible
		end
	end
end

-- Prompts are made on the server; Enabled is only flipped here, so each player sees just their own.
local function refreshPrompts(model: Model)
	local isOwner = model:GetAttribute("Owner") == player.UserId
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			if descendant.Name == "Feed" then
				descendant.Enabled = not isOwner
			elseif descendant.Name == "Command" then
				descendant.Enabled = isOwner
			end
		end
	end
end

local function onDogAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	local head = model:FindFirstChild("Head", true) or model.PrimaryPart
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TrustHearts"
		gui.Size = UDim2.fromOffset(120, 28)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
		gui.MaxDistance = settings.Hearts.Distance
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = settings.Hearts.Color
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		gui.Parent = head
		hearts[model] = label
	end
	refreshHearts()
	refreshPrompts(model)
	model:GetAttributeChangedSignal("Owner"):Connect(function()
		refreshPrompts(model)
	end)
	model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			refreshPrompts(model)
		end
	end)
end

function Dog.Start()
	CollectionService:GetInstanceAddedSignal(settings.Tag):Connect(onDogAdded)
	CollectionService:GetInstanceRemovedSignal(settings.Tag):Connect(function(instance)
		hearts[instance :: Model] = nil
	end)
	for _, instance in CollectionService:GetTagged(settings.Tag) do
		task.spawn(onDogAdded, instance)
	end
	player:GetAttributeChangedSignal("DogTrust"):Connect(refreshHearts)
end

return Dog
