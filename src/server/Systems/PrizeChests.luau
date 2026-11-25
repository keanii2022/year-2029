-- Prize chests: big glowing crates on plinths at the deep end of every installation set (spots from
-- Logic/WarehouseGenPrizes), a few out in the aisles, and the crates PaEvents drops. Prying one open
-- is a long hold that makes noise robots hear, and it pays a themed haul. Once open, anyone close
-- can take what's left. Emptied ones sit open and dark until the morning restock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local PrizesLogic = require(ReplicatedStorage.Shared.Logic.Prizes)
local Rng = require(ReplicatedStorage.Shared.Logic.WarehouseGenRng)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Prizes.Chests

export type Spec = {
	x: number,
	z: number,
	y: number?,
	turn: number?, -- degrees
	plinth: boolean?,
	value: number,
	loot: PrizesLogic.ChestLoot,
	room: any?,
	restocks: boolean, -- hall and aisle chests refill every morning; event crates don't
}
export type Chest = {
	spec: Spec,
	model: Model,
	root: BasePart,
	prompt: ProximityPrompt,
	light: PointLight,
	edge: BasePart?,
	stacks: { InventoryLogic.Stack },
	opened: boolean,
	locked: boolean, -- a bait crate counting down: glows but can't be pried yet
	prying: { [Player]: boolean },
}

local PrizeChests = {}

local chests: { Chest } = {}
local byRoom: { [any]: { Chest } } = {}
local folder: Folder
local feedbackRemote: RemoteEvent
local random = Random.new()

local function playSound(part: BasePart, soundName: string, level: string)
	local id = ModelLibrary.soundId(soundName)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function stackText(stack: InventoryLogic.Stack): string
	local name = InventoryItems[stack.id].name
	return if stack.count > 1 then `{name} x{stack.count}` else name
end

local function refresh(chest: Chest)
	local lit = not chest.opened
	chest.light.Enabled = lit
	ModelRig.setGlow(chest.model, lit)
	ModelRig.setPose(chest.model, "Lid", if chest.opened then 1 else 0)
	local edge = chest.edge
	if edge then
		edge.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		edge.Color = if lit then Settings.Light.Color else Settings.Plinth.EdgeOff
	end
	local prompt = chest.prompt
	if not chest.opened then
		prompt.Enabled = not chest.locked
		prompt.ActionText = "Pry open"
		prompt.ObjectText = "PRIZE CRATE"
		prompt.HoldDuration = Settings.OpenHold
	elseif #chest.stacks > 0 then
		prompt.Enabled = true
		prompt.ActionText = "Take"
		prompt.ObjectText = `{#chest.stacks} left`
		prompt.HoldDuration = Settings.TakeHold
	else
		prompt.Enabled = false
	end
end

local function fill(chest: Chest, rng: Rng.Rng)
	chest.stacks = PrizesLogic.roll(chest.spec.loot, chest.spec.value, rng, InventoryItems, Settings.Slots)
	chest.opened = false
	refresh(chest)
end

