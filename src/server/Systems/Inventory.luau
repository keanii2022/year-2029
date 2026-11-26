-- The server's copy of what every player carries, plus loot piles in the world.
-- Other systems go through this API; clients only get a read-only "InventoryChanged" snapshot.
-- Also owns each player's quick slots (Logic/QuickSlots): which bag items sit on the hotbar.
-- They live for the session, so a respawn puts things you pick back up into their old slots.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local Net = require(ReplicatedStorage.Shared.Net)
local QuickSlots = require(ReplicatedStorage.Shared.Logic.QuickSlots)

type Stack = InventoryLogic.Stack

local settings = Config.Guns

local Inventory = {}
Inventory.Items = InventoryItems

local bags: { [Player]: { Stack } } = {}
local quicks: { [Player]: QuickSlots.Quick } = {}
local addedListeners: { (Player, string) -> () } = {}
local lastDrop: { [Player]: number } = {}
local piles: { [Model]: { Stack } } = {}
local changedRemote: RemoteEvent
local quickRemote: RemoteEvent
local pilesFolder: Folder

local function bagOf(player: Player): { Stack }
	local bag = bags[player]
	if not bag then
		bag = {}
		bags[player] = bag
	end
	return bag
end

local function quickOf(player: Player): QuickSlots.Quick
	local quick = quicks[player]
	if not quick then
		quick = QuickSlots.new(Config.Hotbar.QuickSlots)
		quicks[player] = quick
	end
	return quick
end

local function groupOf(itemId: string): string?
	return QuickSlots.groupOf(itemId, Config.Hotbar.Slots, Config.Supplies.Uses, settings.Blasters)
end

local function sync(player: Player)
	if player.Parent then
		changedRemote:FireClient(player, InventoryLogic.totals(bagOf(player)))
	end
end

-- inBag: an item that just went to the bag because every quick slot was taken (the client toasts it)
local function syncQuick(player: Player, inBag: string?)
	if player.Parent then
		quickRemote:FireClient(player, quickOf(player), inBag)
	end
end

-- Puts newly carried items into a free quick slot; anything that can't fit there gets toasted.
local function placeQuick(player: Player, itemIds: { string })
	local quick = quickOf(player)
	local carried =
		QuickSlots.carried(bagOf(player), Config.Hotbar.Slots, Config.Supplies.Uses, settings.Blasters)
	local before = table.concat(quick, "|")
	local inBag: string? = nil
	for _, itemId in itemIds do
		local group = groupOf(itemId)
		if group and not QuickSlots.autoAssign(quick, group, carried) then
			inBag = itemId
		end
	end
	if inBag or table.concat(quick, "|") ~= before then
		syncQuick(player, inBag)
	end
end

-- Adds up to count (default 1). Returns how many fit; the rest is refused.
function Inventory.add(player: Player, itemId: string, count: number?): number
	local added = InventoryLogic.add(bagOf(player), InventoryItems, itemId, count or 1, settings.BaseSlots)
	if added > 0 then
		sync(player)
		placeQuick(player, { itemId })
		for _, listener in addedListeners do
			task.spawn(listener, player, itemId)
		end
	end
	return added
end

-- Called with (player, itemId) whenever something lands in a bag (starting kit included)
function Inventory.onAdded(listener: (Player, string) -> ())
	table.insert(addedListeners, listener)
end

-- Removes up to count (default 1). Returns how many were removed.
-- Sends the player their bag again (a refused shot leaves the client a round short otherwise)
function Inventory.resend(player: Player)
	sync(player)
end

function Inventory.remove(player: Player, itemId: string, count: number?): number
	local removed = InventoryLogic.remove(bagOf(player), itemId, count or 1)
	if removed > 0 then
		sync(player)
	end
	return removed
end

function Inventory.count(player: Player, itemId: string): number
	return InventoryLogic.count(bagOf(player), itemId)
end

function Inventory.has(player: Player, itemId: string, count: number?): boolean
	return Inventory.count(player, itemId) >= (count or 1)
end

-- One { id, count } per item, safe to change.
function Inventory.list(player: Player): { Stack }
	return InventoryLogic.totals(bagOf(player))
end

function Inventory.bestItem(player: Player): string?
	return InventoryLogic.bestItem(bagOf(player), InventoryItems)
end

local function pileSummary(contents: { Stack }): string
	local names = {}
	for _, entry in contents do
		local name = InventoryItems[entry.id].name
		table.insert(names, if entry.count > 1 then `{name} x{entry.count}` else name)
	end
	return table.concat(names, ", ")
end

