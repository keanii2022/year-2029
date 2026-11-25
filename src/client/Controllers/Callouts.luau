-- Callouts on Q / Circle / CALL. A tap asks the server to play your selected call; holding switches
-- to the next one (the phone also has a small cycle button). A call you hear plays from the caller,
-- cuts off their last one, and puts a faint arrow on the edge of the screen pointing toward it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Input = require(script.Parent.Input)

local Settings = Config.Callouts
local player = Players.LocalPlayer

local Callouts = {}

type Marker = { frame: Frame, position: Vector3, shownAt: number }

local gui: ScreenGui
local label: TextLabel
local markers: { Marker } = {}
local calloutRemote: RemoteEvent
local selected = 0
local lastCallAt = -math.huge
local labelShownAt = -math.huge
local pressCount = 0
local switchedThisPress = false
local pressing = false
-- What each caller is saying right now, so their next call cuts it off
local playing: { [Player]: Instance } = {}

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

local function stopCall(speaker: Player)
	local old = playing[speaker]
	playing[speaker] = nil
	if old then
		old:Destroy()
	end
end

-- Plays from the caller's head so it moves with them; a holder part stands in if the head isn't here.
local function playCall(speaker: Player, index: number, position: Vector3)
	stopCall(speaker)
	local id = ModelLibrary.soundId(Settings.Sounds[index + 1])
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = if speaker == player then Settings.OwnVolume else Settings.Volume
	sound.RollOffMinDistance = Settings.RollOff[1]
	sound.RollOffMaxDistance = Settings.RollOff[2]
	local character = speaker.Character
	local head = character and character:FindFirstChild("Head")
	local owner: Instance = sound
	if head and head:IsA("BasePart") then
		sound.Parent = head
	else
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		holder.Position = position
		sound.Parent = holder
		holder.Parent = workspace
		owner = holder
	end
	playing[speaker] = owner
	sound.Ended:Connect(function()
		if playing[speaker] == owner then
			stopCall(speaker)
		end
	end)
	sound:Play()
end

local function onHeard(speaker: Player, index: number, position: Vector3)
	if not VoiceLines.validCallout(index, #Settings.Sounds) then
		return
	end
	playCall(speaker, index, position)
	if speaker ~= player then
		table.insert(markers, { frame = buildMarker(), position = position, shownAt = os.clock() })
	end
end

local function showLabel()
	label.Text = `CALL {selected + 1} / {#Settings.Sounds}`
	labelShownAt = os.clock()
end

local function switchCall()
	selected = VoiceLines.nextCallout(selected, #Settings.Sounds)
	showLabel()
end

local function call()
	-- The server enforces the cooldown; this only saves sending presses it would drop.
	if os.clock() - lastCallAt >= Settings.Cooldown then
		lastCallAt = os.clock()
		calloutRemote:FireServer(selected)
	end
end

-- Tap calls on release; still down after HoldTime switches instead, and the release does nothing.
-- Releases always arrive, even for a press a menu swallowed, so only a press seen here can call.
local function onCalloutButton(began: boolean)
	if began then
		pressing = true
		pressCount += 1
		local press = pressCount
		switchedThisPress = false
		task.delay(Settings.HoldTime, function()
			if press == pressCount and Input.isDown("Callout") then
				switchedThisPress = true
				switchCall()
			end
		end)
	elseif pressing then
		pressing = false
		if not switchedThisPress then
			call()
		end
	end
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
	local fadeStart = Settings.LabelTime - Settings.LabelFadeTime
	label.TextTransparency = math.clamp((now - labelShownAt - fadeStart) / Settings.LabelFadeTime, 0, 1)
	label.TextStrokeTransparency = 0.5 + label.TextTransparency * 0.5
end

function Callouts.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Callouts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	label = Instance.new("TextLabel")
	label.Name = "Selected"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.7)
	label.Size = UDim2.fromOffset(160, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Settings.MarkerColor
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.Parent = gui
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Callouts.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	calloutRemote = Net.event("Callout")
	Net.event("CalloutHeard").OnClientEvent:Connect(onHeard)
	Input.bind("Callout", onCalloutButton)
	Input.bind("CalloutNext", function(began)
		if began then
			switchCall()
		end
	end)
	Players.PlayerRemoving:Connect(stopCall)
	RunService.RenderStepped:Connect(updateMarkers)
end

return Callouts
