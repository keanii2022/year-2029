-- Admin mode for testing in the live game. Admins (always in Studio; Config.Admin's ids and names
-- or the place's owner live) get an "Admin" attribute so their client builds the panel. Every
-- AdminCommand is checked here again, so nobody else can fire one. Replies go out on AdminStatus.
-- God is a hidden ForceField (blocks TakeDamage) plus a "God" attribute that robots and needs check.
-- Speed and fly are attributes the client's Movement and AdminPanel act on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local AdminAccess = require(ReplicatedStorage.Shared.Logic.AdminAccess)
local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local WarehouseSizes = require(ReplicatedStorage.Shared.Logic.WarehouseSizes)
local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(script.Parent.Combat)
local DayNight = require(script.Parent.DayNight)
local PaEvents = require(script.Parent.PaEvents)
local DevTeleport = require(script.Parent.DevTeleport)
local Inventory = require(script.Parent.Inventory)
local Robots = require(script.Parent.Robots)
local SizeServers = require(script.Parent.SizeServers)

local settings = Config.Admin
local blasters = Config.Guns.Blasters

local GOD_FIELD = "AdminGod"
local PHASE_NAMES = { Day = "lights on", Siren = "siren", Night = "lights out" }

local Admin = {}

local rules: AdminAccess.Rules = {
	userIds = settings.UserIds,
	userNames = settings.UserNames,
	resolvedIds = {},
	creatorId = game.CreatorId,
	creatorIsUser = game.CreatorType == Enum.CreatorType.User,
}
local speedIndex: { [Player]: number } = {}
local robotsFrozen = false
local statusRemote: RemoteEvent
local simCountRemote: RemoteEvent

local function isAdmin(player: Player): boolean
	return RunService:IsStudio() or AdminAccess.isAdmin(player.UserId, player.Name, rules)
end

local function refresh(player: Player)
	local admin = isAdmin(player)
	player:SetAttribute("Admin", if admin then true else nil)
	-- The size buttons' "Public lobby" toggle, on unless this admin turned it off
	if admin and player:GetAttribute("AdminPublicLobby") == nil then
		player:SetAttribute("AdminPublicLobby", true)
	end
end

local function resolveNames()
	for _, name in settings.UserNames do
		local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, name)
		if ok and type(userId) == "number" then
			table.insert(rules.resolvedIds, userId)
		end
	end
	for _, player in Players:GetPlayers() do
		refresh(player)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function itemName(id: string): string
	local item = InventoryItems[id]
	return if item then item.name else id
end

-- Gear -------------------------------------------------------------------------------------------

local function giveStack(player: Player, id: string, count: number?): number
	local item = InventoryItems[id]
	if not item then
		return 0
	end
	return Inventory.add(player, id, count or item.stackSize)
end

-- The gun (if not already carried) and a full stack of its ammo, so it can reload and fire
local function giveGun(player: Player, gunId: unknown): string
	local gun = if type(gunId) == "string" then blasters[gunId] else nil
	if not gun or not InventoryItems[gunId :: string] then
		return "Unknown gun"
	end
	local id = gunId :: string
	if not Inventory.has(player, id) and giveStack(player, id, 1) == 0 then
		return "Bag full"
	end
	giveStack(player, gun.ammo)
	Combat.fillMag(player, id)
	return `Gave {itemName(id)}`
end

local function gunIdsByRank(): { string }
	local ids = {}
	for id in blasters do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return blasters[a].rank < blasters[b].rank
	end)
	return ids
end

local function giveAllGuns(player: Player): string
	local given = 0
	for _, id in gunIdsByRank() do
		if Inventory.has(player, id) or giveStack(player, id, 1) > 0 then
			given += 1
		end
	end
	local ammo = {}
	for _, id in gunIdsByRank() do
		if Inventory.has(player, id) and not ammo[blasters[id].ammo] then
			ammo[blasters[id].ammo] = true
			giveStack(player, blasters[id].ammo)
		end
	end
	for _, id in gunIdsByRank() do
		if Inventory.has(player, id) then
			Combat.fillMag(player, id)
		end
	end
	local total = #gunIdsByRank()
	local bagSize = Config.Guns.BaseSlots
	return if given == total
		then "Gave every gun, the ones past your quick slots are in the bag"
		else `Gave {given} of {total} guns, bag full ({bagSize} stacks)`
end

-- A full stack of ammo for every gun carried
local function giveAmmo(player: Player): string
	local given = {}
	for id, gun in blasters do
		if Inventory.has(player, id) and not given[gun.ammo] then
			given[gun.ammo] = true
			giveStack(player, gun.ammo)
		end
		if Inventory.has(player, id) then
			Combat.fillMag(player, id)
		end
	end
	return if next(given) then "Ammo topped up" else "No guns to load"
