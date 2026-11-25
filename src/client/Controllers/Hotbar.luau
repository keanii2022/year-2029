-- The hotbar: what's in your bag as slots along the bottom centre, the selected one in your hands.
-- Number keys or the mouse wheel pick a slot on keyboard, L1 / R1 step through on gamepad, a tap
-- picks one on a phone; the keys show as glyphs on the bar. The first slot is empty hands, where
-- Fire grabs furniture. The Fire action does what the selected item does: other controllers
-- register that with Hotbar.onUse(use, handler) and read Hotbar.selected(). While carrying, the
-- pick stays on empty hands (the keys move the prop then).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local HotbarLogic = require(ReplicatedStorage.Shared.Logic.Hotbar)
local Net = require(ReplicatedStorage.Shared.Net)
local NeedsLogic = require(ReplicatedStorage.Shared.Logic.Needs)
local Glyphs = require(script.Parent.Glyphs)
local Hints = require(script.Parent.Hints)
local Input = require(script.Parent.Input)

local settings = Config.Hotbar
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local REFRESH_EVERY = 1 -- seconds; food shown in hand follows hunger, energy and health

type Handler = (began: boolean, device: Input.Device) -> ()

local Hotbar = {}

local bag: { NeedsLogic.Stack } = {}
local slots: { HotbarLogic.Slot } = {}
local selectedId: string? = nil
local shownId: string? = nil
local shownItem: string? = nil
local handlers: { [string]: Handler } = {}
local changedListeners: { () -> () } = {}
local firing: Handler? = nil
local guns: { [string]: HotbarLogic.Gun } = {}

local gui: ScreenGui
local strip: Frame
local cells: { TextButton } = {}
local padPrevious: Frame
local padNext: Frame

local function carrying(): boolean
	return player:GetAttribute("CarrySpeedMultiplier") ~= nil
end

-- Ties a slot's use (Fire, Eat, Flashlight, ...) to what pressing use/fire does with it.
function Hotbar.onUse(use: string, handler: Handler)
	handlers[use] = handler
end

function Hotbar.onChanged(listener: () -> ())
	table.insert(changedListeners, listener)
end

function Hotbar.selected(): HotbarLogic.Slot?
	return (HotbarLogic.find(slots, selectedId))
end

-- The bar's slots in order and the raw bag, for the backpack panel
function Hotbar.slots(): { HotbarLogic.Slot }
	return slots
end

function Hotbar.bag(): { NeedsLogic.Stack }
	return bag
end

local function missing(): NeedsLogic.Missing
	local max = Config.Supplies.Needs.Max
	local hunger = player:GetAttribute("Hunger")
	local energy = player:GetAttribute("Energy")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return {
		hunger = max - (if type(hunger) == "number" then hunger else max),
		energy = max - (if type(energy) == "number" then energy else max),
		health = if humanoid then humanoid.MaxHealth - humanoid.Health else 0,
	}
end

local function cell(index: number): TextButton
	local existing = cells[index]
	if existing then
		return existing
	end
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.Size = UDim2.fromOffset(settings.SlotSize, settings.SlotSize)
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = TEXT
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	for name, props in
		{
			Label = { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 16), TextSize = 10 },
			Count = {
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.new(1, -5, 0, 14),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
			},
		}
	do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.TextColor3 = TEXT
		label.Font = Enum.Font.GothamBold
		for key, value in props do
			(label :: any)[key] = value
		end
		label.Parent = button
	end
	if index <= Input.SlotCount then
		local key = Glyphs.chip(tostring(index), "Keyboard", 14)
		key.Name = "Key"
		key.Position = UDim2.fromOffset(4, 4)
		key.Parent = button
	end
	button.Activated:Connect(function()
		local slot = slots[index]
		if slot then
			Hotbar.select(slot.id)
		end
	end)
	button.Parent = strip
	cells[index] = button
	return button
end

local function redraw()
	local device = Glyphs.device()
	local showKeys = device == "Keyboard"
	local onPad = device == "Gamepad" and #slots > 1
	padPrevious.Visible = onPad
	padNext.Visible = onPad
	for index, slot in slots do
		local button = cell(index)
		local selected = slot.id == selectedId
		button.Visible = true
		button.BackgroundTransparency = if selected then 0.1 else 0.45
		local stroke = button:FindFirstChild("Stroke") :: UIStroke
		stroke.Transparency = if selected then 0.1 else 0.85
		stroke.Thickness = if selected then 2 else 1
		local label = button:FindFirstChild("Label") :: TextLabel
		label.Text = slot.label
		label.TextTransparency = if selected then 0 else 0.35
		local count = button:FindFirstChild("Count") :: TextLabel
		count.Text = if slot.count > 1 then tostring(slot.count) else ""
		local key = button:FindFirstChild("Key") :: GuiObject?
		if key then
			key.Visible = showKeys
		end
	end
	for index = #slots + 1, #cells do
		cells[index].Visible = false
	end
