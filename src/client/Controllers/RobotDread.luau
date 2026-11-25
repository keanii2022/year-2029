-- Robot dread on the client, quiet and slow rather than loud:
-- - heads turn too smoothly toward where the server says they look (LookAt), ticking like a ratchet,
--   with a sideways tilt now and then while they hold on you
-- - a hunting robot close by that you can't see makes the lights round you flicker and the PA hum
-- - a hard night keeps the PA glitching, and the siren says how many nights they've been learning
-- - the mimic: a robot playing back someone's callout from where it stands, in its own copied voice
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Manifest = require(ReplicatedStorage.Shared.Logic.Manifest)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Mix = require(ReplicatedStorage.Shared.Mix)
local Net = require(ReplicatedStorage.Shared.Net)
local RobotMotion = require(ReplicatedStorage.Shared.Logic.RobotMotion)
local RobotNights = require(ReplicatedStorage.Shared.Logic.RobotNights)
local RobotSounds = require(ReplicatedStorage.Shared.Logic.RobotSounds)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Hints = require(script.Parent.Hints)

local settings = Config.Robots
local motion = settings.Motion
local presence = settings.Presence
local nights = settings.Nights
local mimic = settings.Mimic
local player = Players.LocalPlayer

type Head = {
	motor: Motor6D,
	base: CFrame, -- the server's own pose for the joint; our turn goes on top
	sign: number,
	yaw: number,
	tilt: number,
	seed: number,
	writing: boolean,
	nextTickAt: number,
	turning: boolean, -- mid-turn, so the neck crank already played
	connection: RBXScriptConnection,
}

local RobotDread = {}

local random = Random.new()
local heads: { [Model]: Head } = {}
local presenceLevel = 0
local flickerSpot: Vector3? = nil
local presenceHum: Sound?
local nextGlitchAt = 0
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function playFlat(name: string, volume: number, pitch: number)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	Mix.route(sound, "SFX")
	sound:Play()
	Debris:AddItem(sound, 8)
end

local function playOn(
	parent: Instance,
	name: string,
	volume: number,
	pitch: number,
	rollOff: { number }
): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = rollOff[1]
	sound.RollOffMaxDistance = rollOff[2]
	sound.Parent = parent
	Mix.route(sound, "SFX")
	sound:Play()
	Debris:AddItem(sound, 10)
	return sound
end

-- Heads ---------------------------------------------------------------------------------------------

-- Which way a positive turn goes for this model's head, the same rule ModelRig poses it with.
local function headSign(model: Model): number
	local entry = ModelLibrary.entry(model:GetAttribute("ModelName") or model.Name)
	for _, info in if entry then entry.parts else {} do
		if info.name == "Head" then
			return Manifest.turnSign("Y", info.center, info.pivot)
		end
	end
	return 1
end

local function release(model: Model, head: Head)
	head.connection:Disconnect()
	heads[model] = nil
	if head.motor.Parent then
		head.writing = true
		head.motor.C0 = head.base
		head.writing = false
	end
end

local function follow(model: Model)
	local look = model:GetAttribute("LookAt")
	local head = heads[model]
	if typeof(look) ~= "Vector3" then
		if head then
			release(model, head)
		end
		return
	end
	if head then
		return
	end
	local motor: Motor6D? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == "Head" then
			motor = descendant
			break
		end
	end
	if not motor then
		return
	end
	local new: Head
	new = {
		motor = motor,
		base = motor.C0,
		sign = headSign(model),
		yaw = 0,
		tilt = 0,
		seed = random:NextNumber(),
		writing = false,
		nextTickAt = 0,
		turning = false,
		-- the server holds the head straight while it looks; keep up with whatever it last set
		connection = motor:GetPropertyChangedSignal("C0"):Connect(function()
			if not new.writing then
				new.base = motor.C0
			end
		end),
	}
	heads[model] = new
end

local function watchModel(model: Model)
	if model:GetAttribute("RobotId") == nil then
		return
	end
	follow(model)
	model:GetAttributeChangedSignal("LookAt"):Connect(function()
		follow(model)
	end)
end

local function cranksNeck(model: Model): boolean
	return model:GetAttribute("Watching") == true or model:GetAttribute("RobotType") == "scout"
end

local function turnHeads(dt: number)
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for model, head in heads do
		local look = model:GetAttribute("LookAt")
		if not model.Parent or not head.motor.Parent or typeof(look) ~= "Vector3" then
			release(model, head)
			continue
		end
		local pivot = model:GetPivot()
		if camera and (pivot.Position - camera.CFrame.Position).Magnitude > motion.LookRange then
			continue
		end
		local away = pivot:VectorToObjectSpace(Vector3.new(look.X - pivot.X, 0, look.Z - pivot.Z))
		local target = RobotMotion.headYaw(away.X, away.Z, motion.MaxHeadTurn)
		head.yaw = RobotMotion.turnHead(head.yaw, target, dt, motion.HeadSpeed, motion.HeadEase)
		local left = math.abs(target - head.yaw)
		local tilt = if left < 3 then RobotMotion.tilt(now, head.seed, motion.Tilt) else 0
		-- a curious companion tilts its head right over at you (Systems/Companion)
		local curious = model:GetAttribute("HeadTilt")
		if type(curious) == "number" then
			tilt += curious
		end
		head.tilt += (tilt - head.tilt) * math.min(1, dt * 6)
		head.writing = true
		head.motor.C0 = head.base
			* CFrame.fromAxisAngle(Vector3.yAxis, math.rad(head.sign * head.yaw))
			* CFrame.fromAxisAngle(Vector3.zAxis, math.rad(head.tilt))
		head.writing = false
		local part = head.motor.Part1
		local turning = left > motion.RatchetMinTurn
		if turning and not head.turning and part and cranksNeck(model) then
			playOn(
				part,
				motion.NeckCrank,
				motion.NeckCrankVolume,
				random:NextNumber(0.95, 1.05),
				settings.SoundRollOff
			)
		end
		head.turning = turning
		if turning and now >= head.nextTickAt then
			head.nextTickAt = now + motion.RatchetGap
			if part then
				playOn(part, motion.Ratchet, motion.RatchetVolume, motion.RatchetPitch, settings.SoundRollOff)
			end
		end
	end