end

local function giveItem(player: Player, itemId: unknown): string
	if type(itemId) ~= "string" or not InventoryItems[itemId] or blasters[itemId] then
		return "Unknown item"
	end
	local added = giveStack(player, itemId)
	return if added > 0 then `Gave {added} {itemName(itemId)}` else "Bag full"
end

local function giveFoodKit(player: Player): string
	local full = false
	for _, entry in settings.FoodKit do
		if giveStack(player, entry.id, entry.count) < entry.count then
			full = true
		end
	end
	return if full then "Gave what fit, bag full" else "Gave food kit"
end

-- Moves ------------------------------------------------------------------------------------------

local function applyGod(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local field = character:FindFirstChild(GOD_FIELD)
	if player:GetAttribute("God") == true and not field then
		local forceField = Instance.new("ForceField")
		forceField.Name = GOD_FIELD
		forceField.Visible = false
		forceField.Parent = character
	elseif player:GetAttribute("God") ~= true and field then
		field:Destroy()
	end
end

local function toggleGod(player: Player): string
	local on = player:GetAttribute("God") ~= true
	player:SetAttribute("God", on or nil)
	applyGod(player)
	return if on then "God mode on" else "God mode off"
end

local function cycleSpeed(player: Player): string
	local index = AdminAccess.nextIndex(speedIndex[player] or 1, #settings.SpeedLevels)
	speedIndex[player] = index
	local level = settings.SpeedLevels[index]
	player:SetAttribute("AdminSpeed", if level.multiplier == 1 then nil else level.multiplier)
	return `Speed: {level.name}`
end

local function toggleInfiniteAmmo(player: Player): string
	local on = player:GetAttribute("InfiniteAmmo") ~= true
	Combat.setInfiniteAmmo(player, on)
	return if on then "Infinite ammo on" else "Infinite ammo off"
end

local function toggleFly(player: Player): string
	local on = player:GetAttribute("Fly") ~= true
	player:SetAttribute("Fly", on or nil)
	return if on then "Fly on (walls too)" else "Fly off"
end

local function teleportToPlayer(player: Player, userId: unknown): string
	local target = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local character = player.Character
	local targetRoot = target and rootOf(target)
	if not target or not character or not rootOf(player) or not targetRoot then
		return "Can't reach them"
	end
	-- A few studs behind them, facing the same way
	character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 4))
	return `Went to {target.DisplayName}`
end

local function teleportToSpawn(player: Player): string
	local character = player.Character
	if not character or not rootOf(player) then
		return "No body to move"
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			character:PivotTo(descendant.CFrame + Vector3.new(0, 4, 0))
			return "Back at spawn"
		end
	end
	return "No spawn found"
end

-- Time and robots --------------------------------------------------------------------------------

local function skipTime(phase: unknown): string
	if type(phase) ~= "string" or not PHASE_NAMES[phase] then
		return "Unknown time"
	end
	if not DayNight.skipTo(phase) then
		return `Already {PHASE_NAMES[phase]}`
	end
	return `Skipped to {PHASE_NAMES[phase]}`
end

local function toggleClock(): string
	DayNight.setFrozen(not DayNight.isFrozen())
	return if DayNight.isFrozen() then "Clock frozen" else "Clock running"
end

local function holdRobots()
	while robotsFrozen do
		for _, robot in Robots.inRadius(Vector3.zero, math.huge) do
			Robots.disable(robot, settings.RobotFreezeSeconds)
		end
		task.wait(settings.RobotFreezeRefresh)
	end
end

local function setRobotsFrozen(frozen: boolean): string
	if frozen and not robotsFrozen then
		robotsFrozen = true
		task.spawn(holdRobots)
	elseif not frozen then
		robotsFrozen = false
	end
	ReplicatedStorage:SetAttribute("RobotsFrozen", robotsFrozen or nil)
	return if frozen then "Robots frozen" else "Robots waking up"
end

-- Sim lobby (SimPlayers is another system that may not be installed) ----------------------------

local function simPlayers(): any?
	local module = script.Parent:FindFirstChild("SimPlayers")
	if not module then
		return nil
	end
	local ok, loaded = pcall(require, module)
	return if ok then loaded else nil
end

local function withSim(run: (sim: any) -> string): string
	local sim = simPlayers()
	if not sim then
		return "Sim players not installed"
	end
	local ok, result = pcall(run, sim)
	return if ok then result else "Sim players failed"
end

local function simSpawn(player: Player, count: unknown): string
	local amount = AdminAccess.count(count, settings.SimMaxSpawn)
	if not amount then
		return "Pick 1 to " .. settings.SimMaxSpawn
	end
	return withSim(function(sim)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		sim.spawn(amount, root and root.Position)
		return `Sim players: {sim.count()}`
	end)
