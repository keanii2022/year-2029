-- Client side of guns: fires from the camera through the crosshair, flashes the muzzle and sends a
-- glowing bullet flying to the hit right away, and asks the server to check the shot. Also draws
-- other players' shots, kicks the view on each shot and zooms it while aiming.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local Viewmodel = require(script.Parent.Viewmodel)

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

type Bullet = {
	from: Vector3,
	direction: Vector3,
	distance: number,
	travelTime: number,
	startedAt: number,
	part: Part,
	tail: Attachment?,
	head: Attachment?,
	onArrive: () -> (),
}
local bullets: { Bullet } = {}
local scorches: { BasePart } = {}

-- The gun in hand: whichever gun slot is selected on the hotbar.
local function currentGun(): (string?, CombatLogic.Gun?)
	local slot = Hotbar.selected()
	local id = slot and slot.use == "Fire" and slot.item
	if not id or not settings.Blasters[id] or (carried[id] or 0) <= 0 then
		return nil, nil
	end
	return id, settings.Blasters[id]
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
	local id = currentGun()
	local look = id and Config.Hotbar.Guns[id]
	Viewmodel.setArmed(if id then (look and look.model or id) else nil)
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

-- A short glowing streak that flies from the muzzle to the hit, then calls onArrive.
local function launchBullet(from: Vector3, to: Vector3, onArrive: () -> ())
	local offset = to - from
	local distance = offset.Magnitude
	if distance < 0.5 then
		onArrive()
		return
	end
	local part = effectPart(from, to)
	part.Size = Vector3.new(settings.BulletWidth, settings.BulletWidth, 0.05)
	part.Color = settings.BulletColor
	part.CastShadow = false
	local bullet: Bullet = {
		from = from,
		direction = offset / distance,
		distance = distance,
		travelTime = CombatFeel.travelTime(
			distance,
			settings.BulletSpeed,
			settings.BulletMinTravel,
			settings.BulletMaxTravel
		),
		startedAt = os.clock(),
		part = part,
		onArrive = onArrive,
	}
	local image = ModelLibrary.imageId(settings.BulletImage)
	if image then
		-- The texture's head is its right end, which a Beam draws at Attachment1.
		local tail = Instance.new("Attachment")
		tail.Parent = part
		local head = Instance.new("Attachment")
		head.Parent = part
		local beam = Instance.new("Beam")
		beam.Attachment0 = tail
		beam.Attachment1 = head
		beam.Texture = image
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Width0 = settings.BulletWidth * 2
		beam.Width1 = settings.BulletWidth * 2
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Segments = 1
		beam.Color = ColorSequence.new(settings.BulletColor)
		beam.Parent = part
		bullet.tail, bullet.head = tail, head
	else
		part.Material = Enum.Material.Neon
		part.Transparency = 0
	end
	local glow = Instance.new("PointLight")
	glow.Color = settings.BulletColor
	glow.Brightness = 1.5
	glow.Range = 5
	glow.Parent = part
	table.insert(bullets, bullet)
end

local function moveBullets()
	local now = os.clock()
	for index = #bullets, 1, -1 do
		local bullet = bullets[index]
		local tailAt, headAt, done = CombatFeel.streakSpan(
			bullet.distance,
			now - bullet.startedAt,
			bullet.travelTime,
			settings.BulletLength
		)
		if done then
			table.remove(bullets, index)
			bullet.part:Destroy()
			task.spawn(bullet.onArrive)
		else
			local length = math.max(headAt - tailAt, 0.05)
			local headPosition = bullet.from + bullet.direction * headAt
			bullet.part.Size = Vector3.new(settings.BulletWidth, settings.BulletWidth, length)
			bullet.part.CFrame =
				CFrame.lookAt(bullet.from + bullet.direction * (tailAt + length / 2), headPosition)
			if bullet.tail and bullet.head then
				bullet.part.Transparency = 1
				bullet.tail.Position = Vector3.new(0, 0, length / 2)
				bullet.head.Position = Vector3.new(0, 0, -length / 2)
			end
		end
	end
end

