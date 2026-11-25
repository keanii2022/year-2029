-- The store rearranges itself overnight. While it's dark, robots "restock" somewhere far off: now and
-- then a drag or scrape plays from a spot well away from a player. At dawn a share of the loose junk
-- boxes, furniture and shopping carts nobody placed has moved to new clear spots, and a few hanging
-- signs swap texts. Forts, carried things, lockers, containers, hiding spots, installations and
-- anything near a player stay put. Moves go out in small batches so dawn never hitches.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InteractKinds = require(ReplicatedStorage.Shared.Logic.InteractKinds)
local LifeSpots = require(ReplicatedStorage.Shared.Logic.LifeSpots)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Rules = require(ReplicatedStorage.Shared.Logic.Rearrange)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Rearrange
local Origin = Config.Warehouse.Origin
local AISLE_SIGNS = { aisle_sign_hanging = true, aisle_sign = true }

type Sign = { position: Vector3, labels: { TextLabel } }
type Move = { instance: Instance, item: Rules.Item, spot: Rules.Point }

local Rearrange = {}

local random = Random.new()
local cartSpots: { Rules.Point } = {}
local carts: { Model } = {}
local deptSigns: { Sign } = {}
local aisleSigns: { Sign } = {}
local scanned = false
local busy = false
local soundHolder: Model

local function roll(): number
	return random:NextNumber()
end

local function warehouseRoot(): Instance?
	local root = workspace:FindFirstChild("Warehouse")
	return if root and root:GetAttribute("Built") then root else nil
end

local function inChunk(instance: Instance, root: Instance): boolean
	local parent = instance.Parent
	return parent ~= nil and parent.Parent == root and parent.Name:sub(1, 6) == "Chunk_"
end

local function flat(position: Vector3): Rules.Point
	return { x = position.X - Origin.X, z = position.Z - Origin.Z }
end

local function playerSpots(): { Rules.Point }
	local spots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(spots, flat(root.Position))
		end
	end
	return spots
end

local function isClear(x: number, z: number): boolean
	local layout = Warehouse.layout()
	return WarehouseGen.isClear(layout, Config.Warehouse, x, z, Settings.Clearance)
		and WarehouseGen.pocketAt(layout, x, z) == nil
end

-- A player's client simulates unanchored parts it owns; moving those from here would fight it.
local function serverOwned(instance: Instance): boolean
	local parts = if instance:IsA("BasePart") then { instance } else instance:GetDescendants()
	for _, part in parts do
		if part:IsA("BasePart") and not part.Anchored then
			local ok, owner = pcall(part.GetNetworkOwner, part)
			if not ok or owner ~= nil then
				return false
			end
		end
	end
	return true
end

local function stays(model: Model): boolean
	local name = model:GetAttribute("ModelName")
	if model:GetAttribute("SaveLocker") or (name and Config.Containers.Kinds[name]) then
		return true
	end
	local behaviour = name and InteractKinds.get(name)
	return behaviour ~= nil and behaviour.kind == "hide"
end

local function itemFor(instance: Instance, kind: string): Rules.Item
	local position = (instance :: any):GetPivot().Position
	local spot = flat(position)
	local item: Rules.Item = {
		x = spot.x,
		z = spot.z,
		kind = kind,
		placed = instance:GetAttribute("PlacedBy") ~= nil,
		carried = instance:GetAttribute("CarriedBy") ~= nil,
		fixed = Warehouse.pocketAt(position) ~= nil
			or (instance:IsA("Model") and stays(instance))
			or not serverOwned(instance),
	}
	if kind == "junk" then
		local part = instance :: BasePart
		item.y = position.Y - Origin.Y
		item.half = math.max(part.Size.X, part.Size.Z) / 2
	end
	return item
end

local function signFor(instance: Instance): Sign?
	local labels = {}
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("TextLabel") then
			table.insert(labels, descendant)
		end
	end
	if #labels == 0 then
		return nil
	end
	return { position = (instance :: any):GetPivot().Position, labels = labels }
end

-- Carts and signs never come and go, so one pass over the chunk folders finds them for good.
local function scanOnce(root: Instance)
	if scanned then
		return
	end
	scanned = true
	local cartName = Config.Life.CartModel
	local seen = 0
	for _, chunk in root:GetChildren() do
		if chunk.Name:sub(1, 6) == "Chunk_" then
			for _, child in chunk:GetChildren() do
				if child:IsA("Model") then
					local name = child:GetAttribute("ModelName")
					if name == cartName then
						table.insert(carts, child)
					elseif name and AISLE_SIGNS[name] then
						local sign = signFor(child)
						if sign then
							table.insert(aisleSigns, sign)
						end
					end
				elseif child.Name == "DeptSign" and child:IsA("BasePart") then
					local sign = signFor(child)
					if sign then
						table.insert(deptSigns, sign)
					end
				end
				seen += 1
				if seen % Settings.ScanYieldEvery == 0 then
					task.wait()
				end
			end
		end
	end
	for _, spot in LifeSpots.fromShelves(Warehouse.layout().shelves, Config.Life) do
		if spot.kind == "aisle" then
			table.insert(cartSpots, { x = spot.x, z = spot.z })
		end
	end
end

