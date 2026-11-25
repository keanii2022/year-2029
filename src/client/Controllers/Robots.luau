-- Robot gear (EMP G, disruptor V, or Fire with it picked on the hotbar) and the local-only life of stalled
-- robots: flickering eyes, twitches and the odd "ERROR. NEEDS MORE TRAINING." over the nearest one.
-- Robots also talk in Keani's robotised voice: chatter nearby, a line when you walk up on one at work,
-- when one notices you, when it gets back to work, and when it errors out.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)

local settings = Config.Robots
local voiceLines = settings.Voice
local player = Players.LocalPlayer

type Talker = { body: BasePart, speaking: Sound?, nextChatterAt: number, saidTask: boolean }

local Robots = {}

local gearRemote: RemoteEvent
local random = Random.new()
local nextTwitch: { [Model]: number } = {}
local nextLineAt = 0
local talkers: { [Model]: Talker } = {}

local function useGear(action: string)
	return function(began: boolean)
		if began then
			gearRemote:FireServer(action, workspace.CurrentCamera.CFrame.LookVector)
		end
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

-- One line at a time per robot: a new one cuts off whatever it was saying.
local function say(talker: Talker, name: string)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	if talker.speaking then
		talker.speaking:Destroy()
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = voiceLines.Volume
	sound.RollOffMinDistance = voiceLines.RollOff[1]
	sound.RollOffMaxDistance = voiceLines.RollOff[2]
	sound.PlaybackSpeed = random:NextNumber(0.96, 1.04)
	sound.Parent = talker.body
	talker.speaking = sound
	sound:Play()
	Debris:AddItem(sound, 10)
end

-- Chatter every so often while it's calm and you're in earshot; one line per errand when you walk
-- up on it working.
local function talk(model: Model, distance: number, now: number)
	local talker = talkers[model]
	if not talker then
		return
	end
	local state = model:GetAttribute("State")
	if state ~= "errand" then
		talker.saidTask = false
	elseif not talker.saidTask and distance <= voiceLines.TaskRange then
		talker.saidTask = true
		talker.nextChatterAt = now + random:NextNumber(table.unpack(voiceLines.ChatterEvery))
		say(talker, voiceLines.Task)
		return
	end
	if not VoiceLines.isCalm(state, voiceLines) or distance > voiceLines.ChatterRange then
		return
	end
	if now >= talker.nextChatterAt then
		talker.nextChatterAt = now + random:NextNumber(table.unpack(voiceLines.ChatterEvery))
		say(talker, voiceLines.Chatter)
	end
end

local function step(folder: Instance)
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearest, nearestDistance = nil, settings.StallLineRange
	for _, model in folder:GetChildren() do
		-- the folder also holds the boxes and brooms chore bots carry
		if not model:IsA("Model") or model:GetAttribute("RobotId") == nil then
			continue
		end
		if root and root:IsA("BasePart") then
			talk(model, (model:GetPivot().Position - root.Position).Magnitude, now)
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
	for model in talkers do
		if not model.Parent then
			talkers[model] = nil
		end
	end
end

-- Robot sounds, all local: a hum that follows each robot, a scream when it starts chasing, curious
-- beeps when it's onto something, a fault noise when it stalls. You hear them before you see them.
local function soundOn(parent: Instance, name: string, volume: number, looped: boolean): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.RollOffMinDistance = settings.SoundRollOff[1]
	sound.RollOffMaxDistance = settings.SoundRollOff[2]
	sound.Parent = parent
	return sound
end

local function voice(model: Model)
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not body or model:GetAttribute("RobotId") == nil then
		return
	end
	local talker: Talker = {
		body = body,
		speaking = nil,
		nextChatterAt = os.clock() + random:NextNumber(table.unpack(voiceLines.ChatterEvery)),
		saidTask = false,
	}
	talkers[model] = talker
	local lastState = model:GetAttribute("State")
	local hum = soundOn(body, settings.Sounds.Hum, settings.Sounds.HumVolume, true)
	if hum then
		hum:Play()
	end
	-- Now and then an idle robot leaks oil or lets off hydraulic pressure
	task.spawn(function()
		while model.Parent do
			task.wait(random:NextNumber(settings.IdleSoundGap[1], settings.IdleSoundGap[2]))
			local state = model:GetAttribute("State")
			if model.Parent and (state == "study" or state == "stalled" or state == "return") then
				local name = settings.IdleSounds[random:NextInteger(1, #settings.IdleSounds)]
				local sound = soundOn(body, name, settings.Sounds.CueVolume * 0.7, false)
				if sound then
					sound:Play()
					Debris:AddItem(sound, 6)
				end
			end
		end
	end)
	model:GetAttributeChangedSignal("State"):Connect(function()
		local state = model:GetAttribute("State")
		local line = VoiceLines.robotStateLine(lastState, state, voiceLines)
		lastState = state
		if line then
			say(talker, line)
		end
		local cue = settings.StateSounds[state]
		if not cue then
			return
		end
		local name = if type(cue) == "table" then cue[random:NextInteger(1, #cue)] else cue
		local sound = soundOn(body, name, settings.Sounds.CueVolume, false)
		if sound then
			sound.PlaybackSpeed = random:NextNumber(0.92, 1.08)
			sound:Play()
			Debris:AddItem(sound, 6)
		end
	end)
end

-- Getting grabbed: a red flash, a jolt, the clank of the claw and words saying what happened
local function caught(kind: string, itemName: string?)
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if gui then
		local screen = Instance.new("ScreenGui")
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = 20
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
		flash.BackgroundTransparency = 0.35
		flash.Parent = screen
		screen.Parent = gui
		TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(screen, 1.4)
	end
	local camera = workspace.CurrentCamera
	if camera then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local clank = root and soundOn(root, settings.Sounds.Grab, 1, false)
		if clank then
			clank:Play()
			Debris:AddItem(clank, 4)
		end
	end
	if kind == "night" then
		Hints.flash("caught", settings.CaughtNightLine, 5)
	else
		Hints.flash("caught", string.format(settings.CaughtDayLine, itemName or "something"), 6)
	end
end

function Robots.Start()
	Net.event("RobotCaught").OnClientEvent:Connect(caught)
	gearRemote = Net.event("RobotGear")
	for _, gear in { "Emp", "Disruptor" } do
		Input.bind(gear, useGear(gear))
		Hotbar.onUse(gear, useGear(gear))
	end

	task.spawn(function()
		local folder = workspace:WaitForChild("Robots")
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				voice(child)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.defer(voice, child)
			end
		end)
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
