-- Studio playtests and admins only: T jumps you to the next installation (nearest first, then round
-- the map), Shift+T back one. Lands just outside the hall's doorway, facing in. The admin panel's
-- next / previous installation buttons use DevTeleport.step too.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Warehouse = require(script.Parent.Warehouse)

local DevTeleport = {}

local tours: { [Player]: { order: { any }, index: number } } = {}

-- Spot just outside a hall doorway and the way in
local function doorway(hall: any): (Vector3, Vector3)
	local door = hall.doors and hall.doors[1]
	if not door then
		return Warehouse.toWorld((hall.x0 + hall.x1) / 2, hall.z1 + 6), Vector3.new(0, 0, -1)
	end
	local out = 6
	if door.side == "north" then
		return Warehouse.toWorld(hall.x0 + door.at, hall.z0 - out), Vector3.new(0, 0, 1)
	elseif door.side == "south" then
		return Warehouse.toWorld(hall.x0 + door.at, hall.z1 + out), Vector3.new(0, 0, -1)
	elseif door.side == "west" then
		return Warehouse.toWorld(hall.x0 - out, hall.z0 + door.at), Vector3.new(1, 0, 0)
	end
	return Warehouse.toWorld(hall.x1 + out, hall.z0 + door.at), Vector3.new(-1, 0, 0)
end

local function tourFor(player: Player, from: Vector3)
	local tour = tours[player]
	if tour then
		return tour
	end
	local order = table.clone(Warehouse.layout().pockets)
	table.sort(order, function(a, b)
		local pa = Warehouse.toWorld((a.x0 + a.x1) / 2, (a.z0 + a.z1) / 2)
		local pb = Warehouse.toWorld((b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2)
		return (pa - from).Magnitude < (pb - from).Magnitude
	end)
	tour = { order = order, index = 0 }
	tours[player] = tour
	return tour
end

-- Moves player one installation along their tour (step 1 or -1). The caller checks who may.
function DevTeleport.step(player: Player, step: unknown)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (step ~= 1 and step ~= -1) then
		return
	end
	local tour = tourFor(player, root.Position)
	local count = #tour.order
	if count == 0 then
		return
	end
	tour.index = (tour.index + (step :: number) - 1) % count + 1
	local hall = tour.order[tour.index]
	local spot, facing = doorway(hall)
	character:PivotTo(CFrame.lookAt(spot + Vector3.new(0, 3.5, 0), spot + Vector3.new(0, 3.5, 0) + facing))
	Net.event("DevTeleported"):FireClient(player, hall.kind, tour.index, count)
end

local function onRequest(player: Player, step: unknown)
	-- Admin is a server-set attribute; a client can't set it for the server
	if RunService:IsStudio() or player:GetAttribute("Admin") == true then
		DevTeleport.step(player, step)
	end
end

function DevTeleport.Start()
	Net.event("DevTeleported")
	Net.event("DevTeleport").OnServerEvent:Connect(onRequest)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		tours[player] = nil
	end)
end

return DevTeleport
