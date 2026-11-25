-- On-screen help so nobody has to guess the keys. Three parts, all drawn with Glyphs so the keys
-- match the device in use and switch the moment the player does:
-- 1. Hint lines under the crosshair that other controllers set and clear
--    (Hints.set("grab", "{Grab} Grab")): only what matters right now, small and calm.
-- 2. First-time nudges (Hints.nudge): a slightly bigger line, once per session per thing.
-- 3. The controls card (H, the touchpad, or the ? button on a phone): a key list on keyboard and
--    phone, a drawn pad with callouts on a gamepad. Holding the touchpad opens the record instead.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Glyphs = require(script.Parent.Glyphs)
local Input = require(script.Parent.Input)

local settings = Config.Hints
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(16, 16, 18)
local TEXT = Glyphs.Text
local DIM = Color3.fromRGB(150, 146, 136)
local SPRAY_RED = Glyphs.SprayRed
local WARN_TEXT = Color3.fromRGB(236, 92, 80)
local PAD_HOLD = 0.45 -- seconds on the touchpad that open the record instead of the card

export type Tone = "warn" | "nudge"

local Hints = {}

type Line = { template: Glyphs.Template, order: number, tone: Tone? }
local lines: { [string]: Line } = {}
local nudgedAt: { [string]: number } = {}
local list: Frame
local card: Frame
local cardScale: UIScale
local flashlightUsed = false
local padDownAt: number? = nil
local padPress = 0

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- A pill wider than the screen allows shrinks to fit once its size is known
local function shrinkToFit(frame: Frame)
	local scale = make("UIScale", {}, frame)
	task.defer(function()
		local room = list.AbsoluteSize.X
		local width = frame.AbsoluteSize.X
		if width > room and width > 0 then
			scale.Scale = room / width
		end
	end)
end

local function pill(line: Line, layoutOrder: number): Frame
	local big = line.tone == "nudge"
	-- A "\n" in the wording for this device stacks the pill into rows
	local texts = string.split(Glyphs.resolve(line.template), "\n")
	local rowHeight = if big then 32 else 22
	local h = rowHeight * #texts + 8
	local frame = make("Frame", {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = if big then 0.12 else 0.3,
	}, list)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, if big then 16 else 10),
		PaddingRight = UDim.new(0, if big then 14 else 10),
	}, frame)
	if line.tone then
		make("UIStroke", {
			Color = SPRAY_RED,
			Transparency = if big then 0.55 else 0.3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, frame)
	end
	local stack = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, rowHeight * #texts),
		BackgroundTransparency = 1,
	}, frame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, stack)
	for index, text in texts do
		local row = make("Frame", {
			LayoutOrder = index,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, rowHeight),
			BackgroundTransparency = 1,
		}, stack)
		Glyphs.fill(row, text, {
			size = if big then 26 else 20,
			textSize = if big then 18 else 15,
			font = if big then Enum.Font.GothamBold else Enum.Font.GothamMedium,
			color = if line.tone == "warn" then WARN_TEXT else TEXT,
		})
	end
	if big then
		-- The spray-paint tick that marks a nudge as new
		make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -10, 0.5, 0),
			Size = UDim2.fromOffset(3, h - 14),
			BackgroundColor3 = SPRAY_RED,
			BorderSizePixel = 0,
		}, frame)
	end
	shrinkToFit(frame)
	return frame
end

local function redraw()
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local sorted = {}
	for id, line in lines do
		table.insert(sorted, { id = id, line = line })
	end
	table.sort(sorted, function(a, b)
		if a.line.order == b.line.order then
			return a.id < b.id
		end
		return a.line.order < b.line.order
	end)
	local maxLines = if Glyphs.device() == "Touch" then settings.TouchMaxLines else settings.MaxLines
	for index, entry in sorted do
		if index > maxLines then
			break
		end
		pill(entry.line, index).Name = entry.id
	end
end

