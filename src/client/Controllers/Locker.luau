-- The locker and your record. Opening a locker shows STASH: your bag and your saved locker side
-- by side, click a stack to move it. M (or Select on gamepad) opens RECORD anywhere: stats,
-- earned looks and laying out your blueprint. FILES is the 2029 Files: chapters and the lore you've
-- found, with a reader. Same dark look as Hud; warnings in red spray paint.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local FilesLogic = require(ReplicatedStorage.Shared.Logic.Files)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Net = require(ReplicatedStorage.Shared.Net)
local ScoresLogic = require(ReplicatedStorage.Shared.Logic.Scores)
local AudioSettings = require(script.Parent.AudioSettings)
local Glyphs = require(script.Parent.Glyphs)
local Input = require(script.Parent.Input)

local Settings = Config.Saves
local Cosmetics = Settings.Cosmetics :: any
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local ROW = Color3.fromRGB(30, 30, 33)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local FEEDBACK_TIME = 2.5
local PAD_ACTION = "LockerPad"
local ROW_HEIGHT = 30
local PANEL_SIZE = Vector2.new(600, 430)
local TOUCH_TARGET = 44 -- smallest comfortable tap
local SLOTS = { "Hat", "Colour", "Trail" }
-- Hats and trails can be taken off; everyone always wears a colour
local CAN_REMOVE = { Hat = true, Trail = true }

type View = "stash" | "record" | "files"
type Stack = { id: string, count: number }
type Record = {
	stats: { [string]: number },
	wearing: { [string]: string },
	chosen: { [string]: string },
	saving: boolean,
}

local Locker = {}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local closeButton: TextButton
local stashTab: TextButton
local recordTab: TextButton
local stashView: Frame
local recordView: Frame
local bagList: ScrollingFrame
local lockerList: ScrollingFrame
local lockerTitle: TextLabel
local statsList: Frame
local savingNote: TextLabel
local blueprintLabel: TextLabel
local layOutButton: TextButton
local feedbackLabel: TextLabel
local footer: Frame
local looks: { [string]: { name: TextLabel, hint: TextLabel } } = {}
local browsing: { [string]: number } = {}
-- FILES page
local FilesSettings = Config.Files
local filesCatalog = FilesLogic.catalog(FilesSettings, Config.NightTricks.Journals)
local filesTab: TextButton
local filesView: Frame
local filesHeader: TextLabel
local filesList: ScrollingFrame
local readerTitle: TextLabel
local readerText: TextLabel
local filesFound: { string } = {}

