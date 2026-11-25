-- The admin panel, only for players the server marked with the "Admin" attribute. F2, holding
-- L1 + R1 together, or the phone's ADMIN button (top left) opens it. Tabs of big buttons that each
-- send one AdminCommand; the server checks it and answers with a status line shown at the bottom.
-- Works by mouse, touch, or the pad (D-pad moves the selection, Cross presses, Circle closes).
-- Also flies the character while the server's "Fly" attribute is on (noclip through walls too),
-- and shows a small ADMIN tag while god or fly is on.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Net = require(ReplicatedStorage.Shared.Net)
local Glyphs = require(script.Parent.Glyphs)

local settings = Config.Admin
local blasters = Config.Guns.Blasters
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TILE = Color3.fromRGB(30, 30, 33)
local TILE_ON = Color3.fromRGB(70, 22, 20)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local WIDTH = 620
local HEIGHT = 400
local CELL = Vector2.new(136, 52)
local GAP = 8
local PAD_ACTION = "AdminPanelPad"
local TABS = { "Guns", "Items", "Moves", "Time", "Robots", "Sim" }

type ButtonSpec = {
	text: string | () -> string,
	command: string,
	arg: any?,
	on: (() -> boolean)?,
}
type Entry = { button: TextButton, spec: ButtonSpec }

local AdminPanel = {}

local gui: ScreenGui
local panel: Frame
local closeButton: TextButton
local grid: ScrollingFrame
local status: TextLabel
local tag: TextLabel
local tabButtons: { [string]: TextButton } = {}
local entries: { Entry } = {}
local currentTab = TABS[1]
local open = false
local simCount: number? = nil
local commandRemote: RemoteEvent

