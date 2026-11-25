-- The server's copy of what every player carries, plus loot piles in the world.
-- Other systems go through this API; clients only get a read-only "InventoryChanged" snapshot.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local Net = require(ReplicatedStorage.Shared.Net)

type Stack = InventoryLogic.Stack

local settings = Config.Guns

local Inventory = {}
Inventory.Items = InventoryItems

local bags: { [Player]: { Stack } } = {}
local piles: { [Model]: { Stack } } = {}
local changedRemote: RemoteEvent
local pilesFolder: Folder

local function bagOf(player: Player): { Stack }
	local bag = bags[player]
	if not bag then
		bag = {}
		bags[player] = bag
	end
	return bag
end

local function sync(player: Player)
	if player.Parent then
		changedRemote:FireClient(player, InventoryLogic.totals(bagOf(player)))
	end
end

-- Adds up to count (default 1). Returns how many fit; the rest is refused.
function Inventory.add(player: Player, itemId: string, count: number?): number
	local added = InventoryLogic.add(bagOf(player), InventoryItems, itemId, count or 1, settings.BaseSlots)
	if added > 0 then
		sync(player)
	end
	return added
end

-- Removes up to count (default 1). Returns how many were removed.
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
	if not contents or not humanoid or humanoid.Health <= 0 then
		return
	end
	if InventoryLogic.moveAll(contents, bagOf(player), InventoryItems, settings.BaseSlots) > 0 then
		sync(player)
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
	prompt.RequiresLineOfSight = false
	prompt.Parent = bag
	prompt.Triggered:Connect(function(player)
		onPickup(pile, prompt, player)
	end)

	CollectionService:AddTag(pile, settings.LootPileTag)
	piles[pile] = contents
	pile.Parent = pilesFolder
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

function Inventory.Init()
	changedRemote = Net.event("InventoryChanged")
	pilesFolder = Instance.new("Folder")
	pilesFolder.Name = "LootPiles"
	pilesFolder.Parent = workspace

	-- Clients ask once at start so a snapshot sent before they were listening is never lost.
	Net.event("InventorySync").OnServerEvent:Connect(sync)
	Players.PlayerRemoving:Connect(function(player)
		bags[player] = nil
	end)
end

return Inventory