local view: View? = nil
local lockerOpen = false
local lockerPosition: Vector3? = nil
local stash: { Stack } = {}
local stashSlots = { used = 0, slots = Settings.Locker.Slots }
local bag: { Stack } = {}
local record: Record? = nil
local blueprintPieces = 0
local feedbackUntil = 0
local moveRemote: RemoteEvent
local closeRemote: RemoteEvent
local equipRemote: RemoteEvent
local layOutRemote: RemoteEvent

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
	l.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function button(props: { [string]: any }, parent: Instance, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.BackgroundColor3 = ROW
	b.TextColor3 = TEXT
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	for key, value in props do
		(b :: any)[key] = value
	end
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function list(props: { [string]: any }, parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BorderSizePixel = 0
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	for key, value in props do
		(scroll :: any)[key] = value
	end
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	scroll.Parent = parent
	return scroll
end

local function itemText(entry: Stack): string
	local def = InventoryItems[entry.id]
	local name = if def then def.name else entry.id
	return if entry.count > 1 then `{name}  x{entry.count}` else name
end

local function clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function fillStack(container: ScrollingFrame, entries: { Stack }, action: string)
	clearRows(container)
	for index, entry in entries do
		local blocked = action == "store" and Settings.Locker.Blocked[entry.id] == true
		button(
			{
				LayoutOrder = index,
				Size = UDim2.new(1, -6, 0, ROW_HEIGHT),
				Text = if blocked then `{itemText(entry)}  (stays out)` else itemText(entry),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = if blocked then 0.55 else 0,
				AutoButtonColor = not blocked,
			},
			container,
			function()
				if not blocked then
					moveRemote:FireServer(action, entry.id, entry.count)
				end
			end
		)
	end
end

local function refreshStash()
	fillStack(bagList, bag, "store")
	fillStack(lockerList, stash, "take")
	local full = stashSlots.used >= stashSlots.slots
	lockerTitle.Text = `LOCKER  {stashSlots.used}/{stashSlots.slots}`
	lockerTitle.TextColor3 = if full then SPRAY_RED else TEXT
end

local function options(slot: string): { any }
	local result = {}
	if CAN_REMOVE[slot] then
		table.insert(result, { id = nil, label = "None" })
	end
	for _, def in Cosmetics[slot] do
		table.insert(result, def)
	end
	return result
end

local function indexOf(slot: string, id: string?): number
	for index, option in options(slot) do
		if option.id == id then
			return index
		end
	end
	return 1
end

local function refreshLook(slot: string)
	local current = record
	local row = looks[slot]
	if not current then
		return
	end
	local choices = options(slot)
	local option = choices[browsing[slot] or indexOf(slot, current.wearing[slot])]
	local locked = option.id ~= nil and not ScoresLogic.isUnlocked(option, current.stats)
	row.name.Text = option.label
	row.name.TextTransparency = if locked then 0.5 else 0
	row.hint.Visible = locked
	if locked then
		row.hint.Text = `LOCKED  {ScoresLogic.unlockHint(option.unlock, Settings.Stats, current.stats)}`
	end
end

local function browse(slot: string, step: number)
	local current = record
	if not current then
		return
	end
	local choices = options(slot)
	local index = ((browsing[slot] or indexOf(slot, current.wearing[slot])) - 1 + step) % #choices + 1
	browsing[slot] = index
	local option = choices[index]
	if ScoresLogic.canEquip(Cosmetics, slot, option.id, current.stats) then
		equipRemote:FireServer(slot, option.id)
	end
	refreshLook(slot)
end

local function refreshRecord()
	local current = record
	clearRows(statsList)
	if current then
		for index, def in Settings.Stats do
			local row = frame({
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
			}, statsList)
			label({
				Size = UDim2.fromScale(0.7, 1),
				Text = string.upper(def.label),
				TextSize = 13,
				TextTransparency = 0.3,
			}, row)
			label({
				Position = UDim2.fromScale(0.7, 0),
				Size = UDim2.fromScale(0.3, 1),
				Text = ScoresLogic.formatStat(current.stats[def.key] or 0, def.minutes),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, row)
		end
		savingNote.Visible = not current.saving
		for _, slot in SLOTS do
			refreshLook(slot)
		end
	end
	if blueprintPieces > 0 then
		blueprintLabel.Text = `BLUEPRINT  {blueprintPieces} pieces. Once a day, in daylight, somewhere clear.`
		layOutButton.Visible = true
	else
		blueprintLabel.Text = "NO BLUEPRINT  Find paper and a pen near your fort to draw one."
		layOutButton.Visible = false
	end
end

local show: (target: View?) -> ()

-- What closes the panel (and on the stash, how to move things) for the device in use
local function fillFooter()
	local template = if view == "stash" then Config.Hints.LockerFooter else Config.Hints.RecordFooter
	Glyphs.fill(footer, if view then template else "", {
		size = 18,
		textSize = 12,
		color = Color3.fromRGB(150, 146, 136),
	})
end

-- Circle shuts the panel. Input drops the pad's buttons while the panel holds the selection, so
-- without this the only way out on a controller was finding the close button.
local function onPad(_action: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		show(nil)
	end
	return Enum.ContextActionResult.Sink
end

-- 2029 Files ------------------------------------------------------------------------------------

local function read(title: string, text: string)
	readerTitle.Text = title
	readerText.Text = text
end

local function fileRow(order: number, text: string, open: boolean, onClick: () -> ())
	button({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 26),
		Text = text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = if open then 0 else 0.55,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = open,
	}, filesList, onClick)
end

local function refreshFiles()
	clearRows(filesList)
	local count = FilesLogic.count(filesFound, filesCatalog)
	local chapters = FilesSettings.Chapters
	local per = FilesSettings.PerChapter
	local open = FilesLogic.chaptersOpen(count, per, #chapters)
	local nextAt = FilesLogic.nextChapterAt(count, per, #chapters)
	filesHeader.Text = `FOUND {count}/{#filesCatalog}`
		.. (if nextAt then `   NEXT CHAPTER AT {nextAt}` else "")
	read("2029 FILES", FilesSettings.Prologue)
	for index, chapter in chapters do
		local isOpen = index <= open
		fileRow(
			index,
			if isOpen then string.upper(chapter.title) else `CHAPTER {index}  ({index * per} found)`,
			isOpen,
			function()
				if isOpen then
					read(chapter.title, chapter.text)
				end
			end
		)
	end
	for index, entry in filesCatalog do
		local found = table.find(filesFound, entry.id) ~= nil
		fileRow(#chapters + index, if found then entry.title else `???  ({entry.kind})`, found, function()
			if found then
				read(entry.title, entry.text)
			end
		end)
	end
end

local function buildFiles()
	filesView = frame({
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 1, -76),
		BackgroundTransparency = 1,
	}, panel)
	filesHeader =
		label({ Size = UDim2.new(0.45, 0, 0, 20), TextSize = 13, TextTransparency = 0.3 }, filesView)
	filesList = list({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0.45, 0, 1, -26) }, filesView)
	readerTitle = label({
		Position = UDim2.new(0.5, 10, 0, 0),
		Size = UDim2.new(0.5, -10, 0, 30),
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 18,
		TextWrapped = true,
	}, filesView)
	readerText = label({
		Position = UDim2.new(0.5, 10, 0, 40),
		Size = UDim2.new(0.5, -10, 1, -40),
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
	}, filesView)
end

function show(target: View?)
	if target == nil and lockerOpen then
		lockerOpen = false
		closeRemote:FireServer()
	end
	view = target
	panel.Visible = target ~= nil
	-- A visible modal button frees the mouse while the panel is up
	closeButton.Modal = target ~= nil
	if target then
		ContextActionService:BindActionAtPriority(
			PAD_ACTION,
			onPad,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonB
		)
	else
		ContextActionService:UnbindAction(PAD_ACTION)
	end
	stashView.Visible = target == "stash"
	recordView.Visible = target == "record"
	filesView.Visible = target == "files"
	fillFooter()
	stashTab.Visible = lockerOpen
	titleLabel.Text = if target == "stash"
		then "YOUR LOCKER"
		elseif target == "files" then "2029 FILES"
		else "YOUR RECORD"
	stashTab.BackgroundTransparency = if target == "stash" then 0 else 0.6
	recordTab.BackgroundTransparency = if target == "record" then 0 else 0.6
	filesTab.BackgroundTransparency = if target == "files" then 0 else 0.6
	if target == "stash" then
		refreshStash()
	elseif target == "record" then
		table.clear(browsing)
		refreshRecord()
	elseif target == "files" then
		refreshFiles()
	end
	if target and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = closeButton
	elseif not target and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function buildPanel()
	panel = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, gui)
	-- Phones held sideways are short; shrink to fit (same as the bag)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / PANEL_SIZE.X, (viewport.Y - 24) / PANEL_SIZE.Y)
		end
	end
	fit()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fit)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	footer = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -8),
		Size = UDim2.new(1, -40, 0, 22),
		BackgroundTransparency = 1,
	}, panel)
	titleLabel =
		label({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(200, 28), TextSize = 20 }, panel)
	closeButton = button(
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(32, 32),
			Text = "X",
		},
		panel,
		function()
			show(nil)
		end
	)
	stashTab = button(
		{
			Position = UDim2.fromOffset(224, 14),
			Size = UDim2.fromOffset(100, 28),
			Text = "STASH",
			TextSize = 12,
		},
		panel,
		function()
			show("stash")
		end
	)
	recordTab = button(
		{
			Position = UDim2.fromOffset(330, 14),
			Size = UDim2.fromOffset(100, 28),
			Text = "RECORD",
			TextSize = 12,
		},
		panel,
		function()
			show("record")
		end
	)
	filesTab = button(
		{
			Position = UDim2.fromOffset(436, 14),
			Size = UDim2.fromOffset(100, 28),
			Text = "FILES",
			TextSize = 12,
		},
		panel,
		function()
			show("files")
		end
	)
