-- The SOUND panel: Master, Music, Effects and Voice sliders and the Gentler scares toggle, saved
-- per player (server Systems/AudioSettings). Opens with the Audio key or from the record panel.
-- Mouse and touch tap the bar or the - and + buttons; a controller walks the rows with the D-pad
-- up and down, left and right adjust, Cross flips the toggle, Circle closes.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Input)

local Settings = Config.Mix
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local ROW = Color3.fromRGB(30, 30, 33)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local ROW_HEIGHT = 44 -- smallest comfortable tap
local PAD_ACTION = "AudioSettingsPad"
local SLIDERS = {
	{ key = "master", label = "MASTER" },
	{ key = "music", label = "MUSIC" },
	{ key = "effects", label = "EFFECTS" },
	{ key = "voice", label = "VOICE" },
}

type Slider = { row: TextButton, fill: Frame, value: TextLabel }

local AudioSettings = {}

local gui: ScreenGui
local panel: Frame
local closeButton: TextButton
local gentleRow: TextButton
local sliders: { [string]: Slider } = {}
local rowKeys: { [Instance]: string } = {}
local audio = Mix.audio()
local dirty = false
local remote: RemoteEvent

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function refresh()
	for key, slider in sliders do
		local level = (audio :: any)[key]
		slider.fill.Size = UDim2.fromScale(level, 1)
		slider.value.Text = `{math.round(level * 100)}%`
	end
	gentleRow.Text = if audio.gentle then "GENTLER SCARES   ON" else "GENTLER SCARES   OFF"
	gentleRow.TextColor3 = if audio.gentle then TEXT else Color3.fromRGB(150, 146, 136)
end

local function changed()
	dirty = true
	Mix.setAudio(audio)
	refresh()
end

local function setLevel(key: string, level: number)
	local step = Settings.SliderStep;
	(audio :: any)[key] = math.clamp(math.round(level / step) * step, 0, 1)
	changed()
end

local function nudge(key: string, direction: number)
	setLevel(key, (audio :: any)[key] + direction * Settings.SliderStep)
end

local function toggleGentle()
	audio.gentle = not audio.gentle
	changed()
end

local function onPad(
	_action: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.ButtonB then
		AudioSettings.close()
		return Enum.ContextActionResult.Sink
	end
	local selected = GuiService.SelectedObject
	local key = selected and rowKeys[selected]
	if key then
		nudge(key, if input.KeyCode == Enum.KeyCode.DPadRight then 1 else -1)
	elseif selected == gentleRow then
		toggleGentle()
	end
	return Enum.ContextActionResult.Sink
end

function AudioSettings.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

function AudioSettings.open()
	panel.Visible = true
	-- A visible modal button frees the mouse while the panel is up
	closeButton.Modal = true
	ContextActionService:BindActionAtPriority(
		PAD_ACTION,
		onPad,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.ButtonB
	)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = sliders.master.row
	end
	refresh()
end

function AudioSettings.close()
	panel.Visible = false
	closeButton.Modal = false
	ContextActionService:UnbindAction(PAD_ACTION)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if dirty then
		dirty = false
		remote:FireServer(audio)
	end
end

local function sideButton(text: string, x: number, parent: Instance, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(x, 0.5),
		Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Selectable = false, -- the controller adjusts from the row itself
	}, parent)
	b.Activated:Connect(onClick)
	return b
end

local function buildSlider(order: number, key: string, text: string, parent: Instance)
	local row = make("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromScale(0.25, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	sideButton("-", 0.27, row, function()
		nudge(key, -1)
	end)
	local bar = make("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.27, ROW_HEIGHT, 0.5, 0),
		Size = UDim2.new(0.5, -ROW_HEIGHT * 1.5, 0, 10),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
	}, row)
	local fill = make("Frame", { BackgroundColor3 = SPRAY_RED, BorderSizePixel = 0 }, bar)
	-- Tap or click along the bar to jump there
	bar.Activated:Connect(function(inputObject: InputObject)
		local width = bar.AbsoluteSize.X
		if width > 0 then
			setLevel(key, (inputObject.Position.X - bar.AbsolutePosition.X) / width)
		end
	end)
	sideButton("+", 0.77, row, function()
		nudge(key, 1)
	end)
	local value = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.fromScale(0.12, 1),
		BackgroundTransparency = 1,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	sliders[key] = { row = row, fill = fill, value = value }
	rowKeys[row] = key
end

local function build()
	gui = make("ScreenGui", {
		Name = "AudioSettings",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
	})
	Input.markMenu(gui)
	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	}, panel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, panel)
	make("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }, panel)
	make("TextLabel", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "SOUND",
		TextColor3 = SPRAY_RED,
		Font = Enum.Font.PermanentMarker,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	for index, slider in SLIDERS do
		buildSlider(index, slider.key, slider.label, panel)
	end
	gentleRow = make("TextButton", {
		LayoutOrder = #SLIDERS + 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, panel)
	gentleRow.Activated:Connect(toggleGentle)
	make("TextLabel", {
		LayoutOrder = #SLIDERS + 2,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "Gentler scares: robot screams and alarms play softer, no jump stingers.",
		TextColor3 = Color3.fromRGB(150, 146, 136),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	closeButton = make("TextButton", {
		LayoutOrder = #SLIDERS + 3,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		Text = "DONE",
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, panel)
	closeButton.Activated:Connect(AudioSettings.close)
	refresh()
end

function AudioSettings.Init()
	build()
end

function AudioSettings.Start()
	Mix.startClient()
	gui.Parent = player:WaitForChild("PlayerGui")
	remote = Net.event("AudioSettings")
	remote.OnClientEvent:Connect(function(saved)
		if type(saved) == "table" and not dirty then
			audio = Mix.audio()
			for key, value in saved do
				if type((audio :: any)[key]) == type(value) then
					(audio :: any)[key] = value
				end
			end
			Mix.setAudio(audio)
			refresh()
		end
	end)
	remote:FireServer(nil)
	Input.bind("Audio", function(began)
		if not began then
			return
		end
		if AudioSettings.isOpen() then
			AudioSettings.close()
		else
			AudioSettings.open()
		end
	end)
end

return AudioSettings
