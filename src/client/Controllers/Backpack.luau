-- The bag: everything you carry as a grid of tiles with counts, and where you fill the hotbar's
-- quick slots. Triangle, B or the phone's BAG button opens it; Triangle / Circle / B / Esc / the X
-- close it. While it's up gameplay input stays off and the mouse is free.
--   Keyboard / mouse: hover an item and press 3 - 6, or drag it onto a quick slot; X drops it.
--   Gamepad: the stick or D-pad picks an item, Square steps the target quick slot, Cross puts it
--   there (Cross on the slot it already sits in takes it back to the bag), R1 drops it.
--   Touch (and mouse clicks): tap an item, then tap a quick slot; TO BAG and DROP act on it.
-- Dropping always takes a second press, so a gun never hits the floor by accident.
-- The server owns the quick slots (Systems/Inventory); this only asks via "QuickSlotRequest".
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local Net = require(ReplicatedStorage.Shared.Net)
local QuickSlots = require(ReplicatedStorage.Shared.Logic.QuickSlots)
local Glyphs = require(script.Parent.Glyphs)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)

local hints = Config.Hints
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TILE = Color3.fromRGB(30, 30, 33)
local TEXT = Color3.fromRGB(225, 222, 215)
local MUTED = Color3.fromRGB(150, 146, 136)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local TILE_SIZE = Vector2.new(104, 64)
local QUICK_SIZE = Vector2.new(84, 52)
local ACTION_SIZE = Vector2.new(84, 24)
local COLUMNS = 5
local ROWS_SHOWN = 4
local GAP = 6
local PAD_ACTION = "BackpackPad"
local SLIDE = 16
local OPEN_TIME = 0.14
local DRAG_START = 6 -- pixels the mouse moves before a press on a tile becomes a drag
-- A drag that ends over a button also counts as a click on it; ignore clicks this soon after
local DRAG_CLICK_GUARD = 0.1

local Backpack = {}

local gui: ScreenGui
local panel: Frame
local closeButton: TextButton
local grid: ScrollingFrame
local empty: TextLabel
local capacity: TextLabel
local status: TextLabel
local footer: Frame
local ghost: TextLabel
local requestRemote: RemoteEvent
local quickButtons: { TextButton } = {}
local open = false

local tiles: { [string]: TextButton } = {}
local pickedId: string? = nil
local hoveredId: string? = nil
local targetIndex = 1
local armedDrop: { id: string, untilTime: number }? = nil
local dragFrom: { id: string, at: Vector2 }? = nil
local dragging = false
local dragEndedAt = 0

-- Hotbar number of the first quick slot (HANDS and LIGHT come before it)
local firstQuickNumber = 1
for _, def in Config.Hotbar.Slots do
	if def.always then
		firstQuickNumber += 1
	end
end

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

local function outline(object: GuiObject, color: Color3, thickness: number)
	local stroke = object:FindFirstChild("Outline") :: UIStroke?
	if not stroke then
		local created = Instance.new("UIStroke")
		created.Name = "Outline"
		created.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		created.Parent = object
		stroke = created
	end
	local line = stroke :: UIStroke
	line.Color = color
	line.Thickness = thickness
	line.Enabled = thickness > 0
end

local function groupOf(itemId: string): string?
	return QuickSlots.groupOf(itemId, Config.Hotbar.Slots, Config.Supplies.Uses, Config.Guns.Blasters)
end

local function carried(): { [string]: boolean }
	return QuickSlots.carried(Hotbar.bag(), Config.Hotbar.Slots, Config.Supplies.Uses, Config.Guns.Blasters)
end

local function itemName(itemId: string): string
	local def = InventoryItems[itemId]
	return if def then def.name else itemId
end

local function say(text: string?)
	status.Text = text or ""
end

-- Into quick slot `index`, swapping with whatever is there; the slot it already sits in empties.
local function putInSlot(itemId: string, index: number)
	local group = groupOf(itemId)
	if not group then
		say(`{itemName(itemId)} stays in the bag`)
		return
	end
	if Hotbar.quick()[index] == group and carried()[group] then
		requestRemote:FireServer("clear", nil, index)
	else
		requestRemote:FireServer("put", itemId, index)
	end
	say(nil)
end

local function backToBag(itemId: string)
	local group = groupOf(itemId)
	local index = group and QuickSlots.find(Hotbar.quick(), group)
	if index then
		requestRemote:FireServer("clear", nil, index)
	end
end

