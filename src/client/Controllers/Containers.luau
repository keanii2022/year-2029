-- What's inside a drawer, cabinet, fridge, chest or wardrobe. The server opens this panel when the
-- door swings open (Interact) and closes it when it shuts. Bag on the left, container on the right,
-- one tile per stack: click or Cross moves the stack, right click or Square moves one, Circle closes.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Net = require(ReplicatedStorage.Shared.Net)
local Glyphs = require(script.Parent.Glyphs)
local Input = require(script.Parent.Input)

local Settings = Config.Containers
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TILE = Color3.fromRGB(30, 30, 33)
local EMPTY = Color3.fromRGB(22, 22, 24)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local TILE_SIZE = Vector2.new(112, 64)
local PANEL_SIZE = Vector2.new(640, 340)
local SLIDE = 24 -- pixels the panel rises as it opens
local OPEN_TIME = 0.18
local PAD_ACTION = "ContainerPad"
local AUTO_CLOSE_SLACK = 4 -- studs past Interact's reach before an open container shuts itself
local REACH_CHECK_EVERY = 0.25 -- seconds

type Stack = { id: string, count: number }
type Side = "bag" | "box"
type State = { title: string, slots: number, stacks: { Stack } }
type Tile = { side: Side, index: number, stack: Stack }

local Containers = {}

local gui: ScreenGui
local panel: Frame
local closeButton: TextButton
local bagGrid: ScrollingFrame
local boxGrid: ScrollingFrame
local boxTitle: TextLabel
local footer: Frame
local moveRemote: RemoteEvent
local closeRemote: RemoteEvent

local current: Model? = nil
local state: State? = nil
local bag: { Stack } = {}
local tiles: { [GuiObject]: Tile } = {}

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function rounded(object: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = object
end

local function grid(position: UDim2, parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BorderSizePixel = 0
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Position = position
	scroll.Size = UDim2.new(0.5, -10, 1, -84)
	scroll.SelectionGroup = true
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	scroll.Parent = parent
	return scroll
end

local function move(tile: Tile, one: boolean)
	local target = current
	if not target then
		return
	end
	moveRemote:FireServer(
		target,
		if tile.side == "bag" then "store" else "take",
		tile.stack.id,
		if one then 1 else tile.stack.count
	)
end

local function addTile(container: ScrollingFrame, side: Side, index: number, stack: Stack): TextButton
	local def = InventoryItems[stack.id]
	local blocked = side == "bag" and Settings.Blocked[stack.id] == true
	local b = Instance.new("TextButton")
	b.LayoutOrder = index
	b.AutoButtonColor = not blocked
	b.BorderSizePixel = 0
	b.BackgroundColor3 = TILE
	b.Text = ""
	rounded(b)
	label({
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 1, -28),
		Text = if def then def.name else stack.id,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = if blocked then 0.55 else 0,
	}, b)
	label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.new(1, -16, 0, 20),
		Text = if blocked then "stays out" else `x{stack.count}`,
		TextSize = if blocked then 11 else 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = if blocked then 0.55 else 0,
	}, b)
	if not blocked then
		local tile = { side = side, index = index, stack = stack }
		tiles[b] = tile
		b.Activated:Connect(function()
			move(tile, false)
		end)
		b.MouseButton2Click:Connect(function()
			move(tile, true)
		end)
	end
	b.Parent = container
	return b
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			tiles[child] = nil
			child:Destroy()
		end
	end
end

-- Tiles are rebuilt on every change, so a gamepad keeps its place: the same tile, else the last
-- one left on that side, else anything on the other side, else the close button.
local function reselect(side: Side, index: number)
	if not UserInputService.GamepadEnabled or not panel.Visible then
		return
	end
	local best: GuiObject? = nil
	local bestIndex = 0
	local other: GuiObject? = nil
	for object, tile in tiles do
		if tile.side ~= side then
			other = other or object
		elseif tile.index == index then
			GuiService.SelectedObject = object
			return
		elseif tile.index > bestIndex then
			best, bestIndex = object, tile.index
		end
	end
	GuiService.SelectedObject = best or other or closeButton
end

local function refresh()
	local open = state
	if not open then
		return
	end
	local selected = GuiService.SelectedObject
	local was = selected and tiles[selected]
	clear(bagGrid)
	clear(boxGrid)
	for index, stack in bag do
		addTile(bagGrid, "bag", index, stack)
	end
	for index, stack in open.stacks do
		addTile(boxGrid, "box", index, stack)
	end
	for index = #open.stacks + 1, open.slots do
		local slot = Instance.new("Frame")
		slot.LayoutOrder = index
		slot.BorderSizePixel = 0
		slot.BackgroundColor3 = EMPTY
		rounded(slot)
		slot.Parent = boxGrid
	end
	local full = #open.stacks >= open.slots
	boxTitle.Text = `{open.title}  {#open.stacks}/{open.slots}`
	boxTitle.TextColor3 = if full then SPRAY_RED else TEXT
	if was then
		reselect(was.side, was.index)
	end
end

-- The footer's keys follow the device in use, live
local function fillFooter()
	Glyphs.fill(footer, Config.Hints.ContainerFooter, {
		size = 18,
		textSize = 12,
		color = Color3.fromRGB(150, 146, 136),
	})
end

