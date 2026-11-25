-- Client side of guns: fires from the camera through the crosshair, flashes the muzzle and sends a
-- glowing bullet flying to the hit right away, and asks the server to check the shot. Also draws
-- other players' shots, kicks the view on each shot and zooms it while aiming. Each gun fires by
-- its mode (Logic/CombatModes): semi, auto, burst, pump or single-action, and keeps its own mag.
-- Reloads the mag from the bag on R / Square / RELOAD and on its own when you fire empty; the
-- server's "Mag<GunId>" attributes have the final say.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local CombatModes = require(ReplicatedStorage.Shared.Logic.CombatModes)
local CombatReload = require(ReplicatedStorage.Shared.Logic.CombatReload)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)
local Interact = require(script.Parent.Interact)
local Viewmodel = require(script.Parent.Viewmodel)

local settings = Config.Guns
local player = Players.LocalPlayer

local Gun = {}

local carried: { [string]: number } = {}
local changedListeners: { () -> () } = {}
local hitListeners: { (down: boolean) -> () } = {}
-- Per gun id: loaded rounds and when it last fired.
local mags: { [string]: number } = {}
local lastShotAt: { [string]: number } = {}
local reloadGun: string? = nil
local reloadStartedAt: number? = nil
local reloadId = 0
local armedId: string? = nil
local firing = false
local aimBlend = 0
local baseFieldOfView: number? = nil
-- The last shot's camera kick, played back each frame by applyAim.
local kickAt = -math.huge
local kickPitch = 0
local kickYaw = 0
local kickFovPunch = 0
local kickShake = 0
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
		if reloadGun and reloadGun ~= id then
			reloadId += 1
			reloadGun = nil
			reloadStartedAt = nil
		end
	end
	local look = id and Config.Hotbar.Guns[id]
	Viewmodel.setArmed(if id then (look and look.model or id) else nil, look and look.reload)
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
	playSound(name, position, sounds.FireVolume, sounds.FirePitch)
	local followUp = feel.followUp
	if followUp then
		task.delay(feel.followUpDelay or 0, playSound, followUp, position, sounds.FireVolume)
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
	reloadGun = id
	reloadStartedAt = os.clock()
	reloadRemote:FireServer(id)
	local look = Config.Hotbar.Guns[id]
	local style = look and look.reload or "mag"
	Viewmodel.reload(gun.reloadTime)
	local sounds = settings.Sounds
	if style == "shells" then
		-- Shells go in one by one, then the pump racks as the gun comes back up.
		playSound(sounds.ShellReload, nil, sounds.ReloadVolume)
		local followUp = feelOf(id).followUp
		if followUp then
			task.delay(gun.reloadTime * (1 - settings.ReloadRiseShare), function()
				if reloadId == thisReload then
					playSound(followUp, nil, sounds.FireVolume)
				end
			end)
		end
	else
		playSound(sounds.Reload, nil, sounds.ReloadVolume)
	end
	notifyChanged()
	task.delay(gun.reloadTime, function()
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
		hasGun = true,
		reloading = reloadStartedAt ~= nil,
		ammo = CombatReload.loaded(mags[id] or 0, bag),
		sinceLastShot = os.clock() + aheadBy - (lastShotAt[id] or 0),
		minInterval = minInterval,
	})
end

-- One pull of the trigger's worth of shot (all pellets for the shotgun). minInterval: the gap
-- since this gun's last shot, shorter inside a burst.
local function fireOnce(minInterval: number?): boolean
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
	local feel = feelOf(gunId)
	playShotSound(feel, nil)
	-- Spend the round now so the HUD and the next shot don't wait on the server's reply.
	carried[gun.ammo] -= 1
	mags[gunId] = CombatReload.loaded(mag, bag) - 1
	notifyChanged()

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local look = CFrame.lookAt(Vector3.zero, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fxFolder }
	Viewmodel.kick(feel.weight)
	kickAt = now
	kickPitch, kickYaw = CombatFeel.kickAngles(feel.kick, feel.twitch, math.random())
	kickFovPunch = feel.fovPunch
	kickShake = feel.shake
	local muzzle = Viewmodel.muzzlePosition() or (camera.CFrame * CFrame.new(settings.MuzzleOffset)).Position
	-- Same fixed pellet pattern as the server, so the tracers land where the hits were counted.
	for index, offset in CombatModes.pelletOffsets(gun.pellets or 1, gun.spread or 0) do
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
		task.delay(feel.followUpDelay or 0, Viewmodel.pump, gun.pumpTime or 0)
	end
	fireRemote:FireServer(origin, direction, gunId)
	return true
end

-- On a gamepad Reload shares Square with Use: it reloads only while a gun is in hand and there's
-- nothing to use: no Interact prompt and no pickup / stash prompt showing.
local function onPadUse(began: boolean, device: Input.Device)
	if not began or device ~= "Gamepad" or not currentGun() or Interact.canUse() then
		return
	end
	startReload()
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
			if not fireOnce(gap) then
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

	-- The kick and punch ride on top of this frame's camera, so they spring back on their own.
	local sinceShot = os.clock() - kickAt
	local kick = CombatFeel.recoil(sinceShot, settings.CameraKickRise, settings.CameraKickSettle)
	camera.FieldOfView += kickFovPunch * kick
	local shake = kickShake * CombatFeel.shakeFade(sinceShot, settings.ShakeTime)
	local shakePitch = (math.random() * 2 - 1) * shake
	local shakeYaw = (math.random() * 2 - 1) * shake
	camera.CFrame *= CFrame.Angles(
		math.rad(kickPitch * kick + shakePitch),
		math.rad(kickYaw * kick + shakeYaw),
		0
	)
end

function Gun.Init()
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
	Net.event("InventoryChanged").OnClientEvent:Connect(function(list: { { id: string, count: number } })
		table.clear(carried)
		for _, entry in list do
			carried[entry.id] = entry.count
		end
		notifyChanged()
	end)
	Net.event("GunHit").OnClientEvent:Connect(function(down: boolean)
		playSound(settings.Sounds.HitMarker, nil, settings.Sounds.HitMarkerVolume)
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
	RunService:BindToRenderStep("GunAimRestore", Enum.RenderPriority.Camera.Value, restoreFieldOfView)
	RunService:BindToRenderStep("GunAim", Enum.RenderPriority.Camera.Value + 2, applyAim)
	RunService.RenderStepped:Connect(moveBullets)
	task.spawn(function()
		while true do
			task.wait(0.2)
			updateHint()
		end
	end)
	Net.event("InventorySync"):FireServer()
end

return Gun
