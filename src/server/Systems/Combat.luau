-- Server side of guns: checks every shot, does the hit raycast, deals damage, and handles
-- going down (everything drops as a loot pile) and the spawn kit. Tracks each player's mag and
-- reload, published as the "Mag" and "Reloading" attributes for the client's HUD.
-- Only players take damage; anything else a shot hits just throws sparks and stops the shot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFeel = require(ReplicatedStorage.Shared.Logic.CombatFeel)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local CombatReload = require(ReplicatedStorage.Shared.Logic.CombatReload)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Inventory = require(script.Parent.Inventory)
local Scores = require(script.Parent.Scores)

local settings = Config.Guns

local Combat = {}

local lastShotAt: { [Player]: number } = {}
-- reloadId tells a finished reload's timer apart from a newer reload or a respawn.
type MagState = { mag: number, reloadStartedAt: number?, reloadId: number }
local mags: { [Player]: MagState } = {}
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

local function heldGun(player: Player): (CombatLogic.Gun?, string?)
	local gunId = CombatLogic.pickGun(settings.Blasters, function(id)
		return Inventory.has(player, id)
	end)
	return if gunId then settings.Blasters[gunId] else nil, gunId
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

local function magState(player: Player): MagState
	local state = mags[player]
	if not state then
		state = { mag = 0, reloadId = 0 }
		mags[player] = state
	end
	return state
end

local function publishMag(player: Player, state: MagState)
	player:SetAttribute("Mag", state.mag)
	player:SetAttribute("Reloading", if state.reloadStartedAt then true else nil)
end

local function finishReload(player: Player, state: MagState, gun: CombatLogic.Gun?)
	state.reloadStartedAt = nil
	if gun then
		state.mag = CombatReload.refill(gun.magSize, Inventory.count(player, gun.ammo))
	end
	publishMag(player, state)
end

-- A reload whose time is up counts as done right away, even if its timer hasn't fired yet.
local function settleReload(player: Player, state: MagState, gun: CombatLogic.Gun?, now: number)
	local startedAt = state.reloadStartedAt
	if
		startedAt
		and gun
		and CombatReload.isDone(startedAt, now, gun.reloadTime, settings.ReloadTimeSlack)
	then
		finishReload(player, state, gun)
	end
end

local function onReload(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local gun = heldGun(player)
	local state = magState(player)
	local now = os.clock()
	settleReload(player, state, gun, now)
	local ok = CombatReload.canReload({
		alive = humanoid ~= nil and humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hasGun = gun ~= nil,
		reloading = state.reloadStartedAt ~= nil,
		mag = state.mag,
		magSize = if gun then gun.magSize else 0,
		bag = if gun then Inventory.count(player, gun.ammo) else 0,
	})
	if not ok or not gun then
		return
	end
	state.reloadId += 1
	local reloadId = state.reloadId
	state.reloadStartedAt = now
	publishMag(player, state)
	task.delay(gun.reloadTime, function()
		if mags[player] == state and state.reloadId == reloadId and state.reloadStartedAt then
			finishReload(player, state, heldGun(player))
		end
	end)
end

local function onFire(player: Player, origin: any, direction: any)
	if not isFiniteVector(origin) or not isFiniteVector(direction) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not character or not humanoid or not head then
		return
	end

	local gun, gunId = heldGun(player)
	local now = os.clock()
	local state = magState(player)
	settleReload(player, state, gun, now)
	local mag = if gun then CombatReload.loaded(state.mag, Inventory.count(player, gun.ammo)) else 0
	local ok = CombatLogic.canFire({
		alive = humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		cuffed = player:GetAttribute("Cuffed") == true,
		hasGun = gun ~= nil,
		reloading = state.reloadStartedAt ~= nil,
		ammo = mag,
		sinceLastShot = now - (lastShotAt[player] or 0),
		minInterval = if gun then gun.fireInterval * settings.FireIntervalSlack else 0,
	})
	if not ok or not gun then
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

	lastShotAt[player] = now
	Inventory.remove(player, gun.ammo, 1)
	state.mag = mag - 1
	publishMag(player, state)

	local params = excludeParams(character)
	local aim = direction.Unit
	local result = workspace:Raycast(origin, aim * gun.range, params)
	local hitPosition = if result then result.Position else origin + aim * gun.range
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

	local hitPlayer = false
	local hitTarget: Player? = nil
	if hitPart then
		local target, targetHumanoid = playerFromPart(hitPart)
		if target and targetHumanoid and target ~= player and targetHumanoid.Health > 0 then
			targetHumanoid:TakeDamage(CombatLogic.damageAt(gun, (hitPosition - origin).Magnitude))
			hitPlayer = true
			hitTarget = target
			local downed = targetHumanoid.Health <= 0
			if downed then
				Scores.add(player, "PlayerKills", 1)
			end
			hitRemote:FireClient(player, downed)
		end
	end
	fxRemote:FireAllClients(player, origin, hitPosition, hitNormal, hitPlayer, gunId)
	sendWhizzes(player, hitTarget, origin, hitPosition)
end

local function onDown(player: Player, character: Model)
	player:SetAttribute("DownUntil", workspace:GetServerTimeNow() + settings.RespawnDelay)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local spot = if root then root.Position else character:GetPivot().Position
	Inventory.dropAll(player, spot)
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
	-- Every spawn starts with a full mag and no reload in progress.
	local state = magState(player)
	state.reloadId += 1
	finishReload(player, state, heldGun(player))
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

function Combat.Init()
	Players.RespawnTime = settings.RespawnDelay
	hitRemote = Net.event("GunHit")
	fxRemote = Net.unreliable("GunFx")
	whizRemote = Net.unreliable("GunWhiz")
	Net.event("GunFire").OnServerEvent:Connect(onFire)
	Net.event("GunReload").OnServerEvent:Connect(onReload)
	Players.PlayerAdded:Connect(setUpPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastShotAt[player] = nil
		mags[player] = nil
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

-- Uploaded models only load on the server, so put copies of the held blaster, the first-person
-- arms and the items they hold where clients can clone them. Loading yields, so it runs on its
-- own thread.
function Combat.Start()
	task.spawn(function()
		publishViewmodel("viewmodel_blaster")
		for _, name in Config.Hands.Arms do
			publishViewmodel(name)
		end
		for _, items in { Config.Hands.Items, Config.Hotbar.Held, Config.Hotbar.Guns } do
			for _, item in items do
				if item.model then
					publishViewmodel(item.model)
				end
			end
		end
	end)
end

return Combat
