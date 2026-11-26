-- Client side of guns: fires from the camera through the crosshair, flashes the muzzle and sends a
-- glowing bullet flying to the hit right away, and asks the server to check the shot. Also draws
-- other players' shots, kicks the view on each shot and zooms it while aiming. Each gun fires by
-- its mode (Logic/CombatModes): semi, auto, burst, pump or single-action, and keeps its own mag.
-- Reloads the mag from the bag on R / Square / RELOAD and on its own when you fire empty; the
-- server's "Mag<GunId>" attributes have the final say. Shots stray inside a cone (Logic/CombatSpread)
-- that blooms as you fire; on pad and touch they bend to a target near the crosshair, aiming slows
-- over one and starting to aim turns toward it. The view's kick rides on a spring and is undone as it
-- settles, because the default camera keeps whatever pitch and turn it ends a frame with.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local CombatModes = require(ReplicatedStorage.Shared.Logic.CombatModes)
local CombatReload = require(ReplicatedStorage.Shared.Logic.CombatReload)
local CombatSpread = require(ReplicatedStorage.Shared.Logic.CombatSpread)
local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local Spring = require(ReplicatedStorage.Shared.Logic.Spring)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local Interact = require(script.Parent.Interact)
local Movement = require(script.Parent.Movement)
local Viewmodel = require(script.Parent.Viewmodel)

local settings = Config.Guns
local player = Players.LocalPlayer
local spreadTuning = {
	walk = settings.SpreadWalk,
	airborne = settings.SpreadAirborne,
	crouchScale = settings.SpreadCrouchScale,
}

local Gun = {}

local carried: { [string]: number } = {}
local changedListeners: { () -> () } = {}
local hitListeners: { (down: boolean) -> () } = {}
-- Per gun id: loaded rounds and when it last fired.
local mags: { [string]: number } = {}
local lastShotAt: { [string]: number } = {}
local bloom: { [string]: number } = {}
local bloomAt: { [string]: number } = {}
local raisedAt = 0 -- when the gun in hand came out; it fires once its equipTime has passed
local gunUpUntil = 0 -- shooting keeps the gun up for a moment, so sprinting doesn't delay every pull
local reloadGun: string? = nil
local reloadStartedAt: number? = nil
local reloadId = 0
local armedId: string? = nil
local firing = false
local aimBlend = 0
local baseFieldOfView: number? = nil
-- The view's kick (degrees) and how much of it is already in the camera, so each frame only adds
-- the change. kickAt times the FOV punch and shake.
local cameraPitch = Spring.new(settings.SpringStiffness, settings.SpringDamping)
local cameraYaw = Spring.new(settings.SpringStiffness, settings.SpringDamping)
local appliedPitch = 0
local appliedYaw = 0
local kickAt = -math.huge
local kickFovPunch = 0
local kickShake = 0
-- Aim assist: where the view looked at the end of last frame, and the ADS snap still to turn.
local lastLook: Vector3? = nil
local wasAiming = false
local snapYaw = 0
local snapPitch = 0
local snapLeft = 0
local savedMouseSensitivity: number? = nil
local hitStreak = 0
local lastHitAt = -math.huge
local fireRemote: RemoteEvent
local reloadRemote: RemoteEvent
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

-- Mag, reserve and whether a reload is under way, or nil when holding no gun.
function Gun.getMagazine(): (number?, number?, boolean)
	local id, gun = currentGun()
	if not id or not gun then
		return nil, nil, false
	end
	local bag = carried[gun.ammo] or 0
	local mag = mags[id] or 0
	return CombatReload.loaded(mag, bag), CombatReload.reserve(mag, bag), reloadGun == id
end

-- What the gun in hand shoots, for the HUD ("CELLS", "SHELLS"), or nil when holding no gun.
function Gun.getAmmoLabel(): string?
	local _, gun = currentGun()
	return if gun then settings.AmmoLabels[gun.ammo] or string.upper(gun.ammo) else nil
end

function Gun.onChanged(listener: () -> ())
	table.insert(changedListeners, listener)
end

function Gun.onHit(listener: (down: boolean) -> ())
	table.insert(hitListeners, listener)
end

