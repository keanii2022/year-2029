-- Draws haunts on this client. Private scares arrive from the server (Net "HauntScare") and only
-- this player sees them: the lost kid at the edge of the flashlight, a giggle behind you, a
-- mannequin standing behind you, a ball rolling out of the dark, a pigeon flock bursting up.
-- Also runs the everyone-sees loops tagged "HauntLoop" (greeter wave, shirt folder, robot pile
-- twitch, moths, security cams, candles, pigeons) locally, so the server never streams the motion.
-- Animation clips can't be uploaded by Open Cloud yet, so every motion here is procedural.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HauntSight = require(ReplicatedStorage.Shared.Logic.HauntSight)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Manifest = require(ReplicatedStorage.Shared.Logic.Manifest)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.Haunts
local player = Players.LocalPlayer
local random = Random.new()

local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

type Poser = (partName: string, t: number) -> ()
type Looped = {
	model: Model,
	kind: string,
	pose: Poser,
	nextAt: number,
	jerkUntil: number,
	yaw: number,
	light: PointLight?,
}

local HauntsController = {}

local looped: { [Model]: Looped } = {}
local scaring = false

-- Moving parts ------------------------------------------------------------------------------------

-- The server's ModelRig made the Motor6Ds; rigging again here would double them, so this drives the
-- existing motors with the same pose math as ModelRig.setPose, from the C0 they arrived with.
local function poserFor(model: Model): (Poser, { [string]: { motor: Motor6D, base: CFrame } })
	local name = model:GetAttribute("ModelName") or model.Name
	local entry = ModelLibrary.entry(name)
	local infos = {}
	for _, info in if entry then entry.parts else {} do
		infos[info.name] = info
	end
	local motors = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = { motor = descendant, base = descendant.C0 }
		end
	end
	local function pose(partName: string, t: number)
		local joint, info = motors[partName], infos[partName]
		local motion = joint and info and Manifest.motion(name, partName, Config.Models.AxisOverrides)
		if not motion then
			return
		end
		local degrees, studs = Manifest.pose(motion, t, info, Config.Models)
		local axis = AXES[motion.axis]
		joint.motor.C0 = joint.base * CFrame.new(axis * studs) * CFrame.fromAxisAngle(axis, math.rad(degrees))
	end
	return pose, motors
end

-- Scare helpers -----------------------------------------------------------------------------------

local function camera(): Camera
	return workspace.CurrentCamera
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character or {}, camera() }
	return params
end

-- Furthest point up to distance along a flat direction from the camera, stopping short of walls.
local function reach(direction: Vector3, distance: number): Vector3
	local origin = camera().CFrame.Position
	local hit = workspace:Raycast(origin, direction * distance, rayParams())
	local length = if hit then math.max(hit.Distance - 2, 0) else distance
	return origin + direction * length
end

local function ground(position: Vector3): Vector3?
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), rayParams())
	return hit and hit.Position
end

local function spawnModel(name: string): Model?
	local templates = ReplicatedStorage:FindFirstChild("HauntTemplates")
	local template = templates and templates:FindFirstChild(name)
	local model = if template then template:Clone() :: Model else ModelLibrary.get(name)
	if not model then
		return nil
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return model
end

