-- Grab and build. The server owns every carried prop: clients send aim and rotation,
-- the server moves the prop, finds where it lands, and freezes it there on drop.
-- Dropped props remember their placer in "PlacedBy"; anyone else has to pry them loose first.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local GrabPry = require(ReplicatedStorage.Shared.Logic.GrabPry)
local GrabRules = require(ReplicatedStorage.Shared.Logic.GrabRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)

local Loudness = require(script.Parent.Loudness)

local Settings = Config.Grab

-- Casts use a slightly smaller box so props can sit flush against walls and each other.
local CAST_SHRINK = 0.98
-- A finished pry the client never claims (lost remote, lag spike) stops making noise after this.
local PRY_ABANDON_AFTER = 2

type Carry = {
	prop: PVInstance,
	parts: { BasePart },
	collide: { [BasePart]: boolean },
	anchored: { [BasePart]: true }, -- only the parts that were anchored at pickup
	size: Vector3,
	pivotOffset: CFrame,
	pickupPivot: CFrame,
	boxCFrame: CFrame,
	angles: Vector3, -- tip, turn, roll in degrees
	aim: Vector3?,
	humanoid: Humanoid?,
	lastGhost: number,
}

type Pry = {
	prop: PVInstance,
	startedAt: number,
	lastNoise: number?,
	soundIndex: number,
}

local Grab = {}

local carriers: { [Player]: Carry } = {}
local carriedBy: { [PVInstance]: Player } = {}
local pries: { [Player]: Pry } = {}
local ownerWarnedAt: { [number]: number } = {}

local requestRemote: RemoteEvent
local dropRemote: RemoteEvent
local stateRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent
local ghostRemote: UnreliableRemoteEvent
local pryRemote: RemoteEvent
local feedbackRemote: RemoteEvent

local function boxOf(prop: PVInstance): (CFrame, Vector3)
	if prop:IsA("BasePart") then
		return prop.CFrame, prop.Size
	end
	return (prop :: Model):GetBoundingBox()
end

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

local function rotationOf(angles: Vector3): CFrame
	return CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
end

local function findLanding(carry: Carry, root: BasePart, humanoid: Humanoid): (CFrame?, boolean, string?)
	local rotation = rotationOf(carry.angles)
	local position = carry.boxCFrame.Position
	local x = GrabMath.snapToGrid(position.X, Settings.GridSize)
	local z = GrabMath.snapToGrid(position.Z, Settings.GridSize)
	local size = carry.size

	local ignore: { Instance } = { carry.prop }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.FilterDescendantsInstances = ignore
	castParams.RespectCanCollide = true

	local start = CFrame.new(x, position.Y, z) * rotation
	local hit =
		workspace:Blockcast(start, size * CAST_SHRINK, Vector3.new(0, -Settings.MaxDropFall, 0), castParams)
	if not hit then
		local ok, reason = GrabRules.canPlace({
			groundFound = false,
			distance = 0,
			reach = Settings.PlaceReach,
			heightAboveFeet = 0,
			maxHeightAboveFeet = Settings.MaxPlaceAboveFeet,
			blocked = false,
		})
		return nil, ok, reason
	end

	local halfHeight = GrabMath.verticalHalfExtent(
		size.X,
		size.Y,
		size.Z,
		rotation.RightVector.Y,
		rotation.UpVector.Y,
		rotation.LookVector.Y
	)
	local y = GrabMath.landingY(position.Y, hit.Distance, halfHeight, CAST_SHRINK)
	local landed = CFrame.new(x, y, z) * rotation

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { carry.prop }
	overlapParams.RespectCanCollide = true
	local overlapping = workspace:GetPartBoundsInBox(landed, size * CAST_SHRINK, overlapParams)

	local feetY = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local ok, reason = GrabRules.canPlace({
		groundFound = true,
		distance = (landed.Position - root.Position).Magnitude,
		reach = Settings.PlaceReach,
		heightAboveFeet = (y - halfHeight) - feetY,
		maxHeightAboveFeet = Settings.MaxPlaceAboveFeet,
		blocked = #overlapping > 0,
	})
	return landed, ok, reason
end

local function placedByOf(prop: Instance): number?
	local placedBy = prop:GetAttribute("PlacedBy")
	return if type(placedBy) == "number" then placedBy else nil
end

-- placed: the carrier set it down somewhere new, so it becomes theirs.
local function release(player: Player, carry: Carry, pivot: CFrame?, placed: boolean)
	if pivot and carry.prop:IsDescendantOf(workspace) then
		carry.prop:PivotTo(pivot)
	end
	if placed then
		carry.prop:SetAttribute("PlacedBy", player.UserId)
	end
	-- Back to how it was, so hinged parts (ModelRig) swing again. Nothing anchored before means
	-- nothing holds it up, so the whole prop freezes where it lands until the server resets.
	local anyAnchored = next(carry.anchored) ~= nil
	for _, part in carry.parts do
		part.Anchored = carry.anchored[part] == true or not anyAnchored
		part.CanCollide = carry.collide[part]
	end
	player:SetAttribute("CarrySpeedMultiplier", nil)
	carriers[player] = nil
	carriedBy[carry.prop] = nil
	carry.prop:SetAttribute("CarriedBy", nil)
	if player.Parent then
		stateRemote:FireClient(player, nil)
	end
