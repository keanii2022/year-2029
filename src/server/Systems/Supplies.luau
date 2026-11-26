-- Hunger, energy and supplies. Needs live on the player as "Hunger" and "Energy" (0-100) plus
-- "Exhausted" (true while energy is spent; Movement should block sprinting on it).
-- Clients press Eat/Drink/Heal; the server picks the item, waits the use time, then applies it.
-- Supply pickups are scattered over the warehouse by depth and restocked every morning.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Loot = require(ReplicatedStorage.Shared.Logic.Loot)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Needs = require(ReplicatedStorage.Shared.Logic.Needs)
local Rng = require(ReplicatedStorage.Shared.Logic.WarehouseGenRng)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Supplies
local NeedSettings = Settings.Needs

local KINDS = { Eat = "Eating", Drink = "Drinking", Heal = "Patching up", Medkit = "Using the medkit" }
local NOTHING = { Eat = "No food", Drink = "Nothing to drink", Heal = "No bandages", Medkit = "No medkit" }
local FULL = { Eat = "Not hungry", Drink = "Not thirsty", Heal = "Not hurt", Medkit = "Not hurt" }
-- Pickups are spread over frames so a restock doesn't hitch the server
local PICKUPS_PER_FRAME = 60

local Supplies = {}

local states: { [Player]: Needs.State } = {}
local lastUseAt: { [Player]: number } = {}
local feedbackRemote: RemoteEvent
local pickupFolder: Folder
local restockToken = 0

local function bodyOf(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function tell(player: Player, text: string)
	if player.Parent then
		feedbackRemote:FireClient(player, text)
	end
end

local function publish(player: Player, state: Needs.State)
	states[player] = state
	player:SetAttribute("Hunger", math.floor(state.hunger * 10 + 0.5) / 10)
	player:SetAttribute("Energy", math.floor(state.energy * 10 + 0.5) / 10)
	player:SetAttribute("Exhausted", state.exhausted or nil)
end

local function playSound(root: BasePart, soundName: string?, level: string)
	local id = soundName and ModelLibrary.soundId(soundName)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	sound.Parent = root
	Mix.route(sound, "SFX")
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Unpacks a box into its contents. Rolls back if the bag can't take everything.
local function open(player: Player, itemId: string, contents: { { id: string, count: number } }): boolean
	if Inventory.remove(player, itemId, 1) < 1 then
		return false
	end
	local added = {}
	for _, entry in contents do
		local got = Inventory.add(player, entry.id, entry.count)
		table.insert(added, { id = entry.id, count = got })
		if got < entry.count then
			for _, undo in added do
				Inventory.remove(player, undo.id, undo.count)
			end
			Inventory.add(player, itemId, 1)
			return false
		end
	end
	return true
end

local function apply(player: Player, itemId: string, use: Needs.Use, humanoid: Humanoid, root: BasePart)
	local name = InventoryItems[itemId].name
	if use.opens then
		if not open(player, itemId, use.opens) then
			tell(player, "Bag full")
			return
		end
		tell(player, `Opened the {string.lower(name)}`)
	else
		if Inventory.remove(player, itemId, 1) < 1 then
			return
		end
		local state = states[player]
		if state then
			publish(player, Needs.refill(state, use, NeedSettings))
		end
		if use.health then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + use.health)
		end
		tell(player, `{name} done`)
	end
	Loudness.emit(root.Position, use.loudness :: any, player.Character)
	playSound(root, use.sound, use.loudness)
end

local function onUse(player: Player, kind: unknown)
	if type(kind) ~= "string" or not KINDS[kind] then
		return
	end
	local now = os.clock()
	if now - (lastUseAt[player] or 0) < Settings.UseCooldown or player:GetAttribute("UsingSupply") then
		return
	end
	lastUseAt[player] = now
	local character, humanoid, root = bodyOf(player)
	local state = states[player]
	if not character or not humanoid or not root or not state then
		return
	end
	if player:GetAttribute("Cuffed") == true then
		tell(player, "Can't while cuffed")
		return
	end

	local itemId, why = Needs.pick(kind, Inventory.list(player), Settings.Uses, {
		hunger = NeedSettings.Max - state.hunger,
		energy = NeedSettings.Max - state.energy,
		health = humanoid.MaxHealth - humanoid.Health,
	})
	if not itemId then
		tell(player, if why == "full" then FULL[kind] else NOTHING[kind])
		return
	end

	local use = Settings.Uses[itemId]
	player:SetAttribute("UsingSupply", itemId)
	tell(player, if use.opens then "Opening..." else `{KINDS[kind]}...`)
	task.wait(use.time)
	player:SetAttribute("UsingSupply", nil)

	local stillCharacter, stillHumanoid, stillRoot = bodyOf(player)
	if
		stillCharacter ~= character
		or not stillHumanoid
		or not stillRoot
		or player:GetAttribute("Cuffed") == true
	then
		return
	end
	apply(player, itemId, use, stillHumanoid, stillRoot)
end

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local state = states[player]
		local character, humanoid = bodyOf(player)
		if state and character and humanoid and player:GetAttribute("God") ~= true then
			local sprinting = character:GetAttribute("Stance") == "Sprint"
				and humanoid.MoveDirection.Magnitude > 0.1
			local nextState, damage = Needs.step(state, dt, { sprinting = sprinting }, NeedSettings)
			publish(player, nextState)
			if damage > 0 then
				-- For the down screen (Combat): what got you
				character:SetAttribute("HurtBy", "Starved.")
				character:SetAttribute("HurtAt", workspace:GetServerTimeNow())
				humanoid:TakeDamage(damage)
			end
		end
	end
end

