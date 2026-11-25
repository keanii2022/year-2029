-- Grab and build. The carrier's client draws the prop and its placement ghost itself; the server
-- moves the real prop for everyone else from the carrier's hold reports (AimRate a second), and on
-- place checks the spot the client asks for with the same Shared/GrabFit code the ghost used.
-- Placed props remember their placer in "PlacedBy"; anyone else has to pry them loose first, and
-- longer when the piece is fortified (Logic/FortLink). Placed props get a plain box blocker so
-- robot paths and crawlers can't find gaps in mesh collision.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local FortLink = require(ReplicatedStorage.Shared.Logic.FortLink)
local GrabFit = require(ReplicatedStorage.Shared.GrabFit)
local GrabPry = require(ReplicatedStorage.Shared.Logic.GrabPry)
local GrabRules = require(ReplicatedStorage.Shared.Logic.GrabRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)

local Loudness = require(script.Parent.Loudness)

local Settings = Config.Grab

-- A finished pry the client never claims (lost remote, lag spike) stops making noise after this.
local PRY_ABANDON_AFTER = 2
-- A let-go prop counts as still below this speed, in studs (or radians) per second
local SETTLED_SPEED = 0.5
local BLOCKER = "FortBlocker"

type Carry = {
	prop: PVInstance,
	parts: { BasePart },
	collide: { [BasePart]: boolean },
	anchored: { [BasePart]: true }, -- only the parts that were anchored at pickup
	size: Vector3,
	pivotOffset: CFrame,
	pickupPivot: CFrame,
	boxCFrame: CFrame,
	humanoid: Humanoid?,
}

type Pry = {
	prop: PVInstance,
	startedAt: number,
	duration: number,
	lastNoise: number?,
	soundIndex: number,
}

local Grab = {}

local carriers: { [Player]: Carry } = {}
local carriedBy: { [PVInstance]: Player } = {}
local pries: { [Player]: Pry } = {}
-- Let-go props still falling: the parts to freeze again and the welds holding them together meanwhile
local settling: { [PVInstance]: { frozen: { BasePart }, welds: { WeldConstraint } } } = {}
local ownerWarnedAt: { [number]: number } = {}

local requestRemote: RemoteEvent
local dropRemote: RemoteEvent
local stateRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent
local pryRemote: RemoteEvent
local feedbackRemote: RemoteEvent

local boxOf = GrabFit.boxOf

local function partsOf(prop: PVInstance): { BasePart }
	local parts = {}
	if prop:IsA("BasePart") then
		table.insert(parts, prop)
	end
	for _, descendant in prop:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < 1e6
end

local function finiteVector(value: Vector3): boolean
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- Where a let-go prop starts falling from: where it's held if it fits there, otherwise straight
-- above the carrier's head.
local function letGoFrom(carry: Carry, player: Player, root: BasePart): CFrame
	local held = carry.boxCFrame
	if GrabFit.fits(carry.prop, carry.size, held, player, Settings.PlaceTolerance, true) then
		return held
	end
	return CFrame.new(root.Position + Vector3.new(0, 3 + carry.size.Magnitude / 2, 0)) * held.Rotation
end

local function grabbableOf(part: Instance): PVInstance?
	local instance: Instance? = part
	while instance and instance ~= workspace do
		if instance:IsA("PVInstance") and CollectionService:HasTag(instance, Settings.Tag) then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

-- An invisible box the size of the placed prop, so pathfinding and crawlers see it as solid even
-- where the mesh collision leaves gaps (under a couch, between chair legs). Plain parts already
-- are boxes. Transparency 1 keeps it out of every placement and grab check.
local function addBlocker(prop: PVInstance)
	if not (prop:IsA("Model") or prop:IsA("MeshPart")) or prop:FindFirstChild(BLOCKER) then
		return
	end
	local boxCFrame, size = boxOf(prop)
	local blocker = Instance.new("Part")
	blocker.Name = BLOCKER
	blocker.Anchored = true
	blocker.CanTouch = false
	blocker.CastShadow = false
	blocker.Transparency = 1
	blocker.Size = size
	blocker.CFrame = boxCFrame
	blocker.Parent = prop
