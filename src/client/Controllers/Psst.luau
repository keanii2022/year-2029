-- Psst on Q / Circle / PSST: asks the server to whisper. A whisper you hear plays where it came
-- from and puts a faint arrow on the edge of the screen pointing toward it for a moment.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Input)

local Settings = Config.Psst
local player = Players.LocalPlayer

local Psst = {}

type Marker = { frame: Frame, position: Vector3, shownAt: number }

local gui: ScreenGui
local markers: { Marker } = {}
local psstRemote: RemoteEvent
local lastPsstAt = -math.huge

local function bar(parent: Frame, x: number, rotation: number)
	local line = Instance.new("Frame")
	line.Name = "Bar"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(x, 0.5)
	line.Size = UDim2.new(0.55, 0, 0, 3)
	line.Rotation = rotation
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Settings.MarkerColor
	line.BackgroundTransparency = Settings.MarkerTransparency
	line.Parent = parent
end

-- A "^" chevron; rotating its frame points it.
local function buildMarker(): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(Settings.MarkerSize, Settings.MarkerSize)
	frame.BackgroundTransparency = 1
	bar(frame, 0.32, -45)
	bar(frame, 0.68, 45)
	frame.Parent = gui
	return frame
end

local function playWhisper(position: Vector3?)
	local id = ModelLibrary.soundId(Settings.Sound)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	if not position then
		-- A sound under SoundService plays flat, with no position
		sound.Volume = Settings.OwnVolume
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 3)
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = position
	sound.Volume = Settings.Volume
	sound.RollOffMinDistance = Settings.RollOff[1]
	sound.RollOffMaxDistance = Settings.RollOff[2]
	sound.Parent = holder
	holder.Parent = workspace
	sound:Play()
	Debris:AddItem(holder, 3)
end

local function onHeard(speaker: Player, position: Vector3)
	if speaker == player then
		playWhisper(nil)
		return
	end
	playWhisper(position)
	table.insert(markers, { frame = buildMarker(), position = position, shownAt = os.clock() })
end

-- Straight ahead puts the arrow at the top of the screen pointing up; behind you, at the bottom.
local function updateMarkers()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for index = #markers, 1, -1 do
		local marker = markers[index]
		local age = now - marker.shownAt
		if age >= Settings.MarkerTime or not camera then
			marker.frame:Destroy()
			table.remove(markers, index)
		else
			local relative = camera.CFrame:PointToObjectSpace(marker.position)
			local angle = math.atan2(relative.X, -relative.Z)
			local viewport = camera.ViewportSize
			marker.frame.Position = UDim2.fromOffset(
				viewport.X / 2 + math.sin(angle) * viewport.X * Settings.MarkerInset,
				viewport.Y / 2 - math.cos(angle) * viewport.Y * Settings.MarkerInset
			)
			marker.frame.Rotation = math.deg(angle)
			local fadeStart = Settings.MarkerTime - Settings.MarkerFadeTime
			local fade = math.clamp((age - fadeStart) / Settings.MarkerFadeTime, 0, 1)
			local transparency = Settings.MarkerTransparency + (1 - Settings.MarkerTransparency) * fade
			for _, line in marker.frame:GetChildren() do
				if line:IsA("Frame") then
					line.BackgroundTransparency = transparency
				end
			end
		end
	end
end

function Psst.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Psst"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Psst.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	psstRemote = Net.event("Psst")
	Net.event("PsstHeard").OnClientEvent:Connect(onHeard)
	Input.bind("Psst", function(began)
		-- The server enforces the cooldown; this only saves sending presses it would drop.
		if began and os.clock() - lastPsstAt >= Settings.Cooldown then
			lastPsstAt = os.clock()
			psstRemote:FireServer()
		end
	end)
	RunService.RenderStepped:Connect(updateMarkers)
end

return Psst