local function give(player: Player, chest: Chest)
	local got = {}
	for index = #chest.stacks, 1, -1 do
		local stack = chest.stacks[index]
		local added = Inventory.add(player, stack.id, stack.count)
		if added > 0 then
			table.insert(got, stackText({ id = stack.id, count = added }))
			InventoryLogic.remove(chest.stacks, stack.id, added)
		end
	end
	if player.Parent then
		feedbackRemote:FireClient(player, if #got > 0 then `+ {table.concat(got, ", ")}` else "Bag full")
	end
	refresh(chest)
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function onTriggered(chest: Chest, player: Player)
	if not alive(player) or not chest.model.Parent or chest.locked then
		return
	end
	if not chest.opened then
		chest.opened = true
		playSound(chest.root, Settings.Sounds.Open, Settings.OpenLoudness)
		playSound(chest.root, Settings.Sounds.Clang, Settings.OpenLoudness)
		Loudness.emit(chest.root.Position, Settings.OpenLoudness, chest.model)
	end
	give(player, chest)
end

-- Prying makes noise the whole time the button is held
local function onHoldBegan(chest: Chest, player: Player)
	if chest.opened or chest.locked or chest.prying[player] then
		return
	end
	chest.prying[player] = true
	playSound(chest.root, Settings.Sounds.Pry, Settings.HoldLoudness)
	task.spawn(function()
		while chest.prying[player] and not chest.opened and chest.model.Parent do
			Loudness.emit(chest.root.Position, Settings.HoldLoudness, chest.model)
			task.wait(Settings.HoldNoiseEvery)
		end
		chest.prying[player] = nil
	end)
end

local function buildPlinth(parent: Model, footprint: Vector3, base: CFrame): (BasePart, BasePart)
	local plinth = Settings.Plinth
	local size = Vector3.new(footprint.X + plinth.Pad * 2, plinth.Height, footprint.Z + plinth.Pad * 2)
	local block = Instance.new("Part")
	block.Name = "Plinth"
	block.Anchored = true
	block.Size = size
	block.CFrame = base * CFrame.new(0, plinth.Height / 2, 0)
	block.Color = plinth.Color
	block.Material = Enum.Material.Concrete
	block.TopSurface = Enum.SurfaceType.Smooth
	block.Parent = parent
	local edge = Instance.new("Part")
	edge.Name = "PlinthEdge"
	edge.Anchored = true
	edge.CanCollide = false
	edge.CanQuery = false
	edge.CastShadow = false
	edge.Size = Vector3.new(size.X + plinth.Edge * 2, 0.12, size.Z + plinth.Edge * 2)
	edge.CFrame = base * CFrame.new(0, plinth.Height - 0.2, 0)
	edge.Parent = parent
	return block, edge
end

-- Spawns a chest full of loot. Returns nil if the model is missing.
function PrizeChests.spawn(spec: Spec): Chest?
	local model = ModelLibrary.get(Settings.Model)
	if not model then
		return nil
	end
	local joints = ModelRig.rig(model)
	model:ScaleTo(Settings.Scale)
	-- ScaleTo resizes the hinges, but ModelRig poses from the joint offsets it saw at rig time
	for _, joint in joints do
		joint.base = joint.motor.C0
	end
	-- Interact and the robots go by ModelName; the rig is already cached, so the prize can drop it
	model:SetAttribute("ModelName", "prize_crate")
	model.Name = "PrizeCrate"
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return nil
	end

	local rotation = CFrame.Angles(0, math.rad(spec.turn or 0), 0)
	local floor = Warehouse.toWorld(spec.x, spec.z) + Vector3.new(0, spec.y or 0, 0)
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local holder = Instance.new("Model")
	holder.Name = "Prize"
	local edge: BasePart? = nil
	local standOn = floor
	if spec.plinth then
		local _, plinthEdge = buildPlinth(holder, size, CFrame.new(floor) * rotation)
		edge = plinthEdge
		standOn += Vector3.new(0, Settings.Plinth.Height, 0)
	end
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(rotation + (standOn - bottom))

	local light = Instance.new("PointLight")
	light.Color = Settings.Light.Color
	light.Brightness = Settings.Light.Brightness
	light.Range = Settings.Light.Range
	light.Shadows = false
	light.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = Settings.Range
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local chest: Chest = {
		spec = spec,
		model = model,
		root = root,
		prompt = prompt,
		light = light,
		edge = edge,
		stacks = {},
		opened = false,
		locked = false,
		prying = {},
	}
	prompt.Triggered:Connect(function(player)
		onTriggered(chest, player)
	end)
	prompt.PromptButtonHoldBegan:Connect(function(player)
		onHoldBegan(chest, player)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		chest.prying[player] = nil
	end)

	model.Parent = holder
	holder.Parent = folder
	table.insert(chests, chest)
	if spec.room then
		byRoom[spec.room] = byRoom[spec.room] or {}
		table.insert(byRoom[spec.room], chest)
	end
	fill(chest, Rng.new(random:NextInteger(1, 2 ^ 31 - 1)))
	return chest
end

function PrizeChests.remove(chest: Chest)
	local index = table.find(chests, chest)
	if index then
		table.remove(chests, index)
	end
	local list = chest.spec.room and byRoom[chest.spec.room]
	if list then
		local at = table.find(list, chest)
		if at then
			table.remove(list, at)
		end
	end
	table.clear(chest.prying)
	if chest.model.Parent then
		chest.model.Parent:Destroy()
	end
end

function PrizeChests.setLocked(chest: Chest, locked: boolean)
	chest.locked = locked
	refresh(chest)
end

function PrizeChests.isEmpty(chest: Chest): boolean
	return chest.opened and #chest.stacks == 0
end

-- Installation rooms that have chests
function PrizeChests.rooms(): { any }
	local rooms = {}
	for room, list in byRoom do
		if #list > 0 then
			table.insert(rooms, room)
		end
	end
	return rooms
end

-- "The [installation] is now open": emptied chests fill back up, closed ones get another find
function PrizeChests.refill(room: any)
	local rng = Rng.new(random:NextInteger(1, 2 ^ 31 - 1))
	for _, chest in byRoom[room] or {} do
		if chest.opened then
			fill(chest, rng)
		else
			local extra =
				PrizesLogic.roll(chest.spec.loot, chest.spec.value, rng, InventoryItems, Settings.Slots)
			InventoryLogic.moveAll(extra, chest.stacks, InventoryItems, Settings.Slots)
			refresh(chest)
		end
	end
end

local function hallLoot(): PrizesLogic.ChestLoot
	return { headline = Settings.Headline, fill = Settings.Fill, rolls = Settings.Rolls }
end

local function placeAll()
	local layout = Warehouse.layout()
	local loot = hallLoot()
	for _, room in layout.rooms do
		for _, spot in room.prizes or {} do
			PrizeChests.spawn({
				x = spot.x,
				z = spot.z,
				y = spot.y,
				turn = spot.turn,
				plinth = spot.plinth,
				value = PrizesLogic.value(
					Settings,
					WarehouseGen.depth(layout, spot.x, spot.z),
					room.kind,
					room.giant
				),
				loot = loot,
				room = room,
				restocks = true,
			})
		end
	end
	local aisle = Settings.Aisle
	local rng = Rng.new(layout.seed + 31337)
	local edge = layout.half - Config.Warehouse.WallThickness - aisle.Clearance
	local placed = 0
	for _ = 1, aisle.Count * aisle.Tries do
		if placed >= aisle.Count then
			break
		end
		local x, z = rng:range(-edge, edge), rng:range(-edge, edge)
		local depth = WarehouseGen.depth(layout, x, z)
		if
			depth >= aisle.MinDepth and WarehouseGen.isClear(layout, Config.Warehouse, x, z, aisle.Clearance)
		then
			placed += 1
			PrizeChests.spawn({
				x = x,
				z = z,
				turn = rng:range(0, 360),
				value = math.clamp(depth + aisle.Value, 0, 1),
				loot = loot,
				restocks = true,
			})
		end
	end
end

local function restock()
	local rng = Rng.new(random:NextInteger(1, 2 ^ 31 - 1))
	for _, chest in chests do
		if chest.spec.restocks then
			fill(chest, rng)
		end
	end
end

function PrizeChests.Init()
	feedbackRemote = Net.event("SupplyFeedback")
	folder = Instance.new("Folder")
	folder.Name = "PrizeChests"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		for _, chest in chests do
			chest.prying[player] = nil
		end
	end)
end

function PrizeChests.Start()
	placeAll()
	DayNight.onPhaseChanged(function(phase, previous)
		if phase == "Day" and previous ~= "Day" then
			restock()
		end
	end)
end

return PrizeChests