local function onPad(_action: string, inputState: Enum.UserInputState, input: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.ButtonB then
		Containers.close()
		-- Hiding inside (wardrobe, toy chest): Circle backs all the way out, so nobody gets stuck
		if Players.LocalPlayer:GetAttribute("Hidden") == true then
			Net.event("InteractUse"):FireServer(nil, nil)
		end
	else
		local selected = GuiService.SelectedObject
		local tile = selected and tiles[selected]
		if tile then
			move(tile, true)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function hide()
	current = nil
	state = nil
	ContextActionService:UnbindAction(PAD_ACTION)
	panel.Visible = false
	closeButton.Modal = false
	clear(bagGrid)
	clear(boxGrid)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function show(model: Model, incoming: State)
	local opening = current ~= model
	current = model
	state = incoming
	if not opening then
		refresh()
		return
	end
	fillFooter()
	panel.Visible = true
	-- A visible modal button frees the mouse while the panel is up, even in first person
	closeButton.Modal = true
	-- Square is Use and Circle is Call out; while the panel is up they work the panel instead
	ContextActionService:BindActionAtPriority(
		PAD_ACTION,
		onPad,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonX,
		Enum.KeyCode.ButtonB
	)
	refresh()
	reselect("box", 1)
	panel.Position = UDim2.new(0.5, 0, 0.55, SLIDE)
	panel.BackgroundTransparency = 0.6
	TweenService:Create(
		panel,
		TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.55), BackgroundTransparency = 0.08 }
	):Play()
end

-- Closes the panel and lets the server shut the doors behind you.
function Containers.close()
	local model = current
	if model then
		hide()
		closeRemote:FireServer(model)
	end
end

-- Further from the box than Interact's reach (measured to its bounding box) plus some slack
local function outOfReach(model: Model, at: Vector3): boolean
	local box, size = model:GetBoundingBox()
	local offset = box:PointToObjectSpace(at)
	local half = size / 2
	local nearest = Vector3.new(
		math.clamp(offset.X, -half.X, half.X),
		math.clamp(offset.Y, -half.Y, half.Y),
		math.clamp(offset.Z, -half.Z, half.Z)
	)
	return (offset - nearest).Magnitude > Config.Interact.Reach + AUTO_CLOSE_SLACK
end

local function build()
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromScale(0.94, 0.8)
	panel.BorderSizePixel = 0
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	rounded(panel)
	-- Full size on a monitor, shrinks to fit a phone
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = PANEL_SIZE
	fit.Parent = panel
	panel.Parent = gui

	label(
		{ Position = UDim2.fromOffset(20, 16), Size = UDim2.fromOffset(200, 22), Text = "BAG", TextSize = 16 },
		panel
	)
	boxTitle = label({
		Position = UDim2.new(0.5, 10, 0, 16),
		Size = UDim2.new(0.5, -70, 0, 22),
		TextSize = 16,
		Font = Enum.Font.PermanentMarker,
	}, panel)
	closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.BorderSizePixel = 0
	closeButton.BackgroundColor3 = TILE
	closeButton.TextColor3 = TEXT
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 14
	closeButton.Text = "X"
	rounded(closeButton)
	closeButton.Activated:Connect(Containers.close)
	closeButton.Parent = panel

	bagGrid = grid(UDim2.fromOffset(20, 50), panel)
	boxGrid = grid(UDim2.new(0.5, 10, 0, 50), panel)
	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0.5, -1, 0, 50)
	divider.Size = UDim2.new(0, 2, 1, -84)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = SPRAY_RED
	divider.BackgroundTransparency = 0.4
	divider.Parent = panel
	footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 20, 1, -6)
	footer.Size = UDim2.new(1, -40, 0, 24)
	footer.BackgroundTransparency = 1
	footer.Parent = panel
end

function Containers.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Containers"
	Input.markMenu(gui)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	build()
end

function Containers.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	moveRemote = Net.event("ContainerMove")
	closeRemote = Net.event("ContainerClose")

	Net.event("ContainerState").OnClientEvent:Connect(function(model, incoming)
		if
			typeof(model) == "Instance"
			and model:IsA("Model")
			and type(incoming) == "table"
			and type(incoming.stacks) == "table"
			and type(incoming.slots) == "number"
		then
			show(model, incoming)
		end
	end)
	Net.event("ContainerClosed").OnClientEvent:Connect(function(model)
		if model == current then
			hide()
		end
	end)
	Net.event("InventoryChanged").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" then
			bag = snapshot
			refresh()
		end
	end)
	Net.event("InventorySync"):FireServer()
	player.CharacterRemoving:Connect(hide)
	-- Shuts when you go down or get hurt: a looting player isn't stuck in a menu while robbed
	local function watchBody(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last then
				Containers.close()
			end
			last = health
		end)
		humanoid.Died:Connect(Containers.close)
	end
	player.CharacterAdded:Connect(watchBody)
	if player.Character then
		task.spawn(watchBody, player.Character)
	end
	task.spawn(function()
		while true do
			task.wait(REACH_CHECK_EVERY)
			local model = current
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if model and root and outOfReach(model, root.Position) then
				Containers.close()
			end
		end
	end)
	Glyphs.onChanged(function()
		if current then
			fillFooter()
		end
	end)
end

return Containers
