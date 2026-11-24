-- On-screen buttons for phone players, shown only while the last input was a touch. Each button
-- presses an Input action, so a tap does exactly what the key or gamepad button does. Roblox's own
-- thumbstick and jump button stay; the jump button also presses the Jump action (breath, mash).
-- Supplies and gear are picked by tapping the hotbar; the big button then does what's in hand and
-- says so (FIRE, EAT, THROW, ...).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)

local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local IDLE = 0.35
local PRESSED = 0.05

-- mode: hold mirrors the finger, toggle stays pressed until tapped again, tap is a quick press.
-- Positions are from the bottom-right corner (bottom-left for the top row), clear of the jump
-- button Roblox puts in the bottom-right.
type Spec = {
	label: string,
	action: string?,
	mode: "hold" | "toggle" | "tap",
	size: number,
	anchor: Vector2,
	position: UDim2,
}

local BUTTONS: { Spec } = {
	{
		label = "FIRE",
		action = "Fire",
		mode = "hold",
		size = 88,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -196, 1, -100),
	},
	{
		label = "AIM",
		action = "Aim",
		mode = "toggle",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -296, 1, -130),
	},
	{
		label = "RELOAD",
		action = "Reload",
		mode = "tap",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -296, 1, -200),
	},
	{
		label = "USE",
		action = "Use",
		mode = "hold",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -24, 1, -236),
	},
	{
		label = "GRAB",
		action = "Grab",
		mode = "hold",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -96, 1, -236),
	},
	{
		label = "LIGHT",
		action = "Flashlight",
		mode = "tap",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -168, 1, -236),
	},
	{
		label = "CROUCH",
		action = "Crouch",
		mode = "tap",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -24, 1, -308),
	},
	{
		label = "RUN",
		action = "Sprint",
		mode = "toggle",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -96, 1, -308),
	},
	{
		label = "PSST",
		action = "Psst",
		mode = "tap",
		size = 60,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -168, 1, -308),
	},
	{
		action = "Eat",
		mode = "tap",
		size = 52,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, -120, 1, -24),
	},
	{
		action = "Drink",
		mode = "tap",
		size = 52,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, -60, 1, -24),
	},
	{
		action = "Heal",
		mode = "tap",
		size = 52,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -24),
	},
	{
		action = "Emp",
		mode = "tap",
		size = 52,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 60, 1, -24),
	},
	{
		action = "Disruptor",
		mode = "tap",
		size = 52,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 120, 1, -24),
	},
	{ label = "?", mode = "tap", size = 44, anchor = Vector2.new(0, 0), position = UDim2.fromOffset(16, 70) },
	{
		label = "REC",
		action = "Record",
		mode = "tap",
		size = 44,
		anchor = Vector2.new(0, 0),
		position = UDim2.fromOffset(68, 70),
	},
}

local TouchButtons = {}

local gui: ScreenGui
local toggled: { [string]: TextButton } = {}

local function paint(button: TextButton, pressed: boolean)
	button.BackgroundTransparency = if pressed then PRESSED else IDLE
end

local function press(spec: Spec, began: boolean)
	if spec.action then
		Input.press(spec.action, began)
	elseif began then
		Hints.toggleCard()
	end
end

local function build(spec: Spec)
	local button = Instance.new("TextButton")
	button.Name = spec.label
	button.AnchorPoint = spec.anchor
	button.Position = spec.position
	button.Size = UDim2.fromOffset(spec.size, spec.size)
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = spec.label
	button.TextColor3 = TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = if spec.size >= 80 then 18 elseif #spec.label > 5 then 10 else 13
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = TEXT
	stroke.Transparency = 0.7
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	paint(button, false)

	local finger: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or finger then
			return
		end
		if spec.mode == "toggle" then
			local on = toggled[spec.label] == nil
			toggled[spec.label] = if on then button else nil
			paint(button, on)
			press(spec, on)
			return
		end
		paint(button, true)
		press(spec, true)
		if spec.mode == "tap" then
			press(spec, false)
			task.delay(0.12, paint, button, false)
		else
			finger = input
		end
	end)
	-- The finger can slide off the button before lifting, so watch the touch itself.
	UserInputService.TouchEnded:Connect(function(input)
		if input == finger then
			finger = nil
			paint(button, false)
			press(spec, false)
		end
	end)
	button.Parent = gui
end

local function releaseToggles()
	for _, spec in BUTTONS do
		local button = toggled[spec.label]
		if button then
			toggled[spec.label] = nil
			paint(button, false)
			press(spec, false)
		end
	end
end

-- Roblox's jump button lives in TouchGui and is rebuilt now and then, so hook each one that appears.
local function hookJump(descendant: Instance)
	if descendant.Name ~= "JumpButton" or not descendant:IsA("GuiObject") then
		return
	end
	descendant.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Input.press("Jump", true)
			local ended
			ended = UserInputService.TouchEnded:Connect(function(touch)
				if touch == input then
					ended:Disconnect()
					Input.press("Jump", false)
				end
			end)
		end
	end)
end

local function relabelFire()
	local fire = gui:FindFirstChild("FIRE") :: TextButton?
	local slot = Hotbar.selected()
	if fire then
		fire.Text = if slot then Config.Hotbar.Verbs[slot.use] or "USE" else "FIRE"
	end
end

local function refresh()
	local onTouch = Input.lastDevice() == "Touch"
	if gui.Enabled and not onTouch then
		releaseToggles()
	end
	gui.Enabled = onTouch
end

function TouchButtons.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "TouchButtons"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	gui.Enabled = false
	for _, spec in BUTTONS do
		build(spec)
	end
end

function TouchButtons.Start()
	if not UserInputService.TouchEnabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	playerGui.DescendantAdded:Connect(hookJump)
	for _, descendant in playerGui:GetDescendants() do
		hookJump(descendant)
	end
	player.CharacterAdded:Connect(releaseToggles)
	Hotbar.onChanged(relabelFire)
	relabelFire()
	UserInputService.LastInputTypeChanged:Connect(refresh)
	refresh()
end

return TouchButtons