end

local function simMood(mood: unknown): string
	if type(mood) ~= "string" or not table.find(settings.SimMoods, mood) then
		return "Unknown mood"
	end
	return withSim(function(sim)
		sim.setMood(mood)
		return `Sim mood: {mood}`
	end)
end

local function simClear(): string
	return withSim(function(sim)
		sim.clear()
		return "Sim players cleared"
	end)
end

local function simFill(): string
	return withSim(function(sim)
		return `Lobby filled: {sim.fillLobby()} players`
	end)
end

-- Warehouse size servers --------------------------------------------------------------------------

local function openSizeServer(player: Player, sizeName: unknown): string
	if not WarehouseSizes.isSize(sizeName, Config.Warehouse) then
		return "Unknown size"
	end
	local admins = {}
	for _, other in Players:GetPlayers() do
		if isAdmin(other) then
			table.insert(admins, other)
		end
	end
	return SizeServers.open(sizeName :: string, player:GetAttribute("AdminPublicLobby") == true, admins)
end

local function togglePublicLobby(player: Player): string
	local on = player:GetAttribute("AdminPublicLobby") ~= true
	player:SetAttribute("AdminPublicLobby", on)
	return `Public lobby on size servers: {if on then "ON" else "OFF"}`
end

-- A size server asked for a public lobby: fill it once the warehouse is standing
local function fillIfAsked()
	if not SizeServers.choice().publicLobby then
		return
	end
	local root = workspace:WaitForChild("Warehouse")
	while root:GetAttribute("Built") ~= true do
		root:GetAttributeChangedSignal("Built"):Wait()
	end
	local result = simFill()
	for _, player in Players:GetPlayers() do
		if isAdmin(player) then
			statusRemote:FireClient(player, result)
		end
	end
end

local function sendSimCount(player: Player)
	local sim = simPlayers()
	local ok, count = false, nil
	if sim then
		ok, count = pcall(sim.count)
	end
	simCountRemote:FireClient(player, if ok and type(count) == "number" then count else nil)
end

local commands: { [string]: (player: Player, arg: unknown) -> string? } = {
	give_gun = giveGun,
	give_all_guns = giveAllGuns,
	give_ammo = giveAmmo,
	give_item = giveItem,
	give_food_kit = giveFoodKit,
	god = toggleGod,
	pa_event = function()
		local name = PaEvents.trigger()
		return if name then `PA event: {name}` else "No spot free for an event"
	end,
	infinite_ammo = toggleInfiniteAmmo,
	speed = cycleSpeed,
	fly = toggleFly,
	tp_player = teleportToPlayer,
	tp_next = function(player)
		DevTeleport.step(player, 1)
		return nil
	end,
	tp_previous = function(player)
		DevTeleport.step(player, -1)
		return nil
	end,
	tp_spawn = teleportToSpawn,
	time_skip = function(_, phase)
		return skipTime(phase)
	end,
	time_freeze = toggleClock,
	robots_freeze = function()
		return setRobotsFrozen(true)
	end,
	robots_wake = function()
		return setRobotsFrozen(false)
	end,
	sim_spawn = function(player, count)
		return simSpawn(player, count)
	end,
	sim_mood = function(_, mood)
		return simMood(mood)
	end,
	sim_clear = simClear,
	sim_fill = simFill,
	size_server = openSizeServer,
	size_lobby = togglePublicLobby,
	sim_count = function(player)
		sendSimCount(player)
		return nil
	end,
}

local function onCommand(player: Player, command: unknown, arg: unknown)
	if not isAdmin(player) or type(command) ~= "string" then
		return
	end
	local run = commands[command]
	if not run then
		return
	end
	local ok, result = pcall(run, player, arg)
	if not ok then
		warn(`[Admin] {command} failed: {result}`)
		result = "That didn't work"
	end
	if type(result) == "string" then
		statusRemote:FireClient(player, result)
	end
end

local function onPlayerAdded(player: Player)
	refresh(player)
	player.CharacterAdded:Connect(function()
		applyGod(player)
	end)
end

function Admin.Init()
	statusRemote = Net.event("AdminStatus")
	simCountRemote = Net.event("AdminSimCount")
end

function Admin.Start()
	Net.event("AdminCommand").OnServerEvent:Connect(onCommand)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		speedIndex[player] = nil
	end)
	if not RunService:IsStudio() then
		task.spawn(resolveNames)
	end
	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		if isAdmin(player) then
			statusRemote:FireClient(player, `Teleport failed: {message}`)
		end
	end)
	task.spawn(fillIfAsked)
end

return Admin