local function same(a: Glyphs.Template, b: Glyphs.Template): boolean
	if type(a) ~= type(b) then
		return false
	elseif type(a) == "string" then
		return a == b
	end
	local x, y = a :: { [string]: string? }, b :: { [string]: string? }
	return x.Keyboard == y.Keyboard and x.Gamepad == y.Gamepad and x.Touch == y.Touch
end

-- Shows a hint line, or clears it with template = nil. Lower order sits higher. tone "warn" draws it
-- in spray red (low ammo); "nudge" is the bigger first-time look.
function Hints.set(id: string, template: Glyphs.Template?, order: number?, tone: Tone?)
	local current = lines[id]
	if template == nil then
		if current then
			lines[id] = nil
			redraw()
		end
		return
	end
	local wanted = order or 10
	if current and same(current.template, template) and current.order == wanted and current.tone == tone then
		return
	end
	lines[id] = { template = template, order = wanted, tone = tone }
	redraw()
end

-- Shows a hint for a few seconds, then clears it. order defaults to 0 (top); flavour toasts pass a
-- higher one so they never push out a hint that matters.
function Hints.flash(id: string, template: Glyphs.Template, seconds: number?, tone: Tone?, order: number?)
	Hints.set(id, template, order or 0, tone)
	task.delay(seconds or 4, function()
		local line = lines[id]
		if line and same(line.template, template) then
			Hints.set(id, nil)
		end
	end)
end

-- The first time something becomes relevant this session, shows a bigger one-line nudge for a few
-- seconds. Returns true while that nudge is up, so the caller can hold back its small hint.
function Hints.nudge(id: string, template: Glyphs.Template): boolean
	local shownAt = nudgedAt[id]
	if not shownAt then
		nudgedAt[id] = os.clock()
		Hints.flash(`nudge_{id}`, template, settings.NudgeSeconds, "nudge")
		return true
	end
	return lines[`nudge_{id}`] ~= nil
end

-- Takes a nudge down early, once it's done its job (the light went on).
function Hints.clearNudge(id: string)
	Hints.set(`nudge_{id}`, nil)
end

-- Controls card ------------------------------------------------------------------------------------

local function label(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.Gotham
	props.TextSize = props.TextSize or 15
	return make("TextLabel", props, parent)
end

local function vertical(parent: Instance, padding: number, align: Enum.HorizontalAlignment?)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	}, parent)
end

local function row(parent: Instance, order: number, h: number): Frame
	return make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, h),
		BackgroundTransparency = 1,
	}, parent)
end

-- One column of { keys, what it does } rows; one-entry rows are headings.
local function keyColumn(parent: Instance, order: number, rows: { { string } }, width: number)
	local column = make("Frame", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(width, 0),
		BackgroundTransparency = 1,
	}, parent)
	vertical(column, 2)
	for index, entry in rows do
		if #entry == 1 then
			local heading = row(column, index, 26)
			label({
				Size = UDim2.fromScale(1, 1),
				Text = entry[1],
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = DIM,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}, heading)
			continue
		end
		local line = row(column, index, 26)
		local keys = make("Frame", { Size = UDim2.new(0, 124, 1, 0), BackgroundTransparency = 1 }, line)
		Glyphs.fill(keys, entry[1], { size = 20, textSize = 13, color = DIM })
		label({
			Position = UDim2.fromOffset(130, 0),
			Size = UDim2.new(1, -130, 1, 0),
			Text = entry[2],
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, line)
	end
end

local function callouts(parent: Instance, order: number, rows: { { string } }, onLeft: boolean)
	local column = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(212, 196),
		BackgroundTransparency = 1,
	}, parent)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, column)
	for index, entry in rows do
		local line = row(column, index, 26)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if onLeft
				then Enum.HorizontalAlignment.Right
				else Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}, line)
		local chip = make("Frame", {
			LayoutOrder = if onLeft then 2 else 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			BackgroundTransparency = 1,
		}, line)
		Glyphs.fill(chip, entry[1], { size = 22, device = "Gamepad" })
		label({
			LayoutOrder = if onLeft then 1 else 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			Text = entry[2],
		}, line)
	end