local function notifyChanged()
	local id, gun = currentGun()
	-- Putting a gun away drops its reload.
	if id ~= armedId then
		armedId = id
		if id then
			raisedAt = os.clock()
			Viewmodel.equip()
		end
		if reloadGun and reloadGun ~= id then
			reloadId += 1
			reloadGun = nil
			reloadStartedAt = nil
		end
	end
	local look = id and Config.Hotbar.Guns[id]
	Viewmodel.setArmed(
		if id then (look and look.model or id) else nil,
		look and look.reload,
		gun and gun.boltTravel
	)
	if id and gun then
		Viewmodel.setRounds(CombatReload.loaded(mags[id] or 0, carried[gun.ammo] or 0), gun.magSize)
	end
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
		beam.Brightness = settings.BulletBrightness
		beam.Segments = 1
		beam.Parent = part
		bullet.tail, bullet.head = tail, head
	else
		part.Material = Enum.Material.Neon
		part.Transparency = 0
	end
	local glow = Instance.new("PointLight")
	glow.Color = settings.BulletColor
	glow.Brightness = settings.BulletGlowBrightness
	glow.Range = settings.BulletGlowRange
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
	local size = settings.MuzzleFlashSize * (1 + (math.random() * 2 - 1) * settings.MuzzleFlashScaleJitter)
	local image = ModelLibrary.imageId(settings.MuzzleFlashImage)
	if image then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromScale(size, size)
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
		holder.Size = Vector3.one * size * 0.35
		holder.Material = Enum.Material.Neon
		holder.Color = settings.MuzzleFlashColor
		holder.Transparency = 0.15
		holder.CastShadow = false
	end
	local light = Instance.new("PointLight")
	light.Color = settings.MuzzleFlashColor
	light.Brightness = settings.MuzzleLightBrightness
	light.Range = settings.MuzzleLightRange
	light.Shadows = false
	light.Parent = holder
	task.delay(settings.MuzzleLightTime, function()
		light.Enabled = false
	end)
	Debris:AddItem(holder, settings.MuzzleFlashTime)
end

-- The surface a shot landed on, or nil when it hit a character or nothing solid.
local function surfaceAt(position: Vector3, normal: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder }
	local result = workspace:Raycast(position + normal * 0.2, -normal * 0.5, params)
	local surface = result and result.Instance
	local owner = surface and surface:FindFirstAncestorOfClass("Model")
	if not result or not surface or (owner and owner:FindFirstChildOfClass("Humanoid")) then
		return nil
	end
	return result
end

-- A few small chips knocked off the wall, in its colour, that bounce and vanish.
local function chips(position: Vector3, normal: Vector3, color: Color3)
	for _ = 1, settings.ChipCount do
		local chip = Instance.new("Part")
		chip.Size = Vector3.one * settings.ChipSize * (0.6 + math.random() * 0.8)
		chip.CFrame = CFrame.new(position + normal * settings.ChipSize)
			* CFrame.Angles(math.random() * 6.28, math.random() * 6.28, 0)
		chip.Color = Color3.new(
			color.R * settings.ChipDarken,
			color.G * settings.ChipDarken,
			color.B * settings.ChipDarken
		)
		chip.Material = Enum.Material.Concrete
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CastShadow = false
		chip.Massless = true
		chip.Parent = fxFolder
		local spray = (normal + Vector3.new(math.random() - 0.5, math.random() - 0.2, math.random() - 0.5)).Unit
		chip.AssemblyLinearVelocity = spray * settings.ChipSpeed * (0.5 + math.random() * 0.5)
		Debris:AddItem(chip, settings.ChipLife)
	end
end

-- A dark burn on whatever the shot hit. Sticks to loose props so it moves with them.
local function scorch(result: RaycastResult, normal: Vector3)
	local surface = result.Instance
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
			local fade =
				TweenService:Create(mark, TweenInfo.new(settings.ScorchFadeTime), { Transparency = 1 })
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
-- others hear it from where it happened. Silent until the sound is uploaded. jitter overrides the
-- random pitch wobble (0 for sounds whose pitch means something); muffled cuts the top end.
local function playSound(
	name: string,
	position: Vector3?,
	volume: number?,
	pitch: number?,
	jitter: number?,
	muffled: boolean?
)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.PlaybackSpeed = (pitch or 1) * (1 + (math.random() - 0.5) * (jitter or settings.SoundPitchJitter))
	Mix.route(sound, "SFX")
	if muffled then
		local lowPass = Instance.new("EqualizerSoundEffect")
		lowPass.HighGain = settings.FarShotHighGain
		lowPass.MidGain = 0
		lowPass.LowGain = 0
		lowPass.Parent = sound
	end
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

