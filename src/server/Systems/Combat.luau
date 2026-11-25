-- Server side of guns: checks every shot, does the hit raycast, deals damage, and handles
-- going down (everything drops as a loot pile) and the spawn kit. The client names the gun it has
-- selected on the hotbar with each shot and reload; the server checks the player owns it and fires
-- that gun by its Config.Guns rules (mode, interval, mag, pellets). Tracks each gun's mag and the
-- reload, published as "Mag<GunId>" and "Reloading" (the gun's id) attributes for the client's HUD.
-- Players take damage; a robot hit goes to Robots.shot (stagger, knockdown, grudge). Anything else a
-- shot hits just throws sparks and stops the shot.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local CombatModes = require(ReplicatedStorage.Shared.Logic.CombatModes)
local CombatReload = require(ReplicatedStorage.Shared.Logic.CombatReload)
local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Inventory = require(script.Parent.Inventory)
local RobotGear = require(script.Parent.RobotGear)
local Robots = require(script.Parent.Robots)
local Scores = require(script.Parent.Scores)

local settings = Config.Guns

local Combat = {}

type GunState = { mag: number, lastShotAt: number, burstShots: number }
-- reloadId tells a finished reload's timer apart from a newer reload or a respawn.
type PlayerState = {
	guns: { [string]: GunState },
	reloadGun: string?,
	reloadStartedAt: number?,
	reloadId: number,
}
local states: { [Player]: PlayerState } = {}
-- shooter -> victim UserId -> os.clock() of the last kill that counted
local lastKills: { [Player]: { [number]: number } } = {}
local hitRemote: RemoteEvent
local fxRemote: UnreliableRemoteEvent
local whizRemote: UnreliableRemoteEvent
local viewmodels: Folder

local function isFiniteVector(value: any): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local sum = value.X + value.Y + value.Z
	return sum == sum and math.abs(sum) ~= math.huge
end

local function playerFromPart(part: Instance): (Player?, Humanoid?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return Players:GetPlayerFromCharacter(model), humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

local function excludeParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return params
end

-- The gun the client says is selected, if the player really carries it.
local function heldGun(player: Player, gunId: any): (CombatLogic.Gun?, string?)
	local gun = CombatLogic.selectedGun(settings.Blasters, gunId, function(id)
		return Inventory.has(player, id)
	end)
	return gun, if gun then gunId else nil
end

-- Tells every other player whose head the shot flew past, so they hear it whiz by.
local function sendWhizzes(shooter: Player, target: Player?, origin: Vector3, hitPosition: Vector3)
	local shot = hitPosition - origin
	local shotLength = shot.Magnitude
	if shotLength <= 0 then
		return
	end
	local aim = shot / shotLength
	for _, other in Players:GetPlayers() do
		local character = if other ~= shooter and other ~= target then other.Character else nil
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if head then
			local along = (head.Position - origin):Dot(aim)
			local closest = origin + aim * math.clamp(along, 0, shotLength)
			local miss = (head.Position - closest).Magnitude
			if CombatFeel.whizzes(along, shotLength, miss, settings.WhizRadius, settings.WhizMinDistance) then
				whizRemote:FireClient(other, closest)
			end
		end
	end
end

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { guns = {}, reloadId = 0 }
		states[player] = state
	end
	return state
end

local function gunState(state: PlayerState, gunId: string): GunState
	local gun = state.guns[gunId]
	if not gun then
		gun = { mag = 0, lastShotAt = 0, burstShots = 0 }
		state.guns[gunId] = gun
	end
	return gun
end

local function publishMag(player: Player, state: PlayerState, gunId: string)
	player:SetAttribute("Mag" .. gunId, gunState(state, gunId).mag)
	player:SetAttribute("Reloading", state.reloadGun)
end

local function fillMag(player: Player, state: PlayerState, gunId: string)
	local gun = settings.Blasters[gunId]
	if gun then
		gunState(state, gunId).mag = if player:GetAttribute("InfiniteAmmo") == true
			then gun.magSize
			else CombatReload.refill(gun.magSize, Inventory.count(player, gun.ammo))
		publishMag(player, state, gunId)
	end
end

local function finishReload(player: Player, state: PlayerState)
	local gunId = state.reloadGun
	state.reloadGun = nil
	state.reloadStartedAt = nil
	if gunId then
		fillMag(player, state, gunId)
	end
	player:SetAttribute("Reloading", nil)
end

local function cancelReload(player: Player, state: PlayerState)
	state.reloadId += 1
	state.reloadGun = nil
	state.reloadStartedAt = nil
	player:SetAttribute("Reloading", nil)
end

-- A reload whose time is up counts as done right away, even if its timer hasn't fired yet.
local function settleReload(player: Player, state: PlayerState, now: number)
	local startedAt = state.reloadStartedAt
	local gun = state.reloadGun and settings.Blasters[state.reloadGun]
	if
		startedAt
		and gun
		and CombatReload.isDone(startedAt, now, gun.reloadTime, settings.ReloadTimeSlack)
	then
		finishReload(player, state)
	end
end

local function onReload(player: Player, gunId: any)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local gun, id = heldGun(player, gunId)
	local state = stateOf(player)
	local now = os.clock()
	settleReload(player, state, now)
	-- Swapping guns mid-reload and reloading the new one drops the old reload.
	if id and state.reloadGun and state.reloadGun ~= id then
		cancelReload(player, state)
	end
	local ok = CombatReload.canReload({
		alive = humanoid ~= nil and humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hasGun = gun ~= nil,
		reloading = state.reloadStartedAt ~= nil,
		mag = if id then gunState(state, id).mag else 0,
		magSize = if gun then gun.magSize else 0,
		bag = if gun then Inventory.count(player, gun.ammo) else 0,
	})
	if not ok or not gun or not id then
		return
	end
	state.reloadId += 1
	local reloadId = state.reloadId
	state.reloadGun = id
	state.reloadStartedAt = now
	publishMag(player, state, id)
	task.delay(gun.reloadTime, function()
		if states[player] == state and state.reloadId == reloadId and state.reloadStartedAt then
			finishReload(player, state)
		end
	end)
end

-- A flare burning where the shot landed: lights the area for a while, then fades out.
local function dropFlare(position: Vector3, normal: Vector3?)
	local flare = Instance.new("Part")
	flare.Name = "Flare"
	flare.Shape = Enum.PartType.Ball
	flare.Size = Vector3.one * settings.FlareSize
	flare.CFrame = CFrame.new(position + (normal or Vector3.yAxis) * settings.FlareSize)
	flare.Anchored = true
	flare.CanCollide = false
	flare.CanQuery = false
	flare.CanTouch = false
	flare.CastShadow = false
	flare.Material = Enum.Material.Neon
	flare.Color = settings.FlareColor
	local light = Instance.new("PointLight")
	light.Color = settings.FlareColor
	light.Brightness = settings.FlareBrightness
	light.Range = settings.FlareRange
	light.Shadows = true
	light.Parent = flare
	flare.Parent = workspace
	-- Keani's recorded flare: it burns on a loop, then sputters out as it fades
	local function flareSound(name: string, looped: boolean): Sound?
		local id = ModelLibrary.soundId(name)
		if not id then
			return nil
		end
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Looped = looped
		sound.RollOffMaxDistance = 60
		sound.Parent = flare
		Mix.route(sound, "SFX")
		sound:Play()
		return sound
	end
	local burn = flareSound(settings.FlareBurnSound, true)
	task.delay(settings.FlareTime - settings.FlareFadeTime, function()
		if burn then
			burn:Stop()
		end
		flareSound(settings.FlareBurnoutSound, false)
		local fade = TweenInfo.new(settings.FlareFadeTime)
		TweenService:Create(light, fade, { Brightness = 0 }):Play()
		TweenService:Create(flare, fade, { Transparency = 1 }):Play()
	end)
	Debris:AddItem(flare, settings.FlareTime)
end

-- One ray of a shot: what it hits from the camera, or whatever blocks the head's view of that.
local function trace(
	origin: Vector3,
	aim: Vector3,
	range: number,
	head: BasePart,
	params: RaycastParams
): (Vector3, Instance?, Vector3?)
	local result = workspace:Raycast(origin, aim * range, params)
	local hitPosition = if result then result.Position else origin + aim * range
	local hitPart = result and result.Instance
	local hitNormal = result and result.Normal

	-- The camera can peek where the head can't; whatever blocks the head takes the shot instead.
	local fromHead = hitPosition - head.Position
	local blocker = workspace:Raycast(head.Position, fromHead, params)
	if
		blocker
		and not CombatLogic.lineOfSightClear(
			fromHead.Magnitude,
			(blocker.Position - head.Position).Magnitude,
			settings.LineOfSightSlack
		)
	then
		hitPosition, hitPart, hitNormal = blocker.Position, blocker.Instance, blocker.Normal
	end
	return hitPosition, hitPart, hitNormal
end

local function endSpawnGrace(player: Player, character: Model)
	player:SetAttribute("SpawnGrace", nil)
	local shield = character:FindFirstChild("SpawnShield")
	if shield then
		shield:Destroy()
	end
end

-- A real player downing another real player, at most once per victim per KillRepeatWindow
local function countKill(shooter: Player, target: Player?, now: number): boolean
	local kills = lastKills[shooter] or {}
	lastKills[shooter] = kills
	local isPlayer = target ~= nil
	local userId = if target then target.UserId else 0
	if
		not CombatLogic.countsKill(isPlayer, target == shooter, kills[userId], now, settings.KillRepeatWindow)
	then
		return false
	end
	kills[userId] = now
	return true
end

local function onFire(player: Player, origin: any, direction: any, gunId: any)
	if not isFiniteVector(origin) or not isFiniteVector(direction) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local gun, id = heldGun(player, gunId)
	if not character or not humanoid or not head or not gun or not id then
		return
	end

	local now = os.clock()
	local state = stateOf(player)
	settleReload(player, state, now)
	-- Firing another gun drops the reload that was under way.
	if state.reloadGun and state.reloadGun ~= id then
		cancelReload(player, state)
	end
	local held = gunState(state, id)
	local infinite = player:GetAttribute("InfiniteAmmo") == true
	local mag = if infinite
		then gun.magSize
		else CombatReload.loaded(held.mag, Inventory.count(player, gun.ammo))
	local sinceLastShot = now - held.lastShotAt
	local ok = CombatLogic.canFire({
		alive = humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hasGun = true,
		reloading = state.reloadStartedAt ~= nil,
		ammo = mag,
		sinceLastShot = sinceLastShot,
		minInterval = CombatModes.minGap(gun, held.burstShots) * settings.FireIntervalSlack,
	})
	if not ok then
		return
	end
	ok = CombatLogic.checkShot({
		originOffset = (origin - head.Position).Magnitude,
		maxOriginOffset = settings.MaxOriginOffset,
		directionLength = direction.Magnitude,
	})
	if not ok then
		return
	end
	Robots.heardShot(origin)
	endSpawnGrace(player, character)

	held.burstShots =
		CombatModes.burstAfterShot(gun, held.burstShots, sinceLastShot, settings.FireIntervalSlack)
	held.lastShotAt = now
	if infinite then
		held.mag = gun.magSize
	else
		Inventory.remove(player, gun.ammo, 1)
		held.mag = mag - 1
	end
	publishMag(player, state, id)

	-- Every pellet (one for most guns) is its own ray; a target hit by several takes the sum.
	local params = excludeParams(character)
	local aim = direction.Unit
	local look = CFrame.lookAt(Vector3.zero, aim)
	local damageTo: { [Humanoid]: number } = {}
	local victims: { [Humanoid]: Player? } = {}
	local robotDamage: { [any]: { damage: number, at: Vector3 } } = {}
	local centreHit = origin + aim * gun.range
	local centreTarget: Player? = nil
	for index, offset in CombatModes.pelletOffsets(gun.pellets or 1, gun.spread or 0) do
		local pelletAim = (look * CFrame.Angles(math.rad(offset.y), math.rad(-offset.x), 0)).LookVector
		local hitPosition, hitPart, hitNormal = trace(origin, pelletAim, gun.range, head, params)
		local hitPlayer = false
		local target, targetHumanoid
		if hitPart then
			target, targetHumanoid = playerFromPart(hitPart)
		end
		-- simulated players have no Player but take hits like one
		local simPlayer = targetHumanoid ~= nil
			and CollectionService:HasTag(targetHumanoid.Parent :: Instance, Config.SimPlayers.Tag)
		if (target or simPlayer) and targetHumanoid and target ~= player and targetHumanoid.Health > 0 then
			local damage = CombatLogic.damageAt(gun, (hitPosition - origin).Magnitude)
			damageTo[targetHumanoid] = (damageTo[targetHumanoid] or 0) + damage
			victims[targetHumanoid] = target
			hitPlayer = true
		end
		local robot = hitPart and not targetHumanoid and Robots.fromPart(hitPart)
		if robot then
			local hit = robotDamage[robot] or { damage = 0, at = hitPosition }
			hit.damage += CombatLogic.damageAt(gun, (hitPosition - origin).Magnitude)
			robotDamage[robot] = hit
		end
		if index == 1 then
			centreHit = hitPosition
			centreTarget = if hitPlayer then target else nil
			if gun.flare then
				dropFlare(hitPosition, hitNormal)
			end
		end
		fxRemote:FireAllClients(player, origin, hitPosition, hitNormal, hitPlayer, id, index)
	end
	for targetHumanoid, damage in damageTo do
		local body = targetHumanoid.Parent :: Instance
		body:SetAttribute("HurtBy", `Shot by {player.DisplayName}`)
		body:SetAttribute("HurtAt", workspace:GetServerTimeNow())
		targetHumanoid:TakeDamage(damage)
		local downed = targetHumanoid.Health <= 0
		if downed and countKill(player, victims[targetHumanoid], now) then
			Scores.add(player, "PlayerKills", 1)
		end
		hitRemote:FireClient(player, downed)
	end
	for robot, hit in robotDamage do
		Robots.shot(robot, player, hit.damage, origin, hit.at)
	end
	sendWhizzes(player, centreTarget, origin, centreHit)
	if gun.robotWeapon then
		RobotGear.zap(player, aim)
	end
end

-- What the down screen says got you: the last HurtBy a damage source stamped on the body (robot,
-- player, hunger, dog) if it's recent, else a fall into the void, else nothing.
local function downCause(character: Model, spot: Vector3): string?
	local by = character:GetAttribute("HurtBy")
	local at = character:GetAttribute("HurtAt")
	local recent = type(at) == "number" and workspace:GetServerTimeNow() - at <= settings.DownCauseSeconds
	if type(by) == "string" and recent then
		return by
	elseif spot.Y < workspace.FallenPartsDestroyHeight + settings.DownCauseFallMargin then
		return "You fell."
	end
	return nil
end

local function onDown(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local spot = if root then root.Position else character:GetPivot().Position
	player:SetAttribute("DownBy", downCause(character, spot))
	player:SetAttribute("DownUntil", workspace:GetServerTimeNow() + settings.RespawnDelay)
	local pile = Inventory.dropAll(player, spot)
	player:SetAttribute("DownAt", if pile then pile:GetPivot().Position else nil)
end

local function setUpCharacter(player: Player, character: Model)
	player:SetAttribute("DownUntil", nil)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.MaxHealth = settings.MaxHealth
	humanoid.Health = settings.MaxHealth
	humanoid.Died:Connect(function()
		onDown(player, character)
	end)
	for _, item in settings.StartingLoadout do
		Inventory.add(player, item.id, item.count)
	end
	-- Spawn grace: robots skip SpawnGrace players and the hidden ForceField blocks TakeDamage
	local shield = Instance.new("ForceField")
	shield.Name = "SpawnShield"
	shield.Visible = false
	shield.Parent = character
	player:SetAttribute("SpawnGrace", true)
	task.delay(settings.SpawnGraceSeconds, function()
		if player.Character == character then
			endSpawnGrace(player, character)
		end
	end)
	-- Every spawn starts with full mags and no reload in progress.
	local state = stateOf(player)
	cancelReload(player, state)
	for gunId in settings.Blasters do
		fillMag(player, state, gunId)
	end
	if not settings.HealthRegen then
		-- Roblox adds a "Health" regen script to every character; removing it turns regen off.
		local regen = character:WaitForChild("Health", 5)
		if regen and regen:IsA("Script") then
			regen:Destroy()
		end
	end
end

local function setUpPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		setUpCharacter(player, character)
	end)
	if player.Character then
		task.spawn(setUpCharacter, player, player.Character)
	end
end

-- Admin gear arrives loaded so testers can fire right away
function Combat.fillMag(player: Player, gunId: string)
	fillMag(player, stateOf(player), gunId)
end

-- Admin infinite ammo: every owned gun shows a full mag and never drains
function Combat.setInfiniteAmmo(player: Player, on: boolean)
	player:SetAttribute("InfiniteAmmo", on or nil)
	local state = stateOf(player)
	for gunId, gun in settings.Blasters do
		if Inventory.has(player, gunId) then
			gunState(state, gunId).mag = if on then gun.magSize else gunState(state, gunId).mag
			publishMag(player, state, gunId)
		end
	end
end

function Combat.Init()
	Players.RespawnTime = settings.RespawnDelay
	hitRemote = Net.event("GunHit")
	fxRemote = Net.unreliable("GunFx")
	whizRemote = Net.unreliable("GunWhiz")
	Net.event("GunFire").OnServerEvent:Connect(onFire)
	Net.event("GunReload").OnServerEvent:Connect(onReload)
	Players.PlayerAdded:Connect(setUpPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastKills[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
	viewmodels = Instance.new("Folder")
	viewmodels.Name = "Viewmodels"
	viewmodels.Parent = ReplicatedStorage
end

local function publishViewmodel(name: string)
	if viewmodels:FindFirstChild(name) or not ModelLibrary.uploaded(name) then
		return
	end
	local template = ModelLibrary.get(name)
	if template then
		template.Name = name
		template.Parent = viewmodels
	end
end

-- Uploaded models only load on the server, so put copies of every gun, the first-person arms and
-- the items they hold where clients can clone them. Loading yields, so it runs on its own thread.
function Combat.Start()
	task.spawn(function()
		for _, name in Config.Hands.Arms do
			publishViewmodel(name)
		end
		for _, items in { Config.Hotbar.Guns, Config.Hands.Items, Config.Hotbar.Held } do
			for _, item in items do
				if item.model then
					publishViewmodel(item.model)
				end
			end
		end
	end)
end

return Combat
