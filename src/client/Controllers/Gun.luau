-- Client side of guns: fires from the camera through the crosshair, draws your own tracer and
-- sparks right away, and asks the server to check the shot. Also draws other players' shots
-- and zooms the view while aiming.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Input)

local settings = Config.Guns
local player = Players.LocalPlayer

local Gun = {}

local carried: { [string]: number } = {}
local changedListeners: { () -> () } = {}
local hitListeners: { (down: boolean) -> () } = {}
local lastShotAt = 0
local firing = false
local aimBlend = 0
local baseFieldOfView: number? = nil
local fireRemote: RemoteEvent
local fxFolder: Folder

local function currentGun(): (string?, CombatLogic.Gun?)
	local id = CombatLogic.pickGun(settings.Blasters, function(gunId)
		return (carried[gunId] or 0) > 0
	end)
	return id, id and settings.Blasters[id]
end

-- Ammo for the gun in hand, or nil when holding no gun.
function Gun.getAmmo(): number?
	local _, gun = currentGun()
	return if gun then carried[gun.ammo] or 0 else nil
end

function Gun.onChanged(listener: () -> ())
	table.insert(changedListeners, listener)
end

function Gun.onHit(listener: (down: boolean) -> ())
	table.insert(hitListeners, listener)
end

local function notifyChanged()
	for _, listener in changedListeners do
		task.spawn(listener)
	end
end

local function effectPart(position: Vector3, lookAt: Vector3?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = if lookAt then CFrame.lookAt(position, lookAt) else CFrame.new(position)
	part.Parent = fxFolder
	return part
end

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local beam = effectPart((from + to) / 2, to)
	beam.Transparency = 0.1
	beam.Size = Vector3.new(settings.TracerWidth, settings.TracerWidth, length)
	beam.Color = settings.TracerColor
	beam.Material = Enum.Material.Neon
	TweenService:Create(beam, TweenInfo.new(settings.TracerTime), { Transparency = 1 }):Play()
	Debris:AddItem(beam, settings.TracerTime + 0.05)
end

local function sparks(position: Vector3, normal: Vector3, count: number)
	-- The part faces along the surface normal, so Front emission sprays sparks off the surface.
	local holder = effectPart(position, position + normal)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Color = ColorSequence.new(settings.SparkColor)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.18, 0)
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Speed = NumberRange.new(12, 26)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Acceleration = Vector3.new(0, -50, 0)
	emitter.Drag = 3
	emitter.Parent = holder
	emitter:Emit(count)

	local flash = Instance.new("PointLight")
	flash.Color = settings.SparkColor
	flash.Brightness = 3
	flash.Range = 6
	flash.Parent = holder
	task.delay(0.06, function()
		flash.Enabled = false
	end)
	Debris:AddItem(holder, 0.5)
end

local function drawShot(from: Vector3, to: Vector3, normal: Vector3?, hitPlayer: boolean)
	tracer(from, to)
	if normal then
		sparks(to, normal, if hitPlayer then settings.PlayerSparkCount else settings.SparkCount)
	end
end

-- Plays a gun sound: flat in your own ears when position is nil, otherwise out in the world so
-- others hear it from where it happened. Silent until the sound is uploaded.
local function playSound(name: string, position: Vector3?, volume: number?, pitch: number?)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.PlaybackSpeed = (pitch or 1) * (1 + (math.random() - 0.5) * settings.SoundPitchJitter)
	if not position then
		-- A sound under SoundService plays flat, with no position
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 3)
		return
	end
	local emitter = effectPart(position)
	emitter.Transparency = 1
	sound.RollOffMinDistance = settings.SoundRollOff[1]
	sound.RollOffMaxDistance = settings.SoundRollOff[2]
	sound.Parent = emitter
	sound:Play()
	Debris:AddItem(emitter, 4)
end

