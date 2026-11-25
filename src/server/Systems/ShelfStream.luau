-- Streams the real props on the racks: only bays near a player carry their stock, so the shelves
-- look full around you without the map holding tens of thousands of props. Warehouse registers
-- each bay as it builds it; a bay's stock is planned from its seed, so it comes back the same.
-- A prop a player picks up is theirs from then on: it stays where they leave it and its bay won't
-- bring it back.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ShelfStock = require(ReplicatedStorage.Shared.Logic.ShelfStock)

local ShelfStream = {}

local settings = Config.Warehouse

type Bay = {
	floor: CFrame, -- the bay's pivot: floor centre, front along +z
	slots: { ShelfStock.Slot },
	seed: number,
	parent: Instance,
	plan: { ShelfStock.Placement }?,
	live: { [number]: Model }?,
	taken: { [number]: boolean },
}

local bays: { Bay } = {}
local points: { ShelfStock.Point } = {}
local budget = 0
local spawned = 0

local function sizeOf(name: string): { number }?
	local entry = ModelLibrary.entry(name)
	return entry and entry.size
end

local function planOf(bay: Bay): { ShelfStock.Placement }
	if not bay.plan then
		bay.plan = ShelfStock.planBay(bay.seed, bay.slots, settings, sizeOf)
	end
	return bay.plan :: { ShelfStock.Placement }
end

local function costOf(index: number): number
	local bay = bays[index]
	local cost = 0
	for i in planOf(bay) do
		if not bay.taken[i] then
			cost += 1
		end
	end
	return cost
end

local function pace()
	spawned += 1
	if spawned % settings.ShelfSpawnPerFrame == 0 then
		task.wait()
	end
end

-- Half the world-space height of a turned box
local function halfHeight(box: CFrame, size: Vector3): number
	return (
		math.abs(box.RightVector.Y) * size.X
		+ math.abs(box.UpVector.Y) * size.Y
		+ math.abs(box.LookVector.Y) * size.Z
	) / 2
end

local function keep(bay: Bay, index: number)
	bay.taken[index] = true
	if bay.live then
		bay.live[index] = nil
	end
end

local function spawnProp(bay: Bay, index: number, spot: ShelfStock.Placement): Model?
	local model = ModelLibrary.get(spot.name)
	if not model then
		return nil
	end
	local turn = CFrame.Angles(0, math.rad(spot.turn), 0)
	if spot.tipped then
		turn *= CFrame.Angles(0, 0, math.pi / 2)
	end
	local at = bay.floor * CFrame.new(spot.x, spot.y, spot.z)
	model:PivotTo(at * turn)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - halfHeight(box, size)
	model:PivotTo(model:GetPivot() + Vector3.new(0, at.Position.Y - bottom, 0))
	CollectionService:AddTag(model, Config.Grab.Tag)
	model:GetAttributeChangedSignal("CarriedBy"):Once(function()
		keep(bay, index)
	end)
	-- Broken or cleared by something else: gone for good, not respawned
	model.Destroying:Once(function()
		if bay.live and bay.live[index] == model then
			keep(bay, index)
		end
	end)
	model.Parent = bay.parent
	return model
end

local function fill(bay: Bay)
	local live = {}
	bay.live = live
	for index, spot in planOf(bay) do
		if not bay.taken[index] then
			live[index] = spawnProp(bay, index, spot)
			pace()
		end
	end
end

local function empty(bay: Bay)
	local live = bay.live
	bay.live = nil
	for _, model in live or {} do
		model:Destroy()
	end
end

local function playerPoints(): { ShelfStock.Point }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(list, { x = root.Position.X, z = root.Position.Z })
		end
	end
	return list
end

local function update()
	local live = {}
	for index, bay in bays do
		live[index] = bay.live ~= nil
	end
	local wanted = ShelfStock.wanted(
		points,
		live,
		playerPoints(),
		settings.ShelfStreamRadius,
		settings.ShelfStreamKeep,
		budget,
		costOf
	)
	for index, bay in bays do
		if bay.live and not wanted[index] then
			empty(bay)
		end
	end
	for index in wanted do
		local bay = bays[index]
		if not bay.live then
			fill(bay)
		end
	end
end

-- floor: the bay's pivot CFrame. parent: where its props go (kept out of the chunk folders so the
-- night rearranging leaves untouched stock alone).
function ShelfStream.addBay(floor: CFrame, slots: { ShelfStock.Slot }, seed: number, parent: Instance)
	table.insert(bays, { floor = floor, slots = slots, seed = seed, parent = parent, taken = {} })
	table.insert(points, { x = floor.Position.X, z = floor.Position.Z })
end

-- Live props allowed across the map, set by Warehouse once it knows the map size
function ShelfStream.setBudget(count: number)
	budget = count
end

function ShelfStream.Start()
	task.spawn(function()
		while true do
			update()
			task.wait(settings.ShelfStreamEvery)
		end
	end)
end

return ShelfStream
