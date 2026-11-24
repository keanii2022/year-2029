-- Shared input layer: every action has a keyboard/mouse input and a gamepad button.
-- Gamepad names are Roblox's Xbox names; the PS button is in the comment beside each.
-- Other controllers call Input.bind / Input.isDown instead of reading keys themselves.
local UserInputService = game:GetService("UserInputService")

export type Device = "Keyboard" | "Gamepad"
export type Binding = { keyboard: Enum.KeyCode | Enum.UserInputType, gamepad: Enum.KeyCode }

local Input = {}

Input.Actions = table.freeze({
	Sprint = { keyboard = Enum.KeyCode.LeftShift, gamepad = Enum.KeyCode.ButtonL3 }, -- L3
	Crouch = { keyboard = Enum.KeyCode.C, gamepad = Enum.KeyCode.ButtonR3 }, -- R3
	Jump = { keyboard = Enum.KeyCode.Space, gamepad = Enum.KeyCode.ButtonA }, -- Cross
	Psst = { keyboard = Enum.KeyCode.Q, gamepad = Enum.KeyCode.ButtonB }, -- Circle
	Use = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.ButtonX }, -- Square
	Rotate = { keyboard = Enum.KeyCode.R, gamepad = Enum.KeyCode.ButtonY }, -- Triangle
	Grab = { keyboard = Enum.KeyCode.F, gamepad = Enum.KeyCode.ButtonR1 }, -- R1
	Fire = { keyboard = Enum.UserInputType.MouseButton1, gamepad = Enum.KeyCode.ButtonR2 }, -- R2
	Aim = { keyboard = Enum.UserInputType.MouseButton2, gamepad = Enum.KeyCode.ButtonL2 }, -- L2
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
		if gamepad and input.KeyCode == binding.gamepad then
			return action, "Gamepad"
		end
		if not gamepad and (input.KeyCode == binding.keyboard or input.UserInputType == binding.keyboard) then
			return action, "Keyboard"
		end
	end
	return nil, nil
end

local function dispatch(input: InputObject, began: boolean)
	local action, device = match(input)
	if not action or not device then
		return
	end
	held[action] = began
	for _, listener in listeners[action] or {} do
		task.spawn(listener, began, device)
	end
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

function Input.isDown(action: string): boolean
	return held[action] == true
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