-- Stands a model on the floor at position, its front (+z) facing toward lookAt.
local function stand(model: Model, position: Vector3, lookAt: Vector3)
	local facing = flat(lookAt - position)
	local rotation = CFrame.lookAt(Vector3.zero, -facing)
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	model:PivotTo(rotation + (position - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	model.Parent = workspace
end

local function fadeOut(model: Model, time: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(time), { Transparency = 1 }):Play()
		end
	end
	task.delay(time, function()
		model:Destroy()
	end)
end

local function playAt(
	position: Vector3,
	soundName: string,
	volume: number?,
	group: Mix.Group,
	scare: Mix.ScareKind?
)
	local id = ModelLibrary.soundId(soundName)
	if not id then
		return
	end
	local holder = Instance.new("Part")
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Position = position
	holder.Parent = workspace
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or Settings.Volume
	sound.RollOffMinDistance = 4
	sound.RollOffMaxDistance = 60
	sound.Parent = holder
	Mix.route(sound, group, scare)
	sound:Play()
	task.delay(15, function()
		holder:Destroy()
	end)
end

local function seen(position: Vector3): boolean
	local cam = camera()
	return HauntSight.inView(cam.CFrame.Position, cam.CFrame.LookVector, position, cam.FieldOfView * 0.6, 500)
end

-- Runs step(elapsed) every frame until it returns true.
local function every(step: (elapsed: number) -> boolean)
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if step(os.clock() - started) then
			connection:Disconnect()
		end
	end)
end

-- Scares ------------------------------------------------------------------------------------------

local scares: { [string]: (done: () -> ()) -> () } = {}

-- Stands still just outside your flashlight cone (or off to the side of your view), crying, and tilts
-- its head too far. It waits long enough to be walked up to, saying a line at each step closer, and
-- is gone just after the last one, leaving its stuffed robot.
function scares.kid_peek(done)
	local kid = spawnModel("lost_kid")
	if not kid then
		return done()
	end
	local cfg = Settings.Kid
	local look = camera().CFrame.LookVector
	local angle = if player:GetAttribute("FlashlightOn")
		then Config.DayNight.Flashlight.Angle / 2 + cfg.BeamEdge
		else cfg.ViewEdge
	local dx, dz = HauntSight.offAxis(look.X, look.Z, angle, if random:NextNumber() < 0.5 then 1 else -1)
	local spot = ground(reach(Vector3.new(dx, 0, dz), random:NextNumber(cfg.Distance.Min, cfg.Distance.Max)))
	if not spot then
		kid:Destroy()
		return done()
	end
	stand(kid, spot, camera().CFrame.Position)
	playAt(spot, Settings.Sounds.KidAppear, cfg.VoiceVolume, "Scare", "stinger")
	local _, motors = poserFor(kid)
	local head = motors.Head
	local played = 0
	local closeAt = nil
	every(function(elapsed)
		if head then
			local tilt = math.clamp((elapsed - cfg.TiltAfter) / 0.6, 0, 1)
			head.motor.C0 = head.base * CFrame.Angles(0, 0, math.rad(cfg.TiltDegrees * tilt))
		end
		local due = VoiceLines.kidCue(cfg.Voice, (camera().CFrame.Position - spot).Magnitude, played)
		if due then
			played = due
			playAt(spot, cfg.Voice[due].sound, cfg.VoiceVolume, "Voice")
			if due == #cfg.Voice then
				closeAt = elapsed
			end
		end
		local gone = if closeAt then elapsed - closeAt >= cfg.VanishAfterClose else elapsed >= cfg.Hold
		if not gone then
			return false
		end
		local toy = spawnModel("stuffed_robot")
		if toy then
			stand(toy, spot, camera().CFrame.Position)
			task.delay(cfg.ToyStays, fadeOut, toy, 1)
		end
		fadeOut(kid, cfg.FadeTime)
		done()
		return true
	end)
end

-- Stands behind you with its arms out. Once you've seen it, it's gone the next time you look away.
function scares.mannequin_behind(done)
	local cfg = Settings.MannequinBehind
	local back = -flat(camera().CFrame.LookVector)
	local spot = ground(reach(back, cfg.Distance))
	local origin = camera().CFrame.Position
	if not spot or (Vector3.new(spot.X, origin.Y, spot.Z) - origin).Magnitude < cfg.TooClose then
		return done()
	end
	local model = spawnModel("mannequin")
	if not model then
		return done()
	end
	stand(model, spot, origin)
	local pose = poserFor(model)
	local t = cfg.ReachDegrees / Config.Models.MoverDegrees
	pose("UpperArm", t)
	pose("LeftUpperArm", t)
	local seenFor = 0
	local last = 0
	every(function(elapsed)
		local dt = elapsed - last
		last = elapsed
		local position = model:GetPivot().Position
		local watching = seen(position)
		if watching then
			seenFor += dt
		end
		local tooClose = (camera().CFrame.Position - position).Magnitude < cfg.TooClose
		if (seenFor >= cfg.SeenFor and not watching) or tooClose or elapsed > cfg.Timeout then
			model:Destroy()
			done()
			return true
		end
		return false
	end)
end

-- A ball rolls slowly out of the dark and stops at your feet.
function scares.ball_roll(done)
	local cfg = Settings.Ball
	local look = flat(camera().CFrame.LookVector)
	local from = ground(reach(look, cfg.Distance))
	local to = ground(camera().CFrame.Position + look * cfg.StopShort)
	local ball = spawnModel("kid_ball")
	if not (from and to and ball) then
		if ball then
			ball:Destroy()
		end
		return done()
	end
	stand(ball, from, to)
	local start = ball:GetPivot()
	local box, size = ball:GetBoundingBox()
	local radius = math.max(size.Y / 2, 0.1)
	-- Spin about the ball's middle: the uploaded mesh pivots at its bottom, which swung it into the floor
	local centerOffset = start:PointToObjectSpace(box.Position)
	local path = to - from
	local axis = path:Cross(Vector3.yAxis)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	every(function(elapsed)
		local alpha = math.min(elapsed / cfg.RollTime, 1)
		local eased = 1 - (1 - alpha) ^ 2
		local spin = -path.Magnitude * eased / radius
		ball:PivotTo(
			CFrame.new(box.Position + path * eased)
				* CFrame.fromAxisAngle(axis, spin)
				* start.Rotation
				* CFrame.new(-centerOffset)
		)
		if alpha < 1 then
			return false
		end
		task.delay(cfg.Stays, fadeOut, ball, 1)
		done()
		return true
	end)
end

-- Pigeons burst up off the floor ahead of you and are gone into the dark.
function scares.flock_burst(done)
	local cfg = Settings.Flock
	local center = ground(reach(flat(camera().CFrame.LookVector), cfg.Distance))
	if not center then
		return done()
	end
	local birds = {}
	for _ = 1, cfg.Count do
		local bird = spawnModel("pigeon")
		if bird then
			local offset = Vector3.new(random:NextNumber(-3, 3), 0, random:NextNumber(-3, 3))
			local away = flat(offset + Vector3.new(0.01, 0, 0))
			stand(bird, center + offset, center + offset + away)
			local pose = poserFor(bird)
			table.insert(birds, { model = bird, start = bird:GetPivot(), away = away, pose = pose })
		end
	end
	every(function(elapsed)
		local alpha = math.min(elapsed / cfg.FlyTime, 1)
		local flap = math.sin(elapsed * Settings.FlapRate * 2) * 2
		for _, bird in birds do
			local lift = Vector3.new(0, cfg.Rise * alpha * alpha, 0) + bird.away * cfg.Rise * 0.6 * alpha
			bird.model:PivotTo(bird.start + lift)
			bird.pose("WingL", flap)
			bird.pose("WingR", flap)
		end
		if alpha < 1 then
			return false
		end
		for _, bird in birds do
			bird.model:Destroy()
		end
		done()
		return true
	end)
end

-- A soft giggle or a hummed tune right behind you. Silent until the voice lines are recorded.
function scares.giggle(done)
	local behind = camera().CFrame.Position - flat(camera().CFrame.LookVector) * Settings.GiggleBehind
	local names = Settings.Sounds.Giggle
	playAt(behind, names[random:NextInteger(1, #names)], Settings.Volume * 0.5, "Scare", "stinger")
	done()
end

local function onScare(kind: unknown)
	local scare = type(kind) == "string" and scares[kind]
	if not scare or scaring or not player.Character then
		return
	end
	scaring = true
	scare(function()
		scaring = false
	end)
end

-- Loops -------------------------------------------------------------------------------------------

local function track(instance: Instance)
	if not instance:IsA("Model") or looped[instance] then
		return
	end
	local pose = poserFor(instance)
	local glow = instance:FindFirstChild("Glow", true)
	local light = glow and glow:FindFirstChildOfClass("PointLight")
	looped[instance] = {
		model = instance,
		kind = instance:GetAttribute("Loop") or "",
		pose = pose,
		nextAt = os.clock() + random:NextNumber(0, 4),
		jerkUntil = 0,
		yaw = 0,
		light = light,
	}
end

local function untrack(instance: Instance)
	looped[instance :: Model] = nil
end

local function stepLoop(entry: Looped, now: number, dt: number)
	local model = entry.model
	local kind = entry.kind
	if kind == "wave" then
		entry.pose("Arm", math.sin(now * math.pi * 2 / Settings.WavePeriod))
	elseif kind == "fold" then
		local phase = (now % Settings.FoldPeriod) / Settings.FoldPeriod
		entry.pose("Arm", if phase < 0.5 then math.sin(phase * 2 * math.pi) else 0)
		entry.pose("Shirt", if phase >= 0.5 then math.sin((phase - 0.5) * 2 * math.pi) else 0)
	elseif kind == "twitch" then
		if now >= entry.nextAt then
			entry.jerkUntil = now + 0.15
			entry.nextAt = now + random:NextNumber(Settings.TwitchGap[1], Settings.TwitchGap[2])
		end
		local jerking = now < entry.jerkUntil
		entry.pose("Twitch", if jerking then 1 else 0)
		local glow = model:FindFirstChild("Glow", true)
		if glow and glow:IsA("BasePart") then
			glow.Transparency = if jerking then 0.7 else 0
		end
	elseif kind == "circle" then
		local center = model:GetAttribute("Center")
		if typeof(center) ~= "Vector3" then
			return
		end
		local radius = model:GetAttribute("Radius") or 1.5
		local angle = now * (model:GetAttribute("Speed") or 2) + (model:GetAttribute("Phase") or 0)
		local position = center
			+ Vector3.new(math.cos(angle) * radius, math.sin(angle * 2.3) * 0.4, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			* math.sign(model:GetAttribute("Speed") or 1)
		model:PivotTo(CFrame.lookAt(position, position - tangent))
		local flap = math.sin(now * Settings.FlapRate * 2)
		entry.pose("WingL", flap)
		entry.pose("WingR", flap)
	elseif kind == "cam" then
		local target = model:GetAttribute("Yaw") or 0
		entry.yaw += HauntSight.angleDelta(entry.yaw, target) * math.min(dt * 4, 1)
		entry.pose("Cam", entry.yaw / 360)
	elseif kind == "flicker" then
		if entry.light then
			entry.light.Brightness = Settings.CandleLight.Brightness
				* (0.75 + 0.35 * math.noise(now * 3, model:GetPivot().X))
		end
	elseif kind == "peck" then
		if model:GetAttribute("Flying") then
			local flap = math.sin(now * Settings.FlapRate * 2) * 2
			entry.pose("WingL", flap)
			entry.pose("WingR", flap)
		elseif now >= entry.nextAt then
			entry.pose("Head", random:NextNumber(-1.5, 1.5))
			entry.nextAt = now + random:NextNumber(0.6, 3)
		end
	end
end

local function stepLoops(dt: number)
	local now = os.clock()
	local eye = camera().CFrame.Position
	for model, entry in looped do
		if not model.Parent then
			continue
		end
		local root = model.PrimaryPart
		local position = if root then root.Position else model:GetPivot().Position
		if entry.kind == "circle" then
			local center = model:GetAttribute("Center")
			position = if typeof(center) == "Vector3" then center else position
		end
		if (position - eye).Magnitude <= Settings.LoopRange then
			stepLoop(entry, now, dt)
		end
	end
end

function HauntsController.Start()
	Net.event("HauntScare").OnClientEvent:Connect(onScare)
	CollectionService:GetInstanceAddedSignal("HauntLoop"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("HauntLoop"):Connect(untrack)
	for _, instance in CollectionService:GetTagged("HauntLoop") do
		track(instance)
	end
	RunService.RenderStepped:Connect(stepLoops)
end

return HauntsController
