-- On-screen help so nobody has to guess the keys: short hint lines under the crosshair that other
-- controllers set and clear (Hints.set("grab", "[F] Grab")), a controls card on H, and a few
-- first-time nudges (the controls card itself, the flashlight when it gets dark).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local settings = Config.Hints
local player = Players.LocalPlayer

local Hints = {}

local lines: { [string]: { text: string, order: number } } = {}
local list: Frame
local card: Frame
local flashlightUsed = false

local function redraw()
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local sorted = {}
	for id, line in lines do
		table.insert(sorted, { id = id, text = line.text, order = line.order })
	end
	table.sort(sorted, function(a, b)
		return a.order < b.order
	end)
	for index, line in sorted do
		local label = Instance.new("TextLabel")
		label.Name = line.id
		label.LayoutOrder = index
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 26)
		label.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.fromRGB(236, 232, 222)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 16
		label.Text = "  " .. line.text .. "  "
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		label.Parent = list
	end
end

-- Shows a hint line, or clears it with text = nil. Lower order sits higher.
function Hints.set(id: string, text: string?, order: number?)
	local current = lines[id]
	if text == nil then
		if current then
			lines[id] = nil
			redraw()
		end
		return
	end
	if current and current.text == text then
		return
	end
	lines[id] = { text = text, order = order or 10 }
	redraw()
end

-- A hint's wording from Config.Hints, so every controller shows the same text
function Hints.text(name: string): string
	return settings[name]
end

-- Shows a hint for a few seconds, then clears it
function Hints.flash(id: string, text: string, seconds: number?)
	Hints.set(id, text, 0)
	task.delay(seconds or 4, function()
		if lines[id] and lines[id].text == text then
			Hints.set(id, nil)
		end
	end)
end

local function buildCard(parent: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Controls"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(520, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 20), UDim.new(0, 20)
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.PermanentMarker
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(190, 30, 26)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = settings.CardTitle
	title.Parent = frame
	for index, row in settings.Controls do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.Font = if row[2] == "" then Enum.Font.GothamBold else Enum.Font.Gotham
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if row[2] == ""
			then Color3.fromRGB(150, 146, 136)
			else Color3.fromRGB(236, 232, 222)
		label.RichText = true
		label.Text = if row[2] == "" then row[1] else `<b>{row[1]}</b>   {row[2]}`
		label.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function isDark(): boolean
	local phase = ReplicatedStorage:GetAttribute("Phase")
	return phase == "Night" or phase == "Siren"
end

local function watchFlashlight()
	while true do
		task.wait(1)
		if player:GetAttribute("FlashlightOn") == true then
			flashlightUsed = true
		end
		if isDark() and player:GetAttribute("FlashlightOn") ~= true and not flashlightUsed then
			Hints.set("flashlight", settings.FlashlightHint, 1)
		else
			Hints.set("flashlight", nil)
		end
	end
end

function Hints.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hints"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	list = Instance.new("Frame")
	list.Name = "Lines"
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0.5, 40)
	list.Size = UDim2.fromOffset(600, 200)
	list.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = gui

	card = buildCard(gui)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == settings.CardKey then
			card.Visible = not card.Visible
			Hints.set("controls", nil)
		end
	end)
	Hints.flash("controls", settings.StartHint, settings.StartHintSeconds)
	task.spawn(watchFlashlight)
end

return Hints