local function drop(itemId: string)
	local now = os.clock()
	local armed = armedDrop
	if armed and armed.id == itemId and now < armed.untilTime then
		armedDrop = nil
		if pickedId == itemId then
			pickedId = nil
		end
		requestRemote:FireServer("drop", itemId)
		say(nil)
		return
	end
	armedDrop = { id = itemId, untilTime = now + hints.BackpackDropSeconds }
	say(`{itemName(itemId)}: {hints.BackpackDropAgain}`)
end

local function selectedTileId(): string?
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(grid) then
		return selected:GetAttribute("ItemId")
	end
	return nil
end

local function firstEmptyQuick(): number
	local held = carried()
	for index in Hotbar.quick() do
		if QuickSlots.showing(Hotbar.quick(), index, held) == "" then
			return index
		end
	end
	return 1
end

local function refillFooter()
	local template = {
		Keyboard = hints.BackpackFooter.Keyboard,
		Gamepad = string.format(hints.BackpackFooter.Gamepad, firstQuickNumber + targetIndex - 1),
		Touch = hints.BackpackFooter.Touch,
	}
	Glyphs.fill(footer, template, { size = 18, textSize = 12, color = MUTED })
end

local function redrawQuick()
	local slotsOnBar = Hotbar.slots()
	local onPad = Glyphs.device() == "Gamepad"
	for index, button in quickButtons do
		local slot = slotsOnBar[firstQuickNumber + index - 1]
		local name = button:FindFirstChild("Name") :: TextLabel
		if slot and not slot.empty then
			local def = slot.item and InventoryItems[slot.item]
			name.Text = if Config.Guns.Blasters[slot.id] and def then def.name else slot.label
			name.TextTransparency = 0
		else
			name.Text = "empty"
			name.TextTransparency = 0.6
		end
		if onPad then
			outline(button, SPRAY_RED, if index == targetIndex then 2 else 0)
		else
			-- With an item picked, every slot is somewhere it can go
			outline(button, TEXT, if pickedId then 2 else 0)
		end
	end
end

local function fromGamepad(input: InputObject?): boolean
	if input then
		return string.match(input.UserInputType.Name, "^Gamepad") ~= nil
	end
	return Glyphs.device() == "Gamepad"
end

local function onTileActivated(itemId: string, input: InputObject?)
	if dragging or os.clock() - dragEndedAt < DRAG_CLICK_GUARD then
		return
	end
	if fromGamepad(input) then
		putInSlot(itemId, targetIndex)
		return
	end
	pickedId = if pickedId == itemId then nil else itemId
	Backpack.refresh()
end

local function tile(order: number, itemId: string, count: number, badges: { number }): TextButton
	local quickable = groupOf(itemId) ~= nil
	local button = Instance.new("TextButton")
	button.Name = itemId
	button.LayoutOrder = order
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.BackgroundColor3 = TILE
	button.BackgroundTransparency = if quickable then 0 else 0.4
	button.Text = ""
	button:SetAttribute("ItemId", itemId)
	rounded(button)
	local dim = if quickable then 0 else 0.45
	label({
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -30, 1, -28),
		Text = itemName(itemId),
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = dim,
	}, button)
	label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.new(1, -16, 0, 20),
		Text = if count > 1 then `x{count}` else "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = dim,
	}, button)
	-- Which hotbar number it's on, if any
	if #badges > 0 then
		local numbers = {}
		for _, number in badges do
			table.insert(numbers, tostring(number))
		end
		local badge = label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(18, 18),
			Text = table.concat(numbers, ""),
			TextSize = 12,
			TextColor3 = PANEL,
			BackgroundTransparency = 0,
			BackgroundColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, button)
		rounded(badge)
	end
	if itemId == pickedId then
		outline(button, TEXT, 2)
	end
	button.Activated:Connect(function(input)
		onTileActivated(itemId, input)
	end)
	button.MouseEnter:Connect(function()
		hoveredId = itemId
	end)
	button.MouseLeave:Connect(function()
		if hoveredId == itemId then
			hoveredId = nil
		end
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and quickable then
			dragFrom = { id = itemId, at = UserInputService:GetMouseLocation() }
		end
	end)
	button.Parent = grid
	tiles[itemId] = button
	return button
end

