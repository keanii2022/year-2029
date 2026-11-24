-- Press to use: finds the usable object under the crosshair, shows "[E] Open" on it (the key drawn
-- by Glyphs for the device in use), and asks the server to use it on E / Square / USE. While
-- hidden the same button gets you out; Hints shows that line, so nothing floats mid-screen.
-- Also draws the server's ProximityPrompts (pickups, stashes, the dog, uncuffing) in the same
-- style instead of Roblox's default, with the right key glyph and a fill bar for hold prompts.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Glyphs = require(script.Parent.Glyphs)
local Hands = require(script.Parent.Hands)
local Input = require(script.Parent.Input)
local InteractKinds = require(ReplicatedStorage.Shared.Logic.InteractKinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Logic.Interact)

local Settings = Config.Interact

local LOOK_EVERY = 0.1 -- seconds between crosshair checks
local PANEL = Color3.fromRGB(20, 20, 22)
local DIM = Color3.fromRGB(150, 146, 136)

local Interact = {}

local player = Players.LocalPlayer
local useRemote: RemoteEvent
local prompt: BillboardGui
local promptRow: Frame
local shownText: string? = nil
local target: Model? = nil
local targetPart: BasePart? = nil

type Shown =
	{ gui: BillboardGui, row: Frame, object: TextLabel, fill: Frame, touchEnded: RBXScriptConnection }
local shownPrompts: { [ProximityPrompt]: Shown } = {}

local function usableModel(instance: Instance): Model?
	local current: Instance? = instance
	while current and current ~= workspace do
		if current:IsA("Model") and InteractKinds.get(current:GetAttribute("ModelName")) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function look(): (Model?, BasePart?)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return nil, nil
	end
	local center = camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(center.X, center.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local length = Settings.Reach + (camera.CFrame.Position - root.Position).Magnitude + 2
	local hit = workspace:Raycast(ray.Origin, ray.Direction * length, params)
	if not hit then
		return nil, nil
	end
	local model = usableModel(hit.Instance)
	if not model or (hit.Position - root.Position).Magnitude > Settings.Reach + 2 then
		return nil, nil
	end
	return model, hit.Instance :: BasePart
end

-- The dark pill every prompt sits in; returns the row the glyphs go into
local function pill(parent: GuiObject): Frame
	parent.BackgroundColor3 = PANEL
	parent.BackgroundTransparency = 0.25
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = parent
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromScale(0, 1)
	row.BackgroundTransparency = 1
	row.Parent = parent
	return row
end

-- True when Square / E would do something here, so Gun leaves reloading to an empty Square
function Interact.canUse(): boolean
	return (prompt ~= nil and prompt.Enabled)
		or next(shownPrompts) ~= nil
		or player:GetAttribute("Hidden") == true
end

local function refresh()
	if player:GetAttribute("Hidden") == true then
		target, targetPart = nil, nil
		prompt.Enabled = false
		return
	end
	target, targetPart = look()
	if not target or not targetPart then
		prompt.Enabled = false
		return
	end
	local behaviour = InteractKinds.get(target:GetAttribute("ModelName")) :: InteractKinds.Behaviour
	local resolved, key = Rules.resolve(behaviour, targetPart.Name)
	local on = target:GetAttribute(Rules.stateAttribute(key)) == true
	local text = "{Use} " .. Rules.verb(resolved, on, false)
	if text ~= shownText then
		shownText = text
		Glyphs.fill(promptRow, text, { size = 22, textSize = 17, font = Enum.Font.GothamBold })
	end
	prompt.Adornee = targetPart
	prompt.Enabled = true
end

local function buildPrompt()
	prompt = Instance.new("BillboardGui")
	prompt.Name = "InteractPrompt"
	prompt.Size = UDim2.fromOffset(240, 36)
	prompt.AlwaysOnTop = true
	prompt.Enabled = false
	prompt.ResetOnSpawn = false
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.5)
	back.AutomaticSize = Enum.AutomaticSize.X
	back.Size = UDim2.fromOffset(0, 36)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 12)
	padding.Parent = back
	back.Parent = prompt
	promptRow = pill(back)
	promptRow.Position = UDim2.fromScale(0, 0.5)
	promptRow.AnchorPoint = Vector2.new(0, 0.5)
	prompt.Parent = player:WaitForChild("PlayerGui")
end

-- ProximityPrompts -------------------------------------------------------------------------------