end

-- Presence ------------------------------------------------------------------------------------------

local function hunting(model: Model): boolean
	local awake = model:GetAttribute("Night") == true or model:GetAttribute("Role") == "prowler"
	local state = model:GetAttribute("State")
	return awake and (state == "sweep" or state == "investigate" or state == "chase" or state == "carry")
end

local function inSight(camera: Camera, model: Model, character: Model): boolean
	local at = model:GetPivot().Position
	local _, onScreen = camera:WorldToViewportPoint(at)
	if not onScreen then
		return false
	end
	sightParams.FilterDescendantsInstances = { character, model }
	local from = camera.CFrame.Position
	return workspace:Raycast(from, at - from, sightParams) == nil
end

-- The nearest hunting robot in Range you can't see eases the level up; the lights flicker between you.
local function feelPresence(folder: Instance, dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearest, nearestDistance = nil, presence.Range
	if camera and character and root and root:IsA("BasePart") then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("RobotId") ~= nil and hunting(model) then
				local d = (model:GetPivot().Position - root.Position).Magnitude
				if d < nearestDistance and not inSight(camera, model, character) then
					nearest, nearestDistance = model, d
				end
			end
		end
	end
	local rootPart = root :: BasePart
	flickerSpot = if nearest then rootPart.Position:Lerp(nearest:GetPivot().Position, 0.5) else nil
	local target = if nearest then 1 else 0
	local rate = if target > presenceLevel then presence.Rise else presence.Fall
	presenceLevel = math.clamp(presenceLevel + math.sign(target - presenceLevel) * rate * dt, 0, 1)

	if presenceLevel > 0.01 and not presenceHum then
		local id = ModelLibrary.soundId(presence.Hum)
		if id then
			local hum = Instance.new("Sound")
			hum.SoundId = id
			hum.Looped = true
			hum.Volume = 0
			hum.Parent = SoundService
			Mix.route(hum, "Ambience")
			hum:Play()
			presenceHum = hum
		end
	elseif presenceLevel <= 0.01 and presenceHum then
		presenceHum:Destroy()
		presenceHum = nil
	end
	if presenceHum then
		presenceHum.Volume = presence.HumVolume * presenceLevel
	end
	local now = os.clock()
	if presenceLevel > 0.5 and now >= nextGlitchAt then
		nextGlitchAt = now + random:NextNumber(table.unpack(presence.GlitchGap))
		playFlat(presence.Glitch, presence.GlitchVolume, random:NextNumber(0.85, 1))
	end
end

-- Where the lights should stutter for an unseen robot nearby, or nil.
function RobotDread.flickerAt(): Vector3?
	return flickerSpot
end

-- Nights ---------------------------------------------------------------------------------------------

local function tonight(): RobotNights.Threat
	return RobotNights.threat(ReplicatedStorage:GetAttribute("Day") or 1, nights)
end

local function onPhase()
	if ReplicatedStorage:GetAttribute("Phase") ~= "Siren" then
		return
	end
	task.delay(nights.LineDelay, function()
		local line = RobotNights.sirenLine(tonight(), nights)
		if line then
			Hints.flash("robotnight", line, nights.LineSeconds)
		end
	end)
end

-- The mimic -------------------------------------------------------------------------------------------

local function onMimic(model: Model, index: number)
	local callouts = Config.Callouts
	if typeof(model) ~= "Instance" or not VoiceLines.validCallout(index, #callouts.Sounds) then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	local id, pitch = RobotSounds.mimic(index, callouts.Sounds, mimic, ModelLibrary.soundId)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = mimic.Volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = callouts.RollOff[1]
	sound.RollOffMaxDistance = callouts.RollOff[2]
	sound.Parent = body
	Mix.route(sound, "SFX")
	sound:Play()
	Debris:AddItem(sound, 10)
	sound.Ended:Once(function()
		if body.Parent then
			playOn(body, mimic.Tail, mimic.TailVolume, 1, callouts.RollOff)
		end
	end)
end

function RobotDread.Start()
	Net.event("RobotMimic").OnClientEvent:Connect(onMimic)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	RunService.RenderStepped:Connect(turnHeads)

	task.spawn(function()
		local folder = workspace:WaitForChild("Robots")
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				watchModel(child)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.defer(watchModel, child)
			end
		end)
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= 0.1 then
				feelPresence(folder, elapsed)
				elapsed = 0
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(random:NextNumber(table.unpack(nights.HardPaGap)))
			if ReplicatedStorage:GetAttribute("Phase") == "Night" and tonight().hard then
				playFlat(
					nights.HardPa,
					nights.HardPaVolume,
					random:NextNumber(table.unpack(nights.HardPaPitch))
				)
			end
		end
	end)
end

return RobotDread