end

local function buildStash()
	stashView = frame({
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 1, -92),
		BackgroundTransparency = 1,
	}, panel)
	label(
		{ Size = UDim2.new(0.5, -10, 0, 20), Text = "BAG", TextSize = 13, TextTransparency = 0.3 },
		stashView
	)
	lockerTitle = label({
		Position = UDim2.new(0.5, 10, 0, 0),
		Size = UDim2.new(0.5, -10, 0, 20),
		TextSize = 13,
	}, stashView)
	bagList = list({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0.5, -10, 1, -50) }, stashView)
	lockerList = list({ Position = UDim2.new(0.5, 10, 0, 26), Size = UDim2.new(0.5, -10, 1, -50) }, stashView)
	label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "The locker follows you to every server. Your bag doesn't.",
		TextSize = 11,
		TextTransparency = 0.45,
	}, stashView)
end

local function buildLookRow(slot: string, index: number, parent: Instance)
	local row = frame({
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, TOUCH_TARGET + 16),
		BackgroundTransparency = 1,
	}, parent)
	label({
		Size = UDim2.fromOffset(70, TOUCH_TARGET),
		Text = string.upper(slot),
		TextSize = 12,
		TextTransparency = 0.3,
	}, row)
	button(
		{
			Position = UDim2.fromOffset(70, 0),
			Size = UDim2.fromOffset(TOUCH_TARGET, TOUCH_TARGET),
			Text = "<",
		},
		row,
		function()
			browse(slot, -1)
		end
	)
	local name = label({
		Position = UDim2.fromOffset(74 + TOUCH_TARGET, 0),
		Size = UDim2.new(1, -(78 + TOUCH_TARGET * 2), 0, TOUCH_TARGET),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, row)
	button(
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(TOUCH_TARGET, TOUCH_TARGET),
			Text = ">",
		},
		row,
		function()
			browse(slot, 1)
		end
	)
	local hint = label({
		Position = UDim2.fromOffset(70, TOUCH_TARGET),
		Size = UDim2.new(1, -70, 0, 16),
		TextSize = 13,
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, row)
	looks[slot] = { name = name, hint = hint }
end

local function buildRecord()
	recordView = frame({
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 1, -92),
		BackgroundTransparency = 1,
	}, panel)
	label(
		{ Size = UDim2.new(0.45, 0, 0, 20), Text = "STATS", TextSize = 13, TextTransparency = 0.3 },
		recordView
	)
	statsList = frame({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(0.45, 0, 0, 200),
		BackgroundTransparency = 1,
	}, recordView)
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsList
	savingNote = label({
		Position = UDim2.fromOffset(0, 230),
		Size = UDim2.new(0.45, 0, 0, 22),
		Text = "NOT SAVING THIS SESSION",
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 16,
		Visible = false,
	}, recordView)

	label({
		Position = UDim2.new(0.5, 10, 0, 0),
		Size = UDim2.new(0.5, -10, 0, 20),
		Text = "LOOKS",
		TextSize = 13,
		TextTransparency = 0.3,
	}, recordView)
	local looksList = frame({
		Position = UDim2.new(0.5, 10, 0, 26),
		Size = UDim2.new(0.5, -10, 0, (TOUCH_TARGET + 16) * #SLOTS),
		BackgroundTransparency = 1,
	}, recordView)
	local looksLayout = Instance.new("UIListLayout")
	looksLayout.SortOrder = Enum.SortOrder.LayoutOrder
	looksLayout.Parent = looksList
	for index, slot in SLOTS do
		buildLookRow(slot, index, looksList)
	end

	blueprintLabel = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 12,
		TextWrapped = true,
	}, recordView)
	layOutButton = button(
		{
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(200, 32),
			Text = "LAY OUT HERE",
		},
		recordView,
		function()
			layOutRemote:FireServer()
		end
	)
	button(
		{
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(140, 32),
			Text = "SOUND",
		},
		recordView,
		function()
			show(nil)
			AudioSettings.open()
		end
	)
