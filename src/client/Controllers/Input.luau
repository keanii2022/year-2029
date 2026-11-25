-- Shared input layer and the one button map for keyboard, gamepad and phone. Every action has a
-- keyboard/mouse input and/or a gamepad button; phone buttons (TouchButtons) press actions by name.
-- Gamepad names are Roblox's Xbox names; the PS button is in the comment beside each. The layout
-- follows what shooter players already know: R2 fire / use what you hold (empty hands: grab),
-- L2 aim, Square use/reload, Cross jump, L1 / R1 step the hotbar (empty hands is a slot),
-- Triangle opens the backpack. Circle calls out (hold: pick a call), R3 crouches.
-- While carrying, Grab takes over L1 / R1 / L2 and the D-pad to move the prop.
-- Glyphs draws these keys on screen.
-- Other controllers call Input.bind / Input.isDown instead of reading keys themselves.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

export type Device = "Keyboard" | "Gamepad" | "Touch"
-- freeHandsOnPad: Grab turns a carried prop with the D-pad, shoulders and triggers, so on a
-- gamepad these actions only fire while nothing is carried. freeHands: off on every device while
-- carrying (R turns the prop on the keyboard). keyboardAlt: a second key for the same action.
export type Binding = {
	keyboard: (Enum.KeyCode | Enum.UserInputType)?,
	keyboardAlt: Enum.KeyCode?,
	gamepad: Enum.KeyCode?,
	freeHandsOnPad: boolean?,
	freeHands: boolean?,
}

local player = Players.LocalPlayer

local Input = {}

local actions: { [string]: Binding } = {
	Sprint = { keyboard = Enum.KeyCode.LeftShift, gamepad = Enum.KeyCode.ButtonL3 }, -- L3 (click toggles)
	Crouch = {
		keyboard = Enum.KeyCode.C,
		keyboardAlt = Enum.KeyCode.LeftControl,
		gamepad = Enum.KeyCode.ButtonR3,
	}, -- R3
	Jump = { keyboard = Enum.KeyCode.Space, gamepad = Enum.KeyCode.ButtonA }, -- Cross
	-- Tap calls out, hold opens the call wheel (Callouts times it)
	Callout = { keyboard = Enum.KeyCode.Q, gamepad = Enum.KeyCode.ButtonB }, -- Circle
	Use = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.ButtonX }, -- Square
	-- On a gamepad Gun reloads from Square (Use) when there's nothing to use
	Reload = { keyboard = Enum.KeyCode.R, freeHands = true },
	-- Keyboard shortcut: empties your hands and grabs. Otherwise grabbing is Fire with empty hands.
	Grab = { keyboard = Enum.KeyCode.F },
	-- Also drops a carried prop (only empty hands can carry), so it stays on while carrying
	Fire = { keyboard = Enum.UserInputType.MouseButton1, gamepad = Enum.KeyCode.ButtonR2 }, -- R2
	Aim = {
		keyboard = Enum.UserInputType.MouseButton2,
		gamepad = Enum.KeyCode.ButtonL2,
		freeHandsOnPad = true,
	}, -- L2
	Flashlight = { keyboard = Enum.KeyCode.L, gamepad = Enum.KeyCode.DPadUp, freeHandsOnPad = true },
	-- Quick use on the gamepad; keyboard and phone pick these from the hotbar instead
	Eat = { gamepad = Enum.KeyCode.DPadLeft, freeHandsOnPad = true },
	Drink = { gamepad = Enum.KeyCode.DPadRight, freeHandsOnPad = true },
	Heal = { gamepad = Enum.KeyCode.DPadDown, freeHandsOnPad = true },
	-- Shortcuts on the keyboard; the gamepad and phone throw these from the hotbar
	Emp = { keyboard = Enum.KeyCode.G },
	Disruptor = { keyboard = Enum.KeyCode.V },
	HotbarNext = { gamepad = Enum.KeyCode.ButtonR1, freeHands = true }, -- R1
	HotbarPrevious = { gamepad = Enum.KeyCode.ButtonL1, freeHands = true }, -- L1
	-- B, not Tab: Roblox keeps Tab for its player list
	Backpack = { keyboard = Enum.KeyCode.B, gamepad = Enum.KeyCode.ButtonY, freeHands = true }, -- Triangle
	-- Touchpad: tap opens the controls card, hold opens the record (Hints times it)
	Controls = { keyboard = Enum.KeyCode.H, gamepad = Enum.KeyCode.ButtonSelect },
	Record = { keyboard = Enum.KeyCode.M },
	-- Phone-only carry buttons; keyboard and gamepad move props through Grab's own keys
	CarrySpinLeft = {},
	CarrySpinRight = {},
	CarryTipForward = {},
	CarryTipBack = {},
	CarryRollLeft = {},
	CarryRollRight = {},
	CarryCloser = {},
	CarryFarther = {},
}
-- Number keys pick hotbar slots (Slot1 .. Slot9); the mouse wheel is read by Hotbar itself.
local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
for number, key in NUMBER_KEYS do
	actions[`Slot{number}`] = { keyboard = key, freeHands = true }