end

local function notify()
	for _, listener in changedListeners do
		task.spawn(listener)
	end
end

local function rebuild()
	slots = HotbarLogic.slots(settings.Slots, bag, Config.Supplies.Uses, guns, missing())
	selectedId = HotbarLogic.keep(slots, selectedId)
	redraw()
	local selected = Hotbar.selected()
	local item = selected and selected.item
	if selectedId ~= shownId or item ~= shownItem then
		shownId, shownItem = selectedId, item
		notify()
	end
	if #bag > 0 then
		Hints.nudge("item", Config.Hints.ItemNudge)
	end
end

-- Says what Fire does with the item just picked ("{Fire} Eat"); Gun shows its own for guns
local function sayVerb()
	local slot = Hotbar.selected()
	local verb = slot and slot.use ~= "Fire" and settings.Verbs[slot.use]
	if verb then
		local word = string.upper(string.sub(verb, 1, 1)) .. string.lower(string.sub(verb, 2))
		Hints.flash("held", string.format(Config.Hints.HeldHint, word), Config.Hints.HeldHintSeconds)
	else
		Hints.set("held", nil)
	end
end

function Hotbar.select(id: string?)
	if id and id ~= selectedId and not carrying() then
		selectedId = id
		rebuild()
		sayVerb()
	end
end

local function step(by: number)
	Hotbar.select(HotbarLogic.cycle(slots, selectedId, by))
end

local function onFire(began: boolean, device: Input.Device)
	if began then
		local slot = Hotbar.selected()
		firing = slot and handlers[slot.use]
		if firing then
			firing(true, device)
		end
	elseif firing then
		local releasing = firing
		firing = nil
		releasing(false, device)
	end
end

local function onWheel(input: InputObject, gameProcessed: boolean)
	-- While carrying, Grab uses the wheel to move the prop closer or farther
	if
		gameProcessed
		or input.UserInputType ~= Enum.UserInputType.MouseWheel
		or player:GetAttribute("CarrySpeedMultiplier") ~= nil
	then
		return
	end
	step(if input.Position.Z > 0 then -1 else 1)
end

function Hotbar.Init()
	for id, gun in Config.Guns.Blasters do
		local look = settings.Guns[id]
		guns[id] = { rank = gun.rank, label = look and look.label }
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "Hotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	strip = Instance.new("Frame")
	strip.Name = "Slots"
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -settings.Bottom)
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Size = UDim2.fromOffset(0, settings.SlotSize)
	strip.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, settings.SlotGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	-- L1 / R1 chips at the ends of the bar on a gamepad
	for index, action in { "HotbarPrevious", "HotbarNext" } do
		local holder = Instance.new("Frame")
		holder.Name = action
		holder.LayoutOrder = if index == 1 then -1 else 10000
		holder.AutomaticSize = Enum.AutomaticSize.X
		holder.Size = UDim2.fromOffset(0, settings.SlotSize)
		holder.BackgroundTransparency = 1
		holder.Visible = false
		holder.Parent = strip
		Glyphs.fill(holder, "{" .. action .. "}", { size = 22, device = "Gamepad" })
		if index == 1 then
			padPrevious = holder
		else
			padNext = holder
		end
	end
	strip.Parent = gui
end

function Hotbar.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.event("InventoryChanged").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" then
			bag = snapshot
			rebuild()
		end
	end)
	Net.event("InventorySync"):FireServer()

	for number = 1, Input.SlotCount do
		Input.bind(`Slot{number}`, function(began)
			if began then
				Hotbar.select(HotbarLogic.atNumber(slots, number))
			end
		end)
	end
	Input.bind("HotbarNext", function(began)
		if began then
			step(1)
		end
	end)
	Input.bind("HotbarPrevious", function(began)
		if began then
			step(-1)
		end
	end)
	Input.bind("Fire", onFire)
	-- The medkit has no quick-use button, so its slot asks Supplies directly.
	local supplyRemote = Net.event("SupplyUse")
	Hotbar.onUse("Medkit", function(began)
		if began then
			supplyRemote:FireServer("Medkit")
		end
	end)
	-- The battery slot swaps a fresh battery into the flashlight
	local batteryRemote = Net.event("BatterySwap")
	Hotbar.onUse("Battery", function(began)
		if began then
			batteryRemote:FireServer()
		end
	end)
	UserInputService.InputChanged:Connect(onWheel)
	Glyphs.onChanged(redraw)
	rebuild()
	task.spawn(function()
		while true do
			task.wait(REFRESH_EVERY)
			rebuild()
		end
	end)
end

return Hotbar