local function rounded(object: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = object
end

local function textButton(props: { [string]: any }, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.BackgroundColor3 = TILE
	button.TextColor3 = TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextWrapped = true
	for key, value in props do
		(button :: any)[key] = value
	end
	rounded(button)
	button.Parent = parent
	return button
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

local function isOn(name: string): boolean
	return player:GetAttribute(name) == true
end

local function speedName(): string
	local multiplier = tonumber(player:GetAttribute("AdminSpeed")) or 1
	for _, level in settings.SpeedLevels do
		if level.multiplier == multiplier then
			return level.name
		end
	end
	return "normal"
end

local function onOff(name: string, on: boolean): string
	return `{name}: {if on then "ON" else "OFF"}`
end

local function itemName(id: string): string
	local item = InventoryItems[id]
	return string.upper(if item then item.name else id)
end

-- Tab contents -------------------------------------------------------------------------------------

local function gunSpecs(): { ButtonSpec }
	local specs: { ButtonSpec } = {
		{ text = "ALL GUNS", command = "give_all_guns" },
		{ text = "AMMO", command = "give_ammo" },
	}
	local ids = {}
	for id in blasters do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return blasters[a].rank < blasters[b].rank
	end)
	for _, id in ids do
		table.insert(specs, { text = itemName(id), command = "give_gun", arg = id })
	end
	return specs
end

local function itemSpecs(): { ButtonSpec }
	local specs: { ButtonSpec } = { { text = "FOOD KIT", command = "give_food_kit" } }
	local ids = {}
	for id in InventoryItems do
		if not blasters[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return InventoryItems[a].name < InventoryItems[b].name
	end)
	for _, id in ids do
		table.insert(specs, { text = itemName(id), command = "give_item", arg = id })
	end
	return specs
end

local function moveSpecs(): { ButtonSpec }
	local specs: { ButtonSpec } = {
		{
			text = function()
				return onOff("GOD", isOn("God"))
			end,
			command = "god",
			on = function()
				return isOn("God")
			end,
		},
		{
			text = function()
				return `SPEED: {string.upper(speedName())}`
			end,
			command = "speed",
		},
		{
			text = function()
				return onOff("FLY", isOn("Fly"))
			end,
			command = "fly",
			on = function()
				return isOn("Fly")
			end,
		},
		{ text = "◀ PREV HALL", command = "tp_previous" },
		{ text = "NEXT HALL ▶", command = "tp_next" },
		{ text = "TO SPAWN", command = "tp_spawn" },
	}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(
				specs,
				{ text = `TO {string.upper(other.DisplayName)}`, command = "tp_player", arg = other.UserId }
			)
		end
	end
	return specs
end

local function timeSpecs(): { ButtonSpec }
	return {
		{ text = "LIGHTS ON", command = "time_skip", arg = "Day" },
		{ text = "SIREN", command = "time_skip", arg = "Siren" },
		{ text = "LIGHTS OUT", command = "time_skip", arg = "Night" },
		{
			text = function()
				return if ReplicatedStorage:GetAttribute("ClockFrozen") == true
					then "UNFREEZE CLOCK"
					else "FREEZE CLOCK"
			end,
			command = "time_freeze",
			on = function()
				return ReplicatedStorage:GetAttribute("ClockFrozen") == true
			end,
		},
	}
end

local function robotSpecs(): { ButtonSpec }
	local function frozen(): boolean
		return ReplicatedStorage:GetAttribute("RobotsFrozen") == true
	end
	return {
		{ text = "FREEZE ROBOTS", command = "robots_freeze", on = frozen },
		{
			text = "WAKE ROBOTS",
			command = "robots_wake",
			on = function()
				return not frozen()
			end,
		},
	}
end

local function simSpecs(): { ButtonSpec }
	local specs: { ButtonSpec } = {}
	for _, count in settings.SimCounts do
		table.insert(specs, { text = `SPAWN {count}`, command = "sim_spawn", arg = count })
	end
	for _, mood in settings.SimMoods do
		table.insert(specs, { text = string.upper(mood), command = "sim_mood", arg = mood })
	end
	table.insert(specs, { text = "CLEAR", command = "sim_clear" })
	return specs
end

local SPECS: { [string]: () -> { ButtonSpec } } = {
	Guns = gunSpecs,
	Items = itemSpecs,
	Moves = moveSpecs,
	Time = timeSpecs,
	Robots = robotSpecs,
	Sim = simSpecs,
}

local function refreshLabels()
	for _, entry in entries do
		local text = entry.spec.text
		entry.button.Text = if type(text) == "function" then text() else text
		local on = entry.spec.on and entry.spec.on()
		entry.button.BackgroundColor3 = if on then TILE_ON else TILE
	end
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then TILE_ON else TILE
	end
	local countLabel = grid:FindFirstChild("SimCount") :: TextLabel?
	if countLabel then
		countLabel.Text = if simCount then `LIVE: {simCount}` else "LIVE: -"
	end
	local god, fly = isOn("God"), isOn("Fly")
	tag.Visible = god or fly
	tag.Text = "ADMIN" .. (if god then "  GOD" else "") .. (if fly then "  FLY" else "")
end

local function usingPad(): boolean
	return Glyphs.device() == "Gamepad"
end

local function fillGrid()
	local selected = GuiService.SelectedObject
	local hadGridSelection = selected ~= nil and selected:IsDescendantOf(grid)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(entries)
	for order, spec in SPECS[currentTab]() do
		local button = textButton({ LayoutOrder = order }, grid)
		button.Activated:Connect(function()
			commandRemote:FireServer(spec.command, spec.arg)
		end)
		table.insert(entries, { button = button, spec = spec })
	end
	if currentTab == "Sim" then
		label({
			Name = "SimCount",
			LayoutOrder = 100,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
		}, grid)
	end
	grid.CanvasPosition = Vector2.zero
	refreshLabels()
	-- The selected button may have just been rebuilt; put the pad back on the tab
	if open and hadGridSelection then
		GuiService.SelectedObject = tabButtons[currentTab]
	end
end

local function showTab(name: string)
	currentTab = name
	fillGrid()
	if name == "Sim" then
		commandRemote:FireServer("sim_count")
	end
end

-- Open and close -----------------------------------------------------------------------------------

local function onPad(_action: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		AdminPanel.close()
	end
	return Enum.ContextActionResult.Sink
end

function AdminPanel.close()
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

local function show()
	if open or not isOn("Admin") then
		return
	end
	open = true
	fillGrid()
	panel.Visible = true
	-- A visible modal button frees the mouse while the panel is up, even in first person
	closeButton.Modal = true
	ContextActionService:BindActionAtPriority(
		PAD_ACTION,
		onPad,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB
	)
	-- The selection also tells Input to leave the pad to this panel, so nothing fires behind it
	if usingPad() then
		GuiService.SelectedObject = tabButtons[currentTab]
	end
	if currentTab == "Sim" then
		commandRemote:FireServer("sim_count")
	end
end

function AdminPanel.toggle()
	if open then
		AdminPanel.close()
	else
		show()
	end
end

-- Building -----------------------------------------------------------------------------------------

local function buildPanel()
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	rounded(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	label({
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -80, 0, 36),
		Text = "ADMIN",
		Font = Enum.Font.PermanentMarker,
		TextSize = 26,
		TextColor3 = SPRAY_RED,
	}, panel)
	closeButton = textButton({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(40, 36),
		Text = "X",
	}, panel)
	closeButton.Activated:Connect(AdminPanel.close)

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(20, 52)
	divider.Size = UDim2.new(1, -40, 0, 2)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = SPRAY_RED
	divider.BackgroundTransparency = 0.4
	divider.Parent = panel

	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(20, 62)
	tabRow.Size = UDim2.new(1, -40, 0, 40)
	tabRow.SelectionGroup = true
	tabRow.Parent = panel
	local tabWidth = (WIDTH - 40 - (#TABS - 1) * 6) / #TABS
	for index, name in TABS do
		local button = textButton({
			Position = UDim2.fromOffset((index - 1) * (tabWidth + 6), 0),
			Size = UDim2.fromOffset(tabWidth, 40),
			Text = string.upper(name),
			TextSize = 13,
		}, tabRow)
		button.Activated:Connect(function()
			showTab(name)
		end)
		tabButtons[name] = button
	end

	grid = Instance.new("ScrollingFrame")
	grid.BorderSizePixel = 0
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 4
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Position = UDim2.fromOffset(20, 112)
	grid.Size = UDim2.new(1, -36, 1, -150)
	grid.SelectionGroup = true
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = panel

	status = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -10),
		Size = UDim2.new(1, -40, 0, 20),
		Text = "",
		TextSize = 14,
		TextTransparency = 0.15,
	}, panel)

	-- Phones held sideways are short; shrink to fit
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / WIDTH, (viewport.Y - 24) / HEIGHT)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