local function onCharacterAdded(player: Player)
	player:SetAttribute("UsingSupply", nil)
	publish(
		player,
		{ hunger = NeedSettings.SpawnHunger, energy = NeedSettings.SpawnEnergy, exhausted = false }
	)
end

-- Pickups

local function pickupText(itemId: string, count: number): string
	local name = InventoryItems[itemId].name
	return if count > 1 then `{name} x{count}` else name
end

local function stand(model: Model, x: number, z: number, turn: number)
	local rotation = CFrame.Angles(0, turn, 0)
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(rotation + (Warehouse.toWorld(x, z) - bottom))
end

local function fallbackModel(): Model
	local model = Instance.new("Model")
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(1, 0.8, 1)
	box.Color = Color3.fromRGB(70, 66, 58)
	box.Parent = model
	model.PrimaryPart = box
	return model
end

local function buildPickup(roll: Loot.Roll, spot: Loot.Spot, turn: number)
	if not InventoryItems[roll.item] then
		return
	end
	local model = ModelLibrary.get(roll.model) or fallbackModel()
	model.Name = roll.item
	local root: BasePart? = model.PrimaryPart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			root = root or part
		end
	end
	if not root then
		model:Destroy()
		return
	end
	stand(model, spot.x, spot.z, turn)

	local remaining = roll.count
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = pickupText(roll.item, remaining)
	prompt.HoldDuration = Settings.PickupHold
	prompt.MaxActivationDistance = Settings.PickupRange
	prompt.RequiresLineOfSight = true -- no looting through a wall
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if remaining <= 0 or not bodyOf(player) or player:GetAttribute("Cuffed") == true then
			return
		end
		local added = Inventory.add(player, roll.item, remaining)
		if added <= 0 then
			tell(player, "Bag full")
			return
		end
		remaining -= added
		tell(player, `+ {pickupText(roll.item, added)}`)
		if remaining <= 0 then
			model:Destroy()
		else
			prompt.ObjectText = pickupText(roll.item, remaining)
		end
	end)

	model:SetAttribute("SupplyItem", roll.item)
	CollectionService:AddTag(model, Settings.PickupTag)
	model.Parent = pickupFolder
end

-- The guaranteed pickups in each installation: by different pieces of furniture, out in front
local function installationSpots(layout: any, rng: Rng.Rng): { Loot.Spot }
	local spots = {}
	local reach = Settings.InstallationLootReach
	for _, room in layout.rooms do
		if not room.installation then
			continue
		end
		local items = rng:shuffle(room.items)
		local good = if room.giant
			then Settings.GiantInstallationGoodFinds
			else Settings.InstallationGoodFinds
		local depth = WarehouseGen.depth(layout, room.cx, room.cz)
		local count =
			math.max(good, rng:int(Settings.InstallationLootCount[1], Settings.InstallationLootCount[2]))
		for n = 1, count do
			local thing = items[n]
			local x = if thing then thing.x + thing.nx * reach else room.cx + rng:range(-1, 1) * 4
			local z = if thing then thing.z + thing.nz * reach else room.cz + rng:range(-1, 1) * 4
			if n <= good then
				table.insert(spots, { x = x, z = z, depth = depth, good = true })
			else
				table.insert(spots, { x = x, z = z, depth = 1 })
			end
		end
	end
	return spots
end

-- Clears every pickup and lays out a fresh set. A newer restock stops an older one mid-way.
local function restock(seed: number)
	restockToken += 1
	local token = restockToken
	pickupFolder:ClearAllChildren()

	local layout = Warehouse.layout()
	local rng = Rng.new(seed)
	local spots = Loot.floorSpots(
		layout,
		Config.Warehouse,
		rng,
		Warehouse.scaled(Settings.FloorSpots),
		Settings.SpotTries,
		Settings.SpotClearance
	)
	for _, spot in Loot.roomSpots(layout, rng, Settings.RoomLootChance, Settings.RoomDepthBonus) do
		table.insert(spots, spot)
	end
	local guaranteed = #spots + 1
	for _, spot in installationSpots(layout, rng) do
		table.insert(spots, spot)
	end
	for index, spot in spots do
		local entries = if spot.good
			then Settings.GoodFinds
			elseif index >= guaranteed then Settings.InstallationLoot
			else Settings.Loot
		local roll = Loot.roll(entries, spot.depth, rng)
		if roll then
			buildPickup(roll, spot, rng:range(0, math.pi * 2))
		end
		if index % PICKUPS_PER_FRAME == 0 then
			task.wait()
			if token ~= restockToken then
				return
			end
		end
	end
end

local function restockForDay(day: number)
	restock(Warehouse.layout().seed + day * 7919)
end

-- A copy of the player's needs, or nil before they've spawned.
function Supplies.needs(player: Player): Needs.State?
	local state = states[player]
	return if state then table.clone(state) else nil
end

-- Clears and refills every supply pickup now (it also happens on its own every morning).
function Supplies.restock()
	task.spawn(restockForDay, DayNight.day())
end

function Supplies.Init()
	feedbackRemote = Net.event("SupplyFeedback")
	Net.event("SupplyUse").OnServerEvent:Connect(onUse)
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "Supplies"
	pickupFolder.Parent = workspace
end

function Supplies.Start()
	local function setUpPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
		if player.Character then
			onCharacterAdded(player)
		end
	end
	Players.PlayerAdded:Connect(setUpPlayer)
	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastUseAt[player] = nil
	end)

	DayNight.onPhaseChanged(function(phase, previous, day)
		if phase == "Day" and previous ~= "Day" then
			task.spawn(restockForDay, day)
		end
	end)
	task.spawn(restockForDay, DayNight.day())

	while true do
		tick(task.wait(Settings.TickInterval))
	end
end

return Supplies
