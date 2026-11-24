-- The backpack: everything you carry as tiles, same look as the container panel. Triangle, B or
-- the phone's BAG button opens it; picking a tile puts that in your hands and closes it straight
-- away, so it's a quick grab, not a menu. Triangle / Circle / B / the X close it without picking.
-- Things the hotbar can't hold (cells, parts) show dimmed so you still see what you've got.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Net = require(ReplicatedStorage.Shared.Net)
local Glyphs = require(script.Parent.Glyphs)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)

local hints = Config.Hints
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TILE = Color3.fromRGB(30, 30, 33)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local TILE_SIZE = Vector2.new(112, 64)
local COLUMNS = 4
local GAP = 6
local PAD_ACTION = "BackpackPad"
local SLIDE = 16
local OPEN_TIME = 0.14

local Backpack = {}

local gui: ScreenGui
local panel: Frame
local closeButton: TextButton
local grid: ScrollingFrame
local empty: TextLabel
local footer: Frame
local open = false

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = TEXT
	text.Font = Enum.Font.GothamBold
	text.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

local function rounded(object: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = object
end

-- Whether some hotbar slot can hold this item
local function holdable(id: string): boolean
	if Config.Guns.Blasters[id] then
		return true
	end
	local use = Config.Supplies.Uses[id]
	for _, def in Config.Hotbar.Slots do
		if (def.kind and use and use.kind == def.kind) or (def.items and table.find(def.items, id)) then
			return true
		end
	end
	return false
end

local function clear()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function tile(
	index: number,
	name: string,
	count: number,
	selected: boolean,
	pick: (() -> ())?
): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.AutoButtonColor = pick ~= nil
	button.Selectable = pick ~= nil
	button.BorderSizePixel = 0
	button.BackgroundColor3 = TILE
	button.BackgroundTransparency = if pick then 0 else 0.4
	button.Text = ""
	rounded(button)
	local dim = if pick then 0 else 0.55
	label({
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 1, -28),
		Text = name,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = dim,
	}, button)
	label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.new(1, -16, 0, 20),
		Text = if pick then (if count > 1 then `x{count}` else "") else `x{count}  in bag`,
		TextSize = if pick then 16 else 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = dim,
	}, button)
	if selected then
		local stroke = Instance.new("UIStroke")
		stroke.Color = TEXT
		stroke.Thickness = 2
		stroke.Transparency = 0.1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
	end
	if pick then
		button.Activated:Connect(pick)
	end
	button.Parent = grid
	return button
end

local function refillFooter()
	Glyphs.fill(
		footer,
		hints.BackpackFooter,
		{ size = 18, textSize = 12, color = Color3.fromRGB(150, 146, 136) }
	)
end

local function refresh(): TextButton?
	clear()
	local current = Hotbar.selected()
	local first: TextButton? = nil
	local index = 0
	for _, slot in Hotbar.slots() do
		index += 1
		local def = slot.item and InventoryItems[slot.item]
		local name = if slot.count <= 1 and def then def.name else slot.label
		local selected = current ~= nil and current.id == slot.id
		local button = tile(index, name, slot.count, selected, function()
			Hotbar.select(slot.id)
			Backpack.close()
		end)
		if selected or not first then
			first = button
		end
	end
	local loose = 0
	for _, stack in Hotbar.bag() do
		if not holdable(stack.id) then
			index += 1
			loose += 1
			local def = InventoryItems[stack.id]
			tile(index, if def then def.name else stack.id, stack.count, false, nil)
		end
	end
	empty.Visible = index <= 1 and loose == 0
	return first
end

local function onPad(_action: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		Backpack.close()
	end
	return Enum.ContextActionResult.Sink
end

function Backpack.close()
	if not open then
		return
	end
	open = false
	panel.Visible = false
	closeButton.Modal = false
	ContextActionService:UnbindAction(PAD_ACTION)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function show(device: Input.Device?)
	if open or player:GetAttribute("CarrySpeedMultiplier") ~= nil then
		return
	end
	open = true
	refillFooter()
	local first = refresh()
	panel.Visible = true
	-- A visible modal button frees the mouse while the panel is up, even in first person
	closeButton.Modal = true
	-- Triangle and Circle close it; while it's up the pad works the panel only
	ContextActionService:BindActionAtPriority(
		PAD_ACTION,
		onPad,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonY,
		Enum.KeyCode.ButtonB
	)
	-- The selection also tells Input to leave the pad to this panel, so Triangle can't reopen it
	if device == "Gamepad" or Glyphs.device() == "Gamepad" then
		GuiService.SelectedObject = first or closeButton
	end
	panel.Position = UDim2.new(0.5, 0, 0.5, SLIDE)
	panel.BackgroundTransparency = 0.6
	TweenService:Create(
		panel,
		TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.08 }
	):Play()
end

function Backpack.toggle(device: Input.Device?)
	if open then
		Backpack.close()
	else
		show(device)
	end
end

local function build()
	local width = COLUMNS * TILE_SIZE.X + (COLUMNS - 1) * GAP + 40
	local gridHeight = 3 * TILE_SIZE.Y + 2 * GAP
	panel = Instance.new("Frame")
	panel.Name = "Backpack"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(width, gridHeight + 96)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	rounded(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -80, 0, 24),
		Text = hints.BackpackTitle,
		TextSize = 16,
	}, panel)
	closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 10)
	closeButton.Size = UDim2.fromOffset(36, 36)
	closeButton.BorderSizePixel = 0
	closeButton.BackgroundColor3 = TILE
	closeButton.TextColor3 = TEXT
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 14
	closeButton.Text = "X"
	rounded(closeButton)
	closeButton.Activated:Connect(Backpack.close)
	closeButton.Parent = panel

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(20, 50)
	divider.Size = UDim2.new(1, -40, 0, 2)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = SPRAY_RED
	divider.BackgroundTransparency = 0.4
	divider.Parent = panel

	grid = Instance.new("ScrollingFrame")
	grid.BorderSizePixel = 0
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 4
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Position = UDim2.fromOffset(20, 60)
	grid.Size = UDim2.new(1, -36, 0, gridHeight)
	grid.SelectionGroup = true
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = panel

	empty = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -40),
		Size = UDim2.new(1, -40, 0, 18),
		Text = hints.BackpackEmpty,
		TextSize = 13,
		TextTransparency = 0.4,
		Visible = false,
	}, panel)

	footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 20, 1, -8)
	footer.Size = UDim2.new(1, -40, 0, 24)
	footer.BackgroundTransparency = 1
	footer.Parent = panel

	-- Phones held sideways are short; shrink to fit
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / width, (viewport.Y - 24) / panel.Size.Y.Offset)
		end
	end
	fit()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fit)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

function Backpack.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Backpack"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	build()
end

function Backpack.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	Input.bind("Backpack", function(began, device)
		if began then
			Backpack.toggle(device)
		end
	end)
	local function refreshIfOpen()
		if open then
			task.defer(refresh)
		end
	end
	Hotbar.onChanged(refreshIfOpen)
	Net.event("InventoryChanged").OnClientEvent:Connect(refreshIfOpen)
	Glyphs.onChanged(function()
		if open then
			refillFooter()
		end
	end)
	player:GetAttributeChangedSignal("CarrySpeedMultiplier"):Connect(Backpack.close)
	player.CharacterRemoving:Connect(Backpack.close)
end

return Backpack
