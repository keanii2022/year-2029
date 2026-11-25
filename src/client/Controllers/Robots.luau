-- Robot gear (EMP G, disruptor V, or Fire with it picked on the hotbar) and the local-only life of stalled
-- robots: flickering eyes, twitches and the odd "ERROR. NEEDS MORE TRAINING." over the nearest one.
-- Robots also talk in Keani's robotised voice: chatter nearby, a line when you walk up on one at work,
-- when one notices you, when it gets back to work, and when it errors out.
-- Every robot sound is 3D on the robot: footsteps that speed up with it, a hum, a notice alert, a
-- chase loop with a climbing whine, the catch clank, and the clank and sparks when a shot hits one.
-- One that spots you lets out an alert and the others answer from the dark.
-- Dread: a heartbeat and a drained screen as hunting robots close in, lights stuttering near them,
-- and far-off robot noises at night and through the siren. Getting caught throws you to the floor.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local RobotHunt = require(ReplicatedStorage.Shared.Logic.RobotHunt)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local LightingController = require(script.Parent.Lighting)
local RobotDread = require(script.Parent.RobotDread)

local settings = Config.Robots
local voiceLines = settings.Voice
local sounds = settings.Sounds
local hunt = settings.Hunt
local dread = settings.Dread
local ambience = settings.Ambience
local catchFeel = settings.Catch
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
	eyes: BasePart?,
	eyeColor: Color3?, -- what the server dressed the eyes in, shown while it isn't suspicious or chasing
	hum: Sound?,
	humVolume: number,
	pendingChase: boolean, -- spotted you but still staring: the chase sounds wait until it goes
	staring: boolean,
}

local Robots = {}

local gearRemote: RemoteEvent
local random = Random.new()
local nextTwitch: { [Model]: number } = {}
local nextLineAt = 0
local talkers: { [Model]: Talker } = {}
local dreadLevel = 0
local heartbeat: Sound?
local grade: ColorCorrectionEffect?

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