end

-- Death, leaving or respawn: land it if the spot is good, otherwise put it back where it was picked up.
local function forceDrop(player: Player, carry: Carry)
	local root, humanoid = bodyOf(player)
	if root and humanoid then
		local landed, ok = findLanding(carry, root, humanoid)
		if landed and ok then
			release(player, carry, landed * carry.pivotOffset, true)
			return
		end
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
	return math.max((boxCFrame.Position - root.Position).Magnitude - size.Magnitude / 2, 0)
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

local function pryNoise(player: Player, pry: Pry)
	local parts = partsOf(pry.prop)
	local holder = parts[1]
	if not holder then
		return
	end
	Loudness.emit(holder.Position, "loud", player)
	pry.soundIndex = pry.soundIndex % #Settings.PrySounds + 1
	local id = ModelLibrary.soundId(Settings.PrySounds[pry.soundIndex])
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff("loud")
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
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
	pries[player] = { prop = prop, startedAt = os.clock(), lastNoise = nil, soundIndex = 0 }
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
			duration = Settings.PrySeconds,
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

	local tip, turn, roll = boxCFrame:ToEulerAnglesYXZ()
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
		angles = Vector3.new(
			GrabMath.wrapAngle(math.deg(tip)),
			GrabMath.wrapAngle(math.deg(turn)),
			GrabMath.wrapAngle(math.deg(roll))
		),
		aim = nil,
		humanoid = humanoid,
		lastGhost = 0,
	}
	-- The client Movement controller owns WalkSpeed and multiplies by this attribute.
	player:SetAttribute("CarrySpeedMultiplier", multiplier)
	carriers[player] = carry
	carriedBy[prop] = player
	prop:SetAttribute("CarriedBy", player.UserId)
	stateRemote:FireClient(player, prop)
end

local function onDrop(player: Player)
	local carry = carriers[player]
	local root, humanoid = bodyOf(player)
	if not carry or not root or not humanoid then
		return
	end
	local landed, ok, reason = findLanding(carry, root, humanoid)
	if landed and ok then
		release(player, carry, landed * carry.pivotOffset, true)
	else
		ghostRemote:FireClient(player, landed, carry.size, false)
		refuse(player, reason)
	end
end

local function onAim(player: Player, position: any, tip: any, turn: any, roll: any)
	local carry = carriers[player]
	if not carry or typeof(position) ~= "Vector3" then
		return
	end
	if not (isFiniteNumber(tip) and isFiniteNumber(turn) and isFiniteNumber(roll)) then
		return
	end
	if not (isFiniteNumber(position.X) and isFiniteNumber(position.Y) and isFiniteNumber(position.Z)) then
		return
	end
	carry.aim = position
	carry.angles = Vector3.new(GrabMath.wrapAngle(tip), GrabMath.wrapAngle(turn), GrabMath.wrapAngle(roll))
end

local function stepPries(now: number)
	for player, pry in pries do
		local stillOk = isGrabbable(pry.prop) and canGrabNow(player, pry.prop)
		local abandoned = now - pry.startedAt > Settings.PrySeconds + PRY_ABANDON_AFTER
		if not stillOk or abandoned then
			cancelPry(player)
		elseif GrabPry.due(pry.lastNoise, now, Settings.PryNoiseInterval) then
			pry.lastNoise = now
			pryNoise(player, pry)
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	stepPries(now)
	local alpha = 1 - math.exp(-dt * Settings.CarrySmoothing)
	for player, carry in carriers do
		if not carry.prop:IsDescendantOf(workspace) then
			release(player, carry, nil, false)
			continue
		end
		local root, humanoid = bodyOf(player)
		if not root or not humanoid or humanoid ~= carry.humanoid then
			forceDrop(player, carry)
			continue
		end

		local origin = root.Position
		local target = carry.aim or (origin + root.CFrame.LookVector * Settings.DefaultHoldDistance)
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
		local goal = CFrame.new(x, y, z) * rotationOf(carry.angles)
		carry.boxCFrame = carry.boxCFrame:Lerp(goal, alpha)
		carry.prop:PivotTo(carry.boxCFrame * carry.pivotOffset)

		if now - carry.lastGhost >= 1 / Settings.GhostRate then
			carry.lastGhost = now
			local landed, ok = findLanding(carry, root, humanoid)
			ghostRemote:FireClient(player, landed, carry.size, ok)
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
	ghostRemote = Net.unreliable("GrabGhost")
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