local function fireOnce(): boolean
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local _, gun = currentGun()
	if not camera or not character or not humanoid or not gun then
		return false
	end
	local ok = CombatLogic.canFire({
		alive = humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hasGun = true,
		ammo = carried[gun.ammo] or 0,
		sinceLastShot = os.clock() - lastShotAt,
		minInterval = gun.fireInterval,
	})
	if not ok then
		if (carried[gun.ammo] or 0) <= 0 and os.clock() - lastShotAt >= gun.fireInterval then
			lastShotAt = os.clock()
			playSound(settings.Sounds.Empty, nil, 0.7)
		end
		return false
	end
	lastShotAt = os.clock()
	playSound(settings.Sounds.Fire, nil, settings.Sounds.FireVolume, settings.Sounds.FirePitch)
	-- Spend the cell now so the HUD and the next shot don't wait on the server's reply.
	carried[gun.ammo] -= 1
	notifyChanged()

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fxFolder }
	local result = workspace:Raycast(origin, direction * gun.range, params)
	local hitPosition = if result then result.Position else origin + direction * gun.range
	local hitPlayer = false
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		hitPlayer = model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
	end
	drawShot(
		(camera.CFrame * CFrame.new(settings.MuzzleOffset)).Position,
		hitPosition,
		result and result.Normal,
		hitPlayer
	)
	playSound(settings.Sounds.Impact, hitPosition, settings.Sounds.ImpactVolume, settings.Sounds.ImpactPitch)
	fireRemote:FireServer(origin, direction)
	return true
end

local function onFire(began: boolean)
	if not began or firing then
		return
	end
	firing = true
	fireOnce()
	local _, gun = currentGun()
	while gun and gun.automatic and Input.isDown("Fire") do
		task.wait(gun.fireInterval)
		if not Input.isDown("Fire") or not fireOnce() then
			break
		end
		_, gun = currentGun()
	end
	firing = false
end

-- Camera.luau eases FieldOfView toward its own target every frame. To zoom without fighting it,
-- put its value back before it runs and scale it again right after.
local function restoreFieldOfView()
	local camera = workspace.CurrentCamera
	if camera and baseFieldOfView then
		camera.FieldOfView = baseFieldOfView
	end
end

local function applyAim(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local aiming = Input.isDown("Aim") and Gun.getAmmo() ~= nil
	aimBlend = MovementLogic.smooth(aimBlend, if aiming then 1 else 0, settings.AimEase, dt)
	baseFieldOfView = camera.FieldOfView
	camera.FieldOfView = camera.FieldOfView * (1 + (settings.AimFieldOfViewScale - 1) * aimBlend)
end

function Gun.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "GunFx"
	fxFolder.Parent = workspace
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Gun.Start()
	fireRemote = Net.event("GunFire")
	Net.event("InventoryChanged").OnClientEvent:Connect(function(list: { { id: string, count: number } })
		table.clear(carried)
		for _, entry in list do
			carried[entry.id] = entry.count
		end
		notifyChanged()
	end)
	Net.event("GunHit").OnClientEvent:Connect(function(down: boolean)
		for _, listener in hitListeners do
			task.spawn(listener, down)
		end
	end)
	Net.unreliable("GunFx").OnClientEvent:Connect(
		function(shooter: Player, origin: Vector3, hitPosition: Vector3, normal: Vector3?, hitPlayer: boolean)
			if shooter ~= player then
				drawShot(origin, hitPosition, normal, hitPlayer)
				playSound(settings.Sounds.Fire, origin, settings.Sounds.FireVolume, settings.Sounds.FirePitch)
				playSound(
					settings.Sounds.Impact,
					hitPosition,
					settings.Sounds.ImpactVolume,
					settings.Sounds.ImpactPitch
				)
			end
		end
	)

	Input.bind("Fire", onFire)
	RunService:BindToRenderStep("GunAimRestore", Enum.RenderPriority.Camera.Value, restoreFieldOfView)
	RunService:BindToRenderStep("GunAim", Enum.RenderPriority.Camera.Value + 2, applyAim)
	Net.event("InventorySync"):FireServer()
end

return Gun
