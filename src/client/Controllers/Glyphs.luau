-- Draws keys on screen so every prompt says exactly what to press on the device in use: light
-- keycaps on keyboard ("E", "LMB"), PlayStation buttons on a gamepad (coloured face shapes,
-- shoulder tabs, D-pad arrows) and the on-screen button's name on a phone.
-- Text templates mark keys with braces: "{Grab} Grab" uses the Grab action's key from Input, and
-- "{=R2}" draws one key by name. A template can also be { Keyboard = ..., Gamepad = ..., Touch = ... }.
-- Three or more spaces in a template leave a wider gap, for grouping "{Fire} Fire   {Aim} Aim".
local UserInputService = game:GetService("UserInputService")

local Input = require(script.Parent.Input)

export type Device = Input.Device
export type Template = string | { Keyboard: string?, Gamepad: string?, Touch: string? }
export type FillOptions = {
	size: number?, -- chip height
	textSize: number?,
	color: Color3?,
	font: Enum.Font?,
	device: Device?,
}

local Glyphs = {}

local TEXT = Color3.fromRGB(236, 232, 222)
local PANEL = Color3.fromRGB(18, 18, 20)
local KEYCAP = Color3.fromRGB(232, 228, 218)
local KEYCAP_INK = Color3.fromRGB(18, 18, 20)
local KEYCAP_EDGE = Color3.fromRGB(120, 116, 108)
Glyphs.SprayRed = Color3.fromRGB(200, 28, 22)
Glyphs.Text = TEXT

-- PlayStation face colours, a touch softer than the real ones so they sit in the dark scene
local FACE = {
	Triangle = Color3.fromRGB(78, 196, 160),
	Circle = Color3.fromRGB(232, 84, 84),
	Cross = Color3.fromRGB(122, 162, 240),
	Square = Color3.fromRGB(226, 128, 190),
}

local PAD_NAMES = {
	ButtonA = "Cross",
	ButtonB = "Circle",
	ButtonX = "Square",
	ButtonY = "Triangle",
	ButtonR1 = "R1",
	ButtonL1 = "L1",
	ButtonR2 = "R2",
	ButtonL2 = "L2",
	ButtonR3 = "R3",
	ButtonL3 = "L3",
	DPadUp = "DPadUp",
	DPadDown = "DPadDown",
	DPadLeft = "DPadLeft",
	DPadRight = "DPadRight",
	ButtonSelect = "Touchpad",
	ButtonStart = "Options",
}
local PAD_GLYPHS = {
	Cross = true,
	Circle = true,
	Square = true,
	Triangle = true,
	R1 = true,
	L1 = true,
	R2 = true,
	L2 = true,
	R3 = true,
	L3 = true,
	LS = true,
	RS = true,
	DPad = true,
	DPadUp = true,
	DPadDown = true,
	DPadLeft = true,
	DPadRight = true,
	Touchpad = true,
	Options = true,
}
local KEY_NAMES = {
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftControl = "Ctrl",
	LeftAlt = "Alt",
	Space = "Space",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	MouseWheel = "Scroll",
}
-- What the phone's on-screen button for each action says
local touchLabels: { [string]: string } = {
	Fire = "FIRE",
	Aim = "AIM",
	Reload = "RELOAD",
	Use = "USE",
	Flashlight = "LIGHT",
	Crouch = "CROUCH",
	Sprint = "RUN",
	Callout = "CALL",
	Jump = "JUMP",
	Record = "RECORD",
	Controls = "?",
	Backpack = "BAG",
	CarrySpin = "SPIN",
	CarryTip = "TIP",
	CarryCloser = "NEAR",
	CarryFarther = "FAR",
}
-- Reload has no gamepad button of its own: a tap on Square reloads a gun that isn't full (Gun)
local GAMEPAD_EXTRA = { Reload = "Square" }

local device: Device = Input.lastDevice()
local listeners: { (Device) -> () } = {}

function Glyphs.device(): Device
	return device
end

-- Calls listener(device) whenever the player switches between keyboard, gamepad and touch.
function Glyphs.onChanged(listener: (Device) -> ())
	table.insert(listeners, listener)
end

function Glyphs.touchLabel(action: string): string?
	return touchLabels[action]
end