local function onPickup(pile: Model, prompt: ProximityPrompt, player: Player)
	local contents = piles[pile]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not contents or not humanoid or humanoid.Health <= 0 or player:GetAttribute("Cuffed") == true then
		return
	end
	local offered = {}
	for _, entry in contents do
		table.insert(offered, entry.id)
	end
	if InventoryLogic.moveAll(contents, bagOf(player), InventoryItems, settings.BaseSlots) > 0 then
		sync(player)
		local taken = {}
		for _, itemId in offered do
			if InventoryLogic.count(bagOf(player), itemId) > 0 then
				table.insert(taken, itemId)
			end
		end
		placeQuick(player, taken)
	end
	if #contents == 0 then
		piles[pile] = nil
		pile:Destroy()
	else
		prompt.ObjectText = pileSummary(contents)
	end
end

local function groundBelow(position: Vector3, ignore: Instance?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { ignore, pilesFolder } else { pilesFolder }
	local hit = workspace:Raycast(position, Vector3.new(0, -20, 0), params)
	return if hit then hit.Position else position
end

local function buildPile(position: Vector3, contents: { Stack }): Model
	local pile = Instance.new("Model")
	pile.Name = "LootPile"

	local bag = Instance.new("Part")
	bag.Name = "Bag"
	bag.Anchored = true
	bag.CanCollide = false
	bag.CanQuery = false
	bag.CanTouch = false
	bag.Size = Vector3.new(2.2, 0.9, 1.6)
	bag.CFrame = CFrame.new(position + Vector3.new(0, bag.Size.Y / 2, 0))
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	bag.Color = Color3.fromRGB(38, 36, 34)
	bag.Material = Enum.Material.Fabric
	bag.Parent = pile
	pile.PrimaryPart = bag

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = pileSummary(contents)
	prompt.HoldDuration = settings.LootPickupHold
	prompt.MaxActivationDistance = settings.LootPickupRange
	prompt.RequiresLineOfSight = true -- no looting through a wall
	prompt.Parent = bag
	prompt.Triggered:Connect(function(player)
		onPickup(pile, prompt, player)
	end)

	CollectionService:AddTag(pile, settings.LootPileTag)
	piles[pile] = contents
	pile.Parent = pilesFolder
	task.delay(settings.LootPileLifetime, function()
		piles[pile] = nil
		pile:Destroy()
	end)
	return pile
end

-- Empties the player's bag into a loot pile on the ground under position. Nil if they had nothing.
function Inventory.dropAll(player: Player, position: Vector3): Model?
	local contents = InventoryLogic.takeAll(bagOf(player))
	if #contents == 0 then
		return nil
	end
	sync(player)
	return buildPile(groundBelow(position, player.Character), contents)
end

-- A loot pile anyone can take from, e.g. salvage spilled by a knocked-down robot
function Inventory.dropPile(position: Vector3, contents: { Stack }): Model?
	if #contents == 0 then
		return nil
	end
	return buildPile(groundBelow(position, nil), contents)
end

-- Throws every one of an item out of the bag onto the floor in front of the player.
function Inventory.drop(player: Player, itemId: string): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local count = InventoryLogic.count(bagOf(player), itemId)
	if not root or not humanoid or humanoid.Health <= 0 or count <= 0 then
		return nil
	end
	InventoryLogic.remove(bagOf(player), itemId, count)
	sync(player)
	local spot = root.Position + root.CFrame.LookVector * 3
	return buildPile(groundBelow(spot, character), { { id = itemId, count = count } })
end

-- The bag panel's requests: "put" an item in quick slot n, "clear" slot n, "drop" an item.
local function onQuickRequest(player: Player, action: any, itemId: any, index: any)
	local validIndex = type(index) == "number" and index % 1 == 0
	local validItem = type(itemId) == "string" and InventoryItems[itemId] ~= nil
	local quick = quickOf(player)
	if action == "put" and validItem and validIndex and Inventory.has(player, itemId) then
		local group = groupOf(itemId)
		if group and QuickSlots.put(quick, index, group) then
			syncQuick(player)
		end
	elseif action == "clear" and validIndex then
		if QuickSlots.clear(quick, index) then
			syncQuick(player)
		end
	elseif action == "drop" and validItem and player:GetAttribute("Cuffed") ~= true then
		local now = os.clock()
		if now - (lastDrop[player] or 0) >= settings.DropCooldown then
			lastDrop[player] = now
			Inventory.drop(player, itemId)
		end
	end
end

function Inventory.Init()
	changedRemote = Net.event("InventoryChanged")
	quickRemote = Net.event("QuickSlotsChanged")
	Net.event("QuickSlotRequest").OnServerEvent:Connect(onQuickRequest)
	pilesFolder = Instance.new("Folder")
	pilesFolder.Name = "LootPiles"
	pilesFolder.Parent = workspace

	-- Clients ask once at start so a snapshot sent before they were listening is never lost.
	Net.event("InventorySync").OnServerEvent:Connect(function(player)
		sync(player)
		syncQuick(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- leaving mid-fight or while cuffed still leaves the loot behind
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			Inventory.dropAll(player, root.Position)
		end
		bags[player] = nil
		quicks[player] = nil
		lastDrop[player] = nil
	end)
end

return Inventory
