-- Server side of guns: checks every shot, does the hit raycast, deals damage, and handles
-- going down (everything drops as a loot pile) and the spawn kit.
-- Only players take damage; anything else a shot hits just throws sparks and stops the shot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Inventory = require(script.Parent.Inventory)

local settings = Config.Guns

local Combat = {}

local lastShotAt: { [Player]: number } = {}
local hitRemote: RemoteEvent
local fxRemote: UnreliableRemoteEvent

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

	local gunId = CombatLogic.pickGun(settings.Blasters, function(id)
		return Inventory.has(player, id)
	end)
	local gun = gunId and settings.Blasters[gunId]
	local now = os.clock()
	local ok = CombatLogic.canFire({
		alive = humanoid.Health > 0,
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		hasGun = gun ~= nil,
		ammo = if gun then Inventory.count(player, gun.ammo) else 0,
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
	if hitPart then
		local target, targetHumanoid = playerFromPart(hitPart)
		if target and targetHumanoid and target ~= player and targetHumanoid.Health > 0 then
			targetHumanoid:TakeDamage(CombatLogic.damageAt(gun, (hitPosition - origin).Magnitude))
			hitPlayer = true
			hitRemote:FireClient(player, targetHumanoid.Health <= 0)
		end
	end
	fxRemote:FireAllClients(player, origin, hitPosition, hitNormal, hitPlayer)
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
	Net.event("GunFire").OnServerEvent:Connect(onFire)
	Players.PlayerAdded:Connect(setUpPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastShotAt[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
end

return Combat
