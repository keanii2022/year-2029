-- Player saves, the locker and blueprints.
-- Saves: one DataStore key per player, read and written only through UpdateAsync with a session
-- lock so two servers never hold the same save. Retries with backoff, waits for request budget,
-- autosaves, saves on leave and on shutdown. In Studio without API access it keeps saves in
-- memory for the session and warns. A save from a newer build is never written over.
-- Locker: one beside every spawn. Any locker opens your own stash, the only stuff that follows
-- you to every server. Blueprint: paper and pen pickups (restocked every morning) draw the fort
-- around you; once per day, in daylight, you lay it out as ghosts that matching props snap into.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Logic.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local Loot = require(ReplicatedStorage.Shared.Logic.Loot)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Logic.WarehouseGenRng)
local SavesBlueprint = require(ReplicatedStorage.Shared.Logic.SavesBlueprint)
local SavesLogic = require(ReplicatedStorage.Shared.Logic.Saves)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Saves
local LockerSettings = Settings.Locker
local BlueprintSettings = Settings.Blueprint
local GrabTag = Config.Grab.Tag

local REQUEST_GAP = 0.15 -- seconds between locker or blueprint requests from one player
local MAX_MOVE = 999
local SPRAY_RED = Color3.fromRGB(200, 28, 22)

type Data = SavesLogic.Data
type Session = {
	data: Data,
	key: string,
	canSave: boolean,
	holdsLock: boolean,
	saveQueued: boolean,
	released: boolean,
}
type Slot = SavesBlueprint.Slot & { cframe: CFrame, ghost: Model? }
type Layout = { slots: { Slot }, snapped: { [Model]: boolean } }

local Saves = {}

local sessions: { [Player]: Session } = {}
local loadedListeners: { (Player, Data) -> () } = {}
local leavingListeners: { (Player, Data) -> () } = {}
local openLocker: { [Player]: Model } = {}
local lastRequestAt: { [Player]: number } = {}
local layouts: { [Player]: Layout } = {}

