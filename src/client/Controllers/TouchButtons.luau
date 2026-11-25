-- On-screen buttons for phone players, shown only while the last input was a touch. Each button
-- presses an Input action, so a tap does exactly what the key or gamepad button does.
-- The cluster wraps round Roblox's jump button (movement stacked above it, actions to its left)
-- and only shows what matters right now: AIM and RELOAD with a gun in hand, SPIN / TIP / ROLL
-- (both ways) and NEAR / FAR while carrying. The big button says what it'll do: FIRE, EAT, THROW,
-- GRAB / PRY (only with something in reach, else a dim HANDS), DROP. CROUCH stays lit while crouched.
-- Roblox's own thumbstick and jump button stay; the jump button also presses Jump (breath, mash).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Glyphs = require(script.Parent.Glyphs)
local Grab = require(script.Parent.Grab)
local Gun = require(script.Parent.Gun)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local Movement = require(script.Parent.Movement)

local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local IDLE = 0.35
local PRESSED = 0.05
local DIM_TEXT = 0.55 -- the big button's text with nothing in reach
local REFRESH_EVERY = 0.2

-- Roblox's jump button on a small screen (min side <= 500): 70 across, centre 60 / 55 in from the
-- bottom-right corner. Bigger screens get a 120 one further in; the cluster moves out with it.
local SMALL_JUMP = { centre = Vector2.new(-60, -55), radius = 35 }
local LARGE_JUMP = { centre = Vector2.new(-110, -150), radius = 60 }

-- mode: hold mirrors the finger, toggle stays pressed until tapped again, tap is a quick press,
-- state is a tap whose lit look follows the game (crouched or not).
-- at: centre, from the bottom-right corner, laid out round the small-screen jump button.
-- when: shown only then ("gun", "carry", "free" = not carrying). corner: top-left instead.
type Spec = {
	name: string,
	action: string?,
	mode: "hold" | "toggle" | "tap" | "state",
	size: number,
	at: Vector2,
	when: ("gun" | "carry" | "free")?,
	corner: boolean?,
}

local BUTTONS: { Spec } = {
	{ name = "Fire", action = "Fire", mode = "hold", size = 80, at = Vector2.new(-160, -60) },
	{ name = "Crouch", action = "Crouch", mode = "state", size = 56, at = Vector2.new(-60, -138) },
	{ name = "Use", action = "Use", mode = "hold", size = 56, at = Vector2.new(-136, -150) },
	{
		name = "Backpack",
		action = "Backpack",
		mode = "tap",
		size = 56,
		at = Vector2.new(-212, -150),
		when = "free",
	},
	{ name = "Aim", action = "Aim", mode = "toggle", size = 56, at = Vector2.new(-248, -56), when = "gun" },
	{
		name = "Reload",
		action = "Reload",
		mode = "tap",
		size = 56,
		at = Vector2.new(-288, -130),
		when = "gun",
	},
	{ name = "Sprint", action = "Sprint", mode = "toggle", size = 56, at = Vector2.new(-60, -222) },
	{ name = "Flashlight", action = "Flashlight", mode = "tap", size = 56, at = Vector2.new(-136, -226) },
	-- hold, not tap, so a long press on CALL opens the call wheel like the key does
	{ name = "Callout", action = "Callout", mode = "hold", size = 56, at = Vector2.new(-212, -226) },
	-- Carry buttons: one column per axis, the "right / away" way on top
	{
		name = "CarrySpinRight",
		action = "CarrySpinRight",
		mode = "hold",
		size = 50,
		at = Vector2.new(-236, -106),
		when = "carry",
	},
	{
		name = "CarrySpinLeft",
		action = "CarrySpinLeft",
		mode = "hold",
		size = 50,
		at = Vector2.new(-236, -50),
		when = "carry",
	},
	{
		name = "CarryTipForward",
		action = "CarryTipForward",
		mode = "hold",
		size = 50,
		at = Vector2.new(-292, -106),
		when = "carry",
	},
	{
		name = "CarryTipBack",
		action = "CarryTipBack",
		mode = "hold",
		size = 50,
		at = Vector2.new(-292, -50),
		when = "carry",
	},
	{
		name = "CarryRollRight",
		action = "CarryRollRight",
		mode = "hold",
		size = 50,
		at = Vector2.new(-348, -106),
		when = "carry",
	},
	{
		name = "CarryRollLeft",
		action = "CarryRollLeft",
		mode = "hold",
		size = 50,
		at = Vector2.new(-348, -50),
		when = "carry",
	},
	{
		name = "CarryFarther",
		action = "CarryFarther",
		mode = "hold",
		size = 50,
		at = Vector2.new(-404, -106),
		when = "carry",
	},
	{
		name = "CarryCloser",
		action = "CarryCloser",
		mode = "hold",
		size = 50,
		at = Vector2.new(-404, -50),
		when = "carry",
	},
	{ name = "Controls", mode = "tap", size = 56, at = Vector2.new(16, 72), corner = true },
	{ name = "Record", action = "Record", mode = "tap", size = 56, at = Vector2.new(84, 72), corner = true },
}

