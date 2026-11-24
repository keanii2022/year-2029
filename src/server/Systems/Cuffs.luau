-- Server side of handcuffs: checks every cuff, freezes the cuffed player, runs the timer and
-- mashing, lets the cuffer rob the bag, and lets anyone else hold a prompt to uncuff.
-- The cuffed player gets attributes "Cuffed" (true) and "CuffedUntil" (server time) for clients
-- and other systems to read.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CuffsLogic = require(ReplicatedStorage.Shared.Logic.Cuffs)
local Net = require(ReplicatedStorage.Shared.Net)
local Inventory = require(script.Parent.Inventory)

local settings = Config.Cuffs

type Cuffing = {
	hold: CuffsLogic.Hold,
	cuffer: Player?,
	root: BasePart,
	prompt: ProximityPrompt,
}

local Cuffs = {}

local cuffings: { [Player]: Cuffing } = {}
-- Keyed by UserId so leaving and rejoining doesn't reset the protection.
local lastCuffedAt: { [number]: number } = {}
local robRemote: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): CuffsLogic.Flat
	return { x = v.X, z = v.Z }
end

local function partsOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function sendRobList(cuffer: Player, target: Player)
	robRemote:FireClient(cuffer, target, Inventory.list(target))
end

local function release(target: Player)
	local cuffing = cuffings[target]
	if not cuffing then
		return
	end
	cuffings[target] = nil
	cuffing.prompt:Destroy()
	if cuffing.root.Parent then
		cuffing.root.Anchored = false
	end
	target:SetAttribute("Cuffed", nil)
	target:SetAttribute("CuffedUntil", nil)
	local cuffer = cuffing.cuffer
	if cuffer and cuffer.Parent then
		robRemote:FireClient(cuffer, nil, nil)
	end
end

local function buildUncuffPrompt(target: Player, root: BasePart): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Uncuff"
	prompt.ActionText = "Uncuff"
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = settings.UncuffHold
	prompt.MaxActivationDistance = settings.Range
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(helper)
		if helper ~= target then
			release(target)
		end
	end)
	prompt.Parent = root
	return prompt
end

local function onRequest(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player then
		return
	end
	local cufferRoot, cufferHumanoid = partsOf(player)
	local targetRoot, targetHumanoid = partsOf(target)
	if
		not cufferRoot
		or not cufferHumanoid
		or cufferHumanoid.Health <= 0
		or not targetRoot
		or not targetHumanoid
	then
		return
	end
	local last = lastCuffedAt[target.UserId]
	local ok = CuffsLogic.canCuff({
		cufferPosition = flat(cufferRoot.Position),
		targetPosition = flat(targetRoot.Position),
		targetFacing = flat(targetRoot.CFrame.LookVector),
		targetHealth = targetHumanoid.Health,
		targetMaxHealth = targetHumanoid.MaxHealth,
		targetAlive = targetHumanoid.Health > 0,
		targetCuffed = cuffings[target] ~= nil,
		cufferCuffed = cuffings[player] ~= nil,
		hasCuffs = Inventory.has(player, settings.ItemId),
		sinceTargetLastCuffed = if last then now() - last else nil,
	}, settings)
	-- Cuffs break after one use.
	if not ok or Inventory.remove(player, settings.ItemId, 1) < 1 then
		return
	end

	local start = now()
	lastCuffedAt[target.UserId] = start
	local hold = CuffsLogic.start(start, settings)
	targetRoot.Anchored = true
	target:SetAttribute("Cuffed", true)
	target:SetAttribute("CuffedUntil", hold.endsAt)
	cuffings[target] = {
		hold = hold,
		cuffer = player,
		root = targetRoot,
		prompt = buildUncuffPrompt(target, targetRoot),
	}
	sendRobList(player, target)
end

local function onMash(player: Player)
	local cuffing = cuffings[player]
	if cuffing and CuffsLogic.mash(cuffing.hold, now(), settings) then
		player:SetAttribute("CuffedUntil", cuffing.hold.endsAt)
	end
end

local function onTake(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return
	end
	for target, cuffing in cuffings do
		if cuffing.cuffer ~= player then
			continue
		end
		local root = partsOf(player)
		if not root or (root.Position - cuffing.root.Position).Magnitude > settings.RobRange then
			return
		end
		CuffsLogic.transfer(function(count)
			return Inventory.remove(target, itemId, count)
		end, function(count)
			return Inventory.add(player, itemId, count)
		end, function(count)
			Inventory.add(target, itemId, count)
		end, Inventory.count(target, itemId))
		sendRobList(player, target)
		return
	end
end

local function onHeartbeat()
	local time = now()
	for target, cuffing in cuffings do
		local _, humanoid = partsOf(target)
		if
			CuffsLogic.isOver(cuffing.hold, time)
			or not cuffing.root.Parent
			or not humanoid
			or humanoid.Health <= 0
		then
			release(target)
		end
	end
end

local function setUpPlayer(player: Player)
	player.CharacterRemoving:Connect(function()
		release(player)
	end)
	if settings.DebugGiveCuffs then
		player.CharacterAdded:Connect(function()
			Inventory.add(player, settings.ItemId, 1)
		end)
	end
end

function Cuffs.Init()
	if not Inventory.Items[settings.ItemId] then
		-- InventoryItems is frozen and Inventory refuses unknown ids, so cuffs only work once
		-- the item is added there.
		warn(`Cuffs: no "{settings.ItemId}" item in InventoryItems; cuffs can't be carried yet`)
		settings = table.clone(settings)
		settings.DebugGiveCuffs = false
	end
	robRemote = Net.event("CuffsRob")
	Net.event("CuffsRequest").OnServerEvent:Connect(onRequest)
	Net.event("CuffsMash").OnServerEvent:Connect(onMash)
	Net.event("CuffsTake").OnServerEvent:Connect(onTake)
	RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerAdded:Connect(setUpPlayer)
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		for _, cuffing in cuffings do
			if cuffing.cuffer == player then
				cuffing.cuffer = nil
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
end

return Cuffs
