-- Hunger and energy bars above the health bar, the supplies shopping list, the quick-use actions
-- (gamepad D-pad, or the hotbar's food, drink and bandage slots) and short feedback text. Same
-- look as Hud. On a phone the bars sit under Hud's health bar top-left and the list goes under the
-- ? / RECORD buttons, clear of the thumbstick and the hotbar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NeedsLogic = require(ReplicatedStorage.Shared.Logic.Needs)
local Glyphs = require(script.Parent.Glyphs)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local Movement = require(script.Parent.Movement)

local settings = Config.Supplies
local needSettings = settings.Needs
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local STANCE_WORDS = { Crouch = "CROUCH", Sprint = "SPRINT" }
local stanceLabel: TextLabel
local FEEDBACK_TIME = 2
local BAR_WIDTH = 240
-- Phone spots, matching Hud's touch health bar (156, 90, 220 wide)
local TOUCH_BAR_X = 156
local TOUCH_BAR_WIDTH = 220
local TOUCH_BAR_TOP = { Hunger = 130, Energy = 164 }
local TOUCH_LIST_AT = Vector2.new(16, 140)
-- Words per need: normal, low, empty
local NEED_WORDS = {
	Hunger = { "HUNGER", "HUNGRY", "STARVING" },
	Energy = { "ENERGY", "TIRED", "EXHAUSTED" },
}

type Bar = { panel: Frame, fill: Frame, title: TextLabel, bottom: number }

local Needs = {}

local gui: ScreenGui
local bars: { [string]: Bar } = {}
local listRows: { TextLabel } = {}
local hintRow: Frame
local listPanel: Frame
local listLayout: UIListLayout
local listTitle: TextLabel
local touch = false
local feedbackLabel: TextLabel
local feedbackUntil = 0
local bag: { NeedsLogic.Stack } = {}
local useRemote: RemoteEvent
local device: Input.Device = "Keyboard"

local function frame(props: { [string]: any }, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT
	l.Font = Enum.Font.GothamBold
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- Hud's health bar sits at 24px from the bottom; these stack above it at the same width.
local function buildBar(name: string, bottom: number)
	local panel = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -bottom),
		Size = UDim2.fromOffset(BAR_WIDTH, 8),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
	}, gui)
	local fill = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = TEXT,
	}, panel)
	local title = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(160, 14),
		Text = NEED_WORDS[name][1],
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	bars[name] = { panel = panel, fill = fill, title = title, bottom = bottom }
end

local function buildShoppingList()
	local panel = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -152),
		Size = UDim2.fromOffset(160, 18 * #settings.ShoppingList + 18),
		BackgroundTransparency = 1,
	}, gui)
	listPanel = panel
	listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	listLayout.Parent = panel
	listTitle = label({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "SUPPLIES",
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	for index in settings.ShoppingList do
		listRows[index] = label({
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 18),
			Text = "",
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, panel)
	end
end

local function buildHint()
	hintRow = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -126),
		Size = UDim2.fromOffset(320, 18),
		BackgroundTransparency = 1,
	}, gui)
end

local function buildFeedback()
	feedbackLabel = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(400, 18),
		Text = "",
		TextSize = 14, -- the hands show what's happening; this is just a quiet caption
		TextTransparency = 0.25,
		TextStrokeTransparency = 0.7,
		Visible = false,
	}, gui)
end

-- The D-pad quick-use legend; keyboard and phone have no quick-use keys, so it only shows on a pad
local function refreshHint()
	local parts = {}
	if device == "Gamepad" then
		for _, entry in settings.QuickUse do
			table.insert(parts, "{" .. entry.action .. "} " .. entry.label)
		end
	end
	Glyphs.fill(hintRow, table.concat(parts, "   "), {
		size = 16,
		textSize = 11,
		color = Color3.fromRGB(150, 146, 136),
		font = Enum.Font.GothamBold,
	})
end

local function hasKind(kind: string): boolean
	for _, stack in bag do
		local use = settings.Uses[stack.id]
		if use and use.kind == kind and stack.count > 0 then
			return true
		end
	end
	return false
end

local function readState(): NeedsLogic.State
	local hunger = player:GetAttribute("Hunger")
	local energy = player:GetAttribute("Energy")
	return {
		hunger = if type(hunger) == "number" then hunger else needSettings.Max,
		energy = if type(energy) == "number" then energy else needSettings.Max,
		exhausted = player:GetAttribute("Exhausted") == true,
	}
end

