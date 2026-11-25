-- Robot gear (EMP G, disruptor V, or Fire with it picked on the hotbar) and the local-only life of stalled
-- robots: flickering eyes, twitches and the odd "ERROR. NEEDS MORE TRAINING." over the nearest one.
-- Robots also talk in Keani's robotised voice: chatter nearby, a line when you walk up on one at work,
-- when one notices you, when it gets back to work, and when it errors out.
-- Every robot sound is 3D on the robot: footsteps that speed up with it, a hum, a notice alert, a
-- chase loop with a climbing whine, the catch clank, and the clank and sparks when a shot hits one.
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
local sounds = settings.Sounds
local player = Players.LocalPlayer

type Talker = {
	body: BasePart,
	speaking: Sound?,
	nextChatterAt: number,
	saidTask: boolean,
	lastPosition: Vector3,
	walked: number, -- studs since the last footstep
	stepLoop: Sound?,
	chase: { Sound },
	whine: Sound?, -- the chase loop whose pitch climbs
	chaseSince: number?,
}

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

-- Sparks off a robot where a shot struck it, from a tiny invisible anchor that cleans itself up.
local function sparkBurst(at: Vector3, count: number)
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 120, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.12, 0)
	emitter.Lifetime = NumberRange.new(0.2, 0.6)
	emitter.Speed = NumberRange.new(10, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	anchor.Parent = workspace
	emitter:Emit(count)
	Debris:AddItem(anchor, 1)
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
	if not VoiceLines.chatters(state, voiceLines) or distance > voiceLines.ChatterRange then
		return
	end
	if now >= talker.nextChatterAt then
		talker.nextChatterAt = now + random:NextNumber(table.unpack(voiceLines.ChatterEvery))
		say(talker, voiceLines.Chatter)
	end
end

-- Robot sounds, all local: a hum that follows each robot, a scream when it starts chasing, curious
-- beeps when it's onto something, a fault noise when it stalls. You hear them before you see them.
local function soundOn(
	parent: Instance,
	name: string,
	volume: number,
	looped: boolean,
	night: boolean?
): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local rollOff = if night then settings.NightRollOff else settings.SoundRollOff
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = rollOff[1]
	sound.RollOffMaxDistance = rollOff[2]
	sound.Parent = parent
	return sound
end

local function playOnce(parent: Instance, name: string, volume: number, night: boolean?)
	local sound = soundOn(parent, name, volume, false, night)
	if sound then
		sound.PlaybackSpeed = random:NextNumber(0.94, 1.06)
		sound:Play()
		Debris:AddItem(sound, 8)
	end
end

local function isNight(model: Model): boolean
	return model:GetAttribute("Night") == true
end

-- One footstep per stride walked, so steps quicken as it speeds up; skitterers loop while moving.
local function footsteps(model: Model, talker: Talker)
	local position = model:GetPivot().Position
	local moved =
		Vector3.new(position.X - talker.lastPosition.X, 0, position.Z - talker.lastPosition.Z).Magnitude
	talker.lastPosition = position
	local stepSound = sounds.Steps[model:GetAttribute("RobotType")]
	if not stepSound then
		return
	end
	local night = isNight(model)
	local volume = if night then sounds.NightStepVolume else sounds.StepVolume
	local walking = moved > 0.05 and moved < 20 -- a jump that big is a teleport, not a stride
	if stepSound.stride <= 0 then
		if walking and not talker.stepLoop then
			talker.stepLoop = soundOn(talker.body, stepSound.sound, volume, true, night)
			if talker.stepLoop then
				talker.stepLoop:Play()
			end
		elseif not walking and talker.stepLoop then
			talker.stepLoop:Destroy()
			talker.stepLoop = nil
		end
		return
	end
	if not walking then
		return
	end
	talker.walked += moved
	if talker.walked >= stepSound.stride then
		talker.walked = 0
		playOnce(talker.body, stepSound.sound, volume, night)
	end
end

-- The chase whine climbs from ChaseWhinePitch[1] to [2] over ChaseWhineRiseSeconds.
local function updateChase(talker: Talker, now: number)
	local since = talker.chaseSince
	local whine = talker.whine
	if since and whine then
		local rise = math.clamp((now - since) / sounds.ChaseWhineRiseSeconds, 0, 1)
		local pitch = sounds.ChaseWhinePitch
		whine.PlaybackSpeed = pitch[1] + (pitch[2] - pitch[1]) * rise
	end
end

local function stopChase(talker: Talker)
	for _, sound in talker.chase do
		sound:Destroy()
	end
	talker.chase = {}
	talker.whine = nil
	talker.chaseSince = nil
end

-- It spotted you: an alert (and its own cry for scouts and brutes), then the chase loops.
local function startChase(model: Model, talker: Talker)
	stopChase(talker)
	local night = isNight(model)
	talker.chaseSince = os.clock()
	playOnce(talker.body, sounds.Notice, sounds.CueVolume, night)
	local typeNotice = sounds.NoticeByType[model:GetAttribute("RobotType")]
	if typeNotice then
		playOnce(talker.body, typeNotice, sounds.CueVolume, night)
	end
	local jingle = soundOn(talker.body, sounds.ChaseLoop, sounds.ChaseLoopVolume, true, night)
	local whine = soundOn(talker.body, sounds.ChaseWhine, sounds.ChaseWhineVolume, true, night)
	if jingle then
		jingle:Play()
		table.insert(talker.chase, jingle)
	end
	if whine then
		whine:Play()
		table.insert(talker.chase, whine)
	end
	talker.whine = whine
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
		local talker = talkers[model]
		if talker then
			footsteps(model, talker)
			updateChase(talker, now)
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

local function voice(model: Model)
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not body or model:GetAttribute("RobotId") == nil then
		return
	end
	local night = isNight(model)
	local talker: Talker = {
		body = body,
		speaking = nil,
		nextChatterAt = os.clock() + random:NextNumber(table.unpack(voiceLines.ChatterEvery)),
		saidTask = false,
		lastPosition = model:GetPivot().Position,
		walked = 0,
		stepLoop = nil,
		chase = {},
		whine = nil,
		chaseSince = nil,
	}
	talkers[model] = talker
	local lastState = model:GetAttribute("State")
	local hum =
		soundOn(body, sounds.Hum, if night then sounds.NightHumVolume else sounds.HumVolume, true, night)
	if hum then
		hum:Play()
	end
	if lastState == "chase" then
		startChase(model, talker)
	end
	-- Now and then an idle robot leaks oil or lets off pressure; at night it pings and whirrs, more often
	task.spawn(function()
		local gap = if night then settings.NightIdleSoundGap else settings.IdleSoundGap
		local idle = if night then settings.NightIdleSounds else settings.IdleSounds
		while model.Parent do
			task.wait(random:NextNumber(gap[1], gap[2]))
			if model.Parent and table.find(settings.IdleStates, model:GetAttribute("State")) then
				playOnce(body, idle[random:NextInteger(1, #idle)], sounds.CueVolume * 0.7, night)
			end
		end
	end)
	model:GetAttributeChangedSignal("State"):Connect(function()
		local state = model:GetAttribute("State")
		local line = VoiceLines.robotStateLine(lastState, state, voiceLines)
		local wasChasing = lastState == "chase"
		lastState = state
		if line then
			say(talker, line)
		end
		if state == "chase" and not wasChasing then
			startChase(model, talker)
		elseif state ~= "chase" and wasChasing then
			stopChase(talker)
		end
		local cue = settings.StateSounds[state]
		if cue then
			local name = if type(cue) == "table" then cue[random:NextInteger(1, #cue)] else cue
			playOnce(body, name, sounds.CueVolume, night)
		end
	end)
end

-- A robot did something everyone nearby should hear: got shot, went down, rebooted, grabbed someone.
local function robotFx(model: Model, kind: string, at: Vector3)
	local talker = talkers[model]
	if not talker or not model.Parent then
		return
	end
	local body = talker.body
	local shot = settings.Shot
	if kind == "catch" then
		playOnce(body, sounds.Grab, 1, isNight(model))
	elseif kind == "hit" then
		playOnce(body, shot.Clank, shot.ClankVolume, true)
		sparkBurst(at, 25)
		twitch(model)
	elseif kind == "down" then
		stopChase(talker)
		playOnce(body, shot.Clank, shot.ClankVolume, true)
		playOnce(body, shot.Sputter, sounds.CueVolume, true)
		sparkBurst(at, 60)
	elseif kind == "reboot" then
		playOnce(body, shot.Reboot, sounds.CueVolume, true)
	end
end

-- Getting grabbed: a red flash and words saying what happened (the claw's clank plays on the robot)
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
	if kind == "night" then
		Hints.flash("caught", settings.CaughtNightLine, 5)
	else
		Hints.flash("caught", string.format(settings.CaughtDayLine, itemName or "something"), 6)
	end
end

function Robots.Start()
	Net.event("RobotCaught").OnClientEvent:Connect(caught)
	Net.event("RobotFx").OnClientEvent:Connect(robotFx)
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
