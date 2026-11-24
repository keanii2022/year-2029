-- Shared input layer and the one button map for keyboard, gamepad and phone. Every action has a
-- keyboard/mouse input and/or a gamepad button; phone buttons (TouchButtons) press actions by name.
-- Gamepad names are Roblox's Xbox names; the PS button is in the comment beside each.
-- Other controllers call Input.bind / Input.isDown instead of reading keys themselves.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

export type Device = "Keyboard" | "Gamepad" | "Touch"
-- freeHandsOnPad: Grab turns a carried prop with the D-pad, shoulders and triggers, so on a
-- gamepad these actions only fire while nothing is carried.
export type Binding = {
	keyboard: (Enum.KeyCode | Enum.UserInputType)?,
	gamepad: Enum.KeyCode?,
	freeHandsOnPad: boolean?,
}

local player = Players.LocalPlayer

local Input = {}

Input.Actions = table.freeze({
	Sprint = { keyboard = Enum.KeyCode.LeftShift, gamepad = Enum.KeyCode.ButtonL3 }, -- L3
	Crouch = { keyboard = Enum.KeyCode.C, gamepad = Enum.KeyCode.ButtonR3 }, -- R3
	Jump = { keyboard = Enum.KeyCode.Space, gamepad = Enum.KeyCode.ButtonA }, -- Cross
	Psst = { keyboard = Enum.KeyCode.Q, gamepad = Enum.KeyCode.ButtonB }, -- Circle
	Use = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.ButtonX }, -- Square
	Grab = { keyboard = Enum.KeyCode.F, gamepad = Enum.KeyCode.ButtonR1 }, -- R1
	Fire = {
		keyboard = Enum.UserInputType.MouseButton1,
		gamepad = Enum.KeyCode.ButtonR2,
		freeHandsOnPad = true,
	}, -- R2
	Aim = {
		keyboard = Enum.UserInputType.MouseButton2,
		gamepad = Enum.KeyCode.ButtonL2,
		freeHandsOnPad = true,
	}, -- L2
	Flashlight = { keyboard = Enum.KeyCode.L, gamepad = Enum.KeyCode.DPadUp, freeHandsOnPad = true },
	Eat = { keyboard = Enum.KeyCode.One, gamepad = Enum.KeyCode.DPadLeft, freeHandsOnPad = true },
	Drink = { keyboard = Enum.KeyCode.Two, gamepad = Enum.KeyCode.DPadRight, freeHandsOnPad = true },
	Heal = { keyboard = Enum.KeyCode.Three, gamepad = Enum.KeyCode.DPadDown, freeHandsOnPad = true },
	Emp = { keyboard = Enum.KeyCode.G, gamepad = Enum.KeyCode.ButtonY, freeHandsOnPad = true }, -- Triangle
	Disruptor = { keyboard = Enum.KeyCode.V, gamepad = Enum.KeyCode.ButtonL1, freeHandsOnPad = true }, -- L1
	Record = { keyboard = Enum.KeyCode.M, gamepad = Enum.KeyCode.ButtonSelect }, -- touchpad
	Controls = { keyboard = Enum.KeyCode.H },
} :: { [string]: Binding })

type Listener = (began: boolean, device: Device) -> ()

local listeners: { [string]: { Listener } } = {}
local held: { [string]: boolean } = {}

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
			and (input.KeyCode == binding.keyboard or input.UserInputType == binding.keyboard)
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
	local carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil
	if began and device == "Gamepad" and carrying and Input.Actions[action].freeHandsOnPad then
		return
	end
	send(action, began, device)
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