local TouchButtons = {}

local gui: ScreenGui
local buttons: { [string]: TextButton } = {}
local specs: { [string]: Spec } = {}
local toggled: { [string]: boolean } = {}

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

local function fitText(button: TextButton, size: number)
	local text = button.Text
	button.TextSize = if size >= 80 then 17 elseif #text > 5 then 12 else 14
end

local function build(spec: Spec)
	local button = Instance.new("TextButton")
	button.Name = spec.name
	button.AnchorPoint = if spec.corner then Vector2.zero else Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(spec.size, spec.size)
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = Glyphs.touchLabel(spec.name) or spec.name
	button.TextColor3 = TEXT
	button.Font = Enum.Font.GothamBold
	fitText(button, spec.size)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = TEXT
	stroke.Transparency = if spec.size >= 80 then 0.5 else 0.7
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	paint(button, false)

	local finger: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or finger then
			return
		end
		if spec.mode == "toggle" then
			local on = not toggled[spec.name]
			toggled[spec.name] = on or nil
			paint(button, on)
			press(spec, on)
			return
		end
		if spec.mode == "state" then
			press(spec, true)
			press(spec, false)
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
	buttons[spec.name] = button
	specs[spec.name] = spec
end

local function release(spec: Spec)
	if toggled[spec.name] then
		toggled[spec.name] = nil
		paint(buttons[spec.name], false)
		press(spec, false)
	end
end

local function releaseToggles()
	for _, spec in BUTTONS do
		release(spec)
	end
end

-- Where a point laid out round the small jump button (from the bottom-right corner) lands round
-- whichever jump button this screen gets. Hud places the ammo readout with it too.
function TouchButtons.place(at: Vector2): UDim2
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(844, 390)
	local jump = if math.min(viewport.X, viewport.Y) <= 500 then SMALL_JUMP else LARGE_JUMP
	local grow = jump.radius - SMALL_JUMP.radius
	local offset = at - SMALL_JUMP.centre
	local placed = jump.centre + offset + Vector2.new(math.sign(offset.X), math.sign(offset.Y)) * grow
	return UDim2.new(1, placed.X, 1, placed.Y)
end

local function layout()
	for _, spec in BUTTONS do
		local button = buttons[spec.name]
		button.Position = if spec.corner
			then UDim2.fromOffset(spec.at.X, spec.at.Y)
			else TouchButtons.place(spec.at)
	end
end

-- What the big button does right now, and which context buttons show
local function refreshContext()
	local slot = Hotbar.selected()
	local carrying = Grab.carrying()
	local gun = Gun.getAmmo() ~= nil
	local word = if not slot then "FIRE" else Config.Hotbar.Verbs[slot.use] or "USE"
	local idle = false
	if carrying then
		word = "DROP"
	elseif slot and slot.use == "Grab" then
		local target = Grab.target()
		word = if target == "pry" then "PRY" elseif target then word else "HANDS"
		idle = target == nil
	end
	Glyphs.setTouchLabel("Fire", word)
	local fire = buttons.Fire
	if fire.Text ~= word then
		fire.Text = word
		fitText(fire, 80)
	end
	fire.TextTransparency = if idle then DIM_TEXT else 0
	-- Crouch is a toggle in Movement, so the button just shows it; crouching drops a toggled sprint
	local crouched = Movement.getStance() == "Crouch"
	paint(buttons.Crouch, crouched)
	if crouched then
		release(specs.Sprint)
	end
	for _, spec in BUTTONS do
		local show = spec.when == nil
			or (spec.when == "gun" and gun and not carrying)
			or (spec.when == "carry" and carrying)
			or (spec.when == "free" and not carrying)
		local button = buttons[spec.name]
		if button.Visible and not show then
			release(spec)
		end
		button.Visible = show
	end
end

local function refresh()
	local onTouch = Glyphs.device() == "Touch"
	if gui.Enabled and not onTouch then
		releaseToggles()
	end
	gui.Enabled = onTouch
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
	layout()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	Hotbar.onChanged(refreshContext)
	refreshContext()
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= REFRESH_EVERY and gui.Enabled then
			since = 0
			refreshContext()
		end
	end)
	Glyphs.onChanged(refresh)
	refresh()
end

return TouchButtons