end
Input.Actions = table.freeze(actions)
Input.SlotCount = #NUMBER_KEYS

type Listener = (began: boolean, device: Device) -> ()

local listeners: { [string]: { Listener } } = {}
local held: { [string]: boolean } = {}
-- While set, presses of every other action are dropped (the call wheel is open)
local exclusive: string? = nil
local MENU_ATTRIBUTE = "Menu"
local lastMenuSelection: GuiObject? = nil

local function isGamepad(input: InputObject): boolean
	return string.match(input.UserInputType.Name, "^Gamepad") ~= nil
end

local function match(input: InputObject): (string?, Device?)
	local gamepad = isGamepad(input)
	for action, binding in Input.Actions do
		if gamepad and binding.gamepad and input.KeyCode == binding.gamepad then
			return action, "Gamepad"
		end
		if
			not gamepad
			and binding.keyboard
			and (
				input.KeyCode == binding.keyboard
				or input.UserInputType == binding.keyboard
				or (binding.keyboardAlt and input.KeyCode == binding.keyboardAlt)
			)
		then
			return action, "Keyboard"
		end
	end
	return nil, nil
end

local function send(action: string, began: boolean, device: Device)
	held[action] = began
	for _, listener in listeners[action] or {} do
		task.spawn(listener, began, device)
	end
end

local function dispatch(input: InputObject, began: boolean)
	local action, device = match(input)
	if not action or not device then
		return
	end
	if not began then
		send(action, false, device)
		return
	end
	if exclusive and action ~= exclusive then
		return
	end
	local binding = Input.Actions[action]
	local carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil
	if carrying and (binding.freeHands or (device == "Gamepad" and binding.freeHandsOnPad)) then
		return
	end
	-- While a menu has the gamepad's selection (container, rob list, locker), the pad works the
	-- menu only, so Circle doesn't crouch and Square doesn't reload behind it.
	if device == "Gamepad" and GuiService.SelectedObject ~= nil and action ~= "Controls" then
		return
	end
	send(action, true, device)
end

local function onOpenMenu(object: GuiObject): boolean
	local screen = object:FindFirstAncestorWhichIsA("ScreenGui")
	if not screen or not screen.Enabled or screen:GetAttribute(MENU_ATTRIBUTE) ~= true then
		return false
	end
	local node: Instance? = object
	while node and node ~= screen do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

-- The gamepad selection may only sit on an open menu. The stick can wander off a panel onto the
-- hotbar or the phone buttons, and a selection left anywhere after its menu shuts keeps Roblox from
-- walking or looking and makes dispatch drop the pad's buttons, so it goes back or goes away.
local function keepSelectionOnMenus()
	local selected = GuiService.SelectedObject
	if not selected then
		return
	end
	if onOpenMenu(selected) then
		lastMenuSelection = selected
		return
	end
	local back = lastMenuSelection
	GuiService.SelectedObject = if back and back.Parent and onOpenMenu(back) then back else nil
end

-- A ScreenGui whose buttons the gamepad may select while it's open.
function Input.markMenu(gui: ScreenGui)
	gui:SetAttribute(MENU_ATTRIBUTE, true)
end

-- Calls listener(began, device) on press and release. Returns a function that unbinds.
function Input.bind(action: string, listener: Listener): () -> ()
	assert(Input.Actions[action], `Unknown input action {action}`)
	local list = listeners[action] or {}
	listeners[action] = list
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- On-screen buttons press and release actions through here.
function Input.press(action: string, began: boolean)
	assert(Input.Actions[action], `Unknown input action {action}`)
	send(action, began, "Touch")
end

-- Only this action's presses go through until it's cleared with nil. Releases always do.
function Input.setExclusive(action: string?)
	exclusive = action
end

function Input.isDown(action: string): boolean
	return held[action] == true
end

-- Which kind of device the player last touched, for button labels.
function Input.lastDevice(): Device
	local inputType = UserInputService:GetLastInputType()
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	return if string.match(inputType.Name, "^Gamepad") then "Gamepad" else "Keyboard"
end

function Input.Init()
	-- Roblox's default turns the touchpad / Select button into "pick a GUI button" mode, which would
	-- grab the hotbar every time someone opens the controls card.
	GuiService.AutoSelectGuiEnabled = false
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		task.defer(keepSelectionOnMenus)
	end)
	-- Catches menus that shut without clearing the selection: hidden objects fail onOpenMenu
	RunService.Heartbeat:Connect(keepSelectionOnMenus)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed then
			dispatch(input, true)
		end
	end)
	-- Releases always go through, so a key held into a menu never sticks down.
	UserInputService.InputEnded:Connect(function(input)
		dispatch(input, false)
	end)
end

return Input