end

local function removeBlocker(prop: PVInstance)
	local blocker = prop:FindFirstChild(BLOCKER)
	if blocker then
		blocker:Destroy()
	end
end

local function placedByOf(prop: Instance): number?
	local placedBy = prop:GetAttribute("PlacedBy")
	return if type(placedBy) == "number" then placedBy else nil
end

-- Freezes a let-go prop where it came to rest.
local function settle(prop: PVInstance)
	local state = settling[prop]
	if not state then
		return
	end
	settling[prop] = nil
	for _, part in state.frozen do
		part.Anchored = true
	end
	for _, weld in state.welds do
		weld:Destroy()
	end
end

-- Lets the prop fall with physics, welded to one piece so a multi-part prop doesn't come apart,
-- then freezes it once it's still.
local function fall(prop: PVInstance, frozen: { BasePart })
	local root = if prop:IsA("Model") and prop.PrimaryPart then prop.PrimaryPart else frozen[1]
	if not root then
		return
	end
	local state = { frozen = frozen, welds = {} }
	for _, part in frozen do
		if part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
			table.insert(state.welds, weld)
		end
	end
	for _, part in frozen do
		part.Anchored = false
	end
	pcall(root.SetNetworkOwner, root, nil)
	settling[prop] = state
	task.spawn(function()
		local started = os.clock()
		task.wait(0.5)
		while settling[prop] == state and os.clock() - started < Settings.SettleSeconds do
			local still = root.AssemblyLinearVelocity.Magnitude < SETTLED_SPEED
				and root.AssemblyAngularVelocity.Magnitude < SETTLED_SPEED
			if not root:IsDescendantOf(workspace) or still then
				break
			end
			task.wait(0.2)
		end
		if settling[prop] == state then
			settle(prop)
		end
	end)
end

-- placed: the carrier set it down somewhere new, so it becomes theirs. falls: let go with physics
-- from pivot instead of frozen there.
local function release(player: Player, carry: Carry, pivot: CFrame?, placed: boolean, falls: boolean?)
	if pivot and carry.prop:IsDescendantOf(workspace) then
		carry.prop:PivotTo(pivot)
	end
	if placed then
		carry.prop:SetAttribute("PlacedBy", player.UserId)
	end
	-- Back to how it was, so hinged parts (ModelRig) swing again. Nothing anchored before means
	-- nothing holds it up, so the whole prop freezes where it lands until the server resets.
	local anyAnchored = next(carry.anchored) ~= nil
	local frozen = {}
	for _, part in carry.parts do
		part.Anchored = carry.anchored[part] == true or not anyAnchored
		part.CanCollide = carry.collide[part]
		if part.Anchored then
			table.insert(frozen, part)
		end
	end
	if falls and carry.prop:IsDescendantOf(workspace) then
		fall(carry.prop, frozen)
	elseif placed then
		addBlocker(carry.prop)
	end
	player:SetAttribute("CarrySpeedMultiplier", nil)
	carriers[player] = nil
	carriedBy[carry.prop] = nil
	carry.prop:SetAttribute("CarriedBy", nil)
	if player.Parent then
		stateRemote:FireClient(player, nil)
	end
end

-- Death or respawn: let it fall from where it's held. Gone: put it back where it was picked up.
local function forceDrop(player: Player, carry: Carry)
	local root = bodyOf(player)
	if root then
		release(player, carry, letGoFrom(carry, player, root) * carry.pivotOffset, false, true)
		return
	end
	release(player, carry, carry.pickupPivot, false)
end

local function isGrabbable(prop: any): boolean
	return typeof(prop) == "Instance"
		and prop:IsA("PVInstance")
		and CollectionService:HasTag(prop, Settings.Tag)
		and prop:IsDescendantOf(workspace)
end

-- Gap between the player and the prop's edge, roughly.
local function distanceTo(root: BasePart?, prop: PVInstance): number
	if not root then
		return math.huge
	end
	local boxCFrame, size = boxOf(prop)
	local offset = boxCFrame.Position - root.Position
	local gap = GrabMath.reachGap(offset.X, offset.Y, offset.Z, Settings.GrabReachUp)
	return math.max(gap - size.Magnitude / 2, 0)
