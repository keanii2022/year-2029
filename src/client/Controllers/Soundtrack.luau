-- Plays Keani's soundtrack: with the lights on, the day and dawn loops take turns (one all the way
-- through, then the other); the night loop in the dark; the installation loop whenever you're close
-- to one of the dark halls, whatever the time. One loop at a time, crossfading. Silent until uploaded.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)

local settings = Config.Soundtrack
local player = Players.LocalPlayer

local Soundtrack = {}

local loops: { [string]: Sound } = {}
local lightsTrack = "Day"
local swapAt = 0

local function nearInstallation(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = ReplicatedStorage:FindFirstChild("Installations")
	if not root or not folder then
		return false
	end
	for _, marker in folder:GetChildren() do
		if marker:IsA("Vector3Value") then
			local reach = (marker:GetAttribute("Radius") or 0) + settings.InstallationPadding
			local offset = root.Position - marker.Value
			if math.abs(offset.X) < reach and math.abs(offset.Z) < reach then
				return true
			end
		end
	end
	return false
end

local function wanted(): string
	if nearInstallation() then
		return "Installation"
	end
	local phase = ReplicatedStorage:GetAttribute("Phase") or "Day"
	if phase == "Night" then
		return "Night"
	end
	-- Lights on: day and dawn take turns, a full pass each
	if os.clock() >= swapAt then
		lightsTrack = if lightsTrack == "Day" then "Dawn" else "Day"
		swapAt = os.clock() + settings.RotateSeconds
	end
	return lightsTrack
end

local function step(dt: number)
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local active = wanted()
	local fade = dt / settings.CrossfadeSeconds
	for name, sound in loops do
		local target = if name == active then settings.Volume[name] else 0
		if (name == "Day" or name == "Dawn") and phase == "Siren" then
			target *= settings.SirenDuck
		end
		local change = fade * math.max(settings.Volume[name], 0.01)
		if sound.Volume < target then
			sound.Volume = math.min(target, sound.Volume + change)
		elseif sound.Volume > target then
			sound.Volume = math.max(target, sound.Volume - change)
		end
		if sound.Volume > 0 and not sound.IsPlaying then
			sound:Play()
		elseif sound.Volume <= 0 and sound.IsPlaying then
			sound:Stop()
		end
	end
end

function Soundtrack.Start()
	for name, soundName in settings.Loops do
		local id = ModelLibrary.soundId(soundName)
		if id then
			local sound = Instance.new("Sound")
			sound.Name = "Soundtrack" .. name
			sound.SoundId = id
			sound.Looped = true
			sound.Volume = 0
			sound.Parent = SoundService
			loops[name] = sound
		end
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			step(acc)
			acc = 0
		end
	end)
end

return Soundtrack