end

-- A simple pad built from frames, with each button drawn where it sits on the real thing.
local function padDrawing(parent: Instance, order: number)
	local W, H = 300, 196
	local drawing = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
	}, parent)
	local shell = Color3.fromRGB(38, 38, 42)
	for _, grip in { { x = 58, rotation = 16 }, { x = W - 58, rotation = -16 } } do
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(grip.x, 136),
			Size = UDim2.fromOffset(78, 104),
			Rotation = grip.rotation,
			BackgroundColor3 = shell,
			BackgroundTransparency = 0.1,
		}, drawing)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	end
	local body = make("Frame", {
		Position = UDim2.fromOffset(18, 46),
		Size = UDim2.fromOffset(W - 36, 100),
		BackgroundColor3 = shell,
		BackgroundTransparency = 0.1,
	}, drawing)
	make("UICorner", { CornerRadius = UDim.new(0, 40) }, body)
	make("UIStroke", { Color = TEXT, Transparency = 0.85 }, body)
	local function place(name: string, x: number, y: number, h: number)
		local chip = Glyphs.chip(name, "Gamepad", h)
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.fromOffset(x, y)
		chip.ZIndex = 2
		chip.Parent = drawing
	end
	place("L2", 68, 10, 20)
	place("L1", 68, 33, 18)
	place("R2", W - 68, 10, 20)
	place("R1", W - 68, 33, 18)
	place("Touchpad", W / 2, 66, 18)
	place("DPad", 74, 94, 40)
	local faceX, faceY = W - 74, 94
	place("Triangle", faceX, faceY - 22, 22)
	place("Square", faceX - 22, faceY, 22)
	place("Circle", faceX + 22, faceY, 22)
	place("Cross", faceX, faceY + 22, 22)
	place("LS", 116, 134, 30)
	place("RS", W - 116, 134, 30)
end

local function centredLine(parent: Instance, order: number, template: Glyphs.Template, device: Glyphs.Device)
	local line = row(parent, order, 26)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, line)
	Glyphs.fill(line, template, { size = 20, textSize = 14, color = DIM, device = device })
end

local function fillCard()
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local device = Glyphs.device()
	local layout = settings.Card[device]

	local header = row(card, 1, 38)
	label({
		Size = UDim2.fromScale(1, 1),
		Text = settings.CardTitle,
		Font = Enum.Font.PermanentMarker,
		TextSize = 28,
		TextColor3 = SPRAY_RED,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local close = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
	}, header)
	Glyphs.fill(close, settings.CardClose, { size = 20, textSize = 13, color = DIM })
	make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = SPRAY_RED,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, card)

	local body = make("Frame", {
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
	}, card)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, if device == "Gamepad" then 8 else 28),
	}, body)
	if device == "Gamepad" then
		callouts(body, 1, layout.left, true)
		padDrawing(body, 2)
		callouts(body, 3, layout.right, false)
		centredLine(card, 4, layout.carry, device)
		centredLine(card, 5, layout.footer, device)
	else
		keyColumn(body, 1, layout.left, 340)
		keyColumn(body, 2, layout.right, 340)
	end
	if player:GetAttribute("Admin") == true then
		centredLine(card, 6, Config.Admin.CardLine, device)
	end
end

-- Shrinks the card to fit small screens (a phone held sideways is only ~390 points tall)
local function fitCard()
	cardScale.Scale = 1
	RunService.Heartbeat:Wait()
	local camera = workspace.CurrentCamera
	local size = card.AbsoluteSize
	if camera and size.X > 0 and size.Y > 0 then
		local viewport = camera.ViewportSize
		cardScale.Scale = math.min(1, (viewport.X - 24) / size.X, (viewport.Y - 24) / size.Y)
	end
end

function Hints.toggleCard()
	if not card then
		return
	end
	card.Visible = not card.Visible
	if card.Visible then
		fillCard()
		task.spawn(fitCard)
	end
	Hints.set("controls", nil)