local jobId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`
local store: DataStore? = nil
local useMemory = false
local memory: { [string]: any } = {}
local memoryBoards: { [string]: { [string]: number } } = {}
local pendingSaves = 0
local closing = false
local homeSpots: { CFrame }? = nil

local feedbackRemote: RemoteEvent
local lockerRemote: RemoteEvent
local blueprintRemote: RemoteEvent
local lockerFolder: Folder
local paperFolder: Folder
local ghostFolder: Folder

local statKeys = {}
for _, def in Settings.Stats do
	table.insert(statKeys, def.key)
end

local rules: SavesLogic.Rules = {
	items = InventoryItems,
	stats = statKeys,
	cosmetics = Settings.Cosmetics :: any,
	maxPieces = BlueprintSettings.MaxPieces,
	isKnownModel = function(name)
		return ModelLibrary.entry(name) ~= nil
	end,
}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = deepCopy(inner)
	end
	return copy :: any
end

local function tell(player: Player, text: string)
	if player.Parent then
		feedbackRemote:FireClient(player, text)
	end
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < REQUEST_GAP then
		return true
	end
	lastRequestAt[player] = now
	return false
end

-- DataStore plumbing ---------------------------------------------------------------------------

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local deadline = os.clock() + Settings.BudgetWait
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() < deadline do
		task.wait(0.5)
	end
end

-- Runs request until it works or attempts run out, backing off between tries.
local function withRetries(
	label: string,
	requestType: Enum.DataStoreRequestType,
	attempts: number,
	request: () -> any
): (boolean, any)
	local lastError
	for attempt = 1, attempts do
		if not useMemory then
			waitForBudget(requestType)
		end
		local ok, result = pcall(request)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < attempts then
			task.wait(SavesLogic.retryDelay(attempt, Settings.RetryBase, Settings.RetryMax))
		end
	end
	warn(`[Saves] {label} failed: {lastError}`)
	return false, lastError
end

-- UpdateAsync, or the in-memory stand-in. transform returning nil leaves the value alone.
local function updateKey(key: string, transform: (any) -> any)
	if useMemory then
		local result = transform(deepCopy(memory[key]))
		if result ~= nil then
			memory[key] = deepCopy(result)
		end
		return
	end
	if not store then
		error("no DataStore")
	end
	store:UpdateAsync(key, transform)
end

local function lockOf(current: any): any
	return if type(current) == "table" then current.lock else nil
end

local function releaseLock(key: string)
	withRetries(`release {key}`, Enum.DataStoreRequestType.UpdateAsync, Settings.Retries, function()
		updateKey(key, function(current)
			if SavesLogic.lockState(lockOf(current), jobId, os.time(), Settings.LockExpiry) ~= "ours" then
				return nil
			end
			local record = table.clone(current)
			record.lock = nil
			return record
		end)
	end)
end

local function save(session: Session, release: boolean)
	if not session.canSave then
		if release and session.holdsLock then
			releaseLock(session.key)
		end
		return
	end
	local snapshot = deepCopy(session.data)
	local lostLock = false
	withRetries(`save {session.key}`, Enum.DataStoreRequestType.UpdateAsync, Settings.Retries, function()
		updateKey(session.key, function(current)
			lostLock = SavesLogic.lockState(lockOf(current), jobId, os.time(), Settings.LockExpiry) == "taken"
			-- An autosave still in flight after the final save must not put the lock back
			if lostLock or (session.released and not release) then
				return nil
			end
			local record: any = table.clone(snapshot)
			record.lock = if release then nil else { job = jobId, at = os.time() }
			return record
		end)
	end)
	if lostLock then
		-- Another server took this save over; writing now would undo its progress
		warn(`[Saves] {session.key} is held by another server, no longer saving here`)
		session.canSave = false
	end
end

local function sendBlueprint(player: Player)
	local session = sessions[player]
	local blueprint = session and session.data.blueprint
	if player.Parent then
		blueprintRemote:FireClient(player, { pieces = if blueprint then #blueprint.pieces else 0 })
	end
end

local function loadSession(player: Player)
	local key = `{Settings.KeyPrefix}{player.UserId}`
	local raw, taken = nil, false
	local ok = false
	for attempt = 1, Settings.Retries do
		ok = withRetries(`load {key}`, Enum.DataStoreRequestType.UpdateAsync, Settings.Retries, function()
			updateKey(key, function(current)
				taken = SavesLogic.lockState(lockOf(current), jobId, os.time(), Settings.LockExpiry)
					== "taken"
				if taken then
					return nil
				end
				raw = current
				local record = if type(current) == "table" then table.clone(current) else {}
				record.lock = { job = jobId, at = os.time() }
				return record
			end)
		end)
		if not ok or not taken or not player.Parent then
			break
		end
		-- Usually the last server is still writing this player's save on their way out
		if attempt < Settings.Retries then
			task.wait(SavesLogic.retryDelay(attempt, Settings.RetryBase, Settings.RetryMax))
		end
	end

	local holdsLock = ok and not taken
	if not player.Parent then
		if holdsLock then
			releaseLock(key)
		end
		return
	end

	local data, problem = SavesLogic.load(if holdsLock then raw else nil, rules)
	local session: Session = {
		data = data,
		key = key,
		canSave = holdsLock and problem ~= "newer",
		holdsLock = holdsLock,
		saveQueued = false,
		released = false,
	}
	sessions[player] = session
	if not ok then
		tell(player, "Couldn't load your save. This session won't save.")
	elseif taken then
		tell(player, "Your save is still open on another server. Rejoin in a minute.")
	elseif problem == "newer" then
		tell(player, "This server is out of date. Rejoin to load your save.")
	end
	for _, listener in loadedListeners do
		task.spawn(listener, player, data)
	end
	sendBlueprint(player)
end

local function finish(player: Player, session: Session)
	pendingSaves += 1
	session.released = true
	for _, listener in if session.canSave then leavingListeners else {} do
		local ok, err = pcall(listener, player, session.data)
		if not ok then
			warn(`[Saves] leaving listener failed: {err}`)
		end
	end
	save(session, true)
	pendingSaves -= 1
end

local function connectStore()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Settings.StoreName)
	if ok then
		store = result
		local probeOk, probeError = pcall(result.GetAsync, result, "probe")
		if probeOk then
			return
		end
		result = probeError
	end
	if RunService:IsStudio() then
		useMemory = true
		warn(
			"[Saves] No DataStore access in Studio, so saves only last this session. To test real saves, turn on "
				.. "Game Settings > Security > Enable Studio Access to API Services."
		)
	else
		warn(`[Saves] DataStores unavailable, loads will keep retrying: {result}`)
	end
end

local function autosaveLoop()
	while true do
		task.wait(Settings.AutosaveInterval)
		local list = {}
		for _, session in sessions do
			table.insert(list, session)
		end
		for _, session in list do
			if closing then
				return
			end
			if session.released then
				continue
			end
			-- Saves even when nothing changed: it keeps the session lock fresh
			save(session, false)
			task.wait(0.2)
		end
	end
end

-- Spawns and lockers ---------------------------------------------------------------------------

local function collectSpawns(container: Instance?, into: { CFrame })
	if not container then
		return
	end
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			table.insert(into, descendant.CFrame * CFrame.new(0, -descendant.Size.Y / 2, 0))
		end
	end
end

local WALL_DIRECTIONS = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }

-- Loose props and people don't count as a wall to put the locker against
local function isWall(part: BasePart): boolean
	if not part.Anchored then
		return false
	end
	local node: Instance? = part
	while node and node ~= workspace do
		if CollectionService:HasTag(node, GrabTag) or node:FindFirstChildOfClass("Humanoid") then
			return false
		end
		node = node.Parent
	end
	return true
end

-- The nearest wall in one of the four square directions from a spawn
local function nearestWall(origin: Vector3): (Vector3?, Vector3?)
	local bestPoint, bestDirection, bestDistance = nil, nil, math.huge
	for _, direction in WALL_DIRECTIONS do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skipped = {}
		for _ = 1, 8 do
			params.FilterDescendantsInstances = skipped
			local hit = workspace:Raycast(origin, direction * LockerSettings.WallSearch, params)
			if not hit then
				break
			end
			if isWall(hit.Instance) then
				if hit.Distance < bestDistance then
					bestPoint, bestDirection, bestDistance = hit.Position, direction, hit.Distance
				end
				break
			end
			table.insert(skipped, hit.Instance)
		end
	end
	return bestPoint, bestDirection
end

-- Where a spawn's locker and board go: on the floor at the foot of the nearest wall, square to it,
-- looking out (LookVector) towards the spawn. With no wall close by, a spot out in front of the spawn.
local function homeFrame(spawnFloor: CFrame): CFrame
	local floor = spawnFloor.Position
	local point, direction = nearestWall(floor + Vector3.new(0, LockerSettings.WallProbeHeight, 0))
	if not point or not direction then
		direction = Vector3.xAxis
		point = floor + direction * LockerSettings.OpenFloorGap
	end
	local foot = Vector3.new(point.X, floor.Y, point.Z)
	return CFrame.lookAt(foot, foot - direction)
end

local function sprayLabel(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, 600)
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.3)
	label.Position = UDim2.fromScale(0, 0.15)
	label.Rotation = -8
	label.Font = Enum.Font.PermanentMarker
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = SPRAY_RED
	label.Parent = gui
end

local function placeLocker(home: CFrame)
	local model = ModelLibrary.get(LockerSettings.Model)
	if not model then
		return
	end
	-- Not a warehouse prop: no grabbing, no door-swing interaction, just the stash prompt
	model:SetAttribute("ModelName", nil)
	model:SetAttribute("SaveLocker", true)
	-- Front (+z in the manifest) faces out from the wall, back flush to it, base on the floor
	local spot = home * CFrame.new(LockerSettings.WallOffset)
	local rotation = CFrame.lookAt(Vector3.zero, -home.LookVector)
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local target = spot.Position + home.LookVector * (size.Z / 2 + 0.1)
	model:PivotTo(rotation + (target - (box.Position - Vector3.new(0, size.Y / 2, 0))))

	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not body then
		model:Destroy()
		return
	end
	local door = model:FindFirstChild("Door", true)
	if door and door:IsA("BasePart") then
		sprayLabel(door, "STASH")
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Your locker"
	prompt.HoldDuration = LockerSettings.PromptHold
	prompt.MaxActivationDistance = LockerSettings.Range
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		Saves.openLocker(player, model)
	end)
	model.Parent = lockerFolder
end

local function lockerState(player: Player, open: boolean)
	local session = sessions[player]
	local locker = openLocker[player]
	if not player.Parent then
		return
	end
	lockerRemote:FireClient(player, {
		open = open,
		position = if locker then locker:GetPivot().Position else nil,
		locker = if session then InventoryLogic.totals(session.data.locker) else {},
		slots = LockerSettings.Slots,
		used = if session then #session.data.locker else 0,
	})
end

local function nearLocker(player: Player): boolean
	local root = bodyOf(player)
	local locker = openLocker[player]
	return root ~= nil
		and locker ~= nil
		and locker.Parent ~= nil
		and (root.Position - locker:GetPivot().Position).Magnitude <= LockerSettings.Range + 2
end

local function onLockerMove(player: Player, action: any, id: any, count: any)
	if throttled(player) or (action ~= "store" and action ~= "take") then
		return
	end
	if type(id) ~= "string" or type(count) ~= "number" or count ~= count or not InventoryItems[id] then
		return
	end
	local session = sessions[player]
	if not session or not session.canSave or not nearLocker(player) then
		return
	end
	local amount = math.clamp(math.floor(count), 1, MAX_MOVE)
	local stash = session.data.locker

	if action == "store" then
		local allowed = SavesLogic.canStore(id, InventoryItems, LockerSettings.Blocked)
		if not allowed then
			tell(player, "That can't go in your locker")
			return
		end
		local removed = Inventory.remove(player, id, amount)
		local added = SavesLogic.lockerAdd(stash, InventoryItems, id, removed, LockerSettings.Slots)
		if added < removed then
			Inventory.add(player, id, removed - added)
			tell(player, "Locker full")
		end
	else
		local removed = InventoryLogic.remove(stash, id, amount)
		local added = Inventory.add(player, id, removed)
		if added < removed then
			-- Straight back where it came from; no slot cap so nothing can vanish
			InventoryLogic.add(stash, InventoryItems, id, removed - added, math.huge)
			tell(player, "Bag full")
		end
	end
	Saves.markDirty(player, true)
	lockerState(player, true)
end

local function closeLocker(player: Player)
	if openLocker[player] then
		openLocker[player] = nil
		lockerState(player, false)
	end
end

-- Blueprints -----------------------------------------------------------------------------------

local function anchorFor(root: BasePart, humanoid: Humanoid): CFrame
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local look = root.CFrame.LookVector
	local yaw = SavesBlueprint.snapYaw(math.deg(math.atan2(-look.X, -look.Z)))
	return CFrame.new(feet) * CFrame.Angles(0, math.rad(yaw), 0)
end

local function propOf(part: Instance): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, GrabTag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function overlapParams(): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { ghostFolder, paperFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Grabbable models with a library name touching a sphere around position.
local function propsNear(position: Vector3, radius: number): { [Model]: string }
	local found = {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius, overlapParams()) do
		local prop = propOf(part)
		local name = prop and prop:GetAttribute("ModelName")
		if prop and type(name) == "string" then
			found[prop] = name
		end
	end
	return found
end

local function onDraw(player: Player, paper: Model)
	local session = sessions[player]
	local root, humanoid = bodyOf(player)
	if not session or not root or not humanoid or not paper.Parent then
		return
	end
	if not session.canSave then
		tell(player, "Saves are down right now")
		return
	end
	local anchor = anchorFor(root, humanoid)
	local candidates = {}
	for prop, name in propsNear(anchor.Position, BlueprintSettings.Radius) do
		local relative = anchor:ToObjectSpace(prop:GetPivot())
		local rx, ry, rz = relative:ToOrientation()
		table.insert(candidates, {
			model = name,
			x = relative.X,
			y = relative.Y,
			z = relative.Z,
			rx = math.deg(rx),
			ry = math.deg(ry),
			rz = math.deg(rz),
		})
	end
	local blueprint = SavesBlueprint.capture(
		candidates,
		BlueprintSettings.Radius,
		BlueprintSettings.MaxPieces,
		rules.isKnownModel
	)
	if not blueprint then
		tell(player, "Nothing to draw here. Build a fort first.")
		return
	end
	paper:Destroy()
	session.data.blueprint = blueprint
	Saves.markDirty(player, true)
	tell(player, `Blueprint drawn: {#blueprint.pieces} pieces`)
	sendBlueprint(player)
end

local function slotCFrame(anchor: CFrame, piece: SavesBlueprint.Piece): CFrame
	return anchor
		* CFrame.new(piece.x, piece.y, piece.z)
		* CFrame.fromOrientation(math.rad(piece.rx), math.rad(piece.ry), math.rad(piece.rz))
end

local function slotBlocked(name: string, cframe: CFrame, params: OverlapParams): boolean
	local entry = ModelLibrary.entry(name)
	if not entry then
		return true
	end
	local size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	-- Shrunk so the floor and neighbours it only touches don't count
	local probe = (size - Vector3.one * 0.4):Max(Vector3.one * 0.1)
	return #workspace:GetPartBoundsInBox(cframe * CFrame.new(0, size.Y / 2, 0), probe, params) > 0
end

local function buildGhost(name: string, cframe: CFrame): Model?
	local ghost = ModelLibrary.get(name)
	if not ghost then
		return nil
	end
	ghost:SetAttribute("ModelName", nil)
	for _, descendant in ghost:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Material = Enum.Material.ForceField
			descendant.Color = BlueprintSettings.GhostColor
			descendant.Transparency = BlueprintSettings.GhostTransparency
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end
	ghost:PivotTo(cframe)
	ghost.Parent = ghostFolder
	return ghost
end

local function clearLayout(player: Player)
	local layout = layouts[player]
	if not layout then
		return
	end
	layouts[player] = nil
	for _, slot in layout.slots do
		if slot.ghost then
			slot.ghost:Destroy()
		end
	end
end

local function cycleSeconds(): number
	local lengths = Clock.lengths(Config.DayNight)
	return lengths.Day + lengths.Siren + lengths.Night
end

local function onLayOut(player: Player)
	if throttled(player) then
		return
	end
	local session = sessions[player]
	local root, humanoid = bodyOf(player)
	if not session or not root or not humanoid then
		return
	end
	local blueprint = session.data.blueprint
	if not blueprint then
		tell(player, "No blueprint yet. Find paper and a pen.")
		return
	end
	if not session.canSave then
		tell(player, "Saves are down right now")
		return
	end
	local now = { job = jobId, day = DayNight.day(), at = os.time() }
	local ok, reason =
		SavesBlueprint.canLayOut(session.data.lastLaidOut, now, DayNight.phase(), cycleSeconds())
	if not ok then
		tell(
			player,
			if reason == "day only"
				then "Blueprints go down in daylight only"
				else "Already laid one out today"
		)
		return
	end

	local anchor = anchorFor(root, humanoid)
	local params = overlapParams()
	for _, piece in blueprint.pieces do
		if slotBlocked(piece.model, slotCFrame(anchor, piece), params) then
			tell(player, "Not clear here. Find an open spot.")
			return
		end
	end

	clearLayout(player)
	local layout: Layout = { slots = {}, snapped = {} }
	for _, piece in blueprint.pieces do
		local cframe = slotCFrame(anchor, piece)
		local position = cframe.Position
		table.insert(layout.slots, {
			model = piece.model,
			x = position.X,
			y = position.Y,
			z = position.Z,
			filled = false,
			cframe = cframe,
			ghost = buildGhost(piece.model, cframe),
		})
	end
	layouts[player] = layout
	session.data.lastLaidOut = now
	Saves.markDirty(player, true)
	tell(player, `Blueprint laid out: {#layout.slots} pieces to find`)
end

local function isSettled(prop: Model): boolean
	-- Grab turns collision off while a prop is carried
	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			return true
		end
	end
	return false
end

-- After any drop, props near the dropper that match an empty ghost snap into it.
local function trySnap(dropper: Player)
	local root = bodyOf(dropper)
	if not root or next(layouts) == nil then
		return
	end
	local props = propsNear(root.Position, Config.Grab.PlaceReach + 6)
	for owner, layout in layouts do
		for prop, name in props do
			if not layout.snapped[prop] and isSettled(prop) then
				local at = prop:GetPivot().Position
				local index = SavesBlueprint.matchSlot(
					layout.slots,
					name,
					at.X,
					at.Y,
					at.Z,
					BlueprintSettings.SnapDistance
				)
				if index then
					local slot = layout.slots[index]
					prop:PivotTo(slot.cframe)
					slot.filled = true
					layout.snapped[prop] = true
					if slot.ghost then
						slot.ghost:Destroy()
						slot.ghost = nil
					end
				end
			end
		end
		if SavesBlueprint.remaining(layout.slots) == 0 then
			layouts[owner] = nil
			tell(owner, "Fort rebuilt")
		end
	end
end

local function restockPaper(day: number)
	paperFolder:ClearAllChildren()
	local rng = Rng.new(Warehouse.layout().seed + day * 104729)
	local spots = Loot.floorSpots(
		Warehouse.layout(),
		Config.Warehouse,
		rng,
		Warehouse.scaled(BlueprintSettings.PaperPerDay),
		BlueprintSettings.PaperSpotTries,
		BlueprintSettings.PaperSpotClearance
	)
	for _, spot in spots do
		local paper = ModelLibrary.get(BlueprintSettings.PaperModel)
		local body = paper and (paper.PrimaryPart or paper:FindFirstChildWhichIsA("BasePart", true))
		if paper and body then
			paper:PivotTo(
				CFrame.new(Warehouse.toWorld(spot.x, spot.z)) * CFrame.Angles(0, rng:range(0, math.pi * 2), 0)
			)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Draw blueprint"
			prompt.ObjectText = "Paper and pen"
			prompt.HoldDuration = BlueprintSettings.PromptHold
			prompt.MaxActivationDistance = BlueprintSettings.PromptRange
			prompt.RequiresLineOfSight = false
			prompt.Parent = body
			prompt.Triggered:Connect(function(player)
				onDraw(player, paper)
			end)
			paper.Parent = paperFolder
		end
	end
end

local function onPhaseChanged(phase: string, previous: string, day: number)
	if phase == "Day" and previous ~= "Day" then
		restockPaper(day)
	elseif phase == "Night" then
		for owner in layouts do
			clearLayout(owner)
			tell(owner, "Your blueprint faded")
		end
	end
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("CarrySpeedMultiplier"):Connect(function()
		if player:GetAttribute("CarrySpeedMultiplier") == nil and next(layouts) ~= nil then
			task.defer(trySnap, player)
		end
	end)
	player.CharacterRemoving:Connect(function()
		closeLocker(player)
	end)
	task.spawn(loadSession, player)
end

local function onPlayerRemoving(player: Player)
	openLocker[player] = nil
	lastRequestAt[player] = nil
	clearLayout(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		finish(player, session)
	end
end

-- Public ---------------------------------------------------------------------------------------

-- The player's live save data, or nil while it loads. Change it, then call markDirty.
function Saves.data(player: Player): Data?
	local session = sessions[player]
	return session and session.data
end

function Saves.isLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- False when this session can't write (save failed to load, held elsewhere, or from a newer build).
function Saves.canSave(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.canSave
end

-- Flags a change. soon = also save within SaveSoonDelay instead of waiting for the autosave.
function Saves.markDirty(player: Player, soon: boolean?)
	local session = sessions[player]
	if not session or not soon or session.saveQueued then
		return
	end
	session.saveQueued = true
	task.delay(Settings.SaveSoonDelay, function()
		session.saveQueued = false
		if sessions[player] == session then
			save(session, false)
		end
	end)
end

-- Small saved numbers for other systems (the dog's trust, ...). Nil until loaded or never set.
function Saves.getValue(player: Player, key: string): number?
	local data = Saves.data(player)
	return data and data.extras[key]
end

function Saves.setValue(player: Player, key: string, value: number)
	local data = Saves.data(player)
	if data then
		data.extras[key] = value
		Saves.markDirty(player)
	end
end

function Saves.onLoaded(listener: (Player, Data) -> ())
	table.insert(loadedListeners, listener)
end

-- Runs right before a leaving player's final save (only for sessions that can save); last
-- chance to write into their data. Saves.data already returns nil here, so use the data passed in.
function Saves.onLeaving(listener: (Player, Data) -> ())
	table.insert(leavingListeners, listener)
end

function Saves.tell(player: Player, text: string)
	tell(player, text)
end

function Saves.openLocker(player: Player, locker: Model)
	local session = sessions[player]
	if not session or not bodyOf(player) then
		return
	end
	if not session.canSave then
		tell(player, "Locker's jammed. Saves are down right now.")
		return
	end
	openLocker[player] = locker
	lockerState(player, true)
end

-- Floor CFrames of every live spawn, once the warehouse is built. Yields until then.
-- One per spawn: floor spot at the foot of the wall its locker stands against, LookVector out
function Saves.homeSpots(): { CFrame }
	while not homeSpots do
		task.wait(0.5)
	end
	return homeSpots :: { CFrame }
end

function Saves.writeBoard(stat: string, userId: number, value: number)
	if useMemory then
		memoryBoards[stat] = memoryBoards[stat] or {}
		memoryBoards[stat][tostring(userId)] = value
		return
	end
	withRetries(`board {stat}`, Enum.DataStoreRequestType.SetIncrementSortedAsync, 2, function()
		DataStoreService:GetOrderedDataStore(`{Settings.BoardPrefix}{stat}`):SetAsync(tostring(userId), value)
	end)
end

-- Top entries, highest first, or nil if the board couldn't be read.
function Saves.readBoard(stat: string, count: number): { { userId: number, value: number } }?
	local rows = {}
	if useMemory then
		for key, value in memoryBoards[stat] or {} do
			table.insert(rows, { userId = tonumber(key) :: number, value = value })
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
		while #rows > count do
			table.remove(rows)
		end
		return rows
	end
	local ok, page = withRetries(`read board {stat}`, Enum.DataStoreRequestType.GetSortedAsync, 2, function()
		return DataStoreService:GetOrderedDataStore(`{Settings.BoardPrefix}{stat}`)
			:GetSortedAsync(false, count)
			:GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	for _, entry in page do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { userId = userId, value = entry.value })
		end
	end
	return rows
end

function Saves.Init()
	feedbackRemote = Net.event("SavesFeedback")
	lockerRemote = Net.event("LockerState")
	blueprintRemote = Net.event("BlueprintState")
	Net.event("LockerMove").OnServerEvent:Connect(onLockerMove)
	Net.event("LockerClose").OnServerEvent:Connect(closeLocker)
	Net.event("BlueprintLayOut").OnServerEvent:Connect(onLayOut)
	Net.event("SavesSync").OnServerEvent:Connect(sendBlueprint)

	lockerFolder = Instance.new("Folder")
	lockerFolder.Name = "Lockers"
	lockerFolder.Parent = workspace
	paperFolder = Instance.new("Folder")
	paperFolder.Name = "PaperAndPens"
	paperFolder.Parent = workspace
	ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "BlueprintGhosts"
	ghostFolder.Parent = workspace
end

function Saves.Start()
	connectStore()
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	game:BindToClose(function()
		closing = true
		for player, session in sessions do
			sessions[player] = nil
			task.spawn(finish, player, session)
		end
		local deadline = os.clock() + Settings.CloseTimeout
		task.wait()
		while pendingSaves > 0 and os.clock() < deadline do
			task.wait(0.25)
		end
	end)
	task.spawn(autosaveLoop)

	DayNight.onPhaseChanged(onPhaseChanged)
	task.spawn(restockPaper, DayNight.day())

	local root = workspace:WaitForChild("Warehouse")
	while not root:GetAttribute("Built") do
		task.wait(1)
	end
	local spots = {}
	collectSpawns(root:FindFirstChild("Spawns"), spots)
	collectSpawns(workspace:FindFirstChild("TestRoom"), spots)
	local homes = {}
	for index, spot in spots do
		homes[index] = homeFrame(spot)
		placeLocker(homes[index])
	end
	homeSpots = homes
end

return Saves