local function promptText(proximity: ProximityPrompt): string
	local device = Glyphs.device()
	local key = if device == "Gamepad"
		then Glyphs.keyName(proximity.GamepadKeyCode)
		elseif device == "Touch" then "TAP"
		else Glyphs.keyName(proximity.KeyboardKeyCode)
	local hold = if proximity.HoldDuration > 0 then "Hold " else ""
	return hold .. "{=" .. key .. "} " .. proximity.ActionText
end

local function fillShown(proximity: ProximityPrompt, shown: Shown)
	Glyphs.fill(shown.row, promptText(proximity), { size = 22, textSize = 16, font = Enum.Font.GothamBold })
	shown.object.Text = proximity.ObjectText
	shown.object.Visible = proximity.ObjectText ~= ""
end

local function showPrompt(proximity: ProximityPrompt)
	if shownPrompts[proximity] then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt"
	gui.Size = UDim2.fromOffset(280, 58)
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.Active = true
	gui.Adornee = proximity.Parent :: Instance
	local object = Instance.new("TextLabel")
	object.Size = UDim2.new(1, 0, 0, 16)
	object.BackgroundTransparency = 1
	object.Font = Enum.Font.GothamMedium
	object.TextSize = 13
	object.TextColor3 = DIM
	object.TextStrokeTransparency = 0.7
	object.Parent = gui
	local back = Instance.new("TextButton")
	back.Text = ""
	back.AutoButtonColor = false
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.fromScale(0.5, 1)
	back.AutomaticSize = Enum.AutomaticSize.X
	back.Size = UDim2.fromOffset(0, 38)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 12)
	padding.Parent = back
	back.Parent = gui
	local row = pill(back)
	row.Position = UDim2.fromScale(0, 0.5)
	row.AnchorPoint = Vector2.new(0, 0.5)
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, -8, 1, 0)
	fill.Size = UDim2.fromOffset(0, 3)
	fill.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	fill.BorderSizePixel = 0
	fill.Parent = back
	-- Custom prompts don't take taps by themselves
	local finger: InputObject? = nil
	back.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not finger then
			finger = input
			proximity:InputHoldBegin()
		end
	end)
	local touchEnded = UserInputService.TouchEnded:Connect(function(input)
		if input == finger then
			finger = nil
			proximity:InputHoldEnd()
		end
	end)
	local shown = { gui = gui, row = row, object = object, fill = fill, touchEnded = touchEnded }
	shownPrompts[proximity] = shown
	fillShown(proximity, shown)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function hidePrompt(proximity: ProximityPrompt)
	local shown = shownPrompts[proximity]
	if shown then
		shownPrompts[proximity] = nil
		shown.touchEnded:Disconnect()
		shown.gui:Destroy()
	end
end

local function adopt(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
		instance:GetPropertyChangedSignal("ActionText"):Connect(function()
			local shown = shownPrompts[instance]
			if shown then
				fillShown(instance, shown)
			end
		end)
		instance.Destroying:Connect(function()
			hidePrompt(instance)
		end)
	end
end

local function watchPrompts()
	workspace.DescendantAdded:Connect(adopt)
	for _, descendant in workspace:GetDescendants() do
		adopt(descendant)
	end
	ProximityPromptService.PromptShown:Connect(showPrompt)
	ProximityPromptService.PromptHidden:Connect(hidePrompt)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(proximity)
		local shown = shownPrompts[proximity]
		if shown then
			shown.fill.Size = UDim2.fromOffset(0, 3)
			TweenService:Create(
				shown.fill,
				TweenInfo.new(proximity.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(1, 20, 0, 3) }
			):Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(proximity)
		local shown = shownPrompts[proximity]
		if shown then
			TweenService:Create(shown.fill, TweenInfo.new(0.1), { Size = UDim2.fromOffset(0, 3) }):Play()
		end
	end)
end

function Interact.Init()
	Input.bind("Use", function(began)
		if not began or not useRemote then
			return
		end
		if player:GetAttribute("Hidden") == true then
			useRemote:FireServer(nil, nil)
		elseif target and targetPart then
			useRemote:FireServer(target, targetPart.Name)
			Hands.reach(targetPart.Position)
		end
	end)
end

function Interact.Start()
	useRemote = Net.event("InteractUse")
	buildPrompt()
	watchPrompts()
	Glyphs.onChanged(function()
		shownText = nil
		for proximity, shown in shownPrompts do
			fillShown(proximity, shown)
		end
	end)
	local since = 0
	RunService.RenderStepped:Connect(function(dt)
		since += dt
		if since >= LOOK_EVERY then
			since = 0
			refresh()
		end
	end)
end

return Interact
