-- Size servers: the warehouse is built once per server, so trying another size means a fresh one.
-- An admin picks a size, open() reserves a server, leaves the choice in a MemoryStore hash map
-- under its private server id and teleports every admin there. That server's choice() reads it
-- back before Warehouse builds. Ordinary servers (and anything that goes wrong) get DefaultSize;
-- Studio gets Config.Warehouse.StudioSize.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local WarehouseSizes = require(ReplicatedStorage.Shared.Logic.WarehouseSizes)

local settings = Config.Warehouse
local rules = settings.SizeServer

local SizeServers = {}

local chosen: WarehouseSizes.Choice? = nil
local resolving = false
local resolved = Instance.new("BindableEvent")

local function isSizeServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- Gives up after ReadTimeout seconds; a late answer is simply ignored
local function readStored(key: string): unknown
	local value, done = nil, false
	task.spawn(function()
		local map = MemoryStoreService:GetHashMap(rules.MapName)
		while not done do
			local ok, result = pcall(map.GetAsync, map, key)
			if ok then
				value, done = result, true
			else
				warn(`[SizeServers] read failed: {result}`)
				task.wait(0.5)
			end
		end
	end)
	local deadline = os.clock() + rules.ReadTimeout
	while not done and os.clock() < deadline do
		task.wait(0.1)
	end
	done = true
	return value
end

local function resolve(): WarehouseSizes.Choice
	if RunService:IsStudio() then
		return WarehouseSizes.parseChoice({ size = settings.StudioSize }, settings)
	end
	if isSizeServer() then
		return WarehouseSizes.parseChoice(readStored(game.PrivateServerId), settings)
	end
	return WarehouseSizes.parseChoice(nil, settings)
end

-- This server's size and lobby choice. The first call may yield (up to ReadTimeout); later calls don't.
function SizeServers.choice(): WarehouseSizes.Choice
	if chosen then
		return chosen
	end
	if resolving then
		resolved.Event:Wait()
		return chosen :: WarehouseSizes.Choice
	end
	resolving = true
	local choice = resolve()
	chosen = choice
	ReplicatedStorage:SetAttribute("WarehouseSize", choice.size)
	resolved:Fire()
	return choice
end

-- Reserves a server for sizeName and sends players there. Returns a status line for AdminStatus.
function SizeServers.open(sizeName: string, publicLobby: boolean, players: { Player }): string
	if RunService:IsStudio() then
		return "Only works in the live game (Studio: set Config.Warehouse.StudioSize)"
	end
	local reserved, code, serverId = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not reserved then
		warn(`[SizeServers] reserve failed: {code}`)
		return "Couldn't reserve a server, try again"
	end
	local map = MemoryStoreService:GetHashMap(rules.MapName)
	local stored, err =
		pcall(map.SetAsync, map, serverId, { size = sizeName, publicLobby = publicLobby }, rules.Expiry)
	if not stored then
		warn(`[SizeServers] store failed: {err}`)
		return "Couldn't save the size, try again"
	end
	local sent, sendErr =
		pcall(TeleportService.TeleportToPrivateServer, TeleportService, game.PlaceId, code, players)
	if not sent then
		warn(`[SizeServers] teleport failed: {sendErr}`)
		return "Teleport failed, try again"
	end
	return `Heading to a {string.lower(sizeName)} warehouse...`
end

return SizeServers
