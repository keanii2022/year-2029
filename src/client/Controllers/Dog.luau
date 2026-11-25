-- The dog, client side: trust hearts over its head that only you see (from your "DogTrust" attribute),
-- and the right prompt for you: strangers get Feed, its owner gets the follow / guard / stay command.
-- Also plays the untamed dog's far-off calls (muffled by your distance, with warehouse echo), shows
-- the crouch hint the first time a wary dog watches you, and tells the server when food is in hand.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogCalls = require(ReplicatedStorage.Shared.Logic.DogCalls)
local DogTrust = require(ReplicatedStorage.Shared.Logic.DogTrust)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)

local settings = Config.Dog
local calls = settings.Calls
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

local function soundIdFor(key: string): string?
	for _, name in DogCalls.soundNames(key, settings.Sounds, settings.SoundFallbacks) do
		local id = ModelLibrary.soundId(name)
		if id then
			return id
		end
	end
	return nil
end

-- One far-off call from where the server bounced it. The muffle is set from this listener's distance.
local function playCall(key: any, position: any)
	if type(key) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	local id = soundIdFor(key)
	local camera = workspace.CurrentCamera
	if not id or not camera then
		return
	end
	local spot = Instance.new("Attachment")
	spot.WorldPosition = position
	spot.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = calls.Volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance, sound.RollOffMaxDistance = calls.RollOff[1], calls.RollOff[2]
	local high, mid = DogCalls.muffle((camera.CFrame.Position - position).Magnitude, calls)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain, eq.MidGain, eq.HighGain = 0, mid, high
	eq.Parent = sound
	local reverb = Instance.new("ReverbSoundEffect")
	for property, value in calls.Reverb do
		(reverb :: any)[property] = value
	end
	reverb.Parent = sound
	local echo = Instance.new("EchoSoundEffect")
	for property, value in calls.Echo do
		(echo :: any)[property] = value
	end
	echo.Parent = sound
	sound.Parent = spot
	-- part of the warehouse's background, so it dips under the PA and gunfights like the rest of it
	Mix.route(sound, "Ambience")
	sound:Play()
	sound.Ended:Once(function()
		spot:Destroy()
	end)
	task.delay(30, function()
		if spot.Parent then
			spot:Destroy()
		end
	end)
end

local function watchFor(model: Model)
	local function check()
		if model:GetAttribute("Watching") == player.UserId then
			Hints.nudge("dog", Config.Hints.DogNudge)
		end
	end
	model:GetAttributeChangedSignal("Watching"):Connect(check)
	check()
end

local function onDogAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	watchFor(model)
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

	Net.event("DogCall").OnClientEvent:Connect(playCall)
	local holdingRemote = Net.event("DogHoldingFood")
	local holding = false
	Hotbar.onChanged(function()
		local slot = Hotbar.selected()
		local now = slot ~= nil and slot.id == "Food" and not slot.empty
		if now ~= holding then
			holding = now
			holdingRemote:FireServer(holding)
		end
	end)
end

return Dog