-- A small "?" (suspicious) or "!" (chasing) pops over its head and fades, so a muted or deaf player
-- still sees it notice them. Only up close, and walls hide it.
local function popMark(model: Model, text: string, color: Color3)
	local head = model:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then
		return
	end
	local mark = settings.Mark
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(mark.Size, mark.Size)
	gui.StudsOffsetWorldSpace = Vector3.new(0, mark.Height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = mark.Range
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = head
	TweenService:Create(label, TweenInfo.new(mark.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(gui, mark.Seconds + 0.1)
end

local function eyeColorFor(talker: Talker, state: unknown): Color3?
	if state == "chase" then
		return settings.ChaseEyeColor
	elseif state == "suspicious" then
		return settings.SuspiciousEyeColor
	end
	return talker.eyeColor
end

local function tintEyes(talker: Talker, state: unknown)
	local eyes = talker.eyes
	local color = eyeColorFor(talker, state)
	if not eyes or not color then
		return
	end
	eyes.Color = color
	local glow = eyes:FindFirstChild("EyeGlow")
	if glow and glow:IsA("PointLight") then
		glow.Color = color
	end
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
	Mix.route(sound, "SFX")
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
	night: boolean?,
	group: Mix.Group
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
	Mix.route(sound, group)
	return sound
end

local function playOnce(
	parent: Instance,
	name: string,
	volume: number,
	night: boolean?,
	group: Mix.Group,
	scare: Mix.ScareKind?
)
	local sound = soundOn(parent, name, volume, false, night, group)
	if sound then
		sound.PlaybackSpeed = random:NextNumber(0.94, 1.06)
		if scare then
			Mix.route(sound, group, scare)
		end
		sound:Play()
		Debris:AddItem(sound, 8)
	end
end

-- Night robots, and prowlers at any hour, carry far: you hear them through the racks.
local function isLoud(model: Model): boolean
	return model:GetAttribute("Night") == true or model:GetAttribute("Role") == "prowler"
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
	if model:GetAttribute("Silent") then
		if talker.stepLoop then
			talker.stepLoop:Destroy()
			talker.stepLoop = nil
		end
		return
	end
	local night = isLoud(model)
	local volume = if night then sounds.NightStepVolume else sounds.StepVolume
	local walking = moved > 0.05 and moved < 20 -- a jump that big is a teleport, not a stride
	if stepSound.stride <= 0 then
		if walking and not talker.stepLoop then
			talker.stepLoop = soundOn(talker.body, stepSound.sound, volume, true, night, "SFX")
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
		playOnce(talker.body, stepSound.sound, volume, night, "SFX")
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
	local night = isLoud(model)
	talker.chaseSince = os.clock()
	playOnce(talker.body, sounds.Notice, sounds.CueVolume, night, "Scare", "sharp")
	local typeNotice = sounds.NoticeByType[model:GetAttribute("RobotType")]
	if typeNotice then
		playOnce(talker.body, typeNotice, sounds.CueVolume, night, "Scare", "sharp")
	end
	local jingle = soundOn(talker.body, sounds.ChaseLoop, sounds.ChaseLoopVolume, true, night, "Scare")
	local whine = soundOn(talker.body, sounds.ChaseWhine, sounds.ChaseWhineVolume, true, night, "Scare")
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

-- A sound heard a long way off, at a set pitch.
local function playFar(
	parent: Instance,
	name: string,
	volume: number,
	pitch: number,
	rollOff: { number },
	group: Mix.Group,
	scare: Mix.ScareKind?
)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch * random:NextNumber(0.95, 1.05)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = rollOff[1]
	sound.RollOffMaxDistance = rollOff[2]
	sound.Parent = parent
	Mix.route(sound, group, scare)
	sound:Play()
	Debris:AddItem(sound, 10)
end

-- Somewhere off in the dark, from a random direction: a crash, a scrape, a groan.
local function distantNoise(list: { string })
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local angle = random:NextNumber(0, math.pi * 2)
	local at = camera.CFrame.Position
		+ Vector3.new(math.cos(angle), 0, math.sin(angle))
			* random:NextNumber(table.unpack(ambience.Distance))
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at
	anchor.Parent = workspace.Terrain
	local pitch = random:NextNumber(table.unpack(ambience.Pitch))
	playFar(anchor, list[random:NextInteger(1, #list)], ambience.Volume, pitch, ambience.RollOff, "Ambience")
	Debris:AddItem(anchor, 10)
end

-- Eases dread toward target and shows it: heartbeat louder and faster, colour drained and reddened.
local function feelDread(target: number, dt: number)
	local rate = if target > dreadLevel then dread.Rise else dread.Fall
	dreadLevel = if target > dreadLevel
		then math.min(target, dreadLevel + rate * dt)
		else math.max(target, dreadLevel - rate * dt)
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "RobotDread"
		grade.Parent = Lighting
	end
	local effect = grade :: ColorCorrectionEffect
	effect.Saturation = dread.Saturation * dreadLevel
	effect.Contrast = dread.Contrast * dreadLevel
	effect.TintColor = Color3.new(1, 1, 1):Lerp(dread.Tint, dreadLevel)
	if dreadLevel > 0.02 and not heartbeat then
		local id = ModelLibrary.soundId(dread.Heartbeat)
		if id then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Looped = true
			sound.Volume = 0
			sound.Parent = SoundService
			Mix.route(sound, "Scare")
			sound:Play()
			heartbeat = sound
		end
	elseif dreadLevel <= 0.02 and heartbeat then
		heartbeat:Destroy()
		heartbeat = nil
	end
	if heartbeat then
		local pitch = dread.HeartbeatPitch
		heartbeat.Volume = dread.HeartbeatVolume * dreadLevel
		heartbeat.PlaybackSpeed = pitch[1] + (pitch[2] - pitch[1]) * dreadLevel
	end
end

-- Stop and stare: eyes flare, the hum cuts out, and the chase sounds hold until it goes. The silent
-- hunter keeps its hum off until it lunges.
local function stare(model: Model, talker: Talker)
	local staring = model:GetAttribute("Pose") == "stare"
	if talker.hum then
		talker.hum.Volume = if staring or model:GetAttribute("Silent") then 0 else talker.humVolume
	end
	if talker.pendingChase and not staring then
		talker.pendingChase = false
		if model:GetAttribute("State") == "chase" then
			startChase(model, talker)
			popMark(model, "!", settings.ChaseEyeColor)
			playOnce(talker.body, settings.StateSounds.chase, sounds.CueVolume, isLoud(model))
		end
	end
	if staring == talker.staring then
		return
	end
	talker.staring = staring
	local eyes = talker.eyes
	local glow = eyes and eyes:FindFirstChild("EyeGlow")
	if eyes and staring then
		eyes.Color = settings.ChaseEyeColor
	end
	if glow and glow:IsA("PointLight") then
		local scale = if staring then hunt.StareGlow else 1 / hunt.StareGlow
		glow.Brightness *= scale
		glow.Range *= scale
	end
end

local function step(folder: Instance)
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearest, nearestDistance = nil, settings.StallLineRange
	local fear, fearAt = 0, nil
	local alive = character and character:FindFirstChildOfClass("Humanoid")
	local hasBody = root and root:IsA("BasePart") and alive and alive.Health > 0
	for _, model in folder:GetChildren() do
		-- the folder also holds the boxes and brooms chore bots carry
		if not model:IsA("Model") or model:GetAttribute("RobotId") == nil then
			continue
		end
		if root and root:IsA("BasePart") then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			talk(model, d, now)
			local awake = isLoud(model)
			local weight = if hasBody
				then RobotHunt.dread(d, model:GetAttribute("State"), awake, dread)
				else 0
			if weight > fear then
				fear, fearAt = weight, model:GetPivot().Position
			end
		end
		local talker = talkers[model]
		if talker then
			footsteps(model, talker)
			updateChase(talker, now)
			stare(model, talker)
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
	feelDread(fear, 0.1)
	LightingController.disturb(RobotDread.flickerAt() or fearAt)
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
	local night = isLoud(model)
	local eyes = model:FindFirstChild(settings.EyePart, true)
	local eyePart = if eyes and eyes:IsA("BasePart") then eyes else nil
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
		eyes = eyePart,
		eyeColor = if eyePart then eyePart.Color else nil,
		hum = nil,
		humVolume = if night then sounds.NightHumVolume else sounds.HumVolume,
		pendingChase = false,
		staring = false,
	}
	talkers[model] = talker
	local lastState = model:GetAttribute("State")
	local hum = soundOn(body, sounds.Hum, talker.humVolume, true, night, "SFX")
	if hum then
		hum.Volume = if model:GetAttribute("Silent") then 0 else talker.humVolume
		hum:Play()
	end
	talker.hum = hum
	if lastState == "chase" then
		startChase(model, talker)
	end
	tintEyes(talker, lastState)
	-- Now and then an idle robot leaks oil or lets off pressure; at night it pings and whirrs, more often
	task.spawn(function()
		local prowler = model:GetAttribute("Role") == "prowler"
		local gap = if prowler
			then settings.Prowl.IdleSoundGap
			elseif night then settings.NightIdleSoundGap
			else settings.IdleSoundGap
		local idle = if prowler
			then settings.Prowl.IdleSounds
			elseif night then settings.NightIdleSounds
			else settings.IdleSounds
		while model.Parent do
			task.wait(random:NextNumber(gap[1], gap[2]))
			if model.Parent and table.find(settings.IdleStates, model:GetAttribute("State")) then
				playOnce(body, idle[random:NextInteger(1, #idle)], sounds.CueVolume * 0.7, night, "SFX")
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
			talker.pendingChase = true -- step starts the chase once any stare is over
		elseif state ~= "chase" and wasChasing then
			talker.pendingChase = false
			stopChase(talker)
		end
		if state == "suspicious" then
			popMark(model, "?", settings.SuspiciousEyeColor)
		end
		tintEyes(talker, state)
		local cue = settings.StateSounds[state]
		if cue and state ~= "chase" then
			local name = if type(cue) == "table" then cue[random:NextInteger(1, #cue)] else cue
			playOnce(body, name, sounds.CueVolume, night, "SFX")
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
		playOnce(body, sounds.Grab, 1, isLoud(model), "SFX")
	elseif kind == "hit" then
		playOnce(body, shot.Clank, shot.ClankVolume, true, "SFX")
		sparkBurst(at, 25)
		twitch(model)
	elseif kind == "down" then
		stopChase(talker)
		playOnce(body, shot.Clank, shot.ClankVolume, true, "SFX")
		playOnce(body, shot.Sputter, sounds.CueVolume, true, "SFX")
		sparkBurst(at, 60)
	elseif kind == "reboot" then
		playOnce(body, shot.Reboot, sounds.CueVolume, true, "SFX")
	elseif kind == "land" then
		for _, name in settings.Racks.Sounds do
			playOnce(body, name, settings.Racks.Volume, true, "Scare")
		end
	elseif kind == "lunge" then
		playFar(
			body,
			hunt.LungeSound,
			hunt.LungeVolume,
			hunt.LungePitch,
			settings.NightRollOff,
			"Scare",
			"sharp"
		)
	elseif kind == "alert" then
		playFar(body, hunt.AlertSound, hunt.AlertVolume, hunt.AlertPitch, hunt.RollOff, "Scare", "sharp")
	elseif kind == "answer" then
		task.delay(random:NextNumber(table.unpack(hunt.AnswerDelay)), function()
			if body.Parent then
				local list = hunt.AnswerSounds
				playFar(
					body,
					list[random:NextInteger(1, #list)],
					hunt.AlertVolume,
					hunt.AnswerPitch,
					hunt.RollOff,
					"Scare",
					"sharp"
				)
			end
		end)
	end
end

-- A jolt to the camera that dies away over ShakeSeconds.
local function shakeCamera()
	local name = "RobotCatchShake"
	local started = os.clock()
	RunService:UnbindFromRenderStep(name)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local left = 1 - (os.clock() - started) / catchFeel.ShakeSeconds
		if left <= 0 or not camera then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local angle = math.rad(catchFeel.ShakeAngle) * left
		camera.CFrame *= CFrame.Angles(
			random:NextNumber(-angle, angle),
			random:NextNumber(-angle, angle),
			random:NextNumber(-angle, angle) * 0.5
		)
	end)
end

-- Thrown to the floor away from the robot, flat for DownSeconds. The client owns its body, so the
-- shove happens here; the server already took the health.
local function knockDown(from: Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local away = if from then root.Position - from else -root.CFrame.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.01 then away.Unit else -root.CFrame.LookVector
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = away * catchFeel.Shove + Vector3.yAxis * catchFeel.Lift
	root.AssemblyAngularVelocity = away:Cross(Vector3.yAxis) * -6
	task.delay(catchFeel.DownSeconds, function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Getting grabbed: thrown down, a jolt, a hard red flash, the hit you hear, and words saying what
-- happened (the claw's clank plays on the robot)
local function caught(kind: string, itemName: string?, from: Vector3?)
	shakeCamera()
	for _, name in catchFeel.Sounds do
		local id = ModelLibrary.soundId(name)
		if id then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = catchFeel.Volume
			sound.Parent = SoundService
			Mix.route(sound, "SFX")
			sound:Play()
			Debris:AddItem(sound, 6)
		end
	end
	if kind == "day" then
		knockDown(from)
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if gui then
		local screen = Instance.new("ScreenGui")
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = 20
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
		flash.BackgroundTransparency = 0.15
		flash.Parent = screen
		screen.Parent = gui
		TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(screen, 1.4)
	end
	if kind == "night" then
		Hints.flash("caught", settings.CaughtNightLine, 5)
	elseif itemName then
		Hints.flash("caught", string.format(settings.CaughtDayLine, itemName), 6)
	else
		Hints.flash("caught", settings.CaughtDayHurtLine, 4)
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
		task.spawn(function()
			while true do
				local siren = ReplicatedStorage:GetAttribute("Phase") == "Siren"
				task.wait(
					random:NextNumber(table.unpack(if siren then ambience.SirenGap else ambience.NightGap))
				)
				local phase = ReplicatedStorage:GetAttribute("Phase")
				if phase == "Night" or phase == "Siren" then
					distantNoise(if phase == "Siren" then ambience.Siren else ambience.Night)
				end
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