local function collect(root: Instance): ({ Instance }, { Rules.Item })
	local instances, items = {}, {}
	local cartName = Config.Life.CartModel
	for _, tagged in CollectionService:GetTagged(Config.Grab.Tag) do
		if inChunk(tagged, root) then
			if tagged:IsA("BasePart") and tagged.Name == "JunkBox" then
				table.insert(instances, tagged)
				table.insert(items, itemFor(tagged, "junk"))
			elseif tagged:IsA("Model") and tagged:GetAttribute("ModelName") ~= cartName then
				table.insert(instances, tagged)
				table.insert(items, itemFor(tagged, "furniture"))
			end
		end
	end
	for _, cart in carts do
		if inChunk(cart, root) then
			table.insert(instances, cart)
			table.insert(items, itemFor(cart, "cart"))
		end
	end
	return instances, items
end

local function plan(instances: { Instance }, items: { Rules.Item }): { Move }
	Rules.markCovered(items, Settings.CoverCell)
	local players = playerSpots()
	local taken = {}
	local moves = {}
	for _, index in Rules.choose(items, players, Settings, roll) do
		local item = items[index]
		local spot = if item.kind == "cart"
			then Rules.cartSpot(item.x, item.z, cartSpots, players, taken, Settings, roll, isClear)
			else Rules.spotNear(item.x, item.z, players, taken, Settings, roll, isClear)
		if spot then
			table.insert(moves, { instance = instances[index], item = item, spot = spot })
		end
	end
	return moves
end

local function apply(move: Move)
	local instance = move.instance
	local x, z = Origin.X + move.spot.x, Origin.Z + move.spot.z
	if instance:IsA("BasePart") then
		-- A box always lands on the floor, even if it came off the top of a stack
		instance.CFrame = CFrame.new(x, Origin.Y + instance.Size.Y / 2, z)
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	elseif instance:IsA("Model") then
		local pivot = instance:GetPivot()
		local turn = if move.item.kind == "cart"
			then random:NextNumber(0, math.pi * 2)
			else math.rad(random:NextNumber(-30, 30))
		instance:PivotTo(CFrame.new(x, pivot.Y, z) * CFrame.Angles(0, turn, 0) * pivot.Rotation)
	end
end

-- Players and carries change while the batches run, so each move is checked again just before.
local function stillOk(move: Move, root: Instance, players: { Rules.Point }): boolean
	local instance = move.instance
	return inChunk(instance, root)
		and instance:GetAttribute("PlacedBy") == nil
		and instance:GetAttribute("CarriedBy") == nil
		and not Rules.nearPlayer(move.item.x, move.item.z, players, Settings.KeepAway)
		and not Rules.nearPlayer(move.spot.x, move.spot.z, players, Settings.KeepAway)
		and serverOwned(instance)
end

local function swapSigns(signs: { Sign }, count: number)
	local players = playerSpots()
	local far = {}
	for _, sign in signs do
		local spot = flat(sign.position)
		if sign.labels[1].Parent and not Rules.nearPlayer(spot.x, spot.z, players, Settings.KeepAway) then
			table.insert(far, sign)
		end
	end
	for _, pair in Rules.swaps(#far, count, roll) do
		local a, b = far[pair[1]], far[pair[2]]
		local textA, textB = a.labels[1].Text, b.labels[1].Text
		for _, label in a.labels do
			label.Text = textB
		end
		for _, label in b.labels do
			label.Text = textA
		end
	end
end

local function rearrange()
	local root = warehouseRoot()
	if busy or not root then
		return
	end
	busy = true
	scanOnce(root)
	local instances, items = collect(root)
	local moves = plan(instances, items)
	for start = 1, #moves, Settings.BatchSize do
		local players = playerSpots()
		for n = start, math.min(start + Settings.BatchSize - 1, #moves) do
			local move = moves[n]
			if stillOk(move, root, players) then
				apply(move)
			end
		end
		task.wait()
	end
	swapSigns(deptSigns, Settings.SignSwaps.dept)
	swapSigns(aisleSigns, Settings.SignSwaps.aisle)
	busy = false
end

-- The holder streams to every client (Persistent), so a drag far outside a phone's streaming
-- radius still plays.
local function playDrag()
	local spot = Rules.dragSpot(playerSpots(), Settings.Drag.Distance, roll)
	local sounds = Settings.Drag.Sounds
	local id = ModelLibrary.soundId(sounds[random:NextInteger(1, #sounds)])
	if not spot or not id then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Restock"
	part.Size = Vector3.one
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = Vector3.new(Origin.X + spot.x, Origin.Y + 4, Origin.Z + spot.z)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Settings.Drag.Volume
	sound.PlaybackSpeed = random:NextNumber(0.85, 1.05)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Settings.Drag.RollOffMin
	sound.RollOffMaxDistance = Settings.Drag.RollOffMax
	sound.Parent = part
	Mix.route(sound, "Ambience")
	part.Parent = soundHolder
	sound:Play()
	Debris:AddItem(part, 20)
end

function Rearrange.Start()
	soundHolder = Instance.new("Model")
	soundHolder.Name = "RestockSounds"
	soundHolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	soundHolder.Parent = workspace

	DayNight.onPhaseChanged(function(phase, previous)
		if phase == "Day" and previous ~= "Day" then
			task.spawn(rearrange)
		end
	end)

	while true do
		task.wait(random:NextNumber(Settings.Drag.Gap.Min, Settings.Drag.Gap.Max))
		if DayNight.isNight() and warehouseRoot() then
			playDrag()
		end
	end
end

return Rearrange
