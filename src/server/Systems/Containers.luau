-- Storage: drawers, cabinets, fridges, chests and wardrobes hold items. Contents live here per model
-- and reset with the server; robots and going down never touch them. Opening one through Interact
-- shows its panel; clients ask to move stacks and the server checks they're close to an open one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Container = require(ReplicatedStorage.Shared.Logic.Container)
local InteractRules = require(ReplicatedStorage.Shared.Logic.Interact)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local Loot = require(ReplicatedStorage.Shared.Logic.Loot)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Logic.WarehouseGenRng)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local DayNight = require(script.Parent.DayNight)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Containers

type Stack = InventoryLogic.Stack
type Box = {
	rule: Container.Rule,
	title: string,
	stacks: { Stack },
	openKeys: { [string]: boolean },
	viewers: { [Player]: boolean },
	destroying: RBXScriptConnection,
	guarded: boolean,
}

local Containers = {}

local boxes: { [Model]: Box } = {}
local viewing: { [Player]: Model } = {}
local random = Random.new()
local stateRemote: RemoteEvent
local closedRemote: RemoteEvent

local function ruleOf(model: Model, kind: string): Container.Rule?
	-- The spawn locker is your saved stash (Saves), not a world container
	if model:GetAttribute("SaveLocker") then
		return nil
	end
	return Container.ruleFor(Settings.Kinds, model:GetAttribute("ModelName") :: string?, kind)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function distanceTo(model: Model, root: BasePart): number
	local box, size = model:GetBoundingBox()
	local point = box:PointToObjectSpace(root.Position)
	return InteractRules.distanceToBox(point.X, point.Y, point.Z, size.X / 2, size.Y / 2, size.Z / 2)
end

local function send(player: Player, model: Model, box: Box)
	stateRemote:FireClient(player, model, {
		title = box.title,
		slots = box.rule.slots,
		stacks = table.clone(box.stacks),
	})
end

local function broadcast(model: Model, box: Box)
	for player in box.viewers do
		send(player, model, box)
	end
end

local function unview(player: Player, tellClient: boolean)
	local model = viewing[player]
	if not model then
		return
	end
	viewing[player] = nil
	local box = boxes[model]
	if box then
		box.viewers[player] = nil
	end
	if tellClient and player.Parent then
		closedRemote:FireClient(player, model)
	end
end

-- The installation's stash crate, which the robots guard
local function isGuarded(model: Model): boolean
	local room = Warehouse.roomAt(model:GetPivot().Position)
	return room ~= nil
		and room.installation == true
		and model:GetAttribute("ModelName") == Config.Warehouse.InstallationStash
end

local function guardedLoot(rule: Container.Rule, rng: Rng.Rng): { Stack }
	local stacks = {}
	local rolls = Settings.InstallationStash.rolls
	for _ = 1, rng:int(rolls[1], rolls[2]) do
		local roll = Loot.roll(Config.Supplies.InstallationLoot, 1, rng)
		if roll then
			InventoryLogic.add(stacks, InventoryItems, roll.item, roll.count, rule.slots)
		end
	end
	return stacks
end

local function boxOf(model: Model, rule: Container.Rule): Box
	local existing = boxes[model]
	if existing then
		return existing
	end
	local depth = Warehouse.depth(model:GetPivot().Position)
	local rng = Rng.new(random:NextInteger(1, 2 ^ 31 - 1))
	local guarded = isGuarded(model)
	local box: Box
	box = {
		rule = rule,
		title = Settings.Titles[model:GetAttribute("ModelName")] or "STORAGE",
		stacks = if guarded
			then guardedLoot(rule, rng)
			else Container.startingLoot(rule, Config.Supplies.Loot, depth, rng, InventoryItems),
		guarded = guarded,
		openKeys = {},
		viewers = {},
		destroying = model.Destroying:Connect(function()
			for player in box.viewers do
				unview(player, true)
			end
			box.destroying:Disconnect()
			boxes[model] = nil
		end),
	}
	boxes[model] = box
	return box
end

local function view(player: Player, model: Model, box: Box)
	if viewing[player] ~= model then
		unview(player, true)
	end
	viewing[player] = model
	box.viewers[player] = true
	send(player, model, box)
