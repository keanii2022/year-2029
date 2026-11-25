-- PA events heard on the client: the chime (pa_glitch now and then), the line as a [PA] subtitle,
-- the recorded clip once there is one, and a faint arrow on the screen edge toward the spot for a
-- few seconds (same idea as the Callouts arrow, warmer and slower).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Hints = require(script.Parent.Hints)
local Music = require(script.Parent.Music)

local Settings = Config.Prizes.Pa
local MarkerSettings = Settings.Marker

type Marker = { frame: Frame, position: Vector3, shownAt: number }

local PaEvents = {}

local gui: ScreenGui
local markers: { Marker } = {}

local function playFlat(soundName: string)
	local id = ModelLibrary.soundId(soundName)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Settings.Volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function bar(parent: Frame, x: number, rotation: number)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(x, 0.5)
	line.Size = UDim2.new(0.55, 0, 0, 3)
	line.Rotation = rotation
	line.BorderSizePixel = 0
	line.BackgroundColor3 = MarkerSettings.Color
	line.BackgroundTransparency = MarkerSettings.Transparency
	line.Parent = parent
end

local function addMarker(position: Vector3)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(MarkerSettings.Size, MarkerSettings.Size)
	frame.BackgroundTransparency = 1
	bar(frame, 0.32, -45)
	bar(frame, 0.68, 45)
	frame.Parent = gui
	table.insert(markers, { frame = frame, position = position, shownAt = os.clock() })
end

local function updateMarkers()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for index = #markers, 1, -1 do
		local marker = markers[index]
		local age = now - marker.shownAt
		if age >= MarkerSettings.Seconds or not camera then
			marker.frame:Destroy()
			table.remove(markers, index)
			continue
		end
		local relative = camera.CFrame:PointToObjectSpace(marker.position)
		local angle = math.atan2(relative.X, -relative.Z)
		local viewport = camera.ViewportSize
		marker.frame.Position = UDim2.fromOffset(
			viewport.X / 2 + math.sin(angle) * viewport.X * MarkerSettings.Inset,
			viewport.Y / 2 - math.cos(angle) * viewport.Y * MarkerSettings.Inset
		)
		marker.frame.Rotation = math.deg(angle)
		local fadeStart = MarkerSettings.Seconds - MarkerSettings.FadeSeconds
		local fade = math.clamp((age - fadeStart) / MarkerSettings.FadeSeconds, 0, 1)
		local transparency = MarkerSettings.Transparency + (1 - MarkerSettings.Transparency) * fade
		for _, line in marker.frame:GetChildren() do
			if line:IsA("Frame") then
				line.BackgroundTransparency = transparency
			end
		end
	end
end

local function onEvent(event: any)
	if type(event) ~= "table" or type(event.text) ~= "string" then
		return
	end
	playFlat(Settings.Sounds.Chime)
	task.wait(Settings.ChimeLead)
	if type(event.voice) == "string" then
		Music.playVoiceLine(event.voice)
	end
	Hints.flash("pa_event", Settings.Prefix .. event.text, Settings.SubtitleSeconds)
	if typeof(event.position) == "Vector3" then
		addMarker(event.position)
	end
	if event.glitch then
		task.wait(Settings.SubtitleSeconds * 0.6)
		playFlat(Settings.Sounds.Glitch)
	end
end

function PaEvents.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "PaEvents"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
end

function PaEvents.Start()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Net.event("PaEvent").OnClientEvent:Connect(onEvent)
	RunService.RenderStepped:Connect(updateMarkers)
end

return PaEvents
