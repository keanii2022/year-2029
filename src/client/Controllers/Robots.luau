-- Robot gear keys (EMP G / D-pad down, disruptor V / D-pad right) and the local-only life of stalled
-- robots: flickering eyes, twitches and the odd "ERROR. NEEDS MORE TRAINING." over the nearest one.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local settings = Config.Robots
local player = Players.LocalPlayer

local Robots = {}

local gearRemote: RemoteEvent
local random = Random.new()
local nextTwitch: { [Model]: number } = {}
local nextLineAt = 0

local function useGear(action: string)
	return function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			gearRemote:FireServer(action, workspace.CurrentCamera.CFrame.LookVector)
		end
		return Enum.ContextActionResult.Sink
	end
end

local function isFrozen(model: Model): boolean
	local state = model:GetAttribute("State")
	return state == "stalled" or state == "disabled"
end

local function twitch(model: Model)
	local motors = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			table.insert(motors, descendant)
		end
	end
	if #motors == 0 then
		return
	end
	local motor = motors[random:NextInteger(1, #motors)]
	local rest = motor.C0
	motor.C0 = rest * CFrame.Angles(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.4, 0.4), 0)
	task.delay(0.12, function()
		if motor.Parent then
			motor.C0 = rest
		end
	end)
end

local function sayLine(model: Model)
	local head = model:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = settings.StallLineRange * 1.5
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = settings.NightEyeColor
	label.TextStrokeTransparency = 0.4
	label.Text = settings.StallLine
	label.Parent = gui
	gui.Parent = head
	TweenService:Create(label, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(gui, 2.6)
end

local function step(folder: Instance)
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearest, nearestDistance = nil, settings.StallLineRange
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local frozen = isFrozen(model)
		local eyes = model:FindFirstChild(settings.EyePart, true)
		if eyes and eyes:IsA("BasePart") then
			eyes.Transparency = if frozen and random:NextNumber() < 0.3
				then random:NextNumber(0.4, 0.9)
				else 0
		end
		if not frozen then
			continue
		end
		local due = nextTwitch[model]
		if not due then
			nextTwitch[model] = now + random:NextNumber(table.unpack(settings.TwitchEvery))
		elseif now >= due then
			nextTwitch[model] = nil
			twitch(model)
		end
		if root and root:IsA("BasePart") and model:GetAttribute("Role") == "hunter" then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			if d < nearestDistance then
				nearest, nearestDistance = model, d
			end
		end
	end
	if nearest and now >= nextLineAt then
		nextLineAt = now + random:NextNumber(table.unpack(settings.StallLineEvery))
		sayLine(nearest)
	end
	for model in nextTwitch do
		if not model.Parent then
			nextTwitch[model] = nil
		end
	end
end

function Robots.Start()
	gearRemote = Net.event("RobotGear")
	ContextActionService:BindAction("RobotEmp", useGear("Emp"), false, table.unpack(settings.EmpKeys))
	ContextActionService:BindAction(
		"RobotDisruptor",
		useGear("Disruptor"),
		false,
		table.unpack(settings.DisruptorKeys)
	)

	task.spawn(function()
		local folder = workspace:WaitForChild("Robots")
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= 0.1 then
				elapsed = 0
				step(folder)
			end
		end)
	end)
end

return Robots