end

local function canGrabNow(player: Player, prop: PVInstance): (boolean, BasePart?, Humanoid?, string?)
	local root, humanoid = bodyOf(player)
	local ok, reason = GrabRules.canGrab({
		alive = root ~= nil,
		alreadyCarrying = carriers[player] ~= nil,
		carriedByOther = carriedBy[prop] ~= nil,
		distance = distanceTo(root, prop),
		reach = Settings.GrabReach,
	})
	return ok and humanoid ~= nil, root, humanoid, reason
end

-- Says why a grab or drop didn't happen instead of doing nothing
local function refuse(player: Player, reason: string?)
	local text = reason and Settings.Refused[reason]
	if text then
		feedbackRemote:FireClient(player, text)
	end
end

local function cancelPry(player: Player)
	if not pries[player] then
		return
	end
	pries[player] = nil
	if player.Parent then
		pryRemote:FireClient(player, nil)
	end
end

local function warnOwner(prop: PVInstance, raider: Player)
	local ownerId = placedByOf(prop)
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	if not owner or owner == raider then
		return
	end
	local now = os.clock()
	if GrabPry.due(ownerWarnedAt[owner.UserId], now, Settings.PryOwnerWarningCooldown) then
		ownerWarnedAt[owner.UserId] = now
		feedbackRemote:FireClient(owner, Settings.PryOwnerWarning)
	end
end

-- One creak of a pry: a loud noise robots hear and the next pry sound at the piece. Returns the
-- sound index to pass next time, so the creaks take turns.
local function pryNoise(prop: PVInstance, source: Instance?, soundIndex: number): number
	local holder = partsOf(prop)[1]
	if not holder then
		return soundIndex
	end
	Loudness.emit(holder.Position, "loud", source)
	local nextIndex = soundIndex % #Settings.PrySounds + 1
	local id = ModelLibrary.soundId(Settings.PrySounds[nextIndex])
	if not id then
		return nextIndex
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff("loud")
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return nextIndex
end

local function worldBox(cframe: CFrame, size: Vector3): FortLink.Box
	local position = cframe.Position
	local rotation = cframe.Rotation
	return {
		x = position.X,
		y = position.Y,
		z = position.Z,
		hx = GrabFit.reach(rotation, size, Vector3.xAxis),
		hy = GrabFit.reach(rotation, size, Vector3.yAxis),
		hz = GrabFit.reach(rotation, size, Vector3.zAxis),
	}
end