-- The phone's big button changes its word with what's in hand (EAT, THROW, ...)
function Glyphs.setTouchLabel(action: string, label: string)
	touchLabels[action] = label
end

-- The glyph name for an action on a device ("E", "LMB", "Square", "USE"), or nil if it has none.
function Glyphs.nameFor(action: string, on: Device?): string?
	local which = on or device
	if which == "Touch" then
		return touchLabels[action]
	end
	local binding = Input.Actions[action]
	if not binding then
		return nil
	end
	if which == "Gamepad" then
		return if binding.gamepad then PAD_NAMES[binding.gamepad.Name] else GAMEPAD_EXTRA[action]
	end
	local key = binding.keyboard
	return if key then KEY_NAMES[key.Name] or key.Name else nil
end

function Glyphs.keyName(key: Enum.KeyCode): string
	return PAD_NAMES[key.Name] or KEY_NAMES[key.Name] or key.Name
end

-- The template's wording for a device.
function Glyphs.resolve(template: Template, on: Device?): string
	if type(template) == "table" then
		return template[on or device] or template.Keyboard or ""
	end
	return template
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(radius: UDim, parent: Instance)
	make("UICorner", { CornerRadius = radius }, parent)
end

local function stroke(color: Color3, transparency: number, thickness: number, parent: Instance)
	make("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function bar(
	parent: Instance,
	color: Color3,
	length: number,
	thick: number,
	x: number,
	y: number,
	angle: number
)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, x, 0.5, y),
		Size = UDim2.fromOffset(length, thick),
		Rotation = angle,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
end

local function textChip(text: string, h: number, fill: Color3, ink: Color3, round: boolean): TextLabel
	local chip = make("TextLabel", {
		Name = "Glyph",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		BackgroundColor3 = fill,
		BackgroundTransparency = 0.05,
		Text = text,
		TextColor3 = ink,
		Font = Enum.Font.GothamBold,
		TextSize = math.floor(h * (if #text > 3 then 0.46 else 0.56)),
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, h * 0.28), PaddingRight = UDim.new(0, h * 0.28) }, chip)
	make("UISizeConstraint", { MinSize = Vector2.new(h, h) }, chip)
	corner(if round then UDim.new(1, 0) else UDim.new(0, math.max(3, h * 0.2)), chip)
	return chip
end

local function keycap(name: string, h: number): GuiObject
	local chip = textChip(name, h, KEYCAP, KEYCAP_INK, false)
	stroke(KEYCAP_EDGE, 0.2, 1, chip)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 196, 188)),
	}, chip)
	return chip
end

local function face(name: string, h: number): GuiObject
	local color = FACE[name]
	local chip = make("Frame", {
		Name = "Glyph",
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
	})
	corner(UDim.new(1, 0), chip)
	stroke(color, 0.45, 1, chip)
	local s = h * 0.46
	local thick = math.max(1.5, h / 11)
	if name == "Circle" then
		local ring = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(s, s),
			BackgroundTransparency = 1,
		}, chip)
		corner(UDim.new(1, 0), ring)
		stroke(color, 0, thick, ring)
	elseif name == "Square" then
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(s * 0.86, s * 0.86),
			BackgroundTransparency = 1,
		}, chip)
		stroke(color, 0, thick, chip:FindFirstChildOfClass("Frame") :: Frame)
	elseif name == "Cross" then
		bar(chip, color, s * 1.15, thick, 0, 0, 45)
		bar(chip, color, s * 1.15, thick, 0, 0, -45)
	else
		-- Triangle from three bars: each sits on the midpoint of its edge
		local side = s * 1.1
		local height = side * math.sqrt(3) / 2
		local lift = -height * 0.08
		bar(chip, color, side + thick, thick, 0, height / 2 + lift, 0)
		bar(chip, color, side + thick, thick, -side / 4, lift, -60)
		bar(chip, color, side + thick, thick, side / 4, lift, 60)
	end
	return chip
end