local function showBar(name: string, value: number, forceEmpty: boolean)
	local bar = bars[name]
	local status = if forceEmpty then "empty" else NeedsLogic.status(value, needSettings)
	local words = NEED_WORDS[name]
	local warn = status ~= "ok"
	bar.fill.Size = UDim2.fromScale(math.clamp(value / needSettings.Max, 0, 1), 1)
	bar.fill.BackgroundColor3 = if warn then SPRAY_RED else TEXT
	bar.title.Text = if status == "empty" then words[3] elseif warn then words[2] else words[1]
	bar.title.Font = if warn then Enum.Font.PermanentMarker else Enum.Font.GothamBold
	bar.title.TextColor3 = if warn then SPRAY_RED else TEXT
	bar.title.TextTransparency = if warn then 0 else 0.3
	bar.title.TextSize = if warn or touch then 14 else 12
end

local function refreshList(state: NeedsLogic.State)
	local rows = NeedsLogic.shoppingList(settings.ShoppingList, bag, settings.Uses, state, needSettings)
	for index, row in rows do
		local text = listRows[index]
		-- Once there's enough, a tick instead of a count that looks over the limit ("CELLS 36/30")
		local enough = row.have >= row.want
		text.Text = if enough
			then `{string.upper(row.label)}  {row.have} ✓`
			else `{string.upper(row.label)}  {row.have}/{row.want}`
		text.Font = if row.low then Enum.Font.PermanentMarker else Enum.Font.GothamBold
		text.TextColor3 = if row.low then SPRAY_RED else TEXT
		text.TextTransparency = if row.low then 0 else 0.4
	end
end

local function update()
	local state = readState()
	showBar("Hunger", state.hunger, false)
	showBar("Energy", state.energy, state.exhausted)
	refreshList(state)
	feedbackLabel.Visible = os.clock() < feedbackUntil
end

local function showFeedback(text: unknown)
	if type(text) == "string" then
		feedbackLabel.Text = text
		feedbackUntil = os.clock() + FEEDBACK_TIME
	end
end

local function place()
	for name, bar in bars do
		if touch then
			bar.panel.AnchorPoint = Vector2.zero
			bar.panel.Position = UDim2.fromOffset(TOUCH_BAR_X, TOUCH_BAR_TOP[name])
			bar.panel.Size = UDim2.fromOffset(TOUCH_BAR_WIDTH, 8)
		else
			bar.panel.AnchorPoint = Vector2.new(0, 1)
			bar.panel.Position = UDim2.new(0, 24, 1, -bar.bottom)
			bar.panel.Size = UDim2.fromOffset(BAR_WIDTH, 8)
		end
	end
	listPanel.AnchorPoint = if touch then Vector2.zero else Vector2.new(0, 1)
	listPanel.Position = if touch
		then UDim2.fromOffset(TOUCH_LIST_AT.X, TOUCH_LIST_AT.Y)
		else UDim2.new(0, 24, 1, -152)
	listLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	listTitle.TextSize = if touch then 14 else 12
end

local function onLastInput(now: Input.Device)
	device = now
	touch = now == "Touch"
	refreshHint()
	place()
end

function Needs.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Needs"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	buildBar("Energy", 70)
	-- Crouch / sprint shows by the ENERGY word, since sprinting is what drains it
	stanceLabel = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -4),
		Size = UDim2.fromOffset(90, 14),
		Text = "",
		TextSize = 12,
		TextColor3 = SPRAY_RED,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, bars.Energy.panel)
	RunService.Heartbeat:Connect(function()
		stanceLabel.Text = STANCE_WORDS[Movement.getStance()] or ""
	end)
	buildBar("Hunger", 100)
	buildHint()
	buildShoppingList()
	buildFeedback()
end

function Needs.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	useRemote = Net.event("SupplyUse")
	Net.event("SupplyFeedback").OnClientEvent:Connect(showFeedback)
	Net.event("InventoryChanged").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" then
			bag = snapshot
		end
	end)
	Net.event("InventorySync"):FireServer()

	for _, entry in settings.QuickUse do
		local function use(began: boolean)
			if began then
				useRemote:FireServer(entry.kind)
			end
		end
		-- D-pad down heals with whatever you have: a bandage first, else the medkit
		local function quickUse(began: boolean)
			if began and entry.kind == "Heal" and not hasKind("Heal") and hasKind("Medkit") then
				useRemote:FireServer("Medkit")
			else
				use(began)
			end
		end
		Input.bind(entry.action, quickUse)
		Hotbar.onUse(entry.action, use)
	end
	onLastInput(Glyphs.device())
	Glyphs.onChanged(onLastInput)
	RunService.RenderStepped:Connect(update)
end

return Needs
