-- Callouts on Q / Circle / CALL. A tap asks the server to play your selected call; holding opens a
-- wheel of the calls by name to pick from (stick, D-pad, mouse, 1-7 or a tap). A call you hear plays
-- from the caller, cuts off their last one, and puts a faint arrow on the edge of the screen
-- pointing toward it.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Glyphs = require(script.Parent.Glyphs)
local Input = require(script.Parent.Input)

local Settings = Config.Callouts
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local WHEEL_ACTION = "CalloutWheel"
local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
}
local DPAD_STEPS = {
	[Enum.KeyCode.DPadRight] = 1,
	[Enum.KeyCode.DPadDown] = 1,
	[Enum.KeyCode.DPadLeft] = -1,
	[Enum.KeyCode.DPadUp] = -1,
}

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
local openedThisPress = false
local pressing = false
local wheel: Frame
local footer: Frame
local slots: { TextButton } = {}
local wheelOpen = false
local highlighted = 0
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
	Mix.route(sound, "Voice")
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
	label.Text = Settings.Names[selected + 1]
	labelShownAt = os.clock()
end

local function paintSlots()
	for index, slot in slots do
		local on = index - 1 == highlighted
		slot.BackgroundTransparency = if on then 0.05 else 0.3
		slot.TextColor3 = if on then Glyphs.SprayRed else Glyphs.Text
		local stroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if on then Glyphs.SprayRed else Glyphs.Text
		stroke.Transparency = if on then 0.1 else 0.75
	end
end

local function highlight(index: number)
	highlighted = index
	paintSlots()
end

local function closeWheel()
	if not wheelOpen then
		return
	end
	wheelOpen = false
	wheel.Visible = false
	Input.setExclusive(nil)
	ContextActionService:UnbindAction(WHEEL_ACTION)
end

local function choose(index: number)
	selected = index
	closeWheel()
	showLabel()
end

-- Sinks what it reads, so the stick doesn't walk, Cross doesn't jump and the D-pad doesn't eat or
-- switch the flashlight behind the wheel.
local function onWheelInput(_, inputState: Enum.UserInputState, input: InputObject)
	local count = #Settings.Sounds
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		local pick = VoiceLines.calloutAt(input.Position.X, input.Position.Y, count, Settings.StickDeadZone)
		if pick then
			highlight(pick)
		end
	elseif inputState == Enum.UserInputState.Begin then
		local number = table.find(NUMBER_KEYS, input.KeyCode)
		local step = DPAD_STEPS[input.KeyCode]
		if number then
			highlight(number - 1)
		elseif step then
			highlight(VoiceLines.stepCallout(highlighted, step, count))
		elseif input.KeyCode == Enum.KeyCode.ButtonA then
			choose(highlighted)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function openWheel(device: Input.Device)
	wheelOpen = true
	highlight(selected)
	Glyphs.fill(footer, Config.Hints.CallWheelFooter, { device = device, size = 20 })
	wheel.Visible = true
	Input.setExclusive("Callout")
	local wheelKeys = { Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA }
	for key in DPAD_STEPS do
		table.insert(wheelKeys, key)
	end
	for _, key in NUMBER_KEYS do
		table.insert(wheelKeys, key)
	end
	-- Above Grab's carry keys, which hold the D-pad at High
	local priority = Enum.ContextActionPriority.High.Value + 1
	ContextActionService:BindActionAtPriority(
		WHEEL_ACTION,
		onWheelInput,
		false,
		priority,
		table.unpack(wheelKeys)
	)
end

local function call()
	-- The server enforces the cooldown; this only saves sending presses it would drop.
	if os.clock() - lastCallAt >= Settings.Cooldown then
		lastCallAt = os.clock()
		calloutRemote:FireServer(selected)
	end
end

-- Tap calls on release; still down after HoldTime opens the wheel instead. Letting go then picks
-- the highlighted call, except on a phone, where the wheel waits for a tapped name (tapping CALL
-- again shuts it). Releases always arrive, even for a press a menu swallowed, so only a press seen
-- here can call.
local function onCalloutButton(began: boolean, device: Input.Device)
	if began then
		if wheelOpen then
			closeWheel()
			pressing = false
			return
		end
		pressing = true
		pressCount += 1
		local press = pressCount
		openedThisPress = false
		task.delay(Settings.HoldTime, function()
			if press == pressCount and pressing and Input.isDown("Callout") then
				openedThisPress = true
				openWheel(device)
			end
		end)
	elseif pressing then
		pressing = false
		if wheelOpen then
			if device ~= "Touch" then
				choose(highlighted)
			end
		elseif not openedThisPress then
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

local function addCorner(radius: UDim, parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

-- Dark worn panels in a ring, call 1 at the top going clockwise, so the stick points straight at one
local function buildWheel()
	local radius = Settings.WheelRadius
	wheel = Instance.new("Frame")
	wheel.Name = "CallWheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromOffset(radius * 2 + 40, radius * 2 + 40)
	wheel.BackgroundColor3 = PANEL
	wheel.BackgroundTransparency = 0.45
	wheel.Visible = false
	addCorner(UDim.new(1, 0), wheel)
	wheel.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.fromOffset(120, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Glyphs.SprayRed
	title.Text = "CALLS"
	title.Parent = wheel

	local count = #Settings.Sounds
	for index = 1, count do
		local angle = (index - 1) / count * 2 * math.pi
		local slot = Instance.new("TextButton")
		slot.Name = `Call{index}`
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
		slot.Size = UDim2.fromOffset(124, 36)
		slot.BackgroundColor3 = PANEL
		slot.AutoButtonColor = false
		slot.Font = Enum.Font.GothamBold
		slot.TextSize = 14
		slot.Text = `{index}  {Settings.Names[index]}`
		-- A visible modal button frees the first-person mouse so it can hover the names
		slot.Modal = index == 1
		addCorner(UDim.new(0, 4), slot)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = slot
		slot.MouseEnter:Connect(function()
			highlight(index - 1)
		end)
		slot.Activated:Connect(function()
			choose(index - 1)
		end)
		slot.Parent = wheel
		slots[index] = slot
	end

	footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0.5, 0)
	footer.Position = UDim2.new(0.5, 0, 1, 12)
	footer.AutomaticSize = Enum.AutomaticSize.X
	footer.Size = UDim2.fromOffset(0, 24)
	footer.BackgroundTransparency = 1
	footer.Parent = wheel
end

function Callouts.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Callouts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Over the phone buttons (3), so a name on the wheel takes the tap instead of a button beneath it
	gui.DisplayOrder = 4
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
	buildWheel()
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Callouts.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	calloutRemote = Net.event("Callout")
	Net.event("CalloutHeard").OnClientEvent:Connect(onHeard)
	Input.bind("Callout", onCalloutButton)
	Players.PlayerRemoving:Connect(stopCall)
	-- An open wheel holds Input and the stick; dying with it up must not carry that into the next life
	player.CharacterRemoving:Connect(function()
		pressing = false
		closeWheel()
	end)
	RunService.RenderStepped:Connect(updateMarkers)
end

return Callouts