end

local function onOpenChanged(player: Player?, model: Model, key: string, open: boolean)
	local rule = ruleOf(model, "open")
	if not rule then
		return
	end
	local box = if open then boxOf(model, rule) else boxes[model]
	if not box then
		return
	end
	box.openKeys[key] = if open then true else nil
	if open and player then
		view(player, model, box)
	elseif not Container.isOpen(box.openKeys) then
		for viewer in box.viewers do
			unview(viewer, true)
		end
	end
end

-- Pressing a container that's already open looks inside instead of shutting it on whoever's there.
local function lookInside(player: Player, model: Model, behaviour: any): boolean
	local box = boxes[model]
	if behaviour.kind ~= "open" or not ruleOf(model, "open") or not box then
		return false
	end
	if viewing[player] == model or not Container.isOpen(box.openKeys) then
		return false
	end
	view(player, model, box)
	return true
end

local function onMove(player: Player, model: any, direction: any, itemId: any, count: any)
	if typeof(model) ~= "Instance" or type(itemId) ~= "string" or not InventoryItems[itemId] then
		return
	end
	if player:GetAttribute("Cuffed") == true then
		return
	end
	local box = boxes[model]
	local root = rootOf(player)
	if not box or not model:IsDescendantOf(workspace) then
		return
	end
	local ok = Container.canMove({
		alive = root ~= nil,
		viewing = viewing[player] == model,
		open = Container.isOpen(box.openKeys),
		distance = if root then distanceTo(model, root) else math.huge,
		reach = Config.Interact.Reach + Settings.ReachSlack,
	})
	if not ok then
		return
	end
	if direction == "store" and not Settings.Blocked[itemId] then
		local wanted = Container.moveCount(count, Inventory.count(player, itemId))
		local removed = Inventory.remove(player, itemId, wanted)
		local added = InventoryLogic.add(box.stacks, InventoryItems, itemId, removed, box.rule.slots)
		if added < removed then
			Inventory.add(player, itemId, removed - added)
		end
	elseif direction == "take" then
		local wanted = Container.moveCount(count, InventoryLogic.count(box.stacks, itemId))
		local added = Inventory.add(player, itemId, wanted)
		InventoryLogic.remove(box.stacks, itemId, added)
		if added > 0 and box.guarded then
			Loudness.emit(model:GetPivot().Position, Settings.InstallationStash.takeLoudness, model)
		end
	else
		return
	end
	broadcast(model, box)
end

-- Closing the panel shuts the doors behind you once nobody else is looking. Hiders stay hidden.
local function onClose(player: Player, model: any)
	if typeof(model) ~= "Instance" or viewing[player] ~= model then
		return
	end
	unview(player, false)
	local box = boxes[model]
	if box and next(box.viewers) == nil and Interact.hidingSpot(player) ~= model then
		Interact.shut(model)
	end
end

local function checkViewers()
	for player, model in viewing do
		local root = rootOf(player)
		if
			not root
			or not model:IsDescendantOf(workspace)
			or distanceTo(model, root) > Config.Interact.Reach + Settings.ReachSlack
		then
			unview(player, true)
		end
	end
end

function Containers.Init()
	stateRemote = Net.event("ContainerState")
	closedRemote = Net.event("ContainerClosed")
	Net.event("ContainerMove").OnServerEvent:Connect(onMove)
	Net.event("ContainerClose").OnServerEvent:Connect(onClose)
	Interact.onOpenChanged(onOpenChanged)
	Interact.setUseFilter(lookInside)
	-- the guarded crate in every robot room fills back up each morning (left alone while someone
	-- has it open)
	DayNight.onPhaseChanged(function(phase)
		if phase ~= "Day" then
			return
		end
		for _, box in boxes do
			if box.guarded and next(box.viewers) == nil then
				box.stacks = guardedLoot(box.rule, Rng.new(random:NextInteger(1, 2 ^ 31 - 1)))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		unview(player, false)
	end)
end

function Containers.Start()
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= Settings.CheckEvery then
			since = 0
			checkViewers()
		end
	end)
end

return Containers