end

local function buildFeedback()
	feedbackLabel = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(500, 24),
		Text = "",
		TextSize = 18,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, gui)
end

local function onLockerState(state: any)
	if type(state) ~= "table" then
		return
	end
	stash = if type(state.locker) == "table" then state.locker else {}
	stashSlots = { used = tonumber(state.used) or 0, slots = tonumber(state.slots) or Settings.Locker.Slots }
	lockerPosition = if typeof(state.position) == "Vector3" then state.position else nil
	if state.open then
		lockerOpen = true
		if view ~= "stash" then
			show("stash")
		else
			refreshStash()
		end
	elseif view == "stash" then
		lockerOpen = false
		show(nil)
	end
end

local function update()
	feedbackLabel.Visible = os.clock() < feedbackUntil
	if view ~= "stash" or not lockerPosition then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - lockerPosition).Magnitude > Settings.Locker.Range + 4 then
		show(nil)
	end
end

local function onRecord(began: boolean)
	if began then
		show(if view == "record" then nil else "record")
	end
end

function Locker.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Locker"
	Input.markMenu(gui)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	buildPanel()
	buildStash()
	buildRecord()
	buildFiles()
	buildFeedback()
end

function Locker.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	moveRemote = Net.event("LockerMove")
	closeRemote = Net.event("LockerClose")
	equipRemote = Net.event("CosmeticEquip")
	layOutRemote = Net.event("BlueprintLayOut")

	Net.event("LockerState").OnClientEvent:Connect(onLockerState)
	Net.event("SavesFeedback").OnClientEvent:Connect(function(text)
		if type(text) == "string" then
			feedbackLabel.Text = text
			feedbackUntil = os.clock() + FEEDBACK_TIME
		end
	end)
	Net.event("RecordState").OnClientEvent:Connect(function(state)
		if type(state) == "table" and type(state.stats) == "table" and type(state.wearing) == "table" then
			record = state
			if view == "record" then
				refreshRecord()
			end
		end
	end)
	Net.event("BlueprintState").OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			blueprintPieces = tonumber(state.pieces) or 0
			if view == "record" then
				refreshRecord()
			end
		end
	end)
	Net.event("InventoryChanged").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" then
			bag = snapshot
			if view == "stash" then
				refreshStash()
			end
		end
	end)
	Net.event("FilesState").OnClientEvent:Connect(function(state)
		if type(state) == "table" and type(state.found) == "table" then
			filesFound = state.found
			if view == "files" then
				refreshFiles()
			end
		end
	end)
	Net.event("InventorySync"):FireServer()
	Net.event("FilesSync"):FireServer()
	Net.event("RecordSync"):FireServer()
	Net.event("SavesSync"):FireServer()

	local function closeStash()
		if view == "stash" then
			show(nil)
		end
	end
	player.CharacterRemoving:Connect(closeStash)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid").Died:Connect(closeStash)
	end)
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(closeStash)
		end
	end
	Input.bind("Record", onRecord)
	Glyphs.onChanged(fillFooter)
	RunService.RenderStepped:Connect(update)
end

return Locker
