-- Flashlights. The Flashlight action (Input) asks the server to toggle; the server sets the player's
-- FlashlightOn attribute and every client draws the beams from that. Your own beam follows the
-- camera so it points where you look; other players' beams shine from their heads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Input)

local Settings = Config.DayNight.Flashlight
local player = Players.LocalPlayer

local Flashlight = {}

local toggleRemote: RemoteEvent
local ownBeam: Part?
local otherBeams: { [Player]: SpotLight } = {}

local function makeLight(parent: Instance): SpotLight
	local light = Instance.new("SpotLight")
	light.Brightness = Settings.Brightness
	light.Range = Settings.Range
	light.Angle = Settings.Angle
	light.Color = Settings.Color
	light.Shadows = Settings.Shadows
	light.Face = Enum.NormalId.Front
	light.Parent = parent
	return light
end

local function click()
	local id = ModelLibrary.soundId(Config.DayNight.Sounds.FlashlightClick)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function setOwnBeam(on: boolean)
	if on and not ownBeam then
		local part = Instance.new("Part")
		part.Name = "FlashlightBeam"
		part.Size = Vector3.one * 0.2
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		makeLight(part)
		part.Parent = workspace.CurrentCamera
		ownBeam = part
	elseif not on and ownBeam then
		ownBeam:Destroy()
		ownBeam = nil
	end
end

local function updateOther(other: Player)
	local existing = otherBeams[other]
	local head = other.Character and other.Character:FindFirstChild("Head")
	local wanted = other:GetAttribute("FlashlightOn") == true and head ~= nil
	if existing and (not wanted or existing.Parent ~= head) then
		existing:Destroy()
		otherBeams[other] = nil
	end
	if wanted and not otherBeams[other] then
		otherBeams[other] = makeLight(head :: Instance)
	end
end

local function watch(other: Player)
	if other == player then
		player:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
			setOwnBeam(player:GetAttribute("FlashlightOn") == true)
			click()
		end)
		setOwnBeam(player:GetAttribute("FlashlightOn") == true)
		return
	end
	other:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
		updateOther(other)
	end)
	other.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head")
		updateOther(other)
	end)
	updateOther(other)
end

local function onToggle(began: boolean)
	if began then
		toggleRemote:FireServer(player:GetAttribute("FlashlightOn") ~= true)
	end
end

function Flashlight.Start()
	toggleRemote = Net.event("FlashlightToggle")
	Input.bind("Flashlight", onToggle)

	Players.PlayerAdded:Connect(watch)
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerRemoving:Connect(function(other)
		otherBeams[other] = nil
	end)

	RunService:BindToRenderStep("FlashlightBeam", Enum.RenderPriority.Camera.Value + 1, function()
		if ownBeam then
			ownBeam.CFrame = workspace.CurrentCamera.CFrame
		end
	end)
end

return Flashlight