-- flash: false for a shotgun's extra pellets, so one shot makes one flash.
local function drawShot(from: Vector3, to: Vector3, normal: Vector3?, hitPlayer: boolean, flash: boolean)
	if flash then
		muzzleFlash(from)
	end
	launchBullet(from, to, function()
		local sounds = settings.Sounds
		if not normal then
			return
		end
		if hitPlayer then
			sparks(to, normal, settings.PlayerSparkCount)
			playSound(sounds.Impact, to, sounds.ImpactVolume, sounds.ImpactPitch)
			return
		end
		sparks(to, normal, settings.SparkCount)
		local result = surfaceAt(to, normal)
		if not result then
			return
		end
		scorch(result, normal)
		local kind = CombatFeel.impactKind(result.Material.Name)
		if kind == "concrete" then
			local surface = result.Instance
			chips(to, normal, if surface:IsA("BasePart") then surface.Color else settings.ScorchColor)
		end
		playSound(
			if kind == "metal" then sounds.ImpactMetal else sounds.ImpactConcrete,
			to,
			sounds.ImpactVolume,
			sounds.ImpactPitch
		)
	end)
end

local function feelOf(gunId: string?): CombatFeel.ShotFeel
	return CombatFeel.shotFeel(settings.GunFeel, settings.ShotFeel, settings.DefaultShotFeel, gunId)
end

-- The shot's bang, plus its follow-up (the shotgun's pump) a moment later.
-- Per shooter: when the burst take last started, and where each gun is in its cycle of takes
local burstSoundAt: { [any]: number } = {}
local takeIndex: { [any]: number } = {}

local function playShotSound(feel: CombatFeel.ShotFeel, position: Vector3?, key: any?)
	local sounds = settings.Sounds
	local slot = key or "self"
	local name = feel.sound
	-- The rifle's recording is the whole 3-round burst: play it once per trigger pull
	if feel.oncePerPull then
		local last = burstSoundAt[slot]
		if last and os.clock() - last < feel.oncePerPull then
			return
		end
		burstSoundAt[slot] = os.clock()
	end
	-- The dart blaster cycles its recorded pops in order, one per shot
	if feel.takes then
		local index = (takeIndex[slot] or 0) % #feel.takes + 1
		takeIndex[slot] = index
		name = feel.takes[index]
	end
	Mix.duck("gunfight", Config.Mix.Duck.Gunfight)
	local camera = workspace.CurrentCamera
	local muffled = position ~= nil
		and camera ~= nil
		and (position - camera.CFrame.Position).Magnitude > settings.FarShotDistance
	playSound(name, position, sounds.FireVolume, sounds.FirePitch, nil, muffled)
	local followUp = feel.followUp
	if followUp then
		task.delay(
			feel.followUpDelay or 0,
			playSound,
			followUp,
			position,
			sounds.FireVolume,
			nil,
			nil,
			muffled
		)
	end
end

local function startReload()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local id, gun = currentGun()
	if not id or not gun or not reloadRemote then
		return
	end
	local ok = CombatReload.canReload({
		alive = humanoid ~= nil and humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hasGun = true,
		reloading = reloadStartedAt ~= nil,
		mag = mags[id] or 0,
		magSize = gun.magSize,
		bag = carried[gun.ammo] or 0,
	})
	if not ok then
		return
	end
	reloadId += 1
	local thisReload = reloadId
	local bag = carried[gun.ammo] or 0
	local loaded = CombatReload.loaded(mags[id] or 0, bag)
	local duration = CombatReload.timeFor(gun, loaded, bag)
	local empty = CombatReload.isEmpty(gun, loaded)
	reloadGun = id
	reloadStartedAt = os.clock()
	reloadRemote:FireServer(id)
	local look = Config.Hotbar.Guns[id]
	local style = look and look.reload or "mag"
	Viewmodel.reload(duration, empty)
	local sounds = settings.Sounds
	local function during(share: number, name: string, volume: number, pitch: number?)
		task.delay(duration * share, function()
			if reloadId == thisReload then
				playSound(name, nil, volume, pitch)
			end
		end)
	end
	if style == "shells" then
		-- Shells go in one by one; from empty the pump racks as the gun comes back up.
		local shells = math.max(math.min(gun.magSize, bag) - loaded, 1)
		for shell = 0, shells - 1 do
			during(shell / shells, sounds.ShellReload, sounds.ReloadVolume)
		end
		local followUp = feelOf(id).followUp
		if followUp and empty then
			during(1 - settings.ReloadRiseShare, followUp, sounds.FireVolume)
		end
	elseif style == "mag" then
		-- Old mag out, fresh one clicks home, and from empty the slide or bolt racks at the end.
		playSound(sounds.Reload, nil, sounds.ReloadVolume)
		during(settings.ReloadMagIn[2], sounds.Reload, sounds.ReloadVolume, 1.1)
		if empty then
			during(settings.ReloadRack[1], sounds.Rack, sounds.RackVolume, sounds.RackPitch)
		end
	else
		playSound(sounds.Reload, nil, sounds.ReloadVolume)
	end
	notifyChanged()
	task.delay(duration, function()
		if reloadId == thisReload then
			reloadGun = nil
			reloadStartedAt = nil
			mags[id] = CombatReload.refill(gun.magSize, carried[gun.ammo] or 0)
			notifyChanged()
		end
	end)