function Backpack.refresh()
	if not open then
		return
	end
	local keepSelection = selectedTileId()
	local padWantsTile = GuiService.SelectedObject == closeButton
		or (GuiService.SelectedObject == nil and Glyphs.device() == "Gamepad")
	for _, button in tiles do
		button:Destroy()
	end
	table.clear(tiles)

	local bag = Hotbar.bag()
	local quick = Hotbar.quick()
	local held = carried()
	local first: TextButton? = nil
	for order, stack in bag do
		local badges = {}
		local group = groupOf(stack.id)
		for slot in quick do
			if group and QuickSlots.showing(quick, slot, held) == group then
				table.insert(badges, firstQuickNumber + slot - 1)
			end
		end
		local button = tile(order, stack.id, stack.count, badges)
		if stack.id == keepSelection or not first then
			first = button
		end
	end
	if pickedId and not tiles[pickedId] then
		pickedId = nil
	end
	empty.Visible = #bag == 0

	local used = InventoryLogic.stacksUsed(bag, InventoryItems)
	local size = Config.Guns.BaseSlots
	local full = used >= size
	capacity.Text = if full then `{hints.BackpackFull}   {used} / {size}` else `{used} / {size}`
	capacity.TextColor3 = if full then SPRAY_RED else MUTED

	redrawQuick()
	refillFooter()
	if keepSelection or padWantsTile then
		GuiService.SelectedObject = first or closeButton
	end
end

local function onQuickPressed(index: number)
	if os.clock() - dragEndedAt < DRAG_CLICK_GUARD then
		return
	end
	if pickedId then
		putInSlot(pickedId, index)
		pickedId = nil
	end
	targetIndex = index
	Backpack.refresh()
end

