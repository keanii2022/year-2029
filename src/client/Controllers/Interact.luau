-- Press to use: finds the usable object under the crosshair, shows "E  Open" on it, and asks the
-- server to use it on E / Square. While hidden, the same button gets you out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Hands = require(script.Parent.Hands)
local Input = require(script.Parent.Input)
local InteractKinds = require(ReplicatedStorage.Shared.Logic.InteractKinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Logic.Interact)

local Settings = Config.Interact

local LOOK_EVERY = 0.1 -- seconds between crosshair checks

local Interact = {}

local player = Players.LocalPlayer
local useRemote: RemoteEvent
local prompt: BillboardGui
local label: TextLabel
local target: Model? = nil
local targetPart: BasePart? = nil

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

local function keyName(): string
	local last = UserInputService:GetLastInputType()
	return if string.match(last.Name, "^Gamepad") then "Square" else "E"
end

local function refresh()
	local hidden = player:GetAttribute("Hidden") == true
	if hidden then
		target, targetPart = nil, nil
		local character = player.Character
		prompt.Adornee = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		label.Text = `{keyName()}  Get out`
		prompt.Enabled = prompt.Adornee ~= nil
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
	label.Text = `{keyName()}  {Rules.verb(resolved, on, false)}`
	prompt.Adornee = targetPart
	prompt.Enabled = true
end

local function buildPrompt()
	prompt = Instance.new("BillboardGui")
	prompt.Name = "InteractPrompt"
	prompt.Size = UDim2.fromOffset(220, 36)
	prompt.AlwaysOnTop = true
	prompt.Enabled = false
	prompt.ResetOnSpawn = false
	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	label.BackgroundTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = prompt
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	prompt.Parent = player:WaitForChild("PlayerGui")
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