end

local function buildCard(parent: ScreenGui): Frame
	local frame = make("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = Color3.fromRGB(14, 14, 16),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 5,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
	make("UIStroke", { Color = TEXT, Transparency = 0.88 }, frame)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 22),
		PaddingRight = UDim.new(0, 22),
	}, frame)
	vertical(frame, 8)
	cardScale = make("UIScale", {}, frame)
	return frame
end

local function onControls(began: boolean, device: Input.Device)
	if device ~= "Gamepad" then
		if began then
			Hints.toggleCard()
		end
		return
	end
	if began then
		padPress += 1
		local press = padPress
		padDownAt = os.clock()
		task.delay(PAD_HOLD, function()
			if press == padPress and padDownAt then
				padDownAt = nil
				Input.press("Record", true)
				Input.press("Record", false)
			end
		end)
	elseif padDownAt then
		padDownAt = nil
		Hints.toggleCard()
	end
end

-- Watchers -----------------------------------------------------------------------------------------

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- Truly dark: it's night and no emergency light is close by
local function isDark(at: Vector3): boolean
	if ReplicatedStorage:GetAttribute("Phase") ~= "Night" then
		return false
	end
	for _, strip in CollectionService:GetTagged("WarehouseLight") do
		if
			strip:IsA("BasePart")
			and strip:GetAttribute("Emergency") == true
			and (strip.Position - at).Magnitude < settings.LitRadius
		then
			return false
		end
	end
	return true
end

local function robotClose(at: Vector3): boolean
	local folder = workspace:FindFirstChild("Robots")
	if not folder then
		return false
	end
	for _, robot in folder:GetChildren() do
		local state = robot:GetAttribute("State")
		if
			robot:IsA("Model")
			and state ~= "stalled"
			and state ~= "disabled"
			and (robot:GetPivot().Position - at).Magnitude < settings.RobotNudgeDistance
		then
			return true
		end
	end
	return false
end

local function watch()
	while true do
		task.wait(1)
		local at = rootPosition()
		local lightOn = player:GetAttribute("FlashlightOn") == true
		if lightOn and not flashlightUsed then
			flashlightUsed = true
			Hints.clearNudge("dark")
		end
		if at and not flashlightUsed and not lightOn and isDark(at) then
			local nudging = Hints.nudge("dark", settings.DarkNudge)
			Hints.set("flashlight", if nudging then nil else settings.FlashlightHint, 1)
		else
			Hints.set("flashlight", nil)
		end
		if at and not nudgedAt.robot and robotClose(at) then
			Hints.nudge("robot", settings.RobotNudge)
		end
	end
end

-- First join: what the game is, a line at a time, then where your locker is and the controls card
local function intro()
	task.wait(settings.IntroDelay)
	for _, line in settings.IntroLines do
		Hints.flash("intro", line, settings.IntroGap, "nudge", 1)
		task.wait(settings.IntroGap)
	end
	Hints.nudge("stash", settings.StashNudge)
	task.wait(settings.NudgeSeconds)
	Hints.flash("controls", settings.StartHint, settings.StartHintSeconds)
end

local function onHidden()
	local hidden = player:GetAttribute("Hidden") == true
	Hints.set("hidden", if hidden then settings.HiddenHint else nil, 1)
end

function Hints.Start()
	local gui = make("ScreenGui", {
		Name = "Hints",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))

	-- Just under the crosshair, clear of its centre
	list = make("Frame", {
		Name = "Lines",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 44),
		Size = UDim2.new(1, -24, 0, 200),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	card = buildCard(gui)
	Input.bind("Controls", onControls)
	Glyphs.onChanged(function()
		redraw()
		if card.Visible then
			fillCard()
			task.spawn(fitCard)
		end
	end)
	player:GetAttributeChangedSignal("Hidden"):Connect(onHidden)
	onHidden()
	task.spawn(intro)
	task.spawn(watch)
end

return Hints