local function dpad(name: string, h: number): GuiObject
	local chip = make("Frame", {
		Name = "Glyph",
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
	})
	corner(UDim.new(0, math.max(3, h * 0.22)), chip)
	stroke(TEXT, 0.6, 1, chip)
	local arm = h * 0.24
	local span = h * 0.7
	for _, rotation in { 0, 90 } do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(span, arm),
			Rotation = rotation,
			BackgroundColor3 = TEXT,
			BackgroundTransparency = if name == "DPad" then 0.15 else 0.7,
			BorderSizePixel = 0,
		}, chip)
	end
	local lit = ({
		DPadUp = Vector2.new(0, -1),
		DPadDown = Vector2.new(0, 1),
		DPadLeft = Vector2.new(-1, 0),
		DPadRight = Vector2.new(1, 0),
	})[name]
	if lit then
		local reach = span / 2 - arm / 2
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, lit.X * reach, 0.5, lit.Y * reach),
			Size = UDim2.fromOffset(arm + 1, arm + 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, chip)
	end
	return chip
end

local function padTab(name: string, h: number): GuiObject
	local label = if name == "LS" then "L" elseif name == "RS" then "R" else name
	if name == "Touchpad" then
		label = "TOUCHPAD"
	elseif name == "Options" then
		label = "OPTIONS"
	end
	local stick = name == "L3" or name == "R3" or name == "LS" or name == "RS"
	local trigger = name == "L2" or name == "R2"
	local chip = textChip(label, h, PANEL, TEXT, stick or trigger)
	stroke(TEXT, if stick then 0.35 else 0.5, 1, chip)
	if not stick then
		local constraint = chip:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
		constraint.MinSize = Vector2.new(h * 1.45, h)
	end
	return chip
end

local function touchPill(name: string, h: number): GuiObject
	local chip = textChip(name, h, Color3.fromRGB(12, 12, 14), TEXT, true)
	chip.TextSize = math.floor(h * 0.44)
	stroke(TEXT, 0.45, 1, chip)
	return chip
end

-- One key as a chip, h pixels tall. Style follows the name: PS names draw pad buttons, anything
-- else is a keycap, or an on-screen button when on a phone.
function Glyphs.chip(name: string, on: Device?, h: number?): GuiObject
	local size = h or 22
	if FACE[name] then
		return face(name, size)
	elseif name == "DPad" or string.sub(name, 1, 4) == "DPad" then
		return dpad(name, size)
	elseif PAD_GLYPHS[name] then
		return padTab(name, size)
	elseif (on or device) == "Touch" then
		return touchPill(name, size)
	end
	return keycap(name, size)
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Renders a template into container as chips and text in a row. Keys the device has no button for
-- are left out along with the words after them, so a gamepad-only "{Eat} Eat" vanishes on keyboard.
function Glyphs.fill(container: GuiObject, template: Template, options: FillOptions?)
	local opts: FillOptions = options or {}
	local on = opts.device or device
	local h = opts.size or 22
	local textSize = opts.textSize or math.floor(h * 0.7)
	clear(container)
	local layout = container:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, math.floor(h * 0.28)),
		}, container)
	end
	local order = 0
	local skipping = false
	local function add(object: GuiObject)
		order += 1
		object.LayoutOrder = order
		object.Parent = container
	end
	local function addText(text: string)
		for index, part in string.split(text, "   ") do
			if index > 1 then
				skipping = false
				add(make("Frame", { Size = UDim2.fromOffset(h * 0.4, 1), BackgroundTransparency = 1 }))
			end
			local trimmed = string.match(part, "^%s*(.-)%s*$") or ""
			if trimmed ~= "" and not skipping then
				add(make("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, h),
					BackgroundTransparency = 1,
					Text = trimmed,
					TextColor3 = opts.color or TEXT,
					Font = opts.font or Enum.Font.GothamMedium,
					TextSize = textSize,
				}))
			end
		end
	end
	local text = Glyphs.resolve(template, on)
	local cursor = 1
	while true do
		local first, last, token = string.find(text, "{([^}]*)}", cursor)
		if not first then
			break
		end
		addText(string.sub(text, cursor, first - 1))
		local name = if string.sub(token, 1, 1) == "="
			then string.sub(token, 2)
			else Glyphs.nameFor(token, on)
		if name then
			skipping = false
			add(Glyphs.chip(name, on, h))
		else
			skipping = true
		end
		cursor = last + 1
	end
	addText(string.sub(text, cursor))
end

function Glyphs.Init()
	UserInputService.LastInputTypeChanged:Connect(function()
		local now = Input.lastDevice()
		if now ~= device then
			device = now
			for _, listener in listeners do
				task.spawn(listener, now)
			end
		end
	end)
end

return Glyphs