local function buildTag()
	tag = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(220, 28),
		Font = Enum.Font.PermanentMarker,
		TextSize = 22,
		TextColor3 = SPRAY_RED,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, gui)
end

-- Sits in the top-left row after the phone's ? and record buttons, clear of everything else
local function buildTouchButton()
	local button = textButton({
		Position = UDim2.fromOffset(152, 84),
		Size = UDim2.fromOffset(72, 32),
		Text = "ADMIN",
		TextSize = 13,
		BackgroundTransparency = 0.3,
		TextColor3 = SPRAY_RED,
		Selectable = false,
	}, gui)
	button.Activated:Connect(AdminPanel.toggle)
end

-- Fly ----------------------------------------------------------------------------------------------

local flight: {
	character: Model,
	humanoid: Humanoid,
	attachment: Attachment,
	velocity: LinearVelocity,
	turn: AlignOrientation,
	collided: { [BasePart]: boolean },
	connections: { RBXScriptConnection },
}? =
	nil
local controls: any = nil

local function moveVector(): Vector3
	if controls == nil then
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
		end)
		controls = if ok then (module :: any):GetControls() else false
	end
	return if controls then controls:GetMoveVector() else Vector3.zero
end

local function stopFlying()
	local current = flight
	if not current then
		return
	end
	flight = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	current.velocity:Destroy()
	current.turn:Destroy()
	current.attachment:Destroy()
	for part in current.collided do
		if part.Parent then
			part.CanCollide = true
		end
	end
	if current.humanoid.Parent then
		current.humanoid.AutoRotate = true
	end
end