local function onPad(_action: string, inputState: Enum.UserInputState, input: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.ButtonX then
		targetIndex = targetIndex % Config.Hotbar.QuickSlots + 1
		redrawQuick()
		refillFooter()
	elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
		local itemId = selectedTileId()
		if itemId then
			drop(itemId)
		end
	else
		Backpack.close()
	end
	return Enum.ContextActionResult.Sink
end

-- Escape reaches the game already "processed" (Roblox's menu wants it), so keys are read raw here.
local function onKey(input: InputObject)
	if not open or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		Backpack.close()
		return
	end
	local itemId = hoveredId or pickedId
	if not itemId then
		return
	end
	if input.KeyCode == Enum.KeyCode.X then
		drop(itemId)
		return
	end
	local number = table.find(Input.NumberKeys, input.KeyCode)
	local index = number and number - firstQuickNumber + 1
	if index and index >= 1 and index <= Config.Hotbar.QuickSlots then
		putInSlot(itemId, index)
	end
end

local function quickUnderMouse(): number?
	local mouse = UserInputService:GetMouseLocation()
	for index, button in quickButtons do
		local at, size = button.AbsolutePosition, button.AbsoluteSize
		if mouse.X >= at.X and mouse.X <= at.X + size.X and mouse.Y >= at.Y and mouse.Y <= at.Y + size.Y then
			return index
		end
	end
	return nil
end

local function onMouseMove(input: InputObject)
	local from = dragFrom
	if not open or not from or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	if not dragging and (mouse - from.at).Magnitude >= DRAG_START then
		dragging = true
		ghost.Text = itemName(from.id)
		ghost.Visible = true
	end
	if dragging then
		ghost.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	end
end

local function endDrag()
	local from = dragFrom
	local wasDragging = dragging
	dragFrom, dragging = nil, false
	ghost.Visible = false
	if not wasDragging or not from then
		return
	end
	dragEndedAt = os.clock()
	local index = quickUnderMouse()
	if index then
		putInSlot(from.id, index)
	end
end

function Backpack.close()
	if not open then
		return
	end
	open = false
	panel.Visible = false
	closeButton.Modal = false
	pickedId, hoveredId, armedDrop = nil, nil, nil
	dragFrom, dragging = nil, false
	ghost.Visible = false
	say(nil)
	Input.setExclusive(nil)
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
	targetIndex = firstEmptyQuick()
	-- Only the open key gets through to the game while the bag is up
	Input.setExclusive("Backpack")
	panel.Visible = true
	-- A visible modal button frees the mouse while the panel is up, even in first person
	closeButton.Modal = true
	ContextActionService:BindActionAtPriority(
		PAD_ACTION,
		onPad,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonY,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.ButtonX,
		Enum.KeyCode.ButtonR1
	)
	if device == "Gamepad" or Glyphs.device() == "Gamepad" then
		-- refresh moves it onto the first tile; the selection also leaves the pad to this panel
		GuiService.SelectedObject = closeButton
	end
	Backpack.refresh()
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

-- Not selectable: the gamepad stays on the tiles and works these with Square / Cross / R1
local function smallButton(text: string, size: Vector2): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BorderSizePixel = 0
	button.BackgroundColor3 = TILE
	button.TextColor3 = TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = text
	button.Selectable = false
	rounded(button)
	button.Parent = panel
	return button
end

local function buildQuickRow(top: number, width: number)
	label({
		Position = UDim2.fromOffset(20, top),
		Size = UDim2.fromOffset(200, 16),
		Text = hints.BackpackQuickTitle,
		TextSize = 11,
		TextColor3 = MUTED,
	}, panel)
	for index = 1, Config.Hotbar.QuickSlots do
		local button = smallButton("", QUICK_SIZE)
		button.Position = UDim2.fromOffset(20 + (index - 1) * (QUICK_SIZE.X + GAP), top + 20)
		label({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(20, 14),
			Text = tostring(firstQuickNumber + index - 1),
			TextSize = 11,
			TextColor3 = MUTED,
		}, button)
		label({
			Name = "Name",
			Position = UDim2.fromOffset(6, 20),
			Size = UDim2.new(1, -12, 1, -24),
			TextSize = 11,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, button)
		button.Activated:Connect(function()
			onQuickPressed(index)
		end)
		quickButtons[index] = button
	end
	for row, spec in
		{
			{ text = hints.BackpackToBag, act = backToBag },
			{ text = hints.BackpackDrop, act = drop },
		}
	do
		local button = smallButton(spec.text, ACTION_SIZE)
		button.Position =
			UDim2.fromOffset(width - 20 - ACTION_SIZE.X, top + 20 + (row - 1) * (ACTION_SIZE.Y + 4))
		button.Activated:Connect(function()
			local itemId = pickedId
			if itemId then
				spec.act(itemId)
				Backpack.refresh()
			else
				say("Pick an item first")
			end
		end)
	end
end

local function build()
	local width = COLUMNS * TILE_SIZE.X + (COLUMNS - 1) * GAP + 40
	local gridHeight = ROWS_SHOWN * TILE_SIZE.Y + (ROWS_SHOWN - 1) * GAP
	local quickTop = 60 + gridHeight + 12
	local height = quickTop + 20 + QUICK_SIZE.Y + 60
	panel = Instance.new("Frame")
	panel.Name = "Backpack"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(width, height)
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
		Size = UDim2.fromOffset(120, 24),
		Text = hints.BackpackTitle,
		TextSize = 16,
	}, panel)
	capacity = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 14),
		Size = UDim2.fromOffset(220, 24),
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
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
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 18),
		Text = hints.BackpackEmpty,
		TextSize = 13,
		TextTransparency = 0.4,
		Visible = false,
	}, panel)

	buildQuickRow(quickTop, width)

	status = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -34),
		Size = UDim2.new(1, -40, 0, 16),
		TextSize = 12,
		TextColor3 = SPRAY_RED,
		Text = "",
	}, panel)

	footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 20, 1, -8)
	footer.Size = UDim2.new(1, -40, 0, 24)
	footer.BackgroundTransparency = 1
	footer.Parent = panel

	ghost = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(TILE_SIZE.X, 28),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = TILE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 10,
	}, gui)
	rounded(ghost)

	-- Phones held sideways are short; shrink to fit
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / width, (viewport.Y - 24) / height)
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
	Input.markMenu(gui)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	build()
end

function Backpack.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	requestRemote = Net.event("QuickSlotRequest")
	Input.bind("Backpack", function(began, device)
		if began then
			Backpack.toggle(device)
		end
	end)
	local function refreshIfOpen()
		if open then
			task.defer(Backpack.refresh)
		end
	end
	Hotbar.onChanged(refreshIfOpen)
	Net.event("InventoryChanged").OnClientEvent:Connect(refreshIfOpen)
	Net.event("QuickSlotsChanged").OnClientEvent:Connect(refreshIfOpen)
	Glyphs.onChanged(function()
		if open then
			redrawQuick()
			refillFooter()
		end
	end)
	UserInputService.InputBegan:Connect(onKey)
	UserInputService.InputChanged:Connect(onMouseMove)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			endDrag()
		end
	end)
	GuiService.MenuOpened:Connect(Backpack.close)
	player:GetAttributeChangedSignal("CarrySpeedMultiplier"):Connect(Backpack.close)
	player.CharacterRemoving:Connect(Backpack.close)
	-- Shut the moment you go down, not when the body's cleared away seconds later
	local function watchDeath(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(Backpack.close)
		end
	end
	player.CharacterAdded:Connect(watchDeath)
	if player.Character then
		task.spawn(watchDeath, player.Character)
	end
end

return Backpack