local function muzzleFlash(position: Vector3)
	local holder = effectPart(position)
	local image = ModelLibrary.imageId(settings.MuzzleFlashImage)
	if image then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromScale(settings.MuzzleFlashSize, settings.MuzzleFlashSize)
		billboard.LightInfluence = 0
		billboard.Adornee = holder
		local card = Instance.new("ImageLabel")
		card.Size = UDim2.fromScale(1, 1)
		card.BackgroundTransparency = 1
		card.Image = image
		card.ImageColor3 = settings.MuzzleFlashColor
		card.Rotation = math.random(0, 359)
		card.Parent = billboard
		billboard.Parent = holder
	else
		holder.Shape = Enum.PartType.Ball
		holder.Size = Vector3.one * settings.MuzzleFlashSize * 0.35
		holder.Material = Enum.Material.Neon
		holder.Color = settings.MuzzleFlashColor
		holder.Transparency = 0.15
		holder.CastShadow = false
	end
	local light = Instance.new("PointLight")
	light.Color = settings.MuzzleFlashColor
	light.Brightness = 4
	light.Range = 10
	light.Parent = holder
	Debris:AddItem(holder, settings.MuzzleFlashTime)
end

-- A dark burn on whatever the shot hit. Sticks to loose props so it moves with them.
local function scorch(position: Vector3, normal: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder }
	local result = workspace:Raycast(position + normal * 0.2, -normal * 0.5, params)
	local surface = result and result.Instance
	local owner = surface and surface:FindFirstAncestorOfClass("Model")
	if not result or not surface or (owner and owner:FindFirstChildOfClass("Humanoid")) then
		return
	end
	local mark = Instance.new("Part")
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.03, settings.ScorchSize, settings.ScorchSize)
	local across = if math.abs(normal.Y) > 0.99 then Vector3.xAxis else normal:Cross(Vector3.yAxis).Unit
	-- A cylinder's flat faces sit on its X axis, so X points out of the surface.
	mark.CFrame = CFrame.fromMatrix(result.Position + normal * 0.015, normal, across)
	mark.Color = settings.ScorchColor
	mark.Material = Enum.Material.SmoothPlastic
	mark.Transparency = 0.2
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Massless = true
	if not surface:IsA("BasePart") or surface.Anchored then
		mark.Anchored = true
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = mark
		weld.Part1 = surface
		weld.Parent = mark
	end
	mark.Parent = fxFolder
	table.insert(scorches, mark)
	if #scorches > settings.MaxScorches then
		table.remove(scorches, 1):Destroy()
	end
	task.delay(settings.ScorchTime, function()
		if mark.Parent then
			local fade = TweenService:Create(mark, TweenInfo.new(1), { Transparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			local index = table.find(scorches, mark)
			if index then
				table.remove(scorches, index)
			end
			mark:Destroy()
		end
	end)
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

local function drawShot(from: Vector3, to: Vector3, normal: Vector3?, hitPlayer: boolean)
	muzzleFlash(from)
	launchBullet(from, to, function()
		if normal then
			sparks(to, normal, if hitPlayer then settings.PlayerSparkCount else settings.SparkCount)
			if not hitPlayer then
				scorch(to, normal)
			end
		end
		playSound(settings.Sounds.Impact, to, settings.Sounds.ImpactVolume, settings.Sounds.ImpactPitch)
	end)
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
	Viewmodel.kick()
	drawShot(
		Viewmodel.muzzlePosition() or (camera.CFrame * CFrame.new(settings.MuzzleOffset)).Position,
		hitPosition,
		result and result.Normal,
		hitPlayer
	)
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
	Viewmodel.setAim(aimBlend)
	camera.CFrame *= CFrame.Angles(math.rad(settings.CameraKick * Viewmodel.recoil()), 0, 0)
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
				local offset = hitPosition - origin
				local forward = math.min(settings.OthersMuzzleForward, offset.Magnitude)
				local muzzle = if offset.Magnitude > 0 then origin + offset.Unit * forward else origin
				drawShot(muzzle, hitPosition, normal, hitPlayer)
				playSound(settings.Sounds.Fire, origin, settings.Sounds.FireVolume, settings.Sounds.FirePitch)
			end
		end
	)

	Hotbar.onUse("Fire", onFire)
	Hotbar.onChanged(notifyChanged)
	RunService:BindToRenderStep("GunAimRestore", Enum.RenderPriority.Camera.Value, restoreFieldOfView)
	RunService:BindToRenderStep("GunAim", Enum.RenderPriority.Camera.Value + 2, applyAim)
	RunService.RenderStepped:Connect(moveBullets)
	Net.event("InventorySync"):FireServer()
end

return Gun