local function inBody(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- Whether a placed piece touches another placed piece or a wall (Logic/FortLink).
function Grab.isFortified(prop: PVInstance): boolean
	if placedByOf(prop) == nil or carriedBy[prop] then
		return false
	end
	local boxCFrame, size = boxOf(prop)
	local piece = worldBox(boxCFrame, size)
	local gap = Settings.FortGap
	local ignore: { Instance } = { prop }
	for _, name in { "Robots", "RobotStash" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local reach = Vector3.new(piece.hx, piece.hy, piece.hz) * 2 + Vector3.one * gap * 2
	local neighbours: { FortLink.Neighbour } = {}
	local seen = {}
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(boxCFrame.Position), reach, params) do
		local other = grabbableOf(part)
		if other then
			if not seen[other] and placedByOf(other) ~= nil and not carriedBy[other] then
				seen[other] = true
				local otherCFrame, otherSize = boxOf(other)
				table.insert(neighbours, { box = worldBox(otherCFrame, otherSize), placed = true })
			end
		elseif part.Anchored and part.Transparency < 1 and not inBody(part) then
			table.insert(neighbours, { box = worldBox(part.CFrame, part.Size), placed = false })
		end
	end
	return FortLink.fortified(piece, neighbours, gap, Settings.FortWallOverlap)
end

-- A pry creak from anything else pulling at a piece (a brute robot).
function Grab.pryNoise(prop: PVInstance, source: Instance?, soundIndex: number): number
	return pryNoise(prop, source, soundIndex)
end

-- prop starts a pry, nil means the player let go.
local function onPry(player: Player, prop: any)
	if prop == nil then
		pries[player] = nil
		return
	end
	if not (isGrabbable(prop) and GrabPry.needsPry(placedByOf(prop), player.UserId)) then
		pries[player] = nil
		pryRemote:FireClient(player, nil)
		return
	end
	local ok, _, _, reason = canGrabNow(player, prop)
	if not ok then
		pries[player] = nil
		pryRemote:FireClient(player, nil)
		refuse(player, reason)
		return
	end
	local duration = if Grab.isFortified(prop) then Settings.FortPrySeconds else Settings.PrySeconds
	pries[player] =
		{ prop = prop, startedAt = os.clock(), duration = duration, lastNoise = nil, soundIndex = 0 }
	-- the client times its bar from this, since only the server knows whether the piece is fortified
	pryRemote:FireClient(player, duration)
	warnOwner(prop, player)
end

local function onGrabRequest(player: Player, prop: any)
	if not isGrabbable(prop) then
		return
	end
	local ok, root, humanoid, reason = canGrabNow(player, prop)
	if not ok or not humanoid then
		refuse(player, reason)
		return
	end
	local parts = partsOf(prop)
	if #parts == 0 then
		return
	end
	if GrabPry.needsPry(placedByOf(prop), player.UserId) then
		local pry = pries[player]
		local finished = GrabPry.canFinish({
			started = pry ~= nil,
			samePiece = pry ~= nil and pry.prop == prop,
			elapsed = if pry then os.clock() - pry.startedAt else 0,
			duration = if pry then pry.duration else Settings.PrySeconds,
			grace = Settings.PryGrace,
			distance = distanceTo(root, prop),
			reach = Settings.GrabReach,
		})
		if not finished then
			cancelPry(player)
			return
		end
	end
	pries[player] = nil
	settle(prop)
	removeBlocker(prop)
	parts = partsOf(prop)
	local boxCFrame, size = boxOf(prop)

	local collide = {}
	local anchored = {}
	local mass = 0
	for _, part in parts do
		collide[part] = part.CanCollide
		anchored[part] = if part.Anchored then true else nil
		mass += part:GetMass()
		part.Anchored = true
		part.CanCollide = false
	end

	local multiplier = GrabMath.carrySpeedMultiplier(
		mass,
		Settings.LightMass,
		Settings.HeavyMass,
		Settings.MinSpeedMultiplier
	)
	local pivot = prop:GetPivot()
	local carry: Carry = {
		prop = prop,
		parts = parts,
		collide = collide,
		anchored = anchored,
		size = size,
		pivotOffset = boxCFrame:ToObjectSpace(pivot),
		pickupPivot = pivot,
		boxCFrame = boxCFrame,
		humanoid = humanoid,
	}
	-- The client Movement controller owns WalkSpeed and multiplies by this attribute.
	player:SetAttribute("CarrySpeedMultiplier", multiplier)
	carriers[player] = carry
	carriedBy[prop] = player
	prop:SetAttribute("CarriedBy", player.UserId)
	stateRemote:FireClient(player, prop)
end

-- letGo: the hold-to-drop escape, which always lets the prop fall right where it's held.
-- Otherwise box is where the client's ghost says it goes and eye is the camera it aimed from.
local function onDrop(player: Player, letGo: any, box: any, eye: any)
	local carry = carriers[player]
	local root, humanoid = bodyOf(player)
	if not carry or not root or not humanoid then
		return
	end
	if letGo == true then
		release(player, carry, letGoFrom(carry, player, root) * carry.pivotOffset, true, true)
		return
	end
	if typeof(box) ~= "CFrame" or typeof(eye) ~= "Vector3" then
		return
	end
	if not finiteVector(box.Position) or not finiteVector(eye) then
		return
	end
	local head = headOf(player)
	local eyeAt = if head then head.Position else root.Position
	if (eye - eyeAt).Magnitude <= Settings.CameraSlack then
		eyeAt = eye
	end
	local placeAt = box:Orthonormalize()
	local ok, reason = GrabFit.check({
		prop = carry.prop,
		size = carry.size,
		box = placeAt,
		carrier = player,
		root = root,
		humanoid = humanoid,
		eye = eyeAt,
		tolerance = Settings.PlaceTolerance + Settings.PlaceSlack,
		carrierBlocks = false,
		groundFound = true,
	})
	if ok then
		release(player, carry, placeAt * carry.pivotOffset, true)
	else
		refuse(player, reason)
	end
end

-- The carrier's hold, so everyone else sees the prop move. Kept within hold reach of the carrier.
local function onAim(player: Player, hold: any)
	local carry = carriers[player]
	local root = bodyOf(player)
	if not carry or not root or typeof(hold) ~= "CFrame" or not finiteVector(hold.Position) then
		return
	end
	local origin, target = root.Position, hold.Position
	local x, y, z = GrabMath.clampToReach(
		origin.X,
		origin.Y,
		origin.Z,
		target.X,
		target.Y,
		target.Z,
		Settings.MinHoldDistance,
		Settings.MaxHoldDistance
	)
	carry.boxCFrame = CFrame.new(x, y, z) * hold.Rotation:Orthonormalize()
	carry.prop:PivotTo(carry.boxCFrame * carry.pivotOffset)
end

local function stepPries(now: number)
	for player, pry in pries do
		local stillOk = isGrabbable(pry.prop) and canGrabNow(player, pry.prop)
		local abandoned = now - pry.startedAt > pry.duration + PRY_ABANDON_AFTER
		if not stillOk or abandoned then
			cancelPry(player)
		elseif GrabPry.due(pry.lastNoise, now, Settings.PryNoiseInterval) then
			pry.lastNoise = now
			pry.soundIndex = pryNoise(pry.prop, player, pry.soundIndex)
		end
	end
end

local function step()
	stepPries(os.clock())
	for player, carry in carriers do
		if not carry.prop:IsDescendantOf(workspace) then
			release(player, carry, nil, false)
			continue
		end
		local root, humanoid = bodyOf(player)
		if not root or not humanoid or humanoid ~= carry.humanoid then
			forceDrop(player, carry)
		end
	end
end

local TEST_PROPS = {
	{ name = "Couch", size = Vector3.new(7, 3, 3), color = Color3.fromRGB(120, 120, 125), count = 1 },
	{ name = "Shelf", size = Vector3.new(6, 6, 2), color = Color3.fromRGB(95, 95, 100), count = 1 },
	{ name = "Crate", size = Vector3.new(3, 3, 3), color = Color3.fromRGB(150, 145, 135), count = 4 },
	{ name = "Panel", size = Vector3.new(4, 7, 0.6), color = Color3.fromRGB(170, 170, 170), count = 6 },
}

local function spawnTestProps()
	local folder = Instance.new("Folder")
	folder.Name = "GrabTestProps"
	local origin = Settings.TestPropsOrigin
	local row = 0
	for _, kind in TEST_PROPS do
		for i = 1, kind.count do
			local part = Instance.new("Part")
			part.Name = kind.name
			part.Size = kind.size
			part.Color = kind.color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CFrame = CFrame.new(origin + Vector3.new((i - 1) * 8, kind.size.Y / 2, row * 8))
			CollectionService:AddTag(part, Settings.Tag)
			part.Parent = folder
		end
		row += 1
	end
	folder.Parent = workspace
end

function Grab:Init()
	requestRemote = Net.event("GrabRequest")
	dropRemote = Net.event("GrabDrop")
	stateRemote = Net.event("GrabState")
	aimRemote = Net.unreliable("GrabAim")
	pryRemote = Net.event("GrabPry")
	feedbackRemote = Net.event("SupplyFeedback")
end

function Grab:Start()
	requestRemote.OnServerEvent:Connect(onGrabRequest)
	dropRemote.OnServerEvent:Connect(onDrop)
	aimRemote.OnServerEvent:Connect(onAim)
	pryRemote.OnServerEvent:Connect(onPry)
	Players.PlayerRemoving:Connect(function(player)
		pries[player] = nil
		ownerWarnedAt[player.UserId] = nil
		local carry = carriers[player]
		if carry then
			forceDrop(player, carry)
		end
	end)
	RunService.Heartbeat:Connect(step)

	if Settings.SpawnTestProps then
		spawnTestProps()
	end
end

return Grab