end

local function cancelReload()
	reloadId += 1
	reloadGun = nil
	reloadStartedAt = nil
	notifyChanged()
end

-- Whether the gun in hand could fire aheadBy seconds from now (the revolver checks before it
-- starts cocking), and why not.
local function fireCheck(
	id: string,
	gun: CombatLogic.Gun,
	minInterval: number,
	aheadBy: number
): (boolean, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local bag = carried[gun.ammo] or 0
	return CombatLogic.canFire({
		alive = humanoid ~= nil and humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hidden = player:GetAttribute("Hidden") == true,
		hasGun = true,
		reloading = reloadStartedAt ~= nil,
		ammo = if player:GetAttribute("InfiniteAmmo") == true
			then gun.magSize
			else CombatReload.loaded(mags[id] or 0, bag),
		sinceLastShot = os.clock() + aheadBy - (lastShotAt[id] or 0),
		minInterval = minInterval,
	})
end

-- Seconds until the gun in hand may fire: still coming up after equipping, or coming out of a sprint.
local function readyIn(gun: CombatLogic.Gun): number
	local now = os.clock()
	local wait = raisedAt + (gun.equipTime or 0) - now
	if Movement.getStance() == "Sprint" and now > gunUpUntil then
		wait = math.max(wait, gun.sprintToFire or 0)
	end
	return math.max(wait, 0)
end

local function bloomOf(gunId: string): number
	return CombatSpread.recover(bloom[gunId] or 0, os.clock() - (bloomAt[gunId] or 0), settings.BloomRecovery)
end

-- The gun's spread cone right now, in degrees.
local function coneFor(gunId: string, gun: CombatLogic.Gun, character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	return CombatSpread.cone(gun, {
		aim = aimBlend,
		bloom = bloomOf(gunId),
		moving = Vector2.new(velocity.X, velocity.Z).Magnitude > settings.MovingSpeed,
		airborne = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air,
		crouching = Movement.getStance() == "Crouch",
	}, spreadTuning)
end

-- Aim assist is for thumbs: pads and touch screens, never the mouse.
local function assistOn(): boolean
	return Input.lastDevice() ~= "Keyboard"
end

local function chestOf(body: Model): Vector3?
	local part = body:FindFirstChild("UpperTorso")
		or body:FindFirstChild("Torso")
		or body:FindFirstChild("HumanoidRootPart")
		or body.PrimaryPart
	return if part and part:IsA("BasePart") then part.Position else nil
end

-- The chest of the closest-to-crosshair player, sim bot or robot within coneDegrees and in sight.
local function assistTarget(origin: Vector3, look: Vector3, coneDegrees: number, range: number): Vector3?
	local character = player.Character
	local bodies: { Instance } = CollectionService:GetTagged(Config.SimPlayers.Tag)
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(bodies, other.Character)
		end
	end
	local robots = workspace:FindFirstChild("Robots")
	if robots then
		for _, robot in robots:GetChildren() do
			table.insert(bodies, robot)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance, fxFolder }
	local best: Vector3? = nil
	local bestAngle = coneDegrees
	for _, body in bodies do
		local humanoid = body:FindFirstChildOfClass("Humanoid")
		local chest = body:IsA("Model") and chestOf(body)
		if chest and (not humanoid or humanoid.Health > 0) then
			local offset = chest - origin
			local distance = offset.Magnitude
			if distance > 0.5 and distance <= range then
				local angle = math.deg(math.acos(math.clamp(look:Dot(offset / distance), -1, 1)))
				if angle <= bestAngle then
					local result = workspace:Raycast(origin, offset, params)
					if not result or result.Instance:IsDescendantOf(body) then
						best, bestAngle = chest, angle
					end
				end
			end
		end
	end
	return best
end

local function assistCone(aiming: boolean): number
	return if aiming then settings.AimAssistAimedCone else settings.AimAssistCone
end

-- One pull of the trigger's worth of shot (all pellets for the shotgun). minInterval: the gap
-- since this gun's last shot, shorter inside a burst; shotInPull counts shots within a burst.
local function fireOnce(minInterval: number?, shotInPull: number?): boolean
	local camera = workspace.CurrentCamera
	local character = player.Character
	local gunId, gun = currentGun()
	if not camera or not character or not gunId or not gun then
		return false
	end
	local now = os.clock()
	local bag = carried[gun.ammo] or 0
	local mag = mags[gunId] or 0
	local ok, reason = fireCheck(gunId, gun, minInterval or gun.fireInterval, 0)
	if not ok then
		if reason == "no ammo" and CombatReload.shouldAutoReload(mag, bag) then
			startReload()
		elseif reason == "no ammo" and now - (lastShotAt[gunId] or 0) >= gun.fireInterval then
			lastShotAt[gunId] = now
			playSound(settings.Sounds.Empty, nil, 0.7)
		end
		return false
	end
	lastShotAt[gunId] = now
	gunUpUntil = now + settings.GunUpHold
	local feel = feelOf(gunId)
	playShotSound(feel, nil)
	local sounds = settings.Sounds
	playSound(sounds.ShotClick, nil, sounds.ShotClickVolume, sounds.ShotClickPitch)
	-- Spend the round now so the HUD and the next shot don't wait on the server's reply.
	if player:GetAttribute("InfiniteAmmo") ~= true then
		carried[gun.ammo] -= 1
		mags[gunId] = CombatReload.loaded(mag, bag) - 1
		notifyChanged()
	end

	local origin = camera.CFrame.Position
	local aiming = aimBlend > 0.5
	local centre = camera.CFrame.LookVector
	if assistOn() then
		local chest = assistTarget(origin, centre, assistCone(aiming), gun.range)
		if chest then
			centre = (chest - origin).Unit
		end
	end
	local spreadYaw, spreadPitch =
		CombatSpread.offset(coneFor(gunId, gun, character), math.random(), math.random())
	local direction = (CFrame.lookAt(Vector3.zero, centre) * CFrame.Angles(
		math.rad(spreadPitch),
		math.rad(-spreadYaw),
		0
	)).LookVector
	bloom[gunId] = CombatSpread.bloomAfterShot(gun, bloomOf(gunId))
	bloomAt[gunId] = now
	local look = CFrame.lookAt(Vector3.zero, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fxFolder }
	Viewmodel.kick(feel.weight)
	local pattern = gun.burstKick and gun.burstKick[shotInPull or 1]
	local kickUp, kickSide
	if pattern then
		kickUp, kickSide = pattern[1], pattern[2]
	else
		kickUp, kickSide = CombatFeel.kickAngles(feel.kick, feel.twitch, math.random())
		kickUp *= settings.CameraKickScale
		kickSide *= settings.CameraKickScale
	end
	Spring.kick(cameraPitch, kickUp)
	Spring.kick(cameraYaw, kickSide)
	kickAt = now
	kickFovPunch = feel.fovPunch
	kickShake = feel.shake
	if not gun.noCasing and gun.mode ~= "pump" then
		Viewmodel.ejectCasing()
	end
	local muzzle = Viewmodel.muzzlePosition() or (camera.CFrame * CFrame.new(settings.MuzzleOffset)).Position
	local spread = (gun.spread or 0) * (if aiming then gun.aimSpreadScale or 1 else 1)
	-- Same fixed pellet pattern as the server, so the tracers land where the hits were counted.
	for index, offset in CombatModes.pelletOffsets(gun.pellets or 1, spread) do
		local aim = (look * CFrame.Angles(math.rad(offset.y), math.rad(-offset.x), 0)).LookVector
		local result = workspace:Raycast(origin, aim * gun.range, params)
		local hitPosition = if result then result.Position else origin + aim * gun.range
		local hitPlayer = false
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			hitPlayer = model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
		end
		drawShot(muzzle, hitPosition, result and result.Normal, hitPlayer, index == 1)
	end
	if gun.mode == "pump" then
		-- The spent shell flies out as the pump racks.
		task.delay(feel.followUpDelay or 0, function()
			Viewmodel.pump(gun.pumpTime or 0)
			if not gun.noCasing then
				Viewmodel.ejectCasing()
			end
		end)
	end
	fireRemote:FireServer(origin, direction, gunId, aiming)
	return true
end

-- On a gamepad Reload shares Square with Use. With a gun out, a tap on Square reloads (CombatReload
-- skips a full mag) unless the crosshair is on something usable. Pickup / stash prompts turn into
-- holds meanwhile, so near one a tap still reloads and a hold takes the prompt.
local PAD_PROMPT_HOLD = 0.4 -- seconds
local padPressAt: number? = nil
local shownPrompts: { [ProximityPrompt]: true } = {}
local promptHolds: { [ProximityPrompt]: number } = {} -- prompts made into holds -> their own HoldDuration

local function updatePromptHolds()
	local wanted = Input.lastDevice() == "Gamepad" and currentGun() ~= nil
	for proximity, own in promptHolds do
		if not wanted or not shownPrompts[proximity] then
			proximity.HoldDuration = own
			promptHolds[proximity] = nil
		end
	end
	if wanted then
		for proximity in shownPrompts do
			if not promptHolds[proximity] then
				promptHolds[proximity] = proximity.HoldDuration
				proximity.HoldDuration = math.max(proximity.HoldDuration, PAD_PROMPT_HOLD)
			end
		end
	end
end

local function onPadUse(began: boolean, device: Input.Device)
	if device ~= "Gamepad" then
		return
	end
	if began then
		padPressAt = nil
		if not currentGun() or Interact.canUse() then
			return
		elseif Interact.promptShowing() then
			padPressAt = os.clock()
		else
			startReload()
		end
	elseif padPressAt then
		local tapped = os.clock() - padPressAt < PAD_PROMPT_HOLD
		padPressAt = nil
		if tapped then
			startReload()
		end
	end
end

-- Under the crosshair: Fire / Aim / Reload for a few seconds after you pull the gun out, then
-- only Reload in spray red when the mag runs low, so it stays quiet while you're fine.
local hints = Config.Hints
local equippedId: string? = nil
local equippedAt = 0
local function updateHint()
	local id, gun = currentGun()
	if id ~= equippedId then
		equippedId = id
		equippedAt = os.clock()
	end
	if not gun then
		Hints.set("gun", nil)
		return
	end
	local loaded, reserve, reloading = Gun.getMagazine()
	local low = (loaded or 0) <= math.ceil(gun.magSize * hints.LowAmmoShare)
	local empty = (loaded or 0) == 0 and (reserve or 0) == 0
	if not reloading and low and empty then
		Hints.set("gun", hints.NoAmmoHint, 4, "warn")
	elseif not reloading and low and (reserve or 0) > 0 then
		Hints.set("gun", hints.LowAmmoHint, 4, "warn")
	elseif not reloading and os.clock() - equippedAt < hints.GunHintSeconds then
		Hints.set("gun", hints.GunHint, 4)
	else
		Hints.set("gun", nil)
	end
end

local function onFire(began: boolean)
	if not began or firing then
		return
	end
	local id, gun = currentGun()
	if not id or not gun then
		return
	end
	firing = true
	-- A pull during the equip raise or out of a sprint fires as soon as the gun is up.
	local wait = readyIn(gun)
	if wait > 0 then
		task.wait(wait)
		if currentGun() ~= id then
			firing = false
			return
		end
	end
	if gun.mode == "single-action" then
		-- Thumb the hammer back first, then the shot breaks. If it couldn't fire anyway, skip the
		-- cock so an empty pull still clicks or reloads right away.
		local cockTime = gun.cockTime or 0
		if fireCheck(id, gun, gun.fireInterval, cockTime) then
			Viewmodel.cock(cockTime)
			playSound(settings.Sounds.Cock, nil, settings.Sounds.CockVolume)
			task.wait(cockTime)
			if currentGun() == id then
				fireOnce()
			end
		else
			fireOnce()
		end
	elseif fireOnce() then
		local shot = 1
		while true do
			local nowId, nowGun = currentGun()
			if nowId ~= id or not nowGun then
				break
			end
			local burstGoing = shot < CombatModes.shotsPerPull(gun)
			if not burstGoing and not (CombatModes.holdsToFire(gun) and Input.isDown("Fire")) then
				break
			end
			local gap = CombatModes.gapAfter(gun, shot)
			task.wait(gap)
			if not burstGoing and not Input.isDown("Fire") then
				break
			end
			if not fireOnce(gap, shot + 1) then
				break
			end
			shot += 1
		end
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

-- Turns the view: yaw about the world's up, pitch about the view's own side axis (radians).
local function turnView(camera: Camera, yaw: number, pitch: number)
	local cframe = camera.CFrame
	local position = cframe.Position
	camera.CFrame = CFrame.new(position)
		* CFrame.Angles(0, yaw, 0)
		* (cframe - position)
		* CFrame.Angles(pitch, 0, 0)
end

local function yawPitchOf(look: Vector3): (number, number)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Mouse turning slows by the zoom while aiming, so the crosshair moves the same on screen.
local function updateMouseSensitivity(zoom: number)
	if zoom < 0.999 and Input.lastDevice() == "Keyboard" then
		savedMouseSensitivity = savedMouseSensitivity or UserInputService.MouseDeltaSensitivity
		UserInputService.MouseDeltaSensitivity = (savedMouseSensitivity :: number) * zoom
	elseif savedMouseSensitivity then
		UserInputService.MouseDeltaSensitivity = savedMouseSensitivity
		savedMouseSensitivity = nil
	end
end

-- Pad and touch: slower turning over a target, and a short pull toward one when you start aiming.
local function assistView(camera: Camera, gun: CombatLogic.Gun, aiming: boolean, dt: number)
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	if aiming and not wasAiming then
		local chest = assistTarget(origin, look, settings.AimSnapMax, gun.range)
		if chest then
			local yaw, pitch = yawPitchOf(look)
			local wantYaw, wantPitch = yawPitchOf((chest - origin).Unit)
			snapYaw, snapPitch = wrapAngle(wantYaw - yaw), wantPitch - pitch
			snapLeft = settings.AimSnapTime
		end
	end
	if lastLook and assistTarget(origin, look, assistCone(aiming), gun.range) then
		local yaw, pitch = yawPitchOf(look)
		local lastYaw, lastPitch = yawPitchOf(lastLook)
		local undo = 1 - settings.AimFriction
		turnView(camera, -wrapAngle(yaw - lastYaw) * undo, -(pitch - lastPitch) * undo)
	end
	if snapLeft > 0 then
		local share = math.min(dt, snapLeft) / settings.AimSnapTime
		snapLeft -= dt
		turnView(camera, snapYaw * share, snapPitch * share)
	end
end

local function applyAim(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local _, gun = currentGun()
	local aiming = Input.isDown("Aim") and gun ~= nil
	aimBlend = MovementLogic.smooth(aimBlend, if aiming then 1 else 0, settings.AimEase, dt)
	local zoom = 1 + ((gun and gun.aimFovScale or settings.AimFieldOfViewScale) - 1) * aimBlend
	baseFieldOfView = camera.FieldOfView
	camera.FieldOfView = camera.FieldOfView * zoom
	Viewmodel.setAim(aimBlend)
	updateMouseSensitivity(zoom)

	local pitchKick = Spring.step(cameraPitch, dt)
	local yawKick = Spring.step(cameraYaw, dt)
	if camera.CameraType ~= Enum.CameraType.Custom then
		-- A cutscene or menu owns the camera: leave it alone and start clean afterwards.
		appliedPitch, appliedYaw, lastLook, snapLeft = 0, 0, nil, 0
		wasAiming = aiming
		return
	end
	if gun and assistOn() then
		assistView(camera, gun, aiming, dt)
	else
		snapLeft = 0
	end
	wasAiming = aiming

	-- The default camera keeps the pitch and turn it ends a frame with, so only the change in kick
	-- goes in each frame; as the springs settle the view comes back to where you aimed.
	local wantPitch, wantYaw = 0, 0
	if player:GetAttribute("CameraShake") ~= false then
		local sinceShot = os.clock() - kickAt
		camera.FieldOfView += kickFovPunch * CombatFeel.recoil(
			sinceShot,
			settings.CameraKickRise,
			settings.CameraKickSettle
		)
		local shake = kickShake * CombatFeel.shakeFade(sinceShot, settings.ShakeTime)
		wantPitch = pitchKick + (math.random() * 2 - 1) * shake
		wantYaw = yawKick + (math.random() * 2 - 1) * shake
	end
	turnView(camera, math.rad(wantYaw - appliedYaw), math.rad(wantPitch - appliedPitch))
	appliedPitch, appliedYaw = wantPitch, wantYaw
	lastLook = camera.CFrame.LookVector
end

function Gun.Init()
	if player:GetAttribute("CameraShake") == nil then
		player:SetAttribute("CameraShake", settings.CameraShake)
	end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "GunFx"
	fxFolder.Parent = workspace
end

-- Remotes are fetched in Start because the client waits for them and Init may not yield.
function Gun.Start()
	fireRemote = Net.event("GunFire")
	reloadRemote = Net.event("GunReload")
	local function adoptServerMag(attribute: string)
		local id = string.match(attribute, "^Mag(.+)$")
		local serverMag = player:GetAttribute(attribute)
		if id and settings.Blasters[id] and type(serverMag) == "number" then
			mags[id] = serverMag
			notifyChanged()
		end
	end
	player.AttributeChanged:Connect(adoptServerMag)
	for attribute in player:GetAttributes() do
		adoptServerMag(attribute)
	end
	player.CharacterAdded:Connect(cancelReload)
	Input.bind("Reload", function(began)
		if began then
			startReload()
		end
	end)
	Input.bind("Use", onPadUse)
	ProximityPromptService.PromptShown:Connect(function(proximity)
		shownPrompts[proximity] = true
		updatePromptHolds()
	end)
	ProximityPromptService.PromptHidden:Connect(function(proximity)
		shownPrompts[proximity] = nil
		updatePromptHolds()
	end)
	Net.event("InventoryChanged").OnClientEvent:Connect(function(list: { { id: string, count: number } })
		table.clear(carried)
		for _, entry in list do
			carried[entry.id] = entry.count
		end
		notifyChanged()
	end)
	Net.event("GunHit").OnClientEvent:Connect(function(down: boolean)
		-- Quick hits climb in pitch, so landing a string of them sounds like it.
		local now = os.clock()
		hitStreak = if now - lastHitAt <= settings.HitPitchWindow then hitStreak + 1 else 0
		lastHitAt = now
		local sounds = settings.Sounds
		local pitch = 1 + math.min(hitStreak * settings.HitPitchStep, settings.HitPitchMax)
		playSound(sounds.HitMarker, nil, sounds.HitMarkerVolume, pitch, 0)
		if down then
			playSound(sounds.KillConfirm, nil, sounds.KillConfirmVolume, sounds.KillConfirmPitch, 0)
		end
		for _, listener in hitListeners do
			task.spawn(listener, down)
		end
	end)
	Net.unreliable("GunFx").OnClientEvent:Connect(
		function(
			shooter: Player,
			origin: Vector3,
			hitPosition: Vector3,
			normal: Vector3?,
			hitPlayer: boolean,
			gunId: string?,
			pellet: number?
		)
			if shooter ~= player then
				local offset = hitPosition - origin
				local forward = math.min(settings.OthersMuzzleForward, offset.Magnitude)
				local muzzle = if offset.Magnitude > 0 then origin + offset.Unit * forward else origin
				-- A shotgun sends one of these per pellet; only the first flashes and bangs.
				local first = pellet == nil or pellet == 1
				drawShot(muzzle, hitPosition, normal, hitPlayer, first)
				if first then
					playShotSound(feelOf(gunId), origin, shooter)
				end
			end
		end
	)
	-- The server sends this when someone's shot flies past your head.
	Net.unreliable("GunWhiz").OnClientEvent:Connect(function(passedAt: Vector3)
		playSound(settings.Sounds.Whiz, passedAt, settings.Sounds.WhizVolume)
	end)

	Hotbar.onUse("Fire", onFire)
	Hotbar.onChanged(notifyChanged)
	Hotbar.onChanged(updatePromptHolds)
	RunService:BindToRenderStep("GunAimRestore", Enum.RenderPriority.Camera.Value, restoreFieldOfView)
	RunService:BindToRenderStep("GunAim", Enum.RenderPriority.Camera.Value + 2, applyAim)
	RunService.RenderStepped:Connect(moveBullets)
	task.spawn(function()
		while true do
			task.wait(0.2)
			updateHint()
			updatePromptHolds()
		end
	end)
	Net.event("InventorySync"):FireServer()
end

return Gun