local function startFlying()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if flight or not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AdminFly"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attachment
	turn.RigidityEnabled = true
	turn.CFrame = root.CFrame.Rotation
	turn.Parent = root
	humanoid.AutoRotate = false

	local current = {
		character = character,
		humanoid = humanoid,
		attachment = attachment,
		velocity = velocity,
		turn = turn,
		collided = {},
		connections = {},
	}
	flight = current
	-- Noclip: switch collisions off every physics step (the Humanoid turns some back on)
	table.insert(
		current.connections,
		RunService.Stepped:Connect(function()
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					current.collided[part] = true
					part.CanCollide = false
				end
			end
		end)
	)
	-- Moves where the camera looks, so looking down and walking forward flies down; jump rises
	table.insert(
		current.connections,
		RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local speed = settings.FlySpeed * (tonumber(player:GetAttribute("AdminSpeed")) or 1)
			local direction = camera.CFrame:VectorToWorldSpace(moveVector())
			if humanoid.Jump then
				direction += Vector3.yAxis
			end
			if direction.Magnitude > 1 then
				direction = direction.Unit
			end
			velocity.VectorVelocity = direction * speed
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				turn.CFrame = CFrame.lookAt(Vector3.zero, look)
			end
		end)
	)
	table.insert(current.connections, humanoid.Died:Connect(stopFlying))
end

local function syncFlying()
	if isOn("Fly") then
		startFlying()
	else
		stopFlying()
	end
end

-- Start --------------------------------------------------------------------------------------------

local function bindOpeners()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == settings.OpenKey and not processed then
			AdminPanel.toggle()
		end
	end)
	-- L1 + R1 held together; each press alone still steps the hotbar, so the two cancel out
	local padPress = 0
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.ButtonL1 and input.KeyCode ~= Enum.KeyCode.ButtonR1 then
			return
		end
		local pad = input.UserInputType
		local function bothDown(): boolean
			return UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.ButtonL1)
				and UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.ButtonR1)
		end
		if not bothDown() then
			return
		end
		padPress += 1
		local press = padPress
		task.delay(settings.PadHold, function()
			if press == padPress and bothDown() then
				AdminPanel.toggle()
			end
		end)
	end)
	if UserInputService.TouchEnabled then
		buildTouchButton()
	end
end

local function enable()
	commandRemote = Net.event("AdminCommand")
	gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	buildPanel()
	buildTag()
	gui.Parent = player:WaitForChild("PlayerGui")
	bindOpeners()

	Net.event("AdminStatus").OnClientEvent:Connect(function(text: string)
		status.Text = text
	end)
	Net.event("AdminSimCount").OnClientEvent:Connect(function(count: number?)
		simCount = count
		refreshLabels()
	end)
	for _, name in { "God", "Fly", "AdminSpeed" } do
		player:GetAttributeChangedSignal(name):Connect(refreshLabels)
	end
	for _, name in { "ClockFrozen", "RobotsFrozen" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshLabels)
	end
	local function playersChanged()
		if open and currentTab == "Moves" then
			fillGrid()
		end
	end
	Players.PlayerAdded:Connect(playersChanged)
	Players.PlayerRemoving:Connect(function()
		task.defer(playersChanged)
	end)
	player:GetAttributeChangedSignal("Fly"):Connect(syncFlying)
	player.CharacterAdded:Connect(function(character)
		stopFlying()
		character:WaitForChild("HumanoidRootPart", 10)
		syncFlying()
	end)
	player.CharacterRemoving:Connect(stopFlying)
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		if not isOn("Admin") then
			AdminPanel.close()
		end
	end)
	syncFlying()
	refreshLabels()

	-- Live sim count while that tab is up
	task.spawn(function()
		while true do
			task.wait(settings.SimCountPoll)
			if open and currentTab == "Sim" then
				commandRemote:FireServer("sim_count")
			end
		end
	end)
end

function AdminPanel.Start()
	if isOn("Admin") then
		enable()
		return
	end
	-- The server decides admins a moment after joining (name lookups take a beat)
	local connection
	connection = player:GetAttributeChangedSignal("Admin"):Connect(function()
		if isOn("Admin") then
			connection:Disconnect()
			enable()
		end
	end)
end

return AdminPanel
